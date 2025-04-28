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

    submission_type_str = None  # Store submission type for response
    word = None  # Store submitted word for response

    def transaction_update(current_data):
        nonlocal submission_type_str, word  # ✅ Allow modification outside the transaction
        points_to_add_to_user_id = 0
        points_to_remove_from_robbed_user = 0
        robbed_user_id = ''

        if not current_data:
            raise GameNotFoundError(f"Game with ID {game_id} not found.")

        # ✅ Step 1: Identify Submission Type INSIDE the Transaction
        submission_type, extra_data = identifyWordSubmissionType(
            current_data, user_id, tile_ids)
        submission_type_str = submission_type.name

        # ✅ Step 2: Construct the Submitted Word
        tiles = [tile_service.get_tile_from_data(
            current_data, tile_id) for tile_id in tile_ids]
        tiles.sort(key=lambda t: tile_ids.index(t['tileId']))
        word = ''.join(tile['letter']
                       for tile in tiles if tile and 'letter' in tile)

        # Handle invalid submissions
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
                'word': word,
                'tileIds': tile_ids
            })
            logger.debug(
                f"[submit_word] Invalid word submission logged: {word}")
            return current_data  # ✅ Only return modified game data

        # ✅ Step 3: Process Valid Word Submissions
        word_id = str(uuid.uuid4())

        word_data = {
            'wordId': word_id,
            'word': word,
            'user_id': user_id,
            'tileIds': tile_ids,
            'status': "valid",
            'current_owner_user_id': user_id,
            'word_history': []
        }
        # Get the amount of tileIds that are from the middle
        middle_tile_ids = [tile['tileId']
                           for tile in tiles if tile['location'] == 'middle']
        amount_of_middle_tiles_in_word = len(middle_tile_ids)
        print("there are this amount of middle tiles in the word:",
              amount_of_middle_tiles_in_word)

        if submission_type == WordSubmissionType.MIDDLE_WORD:
            word_data['word_history'].append({
                'word': word,
                'timestamp': int(datetime.now().timestamp() * 1000),
                'status': "valid",
                'tileIds': tile_ids,
                'playerId': user_id
            })
            current_data.setdefault('words', []).append(word_data)
            points_to_add_to_user_id = len(tile_ids)
            logger.debug(f"[submit_word] Middle word added: {word_data}")

        elif submission_type == WordSubmissionType.OWN_WORD_IMPROVEMENT:
            old_word_id = extra_data[0]
            old_word_index = next((index for (index, w) in enumerate(
                current_data['words']) if w['wordId'] == old_word_id), None)
            if old_word_index is not None:
                old_word = current_data['words'][old_word_index]
                old_word_history = old_word.get('word_history', [])
                old_word_history.append({
                    'word': old_word['word'],
                    'timestamp': int(datetime.now().timestamp() * 1000),
                    'status': "valid",
                    'tileIds': old_word['tileIds'],
                    'playerId': old_word['user_id']
                })
                word_data['word_history'] = old_word_history
                current_data['words'][old_word_index] = word_data
                points_to_add_to_user_id = amount_of_middle_tiles_in_word
                logger.debug(
                    f"[submit_word] Own word improvement: {word_data}")

        elif submission_type == WordSubmissionType.STEAL_WORD:
            stolen_word_ids = extra_data
            for stolen_word_id in stolen_word_ids:
                stolen_word_index = next((index for (index, w) in enumerate(
                    current_data['words']) if w["wordId"] == stolen_word_id), None)
                if stolen_word_index is not None:
                    stolen_word = current_data['words'][stolen_word_index]
                    stolen_word_history = stolen_word.get('word_history', [])
                    stolen_word_history.append({
                        'word': stolen_word['word'],
                        'timestamp': int(datetime.now().timestamp() * 1000),
                        'status': "stolen",
                        'tileIds': stolen_word['tileIds'],
                        'playerId': stolen_word['current_owner_user_id']
                    })
                    word_data['word_history'].extend(stolen_word_history)
                    current_data['words'].pop(stolen_word_index)
                    logger.debug(
                        f"[submit_word] Stolen word history updated: {stolen_word_history}")
            print(
                "👀 STEAL_WORD...points_to_add_to_user_id = len(tile_ids)= ", len(tile_ids))
            points_to_add_to_user_id = len(tile_ids)
            robbed_user_id = stolen_word['current_owner_user_id']
            # remove the amount of tiles that are in stolen word
            points_to_remove_from_robbed_user = len(stolen_word['tileIds'])
            current_data.setdefault('words', []).append(word_data)
            logger.debug(f"[submit_word] Stolen word added: {word_data}")

        else:
            logger.error(
                f"[submit_word] Unexpected submission type: {submission_type}")
            return None

        # 5. Update Tile Locations
        for tile in tiles:
            if tile and 'tileId' in tile:
                tile_id = tile['tileId']
                tile_index = next((index for (index, d) in enumerate(
                    current_data['tiles']) if d["tileId"] == tile_id), None)
                if tile_index is not None:
                    current_data['tiles'][tile_index]['location'] = word_id
                else:
                    logger.error(
                        f"[submit_word] Tile ID {tile_id} not found in current data.")
                    return None

        # 6. Update Remaining Letters
        remaining_letters = current_data.get('remainingLetters', {})
        for tile in tiles:
            if tile and 'letter' in tile:
                letter = tile['letter']
                if letter in remaining_letters and remaining_letters[letter] > 0:
                    remaining_letters[letter] -= 1
                    if remaining_letters[letter] == 0:
                        del remaining_letters[letter]
        current_data['remainingLetters'] = remaining_letters
        logger.debug(
            f"[submit_word] Remaining letters updated: {remaining_letters}")

        # 7. Update Player Score for submitting player & (optionally) robbed user
        submitting_player_data = current_data['players'].get(user_id)
        if submitting_player_data:
            submitting_player_data['score'] = (submitting_player_data.get(
                'score', 0) or 0) + points_to_add_to_user_id
            current_data['players'][user_id] = submitting_player_data
            logger.debug(
                f"[submit_word] Player score updated: {submitting_player_data['score']}")
        else:
            logger.error(
                f"[submit_word] Player ID {user_id} not found in current data.")
            return None
        # Remove points from player getting robbed

        if (robbed_user_id != ''):
            print(
                "about to remove points from a robbed user...the robbed_user_id = ", robbed_user_id)
            robbed_player_data = current_data['players'].get(robbed_user_id)
            if robbed_player_data:
                robbed_player_original_score = (
                    robbed_player_data.get('score', 0) or 0)
                print("👀 STEAL_WORD...robbing this user= ", robbed_user_id,
                      " whose score is currently (Before steal)=", robbed_player_data.get('score'))
                print("👀 STEAL_WORD...about to remove this many pts from the user: ",
                      points_to_remove_from_robbed_user)
                # Set their new score
                robbed_player_data['score'] = robbed_player_original_score - \
                    points_to_remove_from_robbed_user
                current_data['players'][robbed_user_id] = robbed_player_data

                print("👀 STEAL_WORD...their score is now=",
                      robbed_player_data['score'])
                logger.debug(
                    f"[submit_word] Player score updated: {robbed_player_data['score']}")
            else:
                logger.error(
                    f"[submit_word] Player ID {user_id} not found in current data.")
                return None
        # 8. Advance Turn if the word is valid
        if submission_type in (
            WordSubmissionType.MIDDLE_WORD,
            WordSubmissionType.OWN_WORD_IMPROVEMENT,
            WordSubmissionType.STEAL_WORD,
        ):
            current_data['currentPlayerTurn'] = user_id
            for player_id, player_data in current_data['players'].items():
                player_data['turn'] = (player_id == user_id)
                logger.debug(f"[submit_word] Player turn set to: {user_id}")

        # 9. Add Game Action
        add_game_action(current_data, game_id, {
            'type': submission_type.name,
            'playerId': user_id,
            'timestamp': int(datetime.now().timestamp() * 1000),
            'wordId': word_id,
            'word': word,
            'tileIds': tile_ids
        })
        logger.debug(
            f"[submit_word] Game action added: {submission_type.name}")

        return current_data
    try:
        result = game_ref.transaction(transaction_update)
        return {
            'success': True,
            'message': 'Word submitted successfully',
            'submission_type': submission_type_str,  # ✅ Send precomputed value
            'word': word  # ✅ Send submitted word
        }
    except db.TransactionAbortedError as e:
        logger.error(f"Transaction failed for game ID {game_id}: {e}")
        return {'success': False, 'message': 'Word submission failed'}
    except GameNotFoundError as e:
        logger.error(f"Game not found: {e}")
        return {'success': False, 'message': str(e)}
    except Exception as e:
        logger.error(f"An unexpected error occurred: {e}")
        return {'success': False, 'message': str(e)}


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
    logger.debug(f"[game_service.py][identifyWordSubmissionType] Start")
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
            f"[game_service.py][identifyWordSubmissionType] Invalid word length")
        return WordSubmissionType.INVALID_LENGTH, []
    if len(middle_tiles_used_in_word) == 0:
        logger.debug(
            f"[game_service.py][identifyWordSubmissionType] No middle tiles used")
        return WordSubmissionType.INVALID_NO_MIDDLE, []
    if not word_validation_service.uses_valid_letters(game_data, tiles):
        logger.debug(f"Checking if valid letters were used...")
        logger.debug(
            f"[game_service.py][identifyWordSubmissionType] Invalid letters used")
        return WordSubmissionType.INVALID_LETTERS_USED, []
    if not word_validation_service.is_valid_word(tiles, game_data.get("gameId")):
        logger.debug(
            f"[game_service.py][identifyWordSubmissionType] Word not in dictionary")
        return WordSubmissionType.INVALID_WORD_NOT_IN_DICTIONARY, []

    if len(tiles) == len(middle_tiles_used_in_word):
        logger.debug(
            f"[game_service.py][identifyWordSubmissionType] Middle word")
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
        return WordSubmissionType.STEAL_WORD, potential_words_to_steal_from

    logger.debug(
        f"[game_service.py][identifyWordSubmissionType] Returning Invalid Unknown Why")
    return WordSubmissionType.INVALID_UNKNOWN_WHY, []


