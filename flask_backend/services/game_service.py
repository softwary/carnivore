import logging
import colorlog
import random
import uuid
from enum import Enum
from datetime import datetime
from services import firebase_service, tile_service, word_validation_service, player_service
from logging_config import logger
from firebase_admin import db


class WordSubmissionType(Enum):
    INVALID_UNKNOWN_WHY = 0
    INVALID_LENGTH = 1
    INVALID_NO_MIDDLE = 2
    INVALID_LETTERS_USED = 3
    INVALID_WORD_NOT_IN_DICTIONARY = 4
    MIDDLE_WORD = 5
    OWN_WORD_IMPROVEMENT = 6
    STEAL_WORD = 7


class InvalidGameDataError(Exception):
    pass


class GameNotFoundError(Exception):
    pass


def add_game_action(current_data, game_id: str, action: dict):
    """Adds an action to the game's action log (works inside transactions).

    Args:
        current_data (dict): The current game data (from the transaction).
        game_id (str): The ID of the game (for logging purposes).
        action (dict): The action to log.
    """
    logger.debug(f"[add_game_action] Called for game {game_id}")
    logger.debug(f"[add_game_action] action = {action}")

    if 'actions' not in current_data:
        current_data['actions'] = {}

    action_id = action['type'] + '_' + str(uuid.uuid4())
    current_data['actions'][action_id] = action

    logger.debug(
        f"[add_game_action] Added action {action_id} to game {game_id}")


