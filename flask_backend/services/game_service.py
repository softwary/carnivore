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

    logger.debug(f"[add_game_action] Added action {action_id} to game {game_id}")

def submit_word(game_id: str, user_id: str, tile_ids: list[int]) -> dict:
    """Submits a word (new, improved, or stolen) within a transaction."""
    game_ref = firebase_service.get_db_reference(f'games/{game_id}')

    def transaction_update(current_data):
        if not current_data:
            raise GameNotFoundError(f"Game with ID {game_id} not found.")

        # 1. Identify Submission Type and Validate
        submission_type, extra_data = identifyWordSubmissionType(
            current_data, user_id, tile_ids
        )

        logger.debug(f"[submit_word] Submission type: {submission_type}, Extra data: {extra_data}")

        if submission_type in (
            WordSubmissionType.INVALID_UNKNOWN_WHY,
            WordSubmissionType.INVALID_LENGTH,
            WordSubmissionType.INVALID_NO_MIDDLE,
            WordSubmissionType.INVALID_LETTERS_USED,
            WordSubmissionType.INVALID_WORD_NOT_IN_DICTIONARY,
        ):
            tiles = [tile_service.get_tile_from_data(current_data, tile_id) for tile_id in tile_ids]
            word = ''.join(tile['letter'] for tile in tiles if tile and 'letter' in tile)
            print("This is an invalid submission_type in submit_word().")
            logger.debug(f"tiles = {tiles} | Word = {word}")
            # Handle invalid word submission
            add_game_action(current_data, game_id, {
                'type': submission_type.name,
                'playerId': user_id,
                'timestamp': int(datetime.now().timestamp() * 1000),
                'word': word,
                'tileIds': tile_ids
            })
            logger.debug(f"[submit_word] Invalid word submission logged: {word}")
            return current_data

        # 2. Construct the Word
        tiles = [tile_service.get_tile_from_data(current_data, tile_id) for tile_id in tile_ids]
        tiles.sort(key=lambda t: tile_ids.index(t['tileId']))
        word = ''.join([tile['letter'] for tile in tiles if tile and 'letter' in tile])
        word_id = str(uuid.uuid4())

        logger.debug(f"[submit_word] Constructed word: {word}, Word ID: {word_id}")

        # 3. Prepare Word Data
        word_data = {
            'wordId': word_id,
            'word': word,
            'user_id': user_id,
            'tileIds': tile_ids,
            'status': "valid",
            'current_owner_user_id': user_id,
            'word_history': []
        }

        # 4. Handle Different Submission Types
        if submission_type == WordSubmissionType.MIDDLE_WORD:
            word_data['word_history'].append({
                'word': word,
                'timestamp': int(datetime.now().timestamp() * 1000),
                'status': "valid",
                'tileIds': tile_ids,
                'playerId': user_id
            })
            current_data.setdefault('words', []).append(word_data)
            logger.debug(f"[submit_word] Middle word added: {word_data}")

        elif submission_type == WordSubmissionType.OWN_WORD_IMPROVEMENT:
            old_word_id = extra_data[0]
            old_word_index = next((index for (index, w) in enumerate(current_data['words']) if w['wordId'] == old_word_id), None)
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
                logger.debug(f"[submit_word] Own word improvement: {word_data}")

        elif submission_type == WordSubmissionType.STEAL_WORD:
            stolen_word_ids = extra_data
            for stolen_word_id in stolen_word_ids:
                stolen_word_index = next((index for (index, w) in enumerate(current_data['words']) if w["wordId"] == stolen_word_id), None)
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
                    logger.debug(f"[submit_word] Stolen word history updated: {stolen_word_history}")

            current_data.setdefault('words', []).append(word_data)
            logger.debug(f"[submit_word] Stolen word added: {word_data}")

        else:
            logger.error(f"[submit_word] Unexpected submission type: {submission_type}")
            return None

        # 5. Update Tile Locations
        for tile in tiles:
            if tile and 'tileId' in tile:
                tile_id = tile['tileId']
                tile_index = next((index for (index, d) in enumerate(current_data['tiles']) if d["tileId"] == tile_id), None)
                if tile_index is not None:
                    current_data['tiles'][tile_index]['location'] = word_id
                else:
                    logger.error(f"[submit_word] Tile ID {tile_id} not found in current data.")
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
        logger.debug(f"[submit_word] Remaining letters updated: {remaining_letters}")

        # 7. Update Player Score
        player_data = current_data['players'].get(user_id)
        if player_data:
            player_data['score'] = (player_data.get('score', 0) or 0) + len(word)
            current_data['players'][user_id] = player_data
            logger.debug(f"[submit_word] Player score updated: {player_data['score']}")
        else:
            logger.error(f"[submit_word] Player ID {user_id} not found in current data.")
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
        logger.debug(f"[submit_word] Game action added: {submission_type.name}")

        return current_data

    try:
        result = game_ref.transaction(transaction_update)
        return {'success': True, 'message': 'Word submitted successfully'}
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
    """Identifies the type of word submission (now takes game_data directly)."""
    logger.debug(f"[game_service.py][identifyWordSubmissionType] Start")
    if not game_data:
        logger.debug(f"[game_service.py][identifyWordSubmissionType] Game data is None.")
        raise GameNotFoundError(f"Game data is None.") # Use custom exception.

    tiles = [tile_service.get_tile_from_data(game_data, tile_id) for tile_id in tile_ids]
    middle_tiles_used_in_word = word_validation_service.get_middle_tiles_used_in_word(tiles)
    logger.debug(f"[game_service.py][identifyWordSubmissionType] Tiles: {tiles}")
    logger.debug(f"[game_service.py][identifyWordSubmissionType] Middle Tiles Used: {middle_tiles_used_in_word}")

    if not word_validation_service.is_valid_word_length(tiles):
        logger.debug(f"[game_service.py][identifyWordSubmissionType] Invalid word length")
        return WordSubmissionType.INVALID_LENGTH, []
    if len(middle_tiles_used_in_word) == 0:
        logger.debug(f"[game_service.py][identifyWordSubmissionType] No middle tiles used")
        return WordSubmissionType.INVALID_NO_MIDDLE, []
    if not word_validation_service.uses_valid_letters(game_data, tiles):
        logger.debug(f"Checking if valid letters were used...")
        logger.debug(f"[game_service.py][identifyWordSubmissionType] Invalid letters used")
        return WordSubmissionType.INVALID_LETTERS_USED, []
    if not word_validation_service.is_valid_word(tiles, game_data.get("gameId")):
        logger.debug(f"[game_service.py][identifyWordSubmissionType] Word not in dictionary")
        return WordSubmissionType.INVALID_WORD_NOT_IN_DICTIONARY, []

    if len(tiles) == len(middle_tiles_used_in_word):
        logger.debug(f"[game_service.py][identifyWordSubmissionType] Middle word")
        return WordSubmissionType.MIDDLE_WORD, []

    potential_words_to_steal_from = []
    words = game_data.get("words", {})
    logger.debug(f"[game_service.py][identifyWordSubmissionType] Words in game: {words}")

    for word in words:
        if word["status"] != "valid":
            continue

        word_tile_ids = set(word["tileIds"])
        submitted_tile_ids = set(tile_ids)
        middle_tile_ids = set(tile["tileId"] for tile in middle_tiles_used_in_word)

        if word_tile_ids.issubset(submitted_tile_ids - middle_tile_ids):
            if word["current_owner_user_id"] == user_id:
                logger.debug(f"[game_service.py][identifyWordSubmissionType] Own word improvement: {word['wordId']}")
                return WordSubmissionType.OWN_WORD_IMPROVEMENT, [word["wordId"]]
            else:
                potential_words_to_steal_from.append(word["wordId"])

    if potential_words_to_steal_from:
        logger.debug(f"[game_service.py][identifyWordSubmissionType] Potential words to steal: {potential_words_to_steal_from}")
        return WordSubmissionType.STEAL_WORD, potential_words_to_steal_from

    logger.debug(f"[game_service.py][identifyWordSubmissionType] Returning Invalid Unknown Why")
    return WordSubmissionType.INVALID_UNKNOWN_WHY, []

