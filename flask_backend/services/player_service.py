from services import firebase_service
from logging_config import logger

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
        logger.debug(f"Checking if it's the turn for user_id: {user_id} in game_id: {game_id}")
        player_data = firebase_service.get_player(game_id, user_id)
        
        if player_data:
            is_turn = player_data.get('turn', False)
            logger.debug(f"Player data found for user_id: {user_id} in game_id: {game_id}. Turn status: {is_turn}")
            return is_turn
        else:
            logger.debug(f"No player found with user_id: {user_id} in game_id: {game_id}")
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
            logger.debug(f"Successfully set turn for user_id: {user_id} in game_id: {game_id}")
            return True
        else:
            logger.debug(f"Failed to set turn for user_id: {user_id} in game_id: {game_id}")
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
            logger.debug(f"No player found with user_id: {user_id} in game_id: {game_id}")
            return False
    except Exception as e:
        logger.debug(f"An error occurred: {e}")
        return False


def add_to_player_score(user_id, word_length):
    """Adds the length of a word to the player's score.

    Args:
        user_id (str): The ID of the user.
        word_length (int): The length of the word to add to the player's score.
    Returns:
        bool: True if the score was successfully updated, False otherwise.
    Raises:
        Exception: If an error occurs while updating the player's score.
    """
    try:
        player_data = firebase_service.get_player(user_id)
        
        if player_data:
            current_score = player_data.get('score', 0)
            new_score = current_score + word_length
            success = firebase_service.update_player_score(user_id, new_score)
            
            if success:
                logger.debug(f"Successfully updated score for user_id: {user_id}. New score: {new_score}")
                return True
            else:
                logger.debug(f"Failed to update score for user_id: {user_id}")
                return False
        else:
            logger.debug(f"No player found with user_id: {user_id}")
            return False
    except Exception as e:
        logger.debug(f"An error occurred: {e}")
        return False