def submit_word(game_id: str, user_id: str, tile_ids: list[int]) -> dict:
    """Submits a word (new, improved, or stolen) within a transaction.

    This function handles the submission of a word in a game. It identifies the type of submission
    (new word, improvement of own word, or stealing another player's word) and processes it accordingly
    within a transaction.

    Args:
        game_id (str): The ID of the game.
        user_id (str): The ID of the user submitting the word.
        tile_ids (list[int]): A list of tile IDs used to form the word.

    Returns:
        dict: A dictionary containing the success status and a message. If successful, it also includes
              the type of submission.
    """
    game_ref = firebase_service.get_db_reference(f'games/{game_id}')

    submission_type_str = None
    submitted_word_str = None

    def transaction_update(current_data):
        nonlocal submission_type_str, submitted_word_str
        points_to_add_to_user_id = 0
        points_to_remove_from_robbed_user = 0
        robbed_user_id_for_action = ''
        primary_stolen_word_for_action = {}
        primary_original_word_for_action = {}
        winner_found = False

        if not current_data:
            raise GameNotFoundError(f"Game with ID {game_id} not found.")

        max_score_to_win_per_player = current_data.get(
            'max_score_to_win_per_player')

        submission_type, extra_data = identifyWordSubmissionType(
            current_data, user_id, tile_ids)
        submission_type_str = submission_type.name

        tiles_for_word = [tile_service.get_tile_from_data(
            current_data, tile_id) for tile_id in tile_ids]
        tiles_for_word.sort(key=lambda t: tile_ids.index(t['tileId']))

        current_word_string = ''.join(tile['letter']
                                      for tile in tiles_for_word if tile and 'letter' in tile)
        submitted_word_str = current_word_string

        if submission_type in (
            WordSubmissionType.INVALID_UNKNOWN_WHY,
            WordSubmissionType.INVALID_LENGTH,
            WordSubmissionType.INVALID_NO_MIDDLE,
            WordSubmissionType.INVALID_LETTERS_USED,
            WordSubmissionType.INVALID_WORD_NOT_IN_DICTIONARY,
        ):
            add_game_action(current_data, game_id, {
                'type': submission_type_str,
                'playerId': user_id,
                'timestamp': int(datetime.now().timestamp() * 1000),
                'word': current_word_string,
                'tileIds': tile_ids
            })
            logger.debug(
                f"[submit_word] Invalid word submission logged: {current_word_string}")
            return current_data

        # This new_word_id will be used for the word being created/submitted
        new_word_id = str(uuid.uuid4())

        # Base structure for the new word being submitted
        new_word_data = {
            'wordId': new_word_id,
            'word': current_word_string,
            'tileIds': tile_ids,
            'status': "valid",
            'current_owner_user_id': user_id,
            'word_history': []
        }

        middle_tile_ids_in_word = [tile['tileId']
                                   for tile in tiles_for_word if tile['location'] == 'middle']
        amount_of_middle_tiles_in_word = len(middle_tile_ids_in_word)

        original_word_id_for_action = None

        if submission_type == WordSubmissionType.MIDDLE_WORD:
            new_word_data['word_history'].append({
                'word': current_word_string,
                'timestamp': int(datetime.now().timestamp() * 1000),
                'status': "valid_middle_word",
                'tileIds': tile_ids,
                'playerId': user_id
            })
            current_data.setdefault('words', []).append(new_word_data)
            points_to_add_to_user_id = len(tile_ids)
            logger.debug(f"[submit_word] Middle word added: {new_word_data}")

        elif submission_type == WordSubmissionType.OWN_WORD_IMPROVEMENT:
            old_word_id = extra_data[0]
            original_word_id_for_action = old_word_id

            old_word_index = next((index for (index, w) in enumerate(
                current_data.get('words', [])) if w['wordId'] == old_word_id), None)

            if old_word_index is not None:
                old_word_ref = current_data['words'][old_word_index]
                primary_original_word_for_action = {
                    'word': old_word_ref['word'], 'wordId': old_word_ref['wordId']}

                # 1. Update the old word
                old_word_ref['status'] = "improved_upon_by_owner"
                old_word_ref['transformedToWordId'] = new_word_id
                old_word_ref.setdefault('word_history', []).append({
                    'word': old_word_ref['word'],
                    'timestamp': int(datetime.now().timestamp() * 1000),
                    'status': "valid_own_word_improvement",
                    'tileIds': old_word_ref['tileIds'],
                    'playerId': old_word_ref['current_owner_user_id'],
                    'improvedTo': new_word_id,
                    'improvedToWordString': current_word_string
                })

                # 2. Prepare the new word data (improvement)
                new_word_data['previousWordId'] = old_word_id
                new_word_data['word_history'].append({
                    'word': current_word_string,
                    'timestamp': int(datetime.now().timestamp() * 1000),
                    'status': "valid_own_word_improvement",
                    'tileIds': tile_ids,
                    'playerId': user_id,
                    'improvedFromWordId': old_word_id,
                    'improvedFromWordString': old_word_ref['word']
                })
                current_data.setdefault('words', []).append(new_word_data)
                points_to_add_to_user_id = amount_of_middle_tiles_in_word
                logger.debug(
                    f"[submit_word] Own word improvement: Old word '{old_word_ref['word']}' ({old_word_id}) status updated. New word '{current_word_string}' ({new_word_id}) added.")
            else:
                logger.error(
                    f"❌ [submit_word] OWN_WORD_IMPROVEMENT: Original word {old_word_id} not found.")
                # Decide if this should abort or be logged as an anomaly
                return None  # Abort transaction

        elif submission_type == WordSubmissionType.STEAL_WORD:
            stolen_word_ids_from_extra = extra_data  # A list of words that can be stolen

            # The first word in the list is the word that should be stolen, since that player has the highest score
            if not stolen_word_ids_from_extra:
                logger.error(
                    "[submit_word] STEAL_WORD: No stolen_word_ids provided in extra_data.")
                return None  # Abort

            # Link to the first stolen word for `previousWordId` on the new word object.
            # The action log can list all original IDs.
            primary_stolen_word_id_for_linking = stolen_word_ids_from_extra[0]
            new_word_data['previousWordId'] = primary_stolen_word_id_for_linking
            original_word_id_for_action = primary_stolen_word_id_for_linking

            temp_robbed_user_id = None
            temp_robbed_word_tile_count = 0

            for i, stolen_word_id_iteration in enumerate(stolen_word_ids_from_extra):
                stolen_word_index = next((index for (index, w) in enumerate(
                    current_data.get('words', [])) if w["wordId"] == stolen_word_id_iteration), None)

                if stolen_word_index is not None:
                    stolen_word_ref = current_data['words'][stolen_word_index]

                    if i == 0:  # Capture details from the primary stolen word
                        temp_robbed_user_id = stolen_word_ref['current_owner_user_id']
                        temp_robbed_word_tile_count = len(
                            stolen_word_ref['tileIds'])
                        primary_stolen_word_for_action = {
                            'word': stolen_word_ref['word'], 'wordId': stolen_word_ref['wordId']}

                    # 1. Update the stolen word
                    stolen_word_ref['status'] = "stolen"
                    stolen_word_ref['transformedToWordId'] = new_word_id
                    stolen_word_ref['stolenByPlayerId'] = user_id
                    stolen_word_ref.setdefault('word_history', []).append({
                        'word': stolen_word_ref['word'],
                        'timestamp': int(datetime.now().timestamp() * 1000),
                        'status': "stolen",
                        'tileIds': stolen_word_ref['tileIds'],
                        'playerId': stolen_word_ref['current_owner_user_id'],
                        'stolenBy': user_id,
                        'becameWordId': new_word_id,
                        'becameWordString': current_word_string
                    })
                    logger.debug(
                        f"[submit_word] Stolen word '{stolen_word_ref['word']}' ({stolen_word_id_iteration}) status updated.")
                else:
                    logger.warning(
                        f"[submit_word] STEAL_WORD: Stolen word {stolen_word_id_iteration} not found. Continuing if others exist.")

            if temp_robbed_user_id is None:
                logger.error(
                    "❌ [submit_word] STEAL_WORD: Could not determine robbed user ID from stolen words.")
                return None

            robbed_user_id_for_action = temp_robbed_user_id
            points_to_remove_from_robbed_user = temp_robbed_word_tile_count

            # 2. Prepare the new word data (steal)
            new_word_data['word_history'].append({
                'word': current_word_string,
                'timestamp': int(datetime.now().timestamp() * 1000),
                'status': "valid_steal",
                'tileIds': tile_ids,
                'playerId': user_id,
                'stoleFromPrimaryWordId': primary_stolen_word_id_for_linking,
                'stoleFromPrimaryWordString': primary_stolen_word_for_action.get('word', '')
            })
            current_data.setdefault('words', []).append(new_word_data)

            points_to_add_to_user_id = len(tile_ids)
            logger.debug(
                f"[submit_word] New word '{current_word_string}' ({new_word_id}) from steal added.")

        else:
            logger.error(
                f"[submit_word] Unexpected submission type: {submission_type}")
            return None

        # 5. Update Tile Locations to the new_word_id
        for tile_obj in tiles_for_word:  # Use the fetched tile objects
            if tile_obj and 'tileId' in tile_obj:
                tile_id_to_update = tile_obj['tileId']
                tile_index_in_gamedata = next((index for (index, d) in enumerate(
                    current_data['tiles']) if d["tileId"] == tile_id_to_update), None)
                if tile_index_in_gamedata is not None:
                    # Use new_word_id
                    current_data['tiles'][tile_index_in_gamedata]['location'] = new_word_id
                else:
                    logger.error(
                        f"[submit_word] Tile ID {tile_id_to_update} not found in current data for location update.")
                    return None

        # 6. Update Player Score
        submitting_player_data = current_data['players'].get(user_id)
        if submitting_player_data:
            submitting_player_data['score'] = (submitting_player_data.get(
                'score', 0) or 0) + points_to_add_to_user_id
            logger.debug(
                f"[submit_word] Player {user_id} score updated to: {submitting_player_data['score']}")
            if max_score_to_win_per_player and submitting_player_data['score'] >= max_score_to_win_per_player:
                winner_found = True
                current_data['status'] = 'winnerFound'
                current_data['winner'] = {'userId': user_id, 'username': submitting_player_data.get(
                    'username', ''), 'score': submitting_player_data['score']}
                logger.debug(
                    f"🎉 [submit_word] Player {user_id} has reached the winning score: {submitting_player_data['score']}")
        else:
            logger.error(
                f"[submit_word] Submitting player ID {user_id} not found.")
            return None

        if robbed_user_id_for_action and points_to_remove_from_robbed_user > 0:
            robbed_player_data = current_data['players'].get(
                robbed_user_id_for_action)
            if robbed_player_data:
                robbed_player_original_score = (
                    robbed_player_data.get('score', 0) or 0)
                robbed_player_data['score'] = robbed_player_original_score - \
                    points_to_remove_from_robbed_user
                logger.debug(
                    f"[submit_word] Robbed player {robbed_user_id_for_action} score updated to: {robbed_player_data['score']}")
            else:
                logger.error(
                    f"[submit_word] Robbed player ID {robbed_user_id_for_action} not found.")
                # Decide if this should abort. For now, continue.

        # 7. Advance Turn
        if not winner_found and submission_type in (
            WordSubmissionType.MIDDLE_WORD,
            WordSubmissionType.OWN_WORD_IMPROVEMENT,
            WordSubmissionType.STEAL_WORD,
        ):
            current_data['currentPlayerTurn'] = user_id
            for player_id, player_data in current_data['players'].items():
                player_data['turn'] = (player_id == user_id)
                logger.debug(f"[submit_word] Player turn set to: {user_id}")

        # 8. Add Game Action
        action_payload = {
            'type': submission_type.name,
            'playerId': user_id,
            'timestamp': int(datetime.now().timestamp() * 1000),
            'wordId': new_word_id,  # ID of the word state created by this action
            'word': current_word_string,  # The actual word string formed
            'tileIds': tile_ids
        }

        if submission_type == WordSubmissionType.STEAL_WORD:
            action_payload['robbedUserId'] = robbed_user_id_for_action
            action_payload['originalWordId'] = primary_stolen_word_for_action.get(
                'wordId')
            action_payload['originalWordString'] = primary_stolen_word_for_action.get(
                'word')
        elif submission_type == WordSubmissionType.OWN_WORD_IMPROVEMENT:
            action_payload['originalWordId'] = primary_original_word_for_action.get(
                'wordId')
            action_payload['originalWordString'] = primary_original_word_for_action.get(
                'word')
            print('🧡🧡🧡originalWordString = ', primary_original_word_for_action.get('word'))

        add_game_action(current_data, game_id, action_payload)
        logger.debug(f"[submit_word] Game action added: {action_payload}")

        return current_data
    try:
        game_ref.transaction(transaction_update)
        return {
            'success': True,
            'message': 'Word submitted successfully',
            'submission_type': submission_type_str,
            'word': submitted_word_str
        }
    except db.TransactionAbortedError as e:
        logger.error(f"Transaction failed for game ID {game_id}: {e}")
        return {'success': False, 'message': 'Word submission failed due to conflict or error.'}
    except GameNotFoundError as e:
        logger.error(
            f"Game not found during transaction for game ID {game_id}: {e}")
        return {'success': False, 'message': str(e)}
    except Exception as e:
        # Use logger.exception for stack trace
        logger.exception(
            f"An unexpected error occurred in submit_word for game ID {game_id}: {e}")
        return {'success': False, 'message': f'An unexpected error occurred: {str(e)}'}


