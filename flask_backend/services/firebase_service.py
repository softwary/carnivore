from firebase_admin import db
from logging_config import logger

# def get_game(game_id):
#     """Fetches a game's data from Firebase."""
#     game_data = db.reference(f'games/{game_id}').get()
#     # print("firebase_service get_game() game_data = ", game_data)
#     return game_data

# def update_game(game_id, game_data):
#     """Updates a game's data in Firebase."""
#     db.reference(f'games/{game_id}').set(game_data)

# def get_player(game_id, user_id):
#     """Fetches a player's data from Firebase."""
#     player_data = db.reference(f'games/{game_id}/players/{user_id}').get()
#     return player_data
#     # return player_data.to_dict() if player_data.exists else None

# def update_player_turn(game_id, user_id, turn_data):
#     """Updates a player's turn data in Firebase."""
#     db.reference(f'games/{game_id}/players/{user_id}/turn').set(turn_data)


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
    ref.update(game_data) # update, not set, to avoid overwriting the whole game

def get_player(game_id: str, user_id: str) -> dict | None:
    """Fetches a player's data from Firebase."""
    ref = get_db_reference(f'games/{game_id}/players/{user_id}')
    test = get_db_reference(f'games/{game_id}/players/')
    return ref.get()

def update_player_turn(game_id: str, user_id: str, turn_data: bool):
    """Updates a player's turn data in Firebase."""
    ref = get_db_reference(f'games/{game_id}/players/{user_id}/turn')
    ref.set(turn_data)
