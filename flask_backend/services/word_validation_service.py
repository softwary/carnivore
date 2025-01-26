from .firebase_service import get_game, update_game

def is_valid_word_length(tiles):
    """Check if a word is at least 3 letters long.

    Args:
        tiles (list): List of tiles in word.

    Returns:
        bool: True if the word is at least 3 letters long, False otherwise.
    """
    return len(tiles) >= 3


def uses_at_least_one_middle_tile(tiles):
    """Check if a word uses at least one tile from the middle.

    Args:
        tiles (list): List of tiles.

    Returns:
        bool: True if at least one tile is from the middle, False otherwise.
    """
    return any(tile['location'] == 'middle' for tile in tiles)

def uses_valid_letters(game_id, tiles):
    """Check if a word uses valid letters that are in the game.

    Args:
        game_id (str): The game ID.
        tiles (list): List of tiles.

    Returns:
        bool: True if all letters are valid, False otherwise.
    """
    print("@@@ in uses_valid_letters()...game_id = ", game_id)
    game_data = get_game(game_id)
    if not game_data:
        print(f"Game with ID {game_id} does not exist.")
        return False

    game_letters = game_data.get('remainingLetters', {})
    print("in uses_valid_letters()...game_letters = ", game_letters)
    tile_letters = [tile['letter'] for tile in tiles if tile['letter']]
    print("in uses_valid_letters()...tile_letters = ", tile_letters)
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