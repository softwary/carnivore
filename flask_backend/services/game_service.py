import logging
import colorlog
import random
import uuid
from enum import Enum
from datetime import datetime
from services import firebase_service, tile_service, word_validation_service, player_service
from logging_config import logger


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

def deal_with_word_submission(game_id: str, user_id: str, word_id: str, word: str, tile_ids: list[int], previous_tile_ids: list[int], action_type: str):
    """
    Handles the common tasks when a word is submitted (new, improved, or stolen).

    Responsibilities:
    - Update tile locations
    - Update the player's score (only for new letters)
    - Ensure turn is set to the submitting player
    - Log the game action

    Args:
        game_id (str): The ID of the game.
        user_id (str): The ID of the user submitting the word.
        word_id (str): The ID of the word being updated.
        word (str): The updated word.
        tile_ids (list[int]): The list of tile IDs forming the word.
        previous_tile_ids (list[int]): The tile IDs of the previous word before modification.
        action_type (str): The type of action (e.g., "NEW_WORD", "OWN_WORD_IMPROVEMENT", "STEAL_WORD").

    Returns:
        dict: Success message.
    """
    game_ref = firebase_service.get_db_reference(f'games/{game_id}')
    word_ref = game_ref.child('words').child(word_id)

    # Fetch and sort new tile data
    new_tiles = [tile_service.get_tile(game_id, tile_id) for tile_id in tile_ids]
    new_tiles.sort(key=lambda t: tile_ids.index(t['tileId']))
    new_tile_ids = [tile['tileId'] for tile in new_tiles]

    # Determine newly added tiles (only count new ones for score)
    previous_tile_set = set(previous_tile_ids)
    new_tile_set = set(new_tile_ids)
    added_tiles = new_tile_set - previous_tile_set  # Score is based on new letters only

    # Update tile locations
    tile_service.update_tiles_location(game_id, new_tiles, word_id)

    # Update player's score (only count new tiles)
    player_ref = game_ref.child('players').child(user_id)
    current_score = player_ref.child('score').get() or 0
    player_ref.update({'score': current_score + len(added_tiles)})

    # ✅ Ensure turn is set for the submitting player and update currentPlayerTurn in Firebase
    game_data = firebase_service.get_game(game_id)
    game_data["currentPlayerTurn"] = user_id  # Update turn to the submitting player
    for player_id, player in game_data["players"].items():
        player["turn"] = (player_id == user_id)  # Set True for submitting player, False for others

    # Save the updated game state
    firebase_service.update_game(game_id, game_data)

    logger.debug(f"deal_with_word_submission()... Set turn for user {user_id}")

    # Log the action
    add_game_action(game_id, {
        'type': action_type,
        'playerId': user_id,
        'timestamp': int(datetime.now().timestamp() * 1000),
        'wordId': word_id,
        'newWord': word,
        'tileIds': new_tile_ids
    })

    return {'success': True, 'message': f'Word {action_type.lower().replace("_", " ")} successfully'}

def advance_turn(game_id: str):
    """Advances the turn to the next player in the game."""
    logger.debug(f"[game_service.py][advance_turn] Called for game {game_id}")

    game_data = firebase_service.get_game(game_id)
    if not game_data:
        logger.debug(f"[game_service.py][advance_turn] Game with ID {game_id} does not exist.")
        return
    
    players = game_data.get("players", {})
    player_ids = list(players.keys())  # Get list of player IDs in order

    # Find the current player index
    current_player_id = game_data.get("currentPlayerTurn", None)
    current_index = player_ids.index(current_player_id) if current_player_id in player_ids else -1

    # Determine the next player's turn
    next_index = (current_index + 1) % len(player_ids) if current_index != -1 else 0
    next_player_id = player_ids[next_index]

    # Update player turns
    for player_id, player_data in players.items():
        player_data["turn"] = (player_id == next_player_id)

    # Update the database
    game_data["currentPlayerTurn"] = next_player_id
    game_data["players"] = players

    firebase_service.update_game(game_id, game_data)
    logger.debug(f"[game_service.py][advance_turn] New turn: Player {next_player_id}")

