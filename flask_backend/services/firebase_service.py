from firebase_admin import db
from logging_config import logger


def get_db_reference(path: str = None) -> db.Reference:
    """Gets a reference to the Firebase Realtime Database.

    Args:
        path (str, optional): The path to the desired location. Defaults to the root.

    Returns:
        db.Reference: A reference to the specified database location.
    """
    return db.reference(path)


def get_game(game_id: str) -> dict | None:
    """Fetches a game's data from Firebase."""
    ref = get_db_reference(f'games/{game_id}')
    return ref.get()


def update_game(game_id: str, game_data: dict):
    """Updates a game's data in Firebase."""
    ref = get_db_reference(f'games/{game_id}')
    # update, not set, to avoid overwriting the whole game
    ref.update(game_data)


def get_player(game_id: str, user_id: str) -> dict | None:
    """Fetches a player's data from Firebase."""
    ref = get_db_reference(f'games/{game_id}/players/{user_id}')
    return ref.get()


def update_player_turn(game_id: str, user_id: str, turn_data: bool):
    """Updates a player's turn data in Firebase."""
    ref = get_db_reference(f'games/{game_id}/players/{user_id}/turn')
    ref.set(turn_data)
