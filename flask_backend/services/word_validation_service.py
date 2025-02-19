from .firebase_service import get_game, update_game
from logging_config import logger
import os

def is_valid_word_length(tiles):
    """Check if a word is at least 3 letters long.

    Args:
        tiles (list): List of tiles in word.

    Returns:
        bool: True if the word is at least 3 letters long, False otherwise.
    """
    return len(tiles) >= 3

def get_middle_tiles_used_in_word(tiles):
    """Get the list of tiles that are from the middle.

    Args:
        tiles (list): List of tiles.

    Returns:
        list: List of tiles from the middle.
    """
    return [tile for tile in tiles if tile['location'] == 'middle']

def uses_valid_letters(game_data, tiles):
    """Checks if the tiles used are either in the middle or belong to a valid word
    that can be extended/stolen by the current user.

    Args:
        game_data (dict): The game data dictionary.
        tiles (list): List of tile dictionaries.

    Returns:
        bool: True if the tile locations are valid, False otherwise.
    """
    if not game_data or not tiles:
        return False

    words = game_data.get('words', [])
    valid_locations = {'middle'}

    # Add wordIds of valid words
    for word_data in words:
        if word_data.get('status') == 'valid':
            existing_tile_ids = set(word_data['tileIds'])
            submitted_tile_ids = set(tile['tileId'] for tile in tiles if tile)
            middle_tiles = [t for t in tiles if t and t.get('location') == 'middle']
            middle_tile_ids = {t['tileId'] for t in middle_tiles}

            if existing_tile_ids.issubset(submitted_tile_ids - middle_tile_ids):
                # The word's tiles are a subset of the *newly* submitted tiles.
                valid_locations.add(word_data['wordId'])
    # Now, check if *every* tile's location is valid.
    for tile in tiles:
        if not tile or 'location' not in tile:
            return False
        if tile['location'] not in valid_locations:
            print(f"Invalid tile location: {tile['location']} (tileId: {tile.get('tileId')})")  # Debugging
            return False

    return True

def is_valid_word(tiles, game_id):
    """Check if a word is valid in the dictionary.

    Args:
        tiles (list): List of tiles.
        game_id (str): The game ID.

    Returns:
        bool: True if the word is valid, False otherwise.
    """
    word = ''.join(tile['letter'] for tile in tiles if tile['letter']).lower()

    # Get the absolute path of the filtered_words.txt file
    base_dir = os.path.dirname(os.path.abspath(__file__))
    word_file_path = os.path.join(base_dir, '../word_validation/dictionary.txt')

    # Check if the word is in the filtered_words.txt file
    try:
        with open(word_file_path, 'r', encoding='utf-8') as file:
            valid_words = set(file.read().splitlines())
            is_valid = word in valid_words
            return is_valid
    except FileNotFoundError:
        print("Error: filtered_words.txt file not found.")
        return False

