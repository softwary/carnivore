import firebase_admin
from firebase_admin import credentials, db
from flask import Flask, request, jsonify
from flask_cors import CORS
import services.firebase_service as firebase_service
import services.player_service as player_service
import services.game_service as game_service
import services.tile_service as tile_service
import services.word_validation_service as word_validation_service
import models.game as game
import models.player as player
import models.tile as tile
from config import LOCAL_DEV_PORT
import google.oauth2.id_token
import google.auth.transport.requests
import requests
import logging
from functools import wraps
from firebase_admin import _auth_utils as auth
import functools
import uuid
import datetime
from flask import Flask
from logging_config import logger

app = Flask(__name__)

cred = credentials.Certificate("./secrets/carnivore-5397b-firebase-adminsdk-9vx7r-f59e9c9d52.json")

CORS(app)

firebase_admin.initialize_app(cred, {"databaseURL": "https://carnivore-5397b-default-rtdb.firebaseio.com"})
ref = db.reference()

request_adapter = google.auth.transport.requests.Request()

def verify_firebase_token(f):
    @functools.wraps(f)
    def wrapper(*args, **kwargs):
        token = request.headers.get('Authorization')
        logger.debug(f"verify_firebase_token() --> token= {token[:10]}")
        if not token:
            logger.warning("verify_firebase_token() --> Authorization token is missing")
            return jsonify({'error': 'Authorization token is required'}), 401

        try:
            if token.startswith('Bearer '):
                token = token[7:]

            idinfo = google.oauth2.id_token.verify_firebase_token(
                token, request_adapter
            )

            user_id = idinfo['sub']
            logger.debug(f"verify_firebase_token() --> user_id= {user_id}")
            request.user_id = user_id

        except ValueError as e:
            logger.error(f"verify_firebase_token() --> ValueError during token verification: {e}")
            return jsonify({'error': 'Invalid token'}), 401
        except google.auth.exceptions.InvalidValue as e:
            logger.error(f"verify_firebase_token() --> InvalidValue error during token verification: {e}")
            return jsonify({'error': 'Invalid token'}), 401
        except google.auth.exceptions.ExpiredToken as e:
            logger.error(f"verify_firebase_token() --> ExpiredToken error during token verification: {e}")
            return jsonify({'error': 'Token has expired'}), 401
        except Exception as e:  # Catch other potential exceptions
            logger.exception("verify_firebase_token() --> An unexpected error occurred: {e}")  # Log the full traceback
            return jsonify({'error': 'Authentication failed'}), 500 # Internal Server Error

        return f(*args, **kwargs)
    return wrapper

def validate_user_and_game_id_in_request_data(f):
    @functools.wraps(f)
    def wrapper(*args, **kwargs):
        data = request.get_json()
        if not data:
            return jsonify({"error": "Missing data in request"}), 400

        user_id = request.user_id  # Assuming you're using the Firebase token decorator
        game_id = data.get('game_id')  # Or however your game ID is provided

        if not user_id:
            return jsonify({"error": "Missing user_id"}), 400
        if not game_id:
            return jsonify({"error": "Missing game_id"}), 400
        
        # Check if game exists (optional but good practice)
        game_data = firebase_service.get_game(game_id)
        if not game_data:
            return jsonify({'error': f"Game with ID {game_id} does not exist."}), 404

        # Check if user is in the game (if needed):
        if not player_service.is_player_in_game(user_id, game_id):
            return jsonify({'error': f"User with ID {user_id} is not part of game {game_id}."}), 400        

        return f(*args, **kwargs)  # Call the route handler
    return wrapper

