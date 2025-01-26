import random
from .firebase_service import get_game, update_game

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

def submit_valid_word(game_id, tiles):
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

    # Put the word in a user's list of words
    # Remove the tileIds of the submitted word from the 
    # game_data['words'].append(word)
    # return True, game_data


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