def add_game_action(game_id: str, action: dict):
    """Adds an action to the game's action log.

    Args:
        game_id (str): The ID of the game.
        action (dict): The action to log.
    """
    logger.debug(f"[game_service.py][add_game_action] Called")
    logger.debug(f"action= {action}")
    logger.debug(f" ")

    game_ref = firebase_service.get_db_reference(f'games/{game_id}')  # Use firebase_service
    game_data = firebase_service.get_game(game_id)  # Use firebase_service

    if not game_data:
        logger.debug(f"Game with ID {game_id} does not exist.")
        return {'success': False, 'message': f"Game with ID {game_id} does not exist."}

    if 'actions' not in game_data:
        game_ref.update({'actions': [action]})
        logger.debug(f"[game_service.py][add_game_action] Initialized actions array in game data")
    else:
        game_ref.child('actions').push(action)
        logger.debug(f"[game_service.py][add_game_action] Added action to game")

    return {'success': True, 'message': 'Action added successfully'}

def identifyWordSubmissionType(game_id, user_id, tile_ids):
    """Identifies the type of word submission.

    Args:
        game_id (str): The ID of the game.
        user_id (str): The ID of the user submitting the word.
        tile_ids (list): The IDs of the tiles used in the word.

    Returns:
        tuple: (WordSubmissionType, list) - The type of word submission and 
               a list containing either the word to improve or potential words to steal.
               Returns (WordSubmissionType.INVALID, []) if the submission is invalid.
    """
    logger.debug(f"[game_service.py][identifyWordSubmissionType] Start")
    game_data = firebase_service.get_game(game_id)
    if not game_data:
        logger.debug(f"[game_service.py][identifyWordSubmissionType] Game with ID {game_id} not found.")
        raise GameNotFoundError(f"Game with ID {game_id} not found.")
    logger.debug(f" ")
    tiles = [tile_service.get_tile(game_id, tile_id) for tile_id in tile_ids]
    middle_tiles_used_in_word = word_validation_service.get_middle_tiles_used_in_word(tiles)
    logger.debug(f"[game_service.py][identifyWordSubmissionType] Tiles: {tiles}")
    logger.debug(f" ")
    logger.debug(f"[game_service.py][identifyWordSubmissionType] Middle Tiles Used: {middle_tiles_used_in_word}")
    logger.debug(f" ")
    match True:
        case _ if not word_validation_service.is_valid_word_length(tiles):
            logger.debug(f"[game_service.py][identifyWordSubmissionType] Invalid word length")
            return WordSubmissionType.INVALID_LENGTH, []
        case _ if len(middle_tiles_used_in_word) == 0:
            logger.debug(f"[game_service.py][identifyWordSubmissionType] No middle tiles used")
            return WordSubmissionType.INVALID_NO_MIDDLE, []
        case _ if not word_validation_service.uses_valid_letters(game_id, tiles):
            logger.debug(f"Checking if valid letters were used...")
            logger.debug(f"[game_service.py][identifyWordSubmissionType] Invalid letters used")
            return WordSubmissionType.INVALID_LETTERS_USED, []
        case _ if not word_validation_service.is_valid_word(tiles, game_id):
            logger.debug(f"[game_service.py][identifyWordSubmissionType] Word not in dictionary")
            return WordSubmissionType.INVALID_WORD_NOT_IN_DICTIONARY, []
    logger.debug(f" ")
    if len(tiles) == len(middle_tiles_used_in_word):
        logger.debug(f"[game_service.py][identifyWordSubmissionType] Middle word")
        logger.debug(f"@@@@@@@@@@@ WordSubmissionType.MIDDLE_WORD = ", WordSubmissionType.MIDDLE_WORD)
        what_to_return = (WordSubmissionType.MIDDLE_WORD, [])
        logger.debug(f" ")
        logger.debug(f"Middle_WORD....so i am returning this: ", what_to_return)
        return what_to_return
    logger.debug(f" ")
    potential_words_to_steal_from = []
    words = game_data.get("words", {})
    logger.debug(f"[game_service.py][identifyWordSubmissionType] Words in game: {words}")
    for word_id, word in words.items():
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

    logger.debug(f"[game_service.py][identifyWordSubmissionType] Invalid game data")
    raise InvalidGameDataError("Could not determine word submission type.")

