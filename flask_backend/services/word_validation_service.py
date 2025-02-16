from .firebase_service import get_game, update_game
from logging_config import logger

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

def uses_valid_letters(game_id, tiles):
    """Check if a word uses valid letters that are in the game.

    Args:
        game_id (str): The game ID.
        tiles (list): List of tiles.

    Returns:
        bool: True if all letters are valid, False otherwise.
    """
    logger.debug(f" ")
    logger.debug(f"@@@ in uses_valid_letters()...game_id = {game_id}")
    logger.debug(f" ")
    logger.debug(f"@@@ in uses_valid_letters()...tiles = {tiles}")
    game_data = get_game(game_id)
    if not game_data:
        logger.debug(f"Game with ID {game_id} does not exist.")
        return False

    game_letters = game_data.get('remainingLetters', {})
    # logger.debug(f"in uses_valid_letters()...game_letters = ", game_letters)
    tile_letters = [tile['letter'] for tile in tiles if tile['letter']]
    logger.debug(f" ")
    # logger.debug(f"in uses_valid_letters()...tile_letters = ", tile_letters)
    logger.debug(f" ")
    return all(letter in game_letters for letter in tile_letters)

def is_valid_word(tiles, game_id):
    """Check if a word is valid in the dictionary.

    Args:
        tiles (list): List of tiles.
        game_id (str): The game ID.

    Returns:
        bool: True if the word is valid, False otherwise.
    """
    word = ''.join(tile['letter'] for tile in tiles if tile['letter'])
    # TODO: Implement dictionary check
    # Just return True always for now
    return True