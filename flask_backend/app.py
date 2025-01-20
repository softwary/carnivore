import firebase_admin
from firebase_admin import credentials, db
from flask import Flask, request, jsonify
from flask_cors import CORS
from services import game_service
from services import firebase_service

from config import LOCAL_DEV_PORT

cred = credentials.Certificate("./secrets/carnivore-5397b-firebase-adminsdk-9vx7r-f59e9c9d52.json")

app = Flask(__name__)
CORS(app)

firebase_admin.initialize_app(cred, {"databaseURL": "https://carnivore-5397b-default-rtdb.firebaseio.com"})
ref = db.reference()

@app.route('/join-game', methods=['POST'])
def join_game():
    print("join_game() called")
    print("request.data=",request.data) 
    print("join_game() called")
    print("request.data=", request.data.decode("utf-8"))  # Decode to string for debugging

    try:
        data = request.get_json(force=True, silent=False)
        print("Parsed JSON data:", data)

        if not data or 'game_id' not in data:
            return jsonify({"error": "Missing game_id"}), 400

        game_id = data['game_id']

        # Correct way to reference a path in Realtime Database:
        game_ref = ref.child('games').child(game_id)

        # Example: Setting some data (you'll likely want to do something more useful)
        # game_ref.set({'status': 'joining'}) # sets the status of that game id to joining

        return jsonify({"success": True, "gameId": game_id}), 200

    except Exception as e:
        print("Error processing request:", str(e))
        return jsonify({"error": str(e)}), 500  # Use 500 for server errors


@app.route('/flip-tile', methods=['POST'])
def flip_tile():
    data = request.get_json(force=True, silent=False)
    print("data = ", data)
    if not data or 'gameId' not in data:
        return jsonify({"error": "Missing gameId in request data"}), 400

    game_id = data['gameId']

    try:
        game_data = firebase_service.get_game(game_id)

        if not game_data:
            return jsonify({"error": "Game with ID {game_id} does not exist."}), 404

        # Process the tile flip logic
        success, updated_game_data = game_service.flip_tile(game_data)
        print("flip_tile()... success=", success)
        print("flip_tile()... updated_game_data=", updated_game_data)
        if success:
            firebase_service.update_game(game_id, updated_game_data)  # Update game state in Firebase
            return jsonify({"success": True, "data": updated_game_data}), 200
        else:
            return jsonify({"error": "No flippable tile available or all letters used"}), 400

    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=LOCAL_DEV_PORT, debug=True)