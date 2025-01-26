from .firebase_service import get_game, update_game

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