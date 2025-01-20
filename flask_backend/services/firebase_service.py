from firebase_admin import db

def get_game(game_id):
    """Fetches a game's data from Firebase."""
    return db.reference(f'games/{game_id}').get()

def update_game(game_id, game_data):
    """Updates a game's data in Firebase."""
    db.reference(f'games/{game_id}').update(game_data)