def identifyWordSubmissionType(game_data, user_id, tile_ids):
    """Identifies the type of word submission based on the provided game data.

    This function analyzes the submitted tiles and determines the type of word 
    submission. It checks for various conditions such as word length, usage of 
    middle tiles, validity of letters, and whether the word exists in the 
    dictionary. It also identifies if the submission is an improvement of the 
    user's own word or a potential steal from another player.

    Args:
        game_data (dict): The game data containing information about the current 
            state of the game, including tiles and words.
        user_id (str): The ID of the user submitting the word.
        tile_ids (list): A list of tile IDs that are being submitted.

    Returns:
        tuple: A tuple containing the type of word submission (WordSubmissionType) 
        and a list of word IDs if applicable.

    Raises:
        GameNotFoundError: If the game data is None.
    """
    if not game_data:
        logger.debug(
            f"[game_service.py][identifyWordSubmissionType] Game data is None.")
        raise GameNotFoundError(f"Game data is None.")  # Use custom exception.

    tiles = [tile_service.get_tile_from_data(
        game_data, tile_id) for tile_id in tile_ids]
    middle_tiles_used_in_word = word_validation_service.get_middle_tiles_used_in_word(
        tiles)
    logger.debug(
        f"[game_service.py][identifyWordSubmissionType] Tiles: {tiles}")
    logger.debug(
        f"[game_service.py][identifyWordSubmissionType] Middle Tiles Used: {middle_tiles_used_in_word}")

    if not word_validation_service.is_valid_word_length(tiles):
        logger.debug(
            "[game_service.py][identifyWordSubmissionType] Invalid word length")
        return WordSubmissionType.INVALID_LENGTH, []
    if len(middle_tiles_used_in_word) == 0:
        logger.debug(
            "[game_service.py][identifyWordSubmissionType] No middle tiles used")
        return WordSubmissionType.INVALID_NO_MIDDLE, []
    if not word_validation_service.uses_valid_letters(game_data, tiles):
        logger.debug(f"Checking if valid letters were used...")
        logger.debug(
            "[game_service.py][identifyWordSubmissionType] Invalid letters used")
        return WordSubmissionType.INVALID_LETTERS_USED, []
    if not word_validation_service.is_valid_word(tiles, game_data.get("gameId")):
        logger.debug(
            "[game_service.py][identifyWordSubmissionType] Word not in dictionary")
        return WordSubmissionType.INVALID_WORD_NOT_IN_DICTIONARY, []

    if len(tiles) == len(middle_tiles_used_in_word):
        logger.debug(
            "[game_service.py][identifyWordSubmissionType] Middle word")
        return WordSubmissionType.MIDDLE_WORD, []

    potential_words_to_steal_from = []
    words = game_data.get("words", {})
    logger.debug(
        f"[game_service.py][identifyWordSubmissionType] Words in game: {words}")

    for word in words:
        if word["status"] != "valid":
            continue

        word_tile_ids = set(word["tileIds"])
        submitted_tile_ids = set(tile_ids)
        middle_tile_ids = set(tile["tileId"]
                              for tile in middle_tiles_used_in_word)

        if word_tile_ids.issubset(submitted_tile_ids - middle_tile_ids):
            if word["current_owner_user_id"] == user_id:
                logger.debug(
                    f"[game_service.py][identifyWordSubmissionType] Own word improvement: {word['wordId']}")
                return WordSubmissionType.OWN_WORD_IMPROVEMENT, [word["wordId"]]
            else:
                potential_words_to_steal_from.append(word["wordId"])

    if potential_words_to_steal_from:
        logger.debug(
            f"[game_service.py][identifyWordSubmissionType] Potential words to steal: {potential_words_to_steal_from}")
        order_words_by_player_score(game_data, potential_words_to_steal_from)
        return WordSubmissionType.STEAL_WORD, potential_words_to_steal_from

    logger.debug(
        "[game_service.py][identifyWordSubmissionType] Returning Invalid Unknown Why")
    return WordSubmissionType.INVALID_UNKNOWN_WHY, []