@app.route('/submit-word', methods=['POST'])
@verify_firebase_token
@validate_user_and_game_id_in_request_data
def submit_word():
    logger.debug(f"")
    logger.debug(f"")
    logger.debug(f"")
    logger.debug(f"#")
    logger.debug(f"in app.py, submit_word() request = {request}")
    user_id = request.user_id
    logger.debug(f"in app.py, submit_word() user_id = {user_id}")
    data = request.get_json(force=True, silent=False)
    logger.debug(f"in app.py, submit_word() request.data = {request.data}")
    game_id = data.get('game_id')
    tile_ids = data.get('tile_ids')
    
    if not tile_ids:
        return jsonify({"error": "Missing tile_ids in request"}), 400
    
    tiles = [tile_service.get_tile(game_id, tile_id) for tile_id in tile_ids]
    logger.debug(f"[tile_service.py][get_tile] tiles = {tiles}")
    logger.debug(f"")
    if not tiles:
        return jsonify({"error": "Tiles not found in game"}), 404

    word = ''.join([tile['letter'] for tile in tiles if tile and 'letter' in tile])
    logger.debug(f"[submit_word] word = {word}")
    logger.debug(f"")

    # Check game exists
    game_data = firebase_service.get_game(game_id)
    # logger.debug(f"[firebase_service.py][get_game] game_data = {game_data}")
    logger.debug(f"")
    logger.debug(f"1235479835701501 I MADE IT HERE!")
    # Determine word submission type
    submission_type, potential_words_to_steal = game_service.identifyWordSubmissionType(game_id, user_id, tile_ids)
    logger.debug(f"WOW LOOK AT THAT I MADE IT NOW HERE...submission_type = {submission_type}")
    logger.debug(f"[game_service.py][identifyWordSubmissionType] submission_type = {submission_type}")
    logger.debug(f"[game_service.py][identifyWordSubmissionType] potential_words_to_steal = {potential_words_to_steal}")
    logger.debug(f"")

    logger.debug(f"in app.py, word = ({word}),submission_type={submission_type}")
    logger.debug(f"")
    # Call appropriate helper function based on submission type
    if submission_type == game_service.WordSubmissionType.INVALID_UNKNOWN_WHY or \
        submission_type == game_service.WordSubmissionType.INVALID_LENGTH or \
        submission_type == game_service.WordSubmissionType.INVALID_NO_MIDDLE or \
        submission_type == game_service.WordSubmissionType.INVALID_LETTERS_USED or \
        submission_type == game_service.WordSubmissionType.INVALID_WORD_NOT_IN_DICTIONARY:
        logger.debug(f"submission_type is {submission_type} hence why I am submitting an invalid word")
        logger.debug(f"--> game_id = {game_id} | user_id={user_id}")
        logger.debug(f"--> tile_ids = {tile_ids} | word={word}")
        result = game_service.submit_invalid_word(game_id, user_id, tile_ids, word)
        logger.debug(f"[game_service.py][submit_invalid_word] result = {result}")
        logger.debug(f"")
    elif submission_type == game_service.WordSubmissionType.MIDDLE_WORD:
        logger.debug(f"[game_service.py][submit_middle_word] trying to submit a middle word")
        logger.debug(f"--> game_id = {game_id} | user_id={user_id}")
        logger.debug(f"--> tile_ids = {tile_ids} | word={word}")
        result = game_service.submit_middle_word(game_id, user_id, tile_ids, word)
        logger.debug(f"[game_service.py][submit_middle_word] result = {result}")
        logger.debug(f"")
    elif submission_type == game_service.WordSubmissionType.OWN_WORD_IMPROVEMENT:
        logger.debug(f"OWN_WORD_IMPROVEMENT is happening")
        result = game_service.improve_own_word(game_id, user_id, tile_ids, word)
        logger.debug(f"[game_service.py][improve_own_word] result = {result}")
        logger.debug(f"")
    elif submission_type == game_service.WordSubmissionType.STEAL_WORD:
        result = game_service.steal_word(game_id, user_id, tile_ids, word)
        logger.debug(f"[game_service.py][steal_word] result = {result}")
        logger.debug(f"")
    else:
        return jsonify({'error': 'Could not identify word submission type'}), 400

    if result['success']:
        return jsonify({'message': result['message']}), 200
    else:
        return jsonify({'error': result['message']}), 400  # Or appropriate error code