def flip_tile(game_id):
    """Flips a random tile that is not flipped and assigns a random letter.

    Args:
        game_id (str): The unique identifier of the game.

    Returns:
        tuple: (bool, dict) indicating whether the tile was flipped successfully, and the new game state.
    """

    game_data = firebase_service.get_game(game_id)

    if not game_data:
        logger.debug(f"flip_tile()... Game with ID {game_id} does not exist.")
        return False, None  # Return explicit failure

    tiles = game_data.get('tiles', [])
    remaining_letters = game_data.get('remainingLetters', {})

    # logger.debug(f"flip_tile()... Initial game data: {game_data}")
    logger.debug(f"flip_tile()... Initial remaining_letters: {remaining_letters}")

    # Filter tiles that are not yet flipped
    unflipped_tiles = [tile for tile in tiles if tile['location'] == 'unflippedTilesPool']

    if not unflipped_tiles or not any(remaining_letters.values()):
        logger.debug("flip_tile()... No unflipped tiles or no available letters.")
        return False, game_data  # No available tiles or letters

    # Select a random unflipped tile
    tile = random.choice(unflipped_tiles)
    logger.debug(f"flip_tile()... Selected tile: {tile}")

    # Select a letter based on weighted probability
    letters, counts = zip(*[(l, c) for l, c in remaining_letters.items() if c > 0])
    letter = random.choices(letters, weights=counts, k=1)[0]
    logger.debug(f"flip_tile()... Selected letter: {letter}")

    # Assign the letter to the tile and update game state
    tile['letter'] = letter
    tile['location'] = 'middle'
    remaining_letters[letter] -= 1

    logger.debug(f"flip_tile()... Updated tile: {tile}")
    logger.debug(f"flip_tile()... Remaining letters after update: {remaining_letters}")

    # Save updated game state
    game_data['remainingLetters'] = remaining_letters
    game_data['tiles'] = tiles  # Since we modified `tile` directly, `tiles` is updated

    # Move to the next player's turn
    set_next_player_turn(game_id)
    logger.debug("flip_tile()... Set next player's turn.")

    return True, game_data

def submit_valid_word(user_id, game_id, tiles):
    """Submits a valid word for the game.

    Args:
        game_id (str): The game ID.
        tiles (list): List of tiles forming the word.

    Returns:
        tuple: (bool, dict) indicating whether the word was submitted successfully, and the new game state.
    """
    logger.debug(f"in game_service.submit_valid_word() ")
    game_data = firebase_service.get_game(game_id)
    if not game_data:
        logger.debug(f"Game with ID {game_id} does not exist.")
        return False, game_data
    
    # Update game state
    word = ''.join(tile['letter'] for tile in tiles if tile['letter'])
    logger.debug(f"in game_service.submit_valid_word() word = {word}")
    
    # Add the word to the game's list of words
    if 'words' not in game_data:
        game_data['words'] = []
    word_id = str(uuid.uuid4())
    game_data['words'].append({'wordId': word_id, 
                               'word': word, 
                               'user_id': user_id, 
                               'tileIds': [tile['tileId'] for tile in tiles]})
    firebase_service.update_game(game_id, game_data)
    # Update the tiles' location property to be the wordId
    tile_service.update_tiles_location(game_id, tiles, word_id)

    # Make it the player with the submitted word's turn
    player_service.set_player_turn(game_id, user_id)

    # TODO: Make this into a separate function in player_service.py
    # Update the player's words and score in the database
    # player_ref = game_ref.child('players').child(user_id)
    # player_ref.child('score').set(
    #     firebase_admin.db.firestore.Increment(len(word)))  # Assuming score is based on word length
    # TODO: Make this into a separate function in player_service.py
    # Update user's game history (in the "users" collection)
    # user_ref = ref.child('users').child(user_id)
    # user_ref.child('gamesPlayed').child(game_id).set({
    #     'won': False,  # You'll need to determine this based on game logic
    #     'score': game_data['players'][user_id]['score'] + len(word)
    # })
    
    return True, game_data

def remove_used_tiles(game_id, tiles):
    """Removes the used letters from the remaining letters in the game.

    Args:
        game_id (str): The game ID.
        tiles (list): List of tiles forming the word.
    """
    logger.debug(f"\n--- remove_used_tiles() START ---")
    game_data = firebase_service.get_game(game_id)
    if not game_data:
        logger.debug(f"remove_used_tiles: Game with ID {game_id} does not exist.")
        logger.debug(f"--- remove_used_tiles() END ---\n")
        return
    
    remaining_letters = game_data.get('remainingLetters', {})
    logger.debug(f"remove_used_tiles: Initial remaining_letters ={remaining_letters}")
    for tile in tiles:
        letter = tile['letter']
        logger.debug(f"remove_used_tiles: Processing tile with letter '{letter}'")
        if letter in remaining_letters and remaining_letters[letter] > 0:
            remaining_letters[letter] -= 1
            logger.debug(f"remove_used_tiles: Decremented remaining_letters['{letter}'] to {remaining_letters[letter]}")
    
    game_data['remainingLetters'] = remaining_letters
    logger.debug(f"remove_used_tiles: Final remaining_letters = {remaining_letters}")
    firebase_service.update_game(game_id, game_data)
    logger.debug(f"--- remove_used_tiles() END ---\n")