def order_words_by_player_score(game_data: dict, potential_word_ids_to_steal_from: list[str]) -> list[str]:
    """Orders a list of word IDs based on the score of their current owners.

    The ordering is from the highest owner score to the lowest. Words whose
    owners or scores cannot be determined are typically treated as having a low score
    for sorting purposes.

    Args:
        game_data (dict): The current game data, containing all words and player information.
        potential_word_ids_to_steal_from (list[str]): A list of word IDs
            representing words that are candidates for stealing.

    Returns:
        list[str]: An ordered list of word IDs, sorted by the score of their
                   respective owners in descending order.
    """

    word_owner_details = []
    all_words_in_game = game_data.get("words", [])
    players_data = game_data.get("players", {})

    # Create a more efficient lookup for word objects by their ID
    word_map = {
        word.get("wordId"): word for word in all_words_in_game if word.get("wordId")}

    for word_id in potential_word_ids_to_steal_from:
        word_obj = word_map.get(word_id)
        owner_score = 0  # Default score if owner/score is not found

        if word_obj:
            owner_id = word_obj.get("current_owner_user_id")
            if owner_id and owner_id in players_data:
                owner_score = players_data[owner_id].get("score") or 0
            else:
                if owner_id:
                    logger.warning(
                        f"Owner ID '{owner_id}' for word '{word_id}' not found in players data. Assigning score 0.")
                else:
                    logger.warning(
                        f"Word '{word_id}' is missing 'current_owner_user_id'. Assigning score 0.")
        else:
            logger.warning(
                f"Word ID '{word_id}' not found in game words. Assigning score 0 for sorting.")

        word_owner_details.append({"word_id": word_id, "score": owner_score})

    # Sort the collected details by score in descending order
    sorted_word_details = sorted(
        word_owner_details, key=lambda x: x["score"], reverse=True)

    # Extract and return only the ordered word_ids
    ordered_word_ids = [item["word_id"] for item in sorted_word_details]

    return ordered_word_ids


