import firebase_admin
from firebase_admin import db
import services.firebase_service as firebase_service
from logging_config import logger

def update_tiles_location(game_id, tiles, word_id):
    """Updates the location property of the tiles to be the wordId.

    Args:
        game_id (str): The game ID.
        tiles (list): List of tiles forming the word.
        word_id (str): The ID of the word.
    """
    game_data = firebase_service.get_game(game_id)

    if not game_data:
        logger.debug(f"Game with ID {game_id} does not exist.")
        return

    logger.debug(f"Updating tiles for game ID: {game_id}")
    logger.debug(f"Word ID: {word_id}")
    logger.debug(f"Tiles to update: {tiles}")

    for tile in tiles:
        if tile and 'tileId' in tile:
            tile_id = tile['tileId']
            logger.debug(f"Processing tile ID: {tile_id}")

            # Find the index of the tile with the matching tileId
            tile_index = next((index for (index, d) in enumerate(game_data['tiles']) if d["tileId"] == tile_id), None)

            if tile_index is not None:
                # Update the specific tile's location using db
                logger.debug(f"Updating tile ID {tile_id} location to {word_id}")
                db.reference(f'games/{game_id}/tiles/{tile_index}').update({'location': word_id})
            else:
                logger.debug(f"Tile with ID {tile_id} not found in the game data.")

    logger.debug(f"Game ID {game_id} updated successfully.")

def get_tile_from_data(game_data, tile_id):
    """Gets a tile from the game data directly (avoids extra DB calls).

    Args:
        game_data (dict): The game data containing tiles.
        tile_id (str): The ID of the tile to retrieve.

    Returns:
        dict: The tile data if found, otherwise None.
    """
    logger.debug(f"Getting tile with ID {tile_id} from game data.")
    if not game_data or 'tiles' not in game_data:
        return None
    for tile in game_data['tiles']:
        if tile and tile.get('tileId') == tile_id:
            return tile
    return None