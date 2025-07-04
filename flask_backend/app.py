import os
import firebase_admin
from firebase_admin import credentials, db
from flask import Flask, request, jsonify
from flask_cors import CORS
import services.firebase_service as firebase_service
import services.player_service as player_service
import services.game_service as game_service
import services.bot_service as bot_service
from services.bot_manager import bot_manager
import services.word_validation_service as word_validation_service
import models.game as game
import models.player as player
import models.tile as tile
from config import LOCAL_DEV_PORT
import google.oauth2.id_token
import google.auth.transport.requests
from functools import wraps
from firebase_admin import _auth_utils as auth
import functools
import uuid
import datetime
from flask import Flask
from logging_config import logger
# from scheduler import start as start_scheduler
import services.hashmap_service as hashmap_service


app = Flask(__name__)

cred = credentials.Certificate(
    "./secrets/carnivore-5397b-firebase-adminsdk-9vx7r-f59e9c9d52.json")

CORS(app, resources={r"/*": {"origins": "*"}})

firebase_admin.initialize_app(
    cred, {"databaseURL": "https://carnivore-5397b-default-rtdb.firebaseio.com"})
ref = db.reference()

request_adapter = google.auth.transport.requests.Request()

ANAGRAM_MAP_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    'services', 'anagram_map.pkl'
)
DICT_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    'word_validation', 'dictionary.txt'
)

if not os.path.exists(ANAGRAM_MAP_PATH):
    print("Building anagram map...")
    hashmap_service.build_anagram_map(DICT_PATH, ANAGRAM_MAP_PATH)
else:
    print("Anagram map already exists.")

# Configure the BotManager with the anagram map path
bot_manager.configure(ANAGRAM_MAP_PATH)

class GameNotFoundError(Exception):
    pass


def verify_firebase_token(f):
    @functools.wraps(f)
    def wrapper(*args, **kwargs):
        """
        Wrapper function to verify Firebase token from the request headers.

        This function extracts the 'Authorization' token from the request headers,
        verifies it using Firebase, and attaches the user ID to the request object.

        Args:
            *args: Variable length argument list.
            **kwargs: Arbitrary keyword arguments.

        Returns:
            Response: A Flask response object with an error message and appropriate
            HTTP status code if the token is missing, invalid, or expired.
            Otherwise, it calls the wrapped function with the provided arguments.

        Raises:
            ValueError: If there is an error during token verification.
            google.auth.exceptions.InvalidValue: If the token is invalid.
            google.auth.exceptions.ExpiredToken: If the token has expired.
            Exception: For any other unexpected errors.
        """
        token = request.headers.get('Authorization')
        if not token:
            logger.warning(
                "verify_firebase_token() --> Authorization token is missing")
            return jsonify({'error': 'Authorization token is required'}), 401

        try:
            if token.startswith('Bearer '):
                token = token[7:]

            idinfo = google.oauth2.id_token.verify_firebase_token(
                token, request_adapter
            )

            user_id = idinfo['sub']
            request.user_id = user_id

        except ValueError as e:
            logger.error(
                f"verify_firebase_token() --> ValueError during token verification: {e}")
            return jsonify({'error': 'Invalid token'}), 401
        except google.auth.exceptions.InvalidValue as e:
            logger.error(
                f"verify_firebase_token() --> InvalidValue error during token verification: {e}")
            return jsonify({'error': 'Invalid token'}), 401
        except google.auth.exceptions.ExpiredToken as e:
            logger.error(
                f"verify_firebase_token() --> ExpiredToken error during token verification: {e}")
            return jsonify({'error': 'Token has expired'}), 401
        except Exception as e:
            logger.exception(
                "verify_firebase_token() --> An unexpected error occurred: {e}")
            return jsonify({'error': 'Authentication failed'}), 500

        return f(*args, **kwargs)
    return wrapper