def set_next_player_turn(game_id):
    """Sets the turn for the next player in the game.

    Args:
        game_id (str): The game ID.
    """
    logger.debug(f"in game_service.set_next_player_turn() ")
    game_data = firebase_service.get_game(game_id)
    if not game_data:
        logger.debug(f"Game with ID {game_id} does not exist.")
        return
    
    players = game_data.get('players', {})
    logger.debug(f"set_next_player_turn()... players= {players}") 
    player_order = [player['turnOrder'] for player in players.values()]
    logger.debug(f"set_next_player_turn()... player_order= {player_order}")
    # current_player_order = next((player['turnOrder'] for player in players.values() if player['turn']), -1)
    current_player_order = next((player['turnOrder'] for player_id, player in players.items() if player.get('turn', False)), -1)

    if current_player_order == -1:
        next_player_order = 1
    else:
        next_player_order = current_player_order + 1 if current_player_order + 1 in player_order else 1
    logger.debug(f"set_next_player_turn()... next_player_order={next_player_order}")
    
    for player_id, player in players.items():
        if player['turnOrder'] == next_player_order:
            player['turn'] = True
            logger.debug(f"set_next_player_turn()... setting turn for player {player_id}")
        else:
            player['turn'] = False
    
    game_data['players'] = players
    firebase_service.update_game(game_id, game_data)
    logger.debug(f"set_next_player_turn()... updated game_data with new player turn")

def is_game_over(game_id):
    """Checks if a game is over."""
    game_data = firebase_service.get_game(game_id)
    if not game_data:
        return True
    #TODO: Implement game over logic
    # Game is over in any of these conditions: 
    # - All tiles are assigned a letter, yet there are 0 letters.inMiddle=True
    # - All tiles are assigned a letter, and no annagram of letters.inMiddle=True + players' words can create a new valid word
    # This is some complex logic that will need to be figured out honestly...
    # Will return false for now!
    return False

def submit_invalid_word(game_id: str, user_id: str, tile_ids: list[int], word: str, reason: str = "unknown") -> dict:
    """Handles an invalid word submission."""
    game_ref = firebase_service.get_db_reference(f'games/{game_id}')  # Use firebase_service

    # Add the word to the game's list of words with an "invalid" status
    word_id = str(uuid.uuid4())
    word_data = {
        'wordId': word_id,
        'word': word,
        'user_id': user_id,
        'tileIds': tile_ids,
        'status': "invalid",
        'reason': reason  # Store the reason for invalidity
    }

    # Use the firebase_service to interact with the database
    game_data = firebase_service.get_game(game_id)
    if not game_data:
        logger.debug(f"Error: Game with ID {game_id} not found in submit_invalid_word.")
        return {'success': False, 'message': f'Game not found: {game_id}'}

    if 'words' not in game_data:
        game_ref.update({'words': [word_data]})  # Initialize the words array
    else:
        game_ref.child('words').push(word_data) # Use push to add to the list

    return {'success': True, 'message': 'Invalid word submitted'}

def submit_middle_word(game_id: str, user_id: str, tile_ids: list[int], word: str) -> dict:
    logger.debug(f"[game_service.py][submit_middle_word] Called")
    logger.debug(f"word= {word}") 
    
    game_ref = firebase_service.get_db_reference(f'games/{game_id}')
    game_data = firebase_service.get_game(game_id)
    word_id = str(uuid.uuid4())

    # Ensure the tiles are ordered correctly
    tiles = [tile_service.get_tile(game_id, tile_id) for tile_id in tile_ids]
    tiles.sort(key=lambda t: tile_ids.index(t['tileId']))

    # Create new word data
    word_data = {
        'wordId': word_id,
        'word': word,
        'user_id': user_id,
        'tileIds': [tile['tileId'] for tile in tiles],
        'status': "valid",
        'current_owner_user_id': user_id,
        'word_history': [
            {
                'word': word,
                'timestamp': int(datetime.now().timestamp() * 1000),
                'status': "valid",
                'tileIds': [tile['tileId'] for tile in tiles],
                'playerId': user_id
            }
        ]
    }

    if 'words' not in game_data:
        game_ref.child('words').child(word_id).set(word_data)
    else:
        game_ref.child('words').push(word_data)

    tile_service.update_tiles_location(game_id, tiles, word_id)

    player_ref = game_ref.child('players').child(user_id)
    current_score = player_ref.child('score').get() or 0
    player_ref.update({'score': current_score + len(word)})

    # Ensure turn is set for the submitting player if the word submission is valid
    player_service.set_player_turn(game_id, user_id)


    add_game_action(game_id, {
        'type': WordSubmissionType.MIDDLE_WORD.name,
        'playerId': user_id,
        'wordId': word_id,
        'word': word,
        'tileIds': [tile['tileId'] for tile in tiles]
    })

    return {'success': True, 'message': 'Middle word submitted successfully'}