def flip_tile(game_id, user_id):
    """Flips a tile within a transaction."""
    game_ref = firebase_service.get_db_reference(f'games/{game_id}')
    print("⭐️game_id = ", game_id)
    print("⭐️user_id = ", user_id)

    def flip_tile_transaction(current_data):
        if not current_data:
            raise GameNotFoundError(f"Game with ID {game_id} not found.")

        if current_data.get('currentPlayerTurn') != user_id:
            logger.warning(
                f"User {user_id} attempted to flip a tile, but it is not their turn.")
            return  # Abort the transaction.

        tiles = current_data.get('tiles', [])
        remaining_letters = current_data.get('remainingLetters', {})

        unflipped_tiles = [
            tile for tile in tiles if tile['location'] == 'unflippedTilesPool']
        available_letters = {l: c for l,
                             c in remaining_letters.items() if c > 0}
        print("🔄 available_letters = ", available_letters)
        print(" ")
        # if not unflipped_tiles or not any(remaining_letters.values()):
        if not unflipped_tiles or not available_letters:

            logger.debug(
                "flip_tile()... No unflipped tiles or no available letters.")

            return current_data  # Return unchanged data.  Don't abort.

        tile = random.choice(unflipped_tiles)
        # Choose from letters that actually have counts > 0
        letters, counts = zip(*available_letters.items())

        positive_counts = [max(0, c) for c in counts]
        if not any(positive_counts):  # Double check if somehow all counts became zero or negative
            logger.warning(
                "flip_tile()... No letters with positive counts available for selection.")
            return current_data

        letter = random.choices(letters, weights=positive_counts, k=1)[0]
        logger.debug(f"🔄 Chosen letter: {letter}")

        tile_index = next((index for (index, t) in enumerate(
            tiles) if t['tileId'] == tile['tileId']), None)
        if tile_index is None:
            logger.error(
                f"Error: Could not find tile with ID {tile['tileId']} in flip_tile")
            # Abort transaction if tile index not found
            raise ValueError(
                f"Tile with ID {tile['tileId']} not found during transaction.")

        # Update the tile *within* the current_data
        current_data['tiles'][tile_index]['letter'] = letter
        current_data['tiles'][tile_index]['location'] = 'middle'
        current_data['tiles'][tile_index]['flippedTimestamp'] = int(datetime.now().timestamp() * 1000)

        # Update remainingLetters count
        # Use the original remaining_letters dict for updating
        if letter in remaining_letters:
            remaining_letters[letter] -= 1
            # Remove the letter key if its count drops to 0 or below
            if remaining_letters[letter] <= 0:
                del remaining_letters[letter]
        else:
            logger.error(
                f"Chosen letter '{letter}' not found in remaining_letters dictionary. This should not happen.")
            # Decide how to handle this error - potentially abort
            raise ValueError(
                f"Inconsistency: Chosen letter '{letter}' not in remaining_letters.")

        # Assign the modified dictionary back
        current_data['remainingLetters'] = remaining_letters

        # Add game action *within* the transaction
        add_game_action(current_data, game_id, {
            'type': 'flip_tile',
            'playerId': user_id,
            'timestamp': int(datetime.now().timestamp() * 1000),
            'tileId': tile['tileId'],
            'tileLetter': letter
        })

        # Advance Player Turn
        players = current_data.get('players', {})
        player_ids = list(players.keys())
        current_player_id = current_data.get('currentPlayerTurn')
        current_index = player_ids.index(
            current_player_id) if current_player_id in player_ids else -1
        next_index = (current_index + 1) % len(player_ids)
        next_player_id = player_ids[next_index]

        for player_id, player_data in players.items():
            player_data['turn'] = (player_id == next_player_id)

        current_data['currentPlayerTurn'] = next_player_id
        current_data['players'] = players

        return current_data

    try:
        updated_data = game_ref.transaction(flip_tile_transaction)
        print(f"Tile flipped successfully for game ID {game_id}.")
        # Log the remainingLetters after choosing a letter
        remaining_letters = updated_data.get('remainingLetters', {})
        logger.debug(
            f"🔄 remainingLetters after choosing a letter: {remaining_letters}")

        return True
    except db.TransactionAbortedError as e:
        print(f"Transaction failed for flip_tile in game ID {game_id}: {e}")
        return False
    except GameNotFoundError as e:
        print(e)
        print("⭐️ Game not found during flip_tile transaction.")
        return False
    except Exception as e:
        print("⭐️ Exception in flip_tile transaction:")
        logger.exception(f"An unexpected error occurred in flip_tile: {e}")
        print(f"An unexpected error occurred: {e}")
        return False


