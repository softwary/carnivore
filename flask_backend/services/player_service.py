from services import firebase_service
from services.firebase_service import db
from logging_config import logger


class GameNotFoundError(Exception):
    """Exception raised when a game is not found."""
    pass


def calculate_score(user_id, game_id):
    """Calculates the score for a given user_id by counting the number of tileIds in each word
    where the user_id is the current_owner_user_id.

    Args:
        user_id (str): The ID of the user.
        game_id (str): The ID of the game.

    Returns:
        dict: A dictionary containing the success status and the calculated score.
    """
    game_ref = firebase_service.get_db_reference(f'games/{game_id}')

    def transaction_calculate_score(current_data):
        if not current_data:
            raise GameNotFoundError(f"Game with ID {game_id} not found.")

        score = 0
        for word in current_data.get('words', []):
            if word['current_owner_user_id'] == user_id:
                score += len(word['tileIds'])

        return {'success': True, 'score': score}

    try:
        result = game_ref.transaction(transaction_calculate_score)
        return result
    except db.TransactionAbortedError as e:
        logger.error(f"Transaction failed for game ID {game_id}: {e}")
        return {'success': False, 'message': 'Score calculation failed'}
    except GameNotFoundError as e:
        logger.error(f"Game not found: {e}")
        return {'success': False, 'message': str(e)}
    except Exception as e:
        logger.error(f"An unexpected error occurred: {e}")
        return {'success': False, 'message': str(e)}


def is_player_turn(user_id, game_id):
    """
    Determines if it is the player's turn in the game.
    Args:
        user_id (int): The ID of the user.
        game_id (int): The ID of the game.
    Returns:
        bool: True if it is the player's turn, False otherwise.
    Raises:
        Exception: If an error occurs while retrieving player data.
    """
    try:
        logger.debug(
            f"Checking if it's the turn for user_id: {user_id} in game_id: {game_id}")
        player_data = firebase_service.get_player(game_id, user_id)

        if player_data:
            is_turn = player_data.get('turn', False)
            logger.debug(
                f"Player data found for user_id: {user_id} in game_id: {game_id}. Turn status: {is_turn}")
            return is_turn
        else:
            logger.debug(
                f"No player found with user_id: {user_id} in game_id: {game_id}")
            return False
    except Exception as e:
        logger.debug(f"An error occurred: {e}")
        return False


def set_player_turn(game_id, user_id):
    """Sets the turn for a player in a game.

    Args:
        game_id (int): The ID of the game.
        user_id (int): The ID of the user whose turn is being set.
    Returns:
        bool: True if the turn was successfully set, False otherwise.
    Raises:
        Exception: If an error occurs while setting the player's turn.
    """
    try:
        success = firebase_service.update_player_turn(game_id, user_id, True)

        if success:
            logger.debug(
                f"Successfully set turn for user_id: {user_id} in game_id: {game_id}")
            return True
        else:
            logger.debug(
                f"Failed to set turn for user_id: {user_id} in game_id: {game_id}")
            return False
    except Exception as e:
        logger.debug(f"An error occurred: {e}")
        return False


def is_player_in_game(user_id, game_id):
    """Checks if a player is part of a game.

    Args:
        user_id (int): The ID of the user.
        game_id (int): The ID of the game.
    Returns:
        bool: True if the player is in the game, False otherwise.
    Raises:
        Exception: If an error occurs while checking the player's participation.
    """
    try:
        player_data = firebase_service.get_player(game_id, user_id)

        if player_data:
            return True
        else:
            logger.debug(
                f"No player found with user_id: {user_id} in game_id: {game_id}")
            return False
    except Exception as e:
        logger.debug(f"An error occurred: {e}")
        return False