def improve_own_word(game_id: str, user_id: str, tile_ids: list[int], word: str) -> dict:
    logger.debug(f"[game_service.py][improve_own_word] Called")

    game_data = firebase_service.get_game(game_id)
    if not game_data:
        return {'success': False, 'message': f"Game with ID {game_id} does not exist."}

    words = game_data.get("words", {})
    improved_word_id = None
    existing_word = None

    # Find the word to improve
    for word_id, word_data in words.items():
        if word_data["current_owner_user_id"] == user_id and word_data["status"] == "valid":
            word_tile_ids = set(word_data["tileIds"])
            submitted_tile_ids = set(tile_ids)
            if word_tile_ids.issubset(submitted_tile_ids):
                improved_word_id = word_id
                existing_word = word_data
                break

    if not improved_word_id:
        return {'success': False, 'message': f"No valid word found for user {user_id} to improve."}

    game_ref = firebase_service.get_db_reference(f'games/{game_id}')
    existing_word_ref = game_ref.child('words').child(improved_word_id)
    existing_word_history = existing_word_ref.child('word_history').get() or []

    # Store previous word state in history
    old_word_data = {
        'word': existing_word['word'],
        'timestamp': int(datetime.now().timestamp() * 1000),
        'status': "valid",
        'tileIds': existing_word['tileIds'],
        'playerId': existing_word['user_id']
    }

    # Avoid duplicate history entries
    if not any(history['word'] == existing_word['word'] for history in existing_word_history):
        existing_word_ref.child('word_history').push(old_word_data)

    # Update word
    existing_word_ref.update({
        'word': word,
        'tileIds': tile_ids
    })

    # Call helper function
    return deal_with_word_submission(
        game_id, user_id, improved_word_id, word, tile_ids, existing_word['tileIds'], "OWN_WORD_IMPROVEMENT"
    )

def steal_word(game_id: str, user_id: str, tile_ids: list[int], word: str) -> dict:
    logger.debug(f"[game_service.py][steal_word] Called")

    game_data = firebase_service.get_game(game_id)
    if not game_data:
        return {'success': False, 'message': f"Game with ID {game_id} does not exist."}

    words = game_data.get("words", {})
    stolen_word_id = None
    stolen_word = None

    # Find a valid word that can be stolen
    for word_id, word_data in words.items():
        if word_data["status"] == "valid" and word_data["current_owner_user_id"] != user_id:
            word_tile_ids = set(word_data["tileIds"])
            submitted_tile_ids = set(tile_ids)
            if word_tile_ids.issubset(submitted_tile_ids):
                stolen_word_id = word_id
                stolen_word = word_data
                break

    if not stolen_word_id:
        return {'success': False, 'message': f"No valid word found for user {user_id} to steal."}

    game_ref = firebase_service.get_db_reference(f'games/{game_id}')
    stolen_word_ref = game_ref.child('words').child(stolen_word_id)

    # Fetch existing word history
    existing_word_history = stolen_word_ref.child('word_history').get() or []

    # Store previous word state in history
    previous_word_entry = {
        'word': stolen_word['word'],
        'timestamp': int(datetime.now().timestamp() * 1000),
        'status': "valid",
        'tileIds': stolen_word['tileIds'],
        'playerId': stolen_word['user_id']
    }

    # Avoid duplicate history entries
    if not any(entry['word'] == stolen_word['word'] for entry in existing_word_history):
        stolen_word_ref.child('word_history').push(previous_word_entry)

    # Update word owner
    stolen_word_ref.update({
        'word': word,
        'tileIds': tile_ids,
        'current_owner_user_id': user_id,
        'user_id': user_id
    })

    # Call helper function
    return deal_with_word_submission(
        game_id, user_id, stolen_word_id, word, tile_ids, stolen_word['tileIds'], "STEAL_WORD"
    )