def validate_user_and_game_id_in_request_data(f):
    """
    Decorator to validate the presence of user_id and game_id in the request data.
    This decorator checks if the request contains JSON data with a valid user_id and game_id.
    It also verifies if the game exists and if the user is part of the game.
    Args:
        f (function): The function to be decorated.
    Returns:
        function: The wrapped function with added validation.
    Raises:
        400: If the request data is missing, or if user_id or game_id is not provided.
        404: If the game with the provided game_id does not exist.
        400: If the user is not part of the game.
    """
    @functools.wraps(f)
    def wrapper(*args, **kwargs):
        data = request.get_json()
        if not data:
            return jsonify({"error": "Missing data in request"}), 400

        user_id = request.user_id
        game_id = data.get('game_id')

        if not user_id:
            return jsonify({"error": "Missing user_id"}), 400
        if not game_id:
            return jsonify({"error": "Missing game_id"}), 400

        # Check if game exists
        game_data = firebase_service.get_game(game_id)
        if not game_data:
            return jsonify({'error': f"Game with ID {game_id} does not exist."}), 404

        # Check if user is in the game (if needed):
        if not player_service.is_player_in_game(user_id, game_id):
            return jsonify({'error': f"User with ID {user_id} is not part of game {game_id}."}), 400

        return f(*args, **kwargs)
    return wrapper


