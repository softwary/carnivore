import random
import uuid
from .firebase_service import get_game, update_game
from .tile_service import update_tiles_location

def flip_tile(game_data):
    """Flips a random tile that is not flipped and assigns a random letter.

    Args:
        game_data (dict): The current state of the game, including tiles and remaining letters.

    Returns:
        tuple: (bool, dict) indicating whether the tile was flipped successfully, and the new game state.
    """
    tiles = game_data.get('tiles', {})
    remaining_letters = game_data.get('remainingLetters', {})
    print("flip_tile()... tiles=", tiles)
    # Filter tiles that are not flipped
    tiles_dict = {tile['tileId']: tile for tile in game_data.get('tiles', [])}

    unflipped_tiles = {tid: t for tid, t in tiles_dict.items() if not t['isFlipped']}
    
    if not unflipped_tiles or not remaining_letters:
        return False, game_data  # No tiles to flip or no letters left
    
    # Select a random unflipped tile
    tile_id, tile = random.choice(list(unflipped_tiles.items()))
    
    # Assign a random letter to the tile based on remaining letters
    letter, count = random.choice([(l, c) for l, c in remaining_letters.items() if c > 0])
    if count > 0:
        tile['letter'] = letter
        tile['isFlipped'] = True
        tile['inMiddle'] = True  # Update if needed
        remaining_letters[letter] -= 1

        # Check if all letters of this type have been used
        if remaining_letters[letter] <= 0:
            del remaining_letters[letter]

        game_data['tiles'][tile_id] = tile
        game_data['remainingLetters'] = remaining_letters
        return True, game_data
    
    return False, game_data

def submit_valid_word(user_id, game_id, tiles):
    """Submits a valid word for the game.

    Args:
        game_id (str): The game ID.
        tiles (list): List of tiles forming the word.

    Returns:
        tuple: (bool, dict) indicating whether the word was submitted successfully, and the new game state.
    """
    game_data = get_game(game_id)
    if not game_data:
        print(f"Game with ID {game_id} does not exist.")
        return False, game_data
    
    # Update game state
    word = ''.join(tile['letter'] for tile in tiles if tile['letter'])
    print("in game_service.submit_valid_word() word = ", word)
    
    # Add the word to the game's list of words
    if 'words' not in game_data:
        game_data['words'] = []
    word_id = str(uuid.uuid4())
    game_data['words'].append({'wordId': word_id, 'word': word, 'user_id': user_id, 'tileIds': [tile['tileId'] for tile in tiles]})
    update_game(game_id, game_data)
    # Update the tiles' location property to be the wordId
    update_tiles_location(game_id, tiles, word_id)
    
    # Remove the used letters from the game
    remove_used_tiles(game_id, tiles)
    
    # Update the game in the database
    # update_game(game_id, game_data)

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
    game_data = get_game(game_id)
    if not game_data:
        print(f"Game with ID {game_id} does not exist.")
        return
    
    remaining_letters = game_data.get('remainingLetters', {})
    for tile in tiles:
        letter = tile['letter']
        if letter in remaining_letters and remaining_letters[letter] > 0:
            remaining_letters[letter] -= 1
            if remaining_letters[letter] == 0:
                del remaining_letters[letter]
    
    game_data['remainingLetters'] = remaining_letters
    update_game(game_id, game_data)



def is_game_over(game_id):
    """Checks if a game is over."""
    game_data = get_game(game_id)
    if not game_data:
        return True
    #TODO: Implement game over logic
    # Game is over in any of these conditions: 
    # - All tiles are assigned a letter, yet there are 0 letters.inMiddle=True
    # - All tiles are assigned a letter, and no annagram of letters.inMiddle=True + players' words can create a new valid word
    # This is some complex logic that will need to be figured out honestly...
    # Will return false for now!
    return False