def flip_tile(game_id, user_id):
    """Flips a tile within a transaction."""
    game_ref = firebase_service.get_db_reference(f'games/{game_id}')

    def flip_tile_transaction(current_data):
        if not current_data:
            raise GameNotFoundError(f"Game with ID {game_id} not found.")

        tiles = current_data.get('tiles', [])
        remaining_letters = current_data.get('remainingLetters', {})

        unflipped_tiles = [tile for tile in tiles if tile['location'] == 'unflippedTilesPool']

        if not unflipped_tiles or not any(remaining_letters.values()):
            logger.debug("flip_tile()... No unflipped tiles or no available letters.")
            return current_data  # Return unchanged data.  Don't abort.

        tile = random.choice(unflipped_tiles)
        letters, counts = zip(*[(l, c) for l, c in remaining_letters.items() if c > 0])
        letter = random.choices(letters, weights=counts, k=1)[0]

        # Find the *index* of the tile to update.  Crucial for Realtime DB.
        tile_index = next((index for (index, t) in enumerate(tiles) if t['tileId'] == tile['tileId']), None)
        if tile_index is None:
            print(f"Error: Could not find tile with ID {tile['tileId']} in flip_tile")
            return None

        # Update the tile *within* the current_data
        current_data['tiles'][tile_index]['letter'] = letter
        current_data['tiles'][tile_index]['location'] = 'middle'

        remaining_letters[letter] -= 1
        if remaining_letters[letter] == 0:
            del remaining_letters[letter]
        current_data['remainingLetters'] = remaining_letters

        # Add game action *within* the transaction
        add_game_action(current_data, game_id, {
            'type': 'flip_tile',
            'playerId': user_id,
            'timestamp': int(datetime.now().timestamp() * 1000),
            'tileId': tile['tileId'],
            'tileLetter': letter
        })

        #Advance Player Turn
        players = current_data.get('players', {})
        player_ids = list(players.keys())
        current_player_id = current_data.get('currentPlayerTurn')
        current_index = player_ids.index(current_player_id) if current_player_id in player_ids else -1
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
    
    #Game is also considered over if all tiles have been flipped, 
    return False

def get_game(game_id):
    """Retrieves a game from the database."""
    ref = firebase_service.get_db_reference(f'games/{game_id}')
    return ref.get()

def update_game(game_id, updated_data):
    """Updates a game in the database."""
    ref = firebase_service.get_db_reference(f'games/{game_id}')
    ref.update(updated_data)

def create_game(game_data):
    """Creates a new game in the database."""
    ref = firebase_service.get_db_reference('games')
    new_game_ref = ref.push(game_data)
    return new_game_ref.key

def delete_game(game_id):
    """Deletes a game from the database."""
    ref = firebase_service.get_db_reference(f'games/{game_id}')
    ref.delete()