@app.route('/join-game', methods=['POST'])
@verify_firebase_token
def join_game():
    """
    Handles the '/join-game' route for joining a game.
    This function is decorated with @app.route to handle POST requests to the '/join-game' endpoint.
    It verifies the Firebase token using the @verify_firebase_token decorator.
    The function expects a JSON payload with a 'game_id' key. It retrieves the game data from the database
    and updates the list of players for the specified game. If the user is not already a player in the game,
    they are added with an initial score of 0 and a turn order.
    Returns:
        Response: A JSON response indicating success or failure.
        - 200: If the user successfully joins the game.
        - 400: If the 'game_id' is missing from the request data.
        - 404: If the game with the specified 'game_id' does not exist.
        - 500: If there is an internal server error.
    Raises:
        Exception: If there is an error processing the request.
    """
    logger.debug(
        f"join_game() --> request.data= {request.data.decode('utf-8')}")
    user_id = request.user_id
    data = request.get_json()
    username = data.get('username')
    logger.debug(f"username= {username}")
    logger.debug(
        f"join_game() --> user_id (expecting a persistent user id here for google logged in users)= {user_id}")
    try:
        data = request.get_json(force=True, silent=False)
        logger.debug(f"join_game() --> Parsed JSON data: {data}")

        if not data or 'game_id' not in data:
            return jsonify({"error": "Missing game_id"}), 400
        game_id = data['game_id']
        game_data = firebase_service.get_game(game_id)
        if not game_data:
            return jsonify({"error": f"Game with ID {game_id} does not exist."}), 404

        success = game_service.add_player_to_game(game_id, user_id, username)
        if success:
            return jsonify({"success": True, "game_id": game_id}), 200
        else:
            return jsonify({"error": "Failed to add player to game"}), 500

    except Exception as e:
        logger.error(f"join_game() --> Error processing request: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/create-game', methods=['POST'])
@verify_firebase_token
def create_game():
    """
    Handles the '/create-game' route for creating a new game.
    This function is decorated with @app.route to handle POST requests to the '/create-game' endpoint.
    It verifies the Firebase token using the @verify_firebase_token decorator.
    The function creates a new game and adds the user as the first player.
    Returns:
        Response: A JSON response indicating success or failure.
        - 200: If the game is successfully created.
        - 500: If there is an internal server error.
    Raises:
        Exception: If there is an error processing the request.
    """
    print("woot woot ✅✅✅create_game() called")
    user_id = request.user_id
    data = request.get_json()
    username = data.get('username')
    game_type= data.get('game_type', 'regular')  # Default to multiplayer if not specified
    logger.debug(f"username= {username}")
    logger.debug(
        f"create_game() --> user_id (expecting a persistent user id here for google logged in users)= {user_id}")
    try:
        game_id = game_service.create_game(user_id, username, game_type)
        if game_id:
            logger.debug(f"create_game() --> username = {username}")
            return jsonify({"success": True, "game_id": game_id}), 200
        else:
            return jsonify({"error": "Failed to create game"}), 500

    except Exception as e:
        logger.error(f"create_game() --> Error processing request: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/play-computer', methods=['POST'])
@verify_firebase_token
def create_bot_game():
    """
    Handles the '/create-bot-game' route for playing against the computer.
    This function is decorated with @app.route to handle POST requests to the '/create-bot-game' endpoint.
    It verifies the Firebase token using the @verify_firebase_token decorator.
    The function creates a new game and adds the user as the first player, and a computer player.
    Returns:
        Response: A JSON response indicating success or failure.
        - 200: If the game is successfully created.
        - 500: If there is an internal server error.
    Raises:
        Exception: If there is an error processing the request.
    """
    print("woot woot ✅✅✅create-bot-game() called")
    user_id = request.user_id
    data = request.get_json()
    username = data.get('username')
    logger.debug(f"username= {username}")
    logger.debug(
        f"create-bot-game() --> user_id (expecting a persistent user id here for google logged in users)= {user_id}")
    try:
        game_id = game_service.create_game(user_id, username, "computer")
        if game_id:
            bot_manager.get_service(game_id)
            logger.debug(f"create_game() --> username = {username}")
            return jsonify({"success": True, "game_id": game_id}), 200
        else:
            return jsonify({"error": "Failed to create game"}), 500

    except Exception as e:
        logger.error(f"create_game() --> Error processing request: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/flip-tile', methods=['POST'])
@verify_firebase_token
@validate_user_and_game_id_in_request_data
def flip_tile():
    """
    Handles the flipping of a tile in the game.

    This endpoint is called when a player wants to flip a tile. It verifies the 
    Firebase token, validates the user and game ID in the request data, and 
    processes the tile flip if all conditions are met.

    Returns:
        Response: A JSON response with the result of the tile flip operation.
            - On success: {"success": True, "data": updated_game_data}, HTTP status 200.
            - On failure due to missing game_id or user_id: {"error": "Missing game_id in request data"}, HTTP status 400.
            - On failure due to non-existent game: {"error": f"Game with ID {game_id} does not exist."}, HTTP status 404.
            - On failure due to not being the player's turn: {"error": "Not the player's turn", "user_id": user_id}, HTTP status 400.
            - On failure due to no flippable tile or all letters used: {"error": "No flippable tile available or all letters used"}, HTTP status 400.
            - On server error: {"error": str(e)}, HTTP status 500.
    """
    user_id = request.user_id
    logger.debug(f"flip_tile() called")
    logger.debug(f"flip_tile() --> user_id= {user_id}")
    try:
        data = request.get_json(force=True, silent=False)
        logger.debug(f"flip_tile() --> data = {data}")
        if not data or 'game_id' not in data or user_id is None:
            logger.debug(
                f"flip_tile() --> Missing game_id in request data or user_id is None")
            return jsonify({"error": "Missing game_id in request data"}), 400

        game_id = data['game_id']
        logger.debug(f"flip_tile() --> game_id= {game_id}")
        game_data = firebase_service.get_game(game_id)

        if not game_data:
            logger.debug(
                f"flip_tile() --> Game with ID {game_id} does not exist.")
            return jsonify({"error": f"Game with ID {game_id} does not exist."}), 404
        if not player_service.is_player_turn(user_id, game_id):
            logger.debug(f"flip_tile() --> Not the player's turn")
            return jsonify({"error": "Not the player's turn", "user_id": user_id}), 400
        else:
            success = game_service.flip_tile(game_id, user_id)
            logger.debug(f"flip_tile() --> success= {success}")
            if success:
                if game_data['gameType'] == "computer":
                    # Have bot check for words to submit after the human user flips a tile
                    bot_service = bot_manager.get_service(game_id)
                    if not bot_service:
                        logger.error(f"flip_tile() --> No bot service found for game {game_id}")
                        return jsonify({"error": "No bot service found for this game"}), 500

                    # If it's a computer game, we need to let the bot check for new moves after a tile flip
                    def bot_generate_and_submit_bot_move():
                        import time
                        import random
                        time.sleep(random.randint(1, 8))
                        bot_service.generate_and_submit_bot_move()
                    
                    import threading
                    thread = threading.Thread(target=bot_generate_and_submit_bot_move)
                    thread.start()

                    # At the same time, the bot also needs to be flipping a tile after the user does

                    def bot_flip_tile():
                        import time
                        import random
                        time.sleep(random.randint(1, 8))
                        bot_service.flip_tile()
                    logger.debug(f"flip_tile() --> Bot flipping tile for game {game_id}")
                    import threading
                    thread = threading.Thread(target=bot_flip_tile)
                    thread.start()

                return jsonify({"success": True}), 200
            else:
                logger.debug(
                    f"flip_tile() --> No flippable tile available or all letters used")
                return jsonify({"error": "No flippable tile available or all letters used"}), 400

    except Exception as e:
        logger.error(f"flip_tile() --> Error processing request: {str(e)}")
        return jsonify({"error": str(e)}), 500


@app.route('/submit-word', methods=['POST'])
@verify_firebase_token
@validate_user_and_game_id_in_request_data
def submit_word_route():
    """Handles word submission requests from the frontend.

    Verifies the user's token, extracts the game ID and tile IDs,
    and calls the game service to submit the word.  Returns appropriate
    JSON responses for success and various error conditions.
    """
    try:
        data = request.get_json()
        user_id = request.user_id
        logger.debug(f"submit_word_route() --> user_id= {user_id}")
        game_id = data.get('game_id')
        logger.debug(f"submit_word_route() --> game_id= {game_id}")
        tile_ids = data.get('tile_ids')
        logger.debug(f"submit_word_route() --> tile_ids= {tile_ids}")
        # if tile_ids have any duplicates, return an error
        if len(tile_ids) != len(set(tile_ids)):
            logger.debug(
                "submit_word_route() --> Duplicate tileIds are in the word, this is invalid")
            return jsonify({"error": "Duplicate tileIds"}), 400
        if not game_id:
            logger.debug("submit_word_route() --> Missing game_id")
            return jsonify({"error": "Missing game_id"}), 400
        if not tile_ids:
            logger.debug("submit_word_route() --> Missing tileIds")
            return jsonify({"error": "Missing tileIds"}), 400
        if not isinstance(tile_ids, list):
            logger.debug("submit_word_route() --> tileIds must be a list")
            return jsonify({"error": "tileIds must be a list"}), 400
        if not all(isinstance(tile_id, int) for tile_id in tile_ids):
            logger.debug("submit_word_route() --> tileIds must be integers")
            return jsonify({"error": "tileIds must be integers"}), 400

        result = game_service.submit_word(game_id, user_id, tile_ids)
        logger.debug(f"🙄submit_word_route() --> result= {result}")
        print("🙄🙄🙄🙄🙄submit_word_route() --> result= {result}")
        if result['success']:
            print(f" a user {user_id} submitted a word successfully")
            logger.debug(
                f"submit_word_route() --> Word submitted successfully: {result}")
            return jsonify(result), 200
        else:
            logger.debug(f"submit_word_route() --> Error: {result['message']}")
            # More specific error handling based on result['message']
            return jsonify({'error': result['message']}), 400

    except Exception as e:
        logger.error(
            f"submit_word_route() --> An unexpected error occurred: {e}")
        return jsonify({'error': 'An unexpected error occurred'}), 500


@app.route('/end-game', methods=['POST'])
@verify_firebase_token
@validate_user_and_game_id_in_request_data
def end_game():
    """Handles the cleanup of a game when it is over."""
    try:
        data = request.get_json()
        game_id = data.get('game_id')
        bot_manager.remove_service(game_id)
        return jsonify({"success": True, "message": f"Cleaned up resources for game {game_id}"}), 200
    except Exception as e:
        logger.error(f"end_game() --> An unexpected error occurred: {e}")
        return jsonify({'error': 'An unexpected error occurred'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=LOCAL_DEV_PORT, debug=True)
