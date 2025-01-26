from .firebase_service import get_game, update_game
from firebase_admin import db

def get_tile(game_id, tile_id):
    """Fetches a specific tile from a game.

    Args:
        game_id: The ID of the game.
        tile_id: The ID of the tile.

    Returns:
        The tile data if found, otherwise None.
    """
    game_data = get_game(game_id)
    if not game_data:
        print(f"Game with ID {game_id} does not exist.")
        return None

    tiles = game_data.get("tiles")
    if not tiles:
        return None
    for tile in tiles:
        if tile.get("tileId") == tile_id:
            return tile
    return tiles.get(tile_id, None)

def update_tiles_location(game_id, tiles, word_id):
        """Updates the location property of the tiles to be the wordId.

        Args:
            game_id (str): The game ID.
            tiles (list): List of tiles forming the word.
            word_id (str): The ID of the word.
        """
        game_data = get_game(game_id)

        if not game_data:
            print(f"Game with ID {game_id} does not exist.")
            return

        print(f"Updating tiles for game ID: {game_id}")
        print(f"Word ID: {word_id}")
        print(f"Tiles to update: {tiles}")

        for tile in tiles:
            if tile and 'tileId' in tile:
                tile_id = tile['tileId']
                print(f"Processing tile ID: {tile_id}")

                # Find the index of the tile with the matching tileId
                tile_index = next((index for (index, d) in enumerate(game_data['tiles']) if d["tileId"] == tile_id), None)

                if tile_index is not None:
                    # Update the specific tile's location using db
                    print(f"Updating tile ID {tile_id} location to {word_id}")
                    db.reference(f'games/{game_id}/tiles/{tile_index}').update({'location': word_id})
                else:
                    print(f"Tile with ID {tile_id} not found in the game data.")

        print(f"Game ID {game_id} updated successfully.")