def is_game_over(game_id):
    """Checks if a game is over."""
    game_data = firebase_service.get_game(game_id)
    if not game_data:
        return True

    remaining_letters = game_data.get("remainingLetters")
    if not remaining_letters:
        return True

    return False


def get_game(game_id):
    """Retrieves a game from the database."""
    ref = firebase_service.get_db_reference(f'games/{game_id}')
    return ref.get()


def update_game(game_id, updated_data):
    """Updates a game in the database."""
    ref = firebase_service.get_db_reference(f'games/{game_id}')
    ref.update(updated_data)


def add_player_to_game(game_id, user_id, username):
    """Adds a player to a game within a transaction."""
    game_ref = firebase_service.get_db_reference(f'games/{game_id}')

    def update_players(current_data):
        if current_data is None:
            current_data = {'players': {}}

        players = current_data.get('players', {})
        if user_id not in players:
            order = len(players) + 1
            # if game type is computer, set turn to True
            turn = True
            if order == 1:
                turn = True
            players[user_id] = {'game_id': game_id, 'username': username,
                                'score': 0, 'turn': turn, 'turnOrder': order}

        current_data['players'] = players

        # Recalculate max_score_to_win_per_player: total tiles / number of players
        total_tiles = len(current_data.get('tiles', []))
        num_players = len(players)
        if num_players > 0:
            current_data['max_score_to_win_per_player'] = total_tiles // num_players

        return current_data

    try:
        game_ref.transaction(update_players)
        return True
    except db.TransactionAbortedError as e:
        logger.error(
            f"Transaction failed for adding player to game ID {game_id}: {e}")
        return False
    except Exception as e:
        logger.error(
            f"An unexpected error occurred while adding player to game: {e}")
        return False