def flip_tile(game_id, user_id):
    """Flips a tile within a transaction."""
    game_ref = firebase_service.get_db_reference(f'games/{game_id}')

    def flip_tile_transaction(current_data):
        if not current_data:
            raise GameNotFoundError(f"Game with ID {game_id} not found.")

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
        game_ref.transaction(flip_tile_transaction)
        print(f"Tile flipped successfully for game ID {game_id}.")
        return True
    except db.TransactionAbortedError as e:
        print(f"Transaction failed for flip_tile in game ID {game_id}: {e}")
        return False
    except GameNotFoundError as e:
        print(e)
        return False
    except Exception as e:
        print(f"An unexpected error occured: {e}")
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
            turn = False
            if order == 1:
                turn = True
            players[user_id] = {'game_id': game_id, 'username': username,
                                'score': 0, 'turn': turn, 'turnOrder': order}

        current_data['players'] = players
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


def create_game(user_id, username):
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
        print("🔄 remainingLetters = ", remainingLetters)
        print("🔄 num_tiles = ", num_tiles)

        new_game = {
            "currentPlayerTurn": user_id,
            "currentTurn": 0,
            "gameStatus": "inProgress",
            "remainingLetters": remainingLetters,
            "tiles": tiles,
            "words": [],
            "players": {}
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