@app.route('/join-game', methods=['POST'])
@verify_firebase_token
def join_game():
    logger.debug(f"join_game() called")
    logger.debug(f"join_game() --> request.data= {request.data}")
    logger.debug(f"join_game() --> request.data= {request.data.decode('utf-8')}")  # Decode to string for debugging
    user_id = request.user_id  # Get user ID from the verified token
    logger.debug(f"join_game() --> user_id (expecting a persistent user id here for google logged in users)= {user_id}")
    try:
        data = request.get_json(force=True, silent=False)
        logger.debug(f"join_game() --> Parsed JSON data: {data}")

        if not data or 'game_id' not in data:
            return jsonify({"error": "Missing game_id"}), 400
        game_id = data['game_id']
        game_ref = ref.child('games').child(game_id)
        game_data = game_ref.get()

        if not game_data:
            return jsonify({"error": f"Game with ID {game_id} does not exist."}), 404

        def update_players(current_data):
            if current_data is None:
                current_data = {'players': {}}
            
            players = current_data.get('players', {})
            if user_id not in players:
                order = len(players) + 1
                turn = False
                if order == 1:
                    turn = True
                players[user_id] = {'game_id': game_id, 'score': 0, 'turn': turn, 'turnOrder': order}

            current_data['players'] = players
            return current_data  # Return the entire updated game data

        game_ref.transaction(update_players)

        return jsonify({"success": True, "game_id": game_id}), 200

    except Exception as e:
        logger.error(f"join_game() --> Error processing request: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/flip-tile', methods=['POST'])
@verify_firebase_token
@validate_user_and_game_id_in_request_data
def flip_tile():
    user_id = request.user_id
    logger.debug(f"flip_tile() called")
    logger.debug(f"flip_tile() --> user_id= {user_id}")
    try:    
        data = request.get_json(force=True, silent=False)
        logger.debug(f"flip_tile() --> data = {data}")
        if not data or 'game_id' not in data or user_id is None:
            logger.debug(f"flip_tile() --> Missing game_id in request data or user_id is None")
            return jsonify({"error": "Missing game_id in request data"}), 400

        game_id = data['game_id']
        logger.debug(f"flip_tile() --> game_id= {game_id}")
        game_data = firebase_service.get_game(game_id)

        if not game_data:
            logger.debug(f"flip_tile() --> Game with ID {game_id} does not exist.")
            return jsonify({"error": f"Game with ID {game_id} does not exist."}), 404
        if not player_service.is_player_turn(user_id, game_id):
            logger.debug(f"flip_tile() --> Not the player's turn")
            return jsonify({"error": "Not the player's turn"}), 400
        else:
            success, updated_game_data = game_service.flip_tile(game_id)
            logger.debug(f"flip_tile() --> success= {success}")
            logger.debug(f"flip_tile() --> updated_game_data= {updated_game_data}")
            if success:
                firebase_service.update_game(game_id, updated_game_data)  # Update game state in Firebase
                logger.debug(f"flip_tile() --> Game state updated in Firebase")
                if len(game_data['players']) > 1:
                    updated_game_data = game_service.set_next_player_turn(game_id)
                    firebase_service.update_game(game_id, updated_game_data)  # Ensure the updated turn is saved
                    logger.debug(f"flip_tile() --> Next player's turn set")
                return jsonify({"success": True, "data": updated_game_data}), 200
            else:
                logger.debug(f"flip_tile() --> No flippable tile available or all letters used")
                return jsonify({"error": "No flippable tile available or all letters used"}), 400

    except Exception as e:
        logger.error(f"flip_tile() --> Error processing request: {str(e)}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=LOCAL_DEV_PORT, debug=True)
