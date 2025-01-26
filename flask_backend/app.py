import firebase_admin
from firebase_admin import credentials, db
from flask import Flask, request, jsonify
from flask_cors import CORS
from services import firebase_service, player_service, game_service, tile_service, word_validation_service
from models import game, player, tile
from config import LOCAL_DEV_PORT
import google.oauth2.id_token
import google.auth.transport.requests
import requests
import logging
from functools import wraps
from firebase_admin import _auth_utils as auth
import functools
import logging

cred = credentials.Certificate("./secrets/carnivore-5397b-firebase-adminsdk-9vx7r-f59e9c9d52.json")

app = Flask(__name__)
CORS(app)

firebase_admin.initialize_app(cred, {"databaseURL": "https://carnivore-5397b-default-rtdb.firebaseio.com"})
ref = db.reference()

logger = logging.getLogger(__name__)

# Create the request adapter once
request_adapter = google.auth.transport.requests.Request()

def verify_firebase_token(f):
    @functools.wraps(f)
    def wrapper(*args, **kwargs):
        token = request.headers.get('Authorization')
        print("token=", token)
        if not token:
            logger.warning("Authorization token is missing")
            return jsonify({'error': 'Authorization token is required'}), 401

        try:
            if token.startswith('Bearer '):
                token = token[7:]

            idinfo = google.oauth2.id_token.verify_firebase_token(
                token, request_adapter
            )

            user_id = idinfo['sub']
            request.user_id = user_id
            # Should this code just return if user_id is null?

        except ValueError as e:
            logger.error(f"ValueError during token verification: {e}")
            return jsonify({'error': 'Invalid token'}), 401
        except google.auth.exceptions.InvalidValue as e:
            logger.error(f"InvalidValue error during token verification: {e}")
            return jsonify({'error': 'Invalid token'}), 401
        except google.auth.exceptions.ExpiredToken as e:
            logger.error(f"ExpiredToken error during token verification: {e}")
            return jsonify({'error': 'Token has expired'}), 401
        except Exception as e:  # Catch other potential exceptions
            logger.exception(f"An unexpected error occurred: {e}")  # Log the full traceback
            return jsonify({'error': 'Authentication failed'}), 500 # Internal Server Error

        return f(*args, **kwargs)
    return wrapper

@app.route('/submit-word', methods=['POST'])
@verify_firebase_token
def submit_word():
    """
    - the user has to exist
    - the gameid has to exist
    - the user submitting the word will have to be in the game they are submitting the word for
    - the game has to still be valid and not done (aka there are remaining letters left)
    These can be handled separately:
    - the word has to be at least 3 letters long (or it is invalid)
    - the word has to use at least one tile that inMiddle=true
    - the word has to use letters that are in the game 
    """
    print("submit_word() called")
    print("request.data=", request.data)
    data = request.get_json(force=True, silent=False)
    user_id = request.user_id
    print("submit_word() user_id (expecting a persistent user id here for google logged in users)= ", user_id)
    if not data:
        return jsonify({"error": "Missing data in request"}), 400
    
    game_id = data['gameId']
    print("@@@@ game_id=", game_id)
    tile_ids = data['tileIds']


    if not game_id:
        return jsonify({"error": "Missing game_id"}), 400
    if not tile_ids:
        return jsonify({"error": "Missing tileIds"}), 400
    
    game_data = firebase_service.get_game(game_id)
    if not game_data:
        return jsonify({"error": "Game does not exist in database"}), 404
    
    # TODO: Check if the user exists and is part of the game
    if game_service.is_game_over(game_id):
        return jsonify({"error": "Game is over"}), 410
    tiles = [tile_service.get_tile(game_id, tile_id) for tile_id in tile_ids]
    if not tiles:
        return jsonify({"error": "Tiles not found in game"}), 404
    print(" ")
    print("tiles = ", tiles)
    # Validate the word length and usage of tiles
    if not word_validation_service.is_valid_word_length(tiles):
        return jsonify({"error": "Word too short"}), 400
    if not word_validation_service.uses_at_least_one_middle_tile(tiles):
        return jsonify({"error": "Word does not use any middle tiles"}), 400
    if not word_validation_service.uses_valid_letters(game_id, tiles):
        return jsonify({"error": "Word uses invalid letters"}), 400
    if not word_validation_service.is_valid_word(tiles, game_id):
        return jsonify({"error": "Word is not valid in the dictionary"}), 400
    

    try:
        print("in submit_word() calling game_service.submit_valid_word()")
        game_service.submit_valid_word(user_id, game_id, tiles)
        return jsonify({"success": True, "message": "Word  submitted successfully"}), 200

    except Exception as e:
        print("in submit_word() Error processing request:", str(e))
        return jsonify({"error": str(e)}), 500  # Use 500 for server errors

@app.route('/join-game', methods=['POST'])
@verify_firebase_token
def join_game():
    print("join_game() called")
    print("request.data=",request.data) 
    print("join_game() called")
    print("request.data=", request.data.decode("utf-8"))  # Decode to string for debugging
    user_id = request.user_id  # Get user ID from the verified token
    print("join_game() user_id (expecting a persistent user id here for google logged in users)= ", user_id)
    try:

        data = request.get_json(force=True, silent=False)
        print("Parsed JSON data:", data)

        if not data or 'game_id' not in data:
            return jsonify({"error": "Missing game_id"}), 400

        game_id = data['game_id']


        game_ref = ref.child('games').child(game_id)
        game_data = game_ref.get()
        def update_players(current_data):
            if current_data is None:  # Game doesn't exist, create it with players
                current_data = {'players': {}}
            
            players = current_data.get('players', {})
            if user_id not in players:
                players[user_id] = {'gameId': game_id, 'score': 0, 'turn': False, 'wordSignatures': [], 'words': []}
            
            current_data['players'] = players
            return current_data  # Return the entire updated game data

        game_ref.transaction(update_players)

        return jsonify({"success": True, "gameId": game_id}), 200

    except Exception as e:
        print("Error processing request:", str(e))
        return jsonify({"error": str(e)}), 500

# TODO: Implement this function
# @app.route('/flip-tile', methods=['POST'])
# def flip_tile():
#     data = request.get_json(force=True, silent=False)
#     print("data = ", data)
#     if not data or 'gameId' not in data:
#         return jsonify({"error": "Missing gameId in request data"}), 400

#     game_id = data['gameId']

#     try:
#         game_data = firebase_service.get_game(game_id)

#         if not game_data:
#             return jsonify({"error": "Game with ID {game_id} does not exist."}), 404

#         # Process the tile flip logic
#         success, updated_game_data = game_service.flip_tile(game_data)
#         print("flip_tile()... success=", success)
#         print("flip_tile()... updated_game_data=", updated_game_data)
#         if success:
#             firebase_service.update_game(game_id, updated_game_data)  # Update game state in Firebase
#             return jsonify({"success": True, "data": updated_game_data}), 200
#         else:
#             return jsonify({"error": "No flippable tile available or all letters used"}), 400

#     except Exception as e:
#         return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=LOCAL_DEV_PORT, debug=True)