def create_game(user_id, username, game_type):
    """Creates a new game in the database with the user_id as a player."""
    ref = firebase_service.get_db_reference('games')
    game_id = str(uuid.uuid4().int)[:4]

    def transaction_create_game(current_data):
        remainingLetters = {
            "A": 11,
            "B": 2,
            "C": 4,
            "D": 6,
            "E": 18,
            "F": 3,
            "G": 4,
            "H": 6,
            "I": 13,
            "J": 2,
            "K": 2,
            "L": 6,
            "M": 4,
            "N": 9,
            "O": 11,
            "P": 3,
            "Q": 2,
            "R": 8,
            "S": 6,
            "T": 11,
            "U": 5,
            "V": 2,
            "W": 3,
            "X": 2,
            "Y": 3,
            "Z": 2,
        }
        num_tiles = sum(remainingLetters.values())
        tiles = [
            {"letter": "", "location": "unflippedTilesPool", "tileId": i}
            for i in range(num_tiles)
        ]
        max_score_to_win_per_player = num_tiles

        print("🔄 remainingLetters = ", remainingLetters)
        print("🔄 num_tiles = ", num_tiles)
        players = {}
        if game_type == "computer":
            players = {
                "computer": {
                    'game_id': game_id, 'username': 'computer',
                    'score': 0, 'turn': False, 'turnOrder': 1

                },
            }
        new_game = {
            "gameType": game_type,
            "currentPlayerTurn": user_id,
            "currentTurn": 0,
            "gameStatus": "inProgress",
            "remainingLetters": remainingLetters,
            "tiles": tiles,
            "words": [],
            "players": players,
        }
        current_data[game_id] = new_game
        return current_data

    try:
        ref.transaction(transaction_create_game)
        success = add_player_to_game(game_id, user_id, username)
        if success:
            return game_id
        else:
            return None
    except db.TransactionAbortedError as e:
        logger.error(f"Transaction failed for creating game: {e}")
        return None
    except Exception as e:
        logger.error(f"An unexpected error occurred while creating game: {e}")
        return None


def delete_game(game_id):
    """Deletes a game from the database."""
    ref = firebase_service.get_db_reference(f'games/{game_id}')
    ref.delete()


def get_games_with_current_player(player_id):
    """
    Retrieves games from the database where the 'currentPlayerTurn' is the given player_id.

    Args:
        player_id (str): The ID of the player whose turn it currently is.

    Returns:
        dict or None: A dictionary of games matching the criteria, or None if no games are found.
                      The dictionary keys will be the game IDs.
    """
    print(f"Querying games for currentPlayerTurn = '{player_id}'...")
    try:
        games_snapshot = firebase_service.get_db_reference("games") \
                                         .order_by_child("currentPlayerTurn") \
                                         .equal_to(player_id) \
                                         .get()
        all_game_ids = list(games_snapshot.keys())

        print(f"All Game IDs: {all_game_ids}")
        return all_game_ids
    except Exception as e:
        print(f"An error occurred while fetching games: {e}")
        return None
