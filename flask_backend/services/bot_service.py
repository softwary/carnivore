import time
import random
from datetime import datetime, timedelta
from firebase_admin import db
# from trie_bot import generate_bot_moves
from services import game_service, firebase_service
import pickle
import itertools
BOT_ID = "computer"
BOT_DELAY = 3  # seconds after last move


class BotService:
    def __init__(self, game_id, difficulty_level="easy", BOT_ID=BOT_ID, delay=BOT_DELAY, anagram_map=None):
        self.difficulty_level = difficulty_level
        self.BOT_ID = BOT_ID
        self.game_id = game_id
        self.delay = delay
        self.anagram_map = pickle.load(open(anagram_map, 'rb'))

    def flip_tile(self):
        """
        Flip a tile in the game.
        This is a placeholder for the actual logic that would flip a tile.
        """
        print("🩵 Bot flipping a tile...")
        # Flip tile after 1-4 seconds            
        time.sleep(random.randint(1, 4))
        game_service.flip_tile(self.game_id, self.BOT_ID)
        # Update the last move time
        # firebase_service.update_last_move_time(self.game_id, self.BOT_ID)


    def _get_valid_middle_words(self, middle_tiles):
        """
        Get all valid words that can be formed with the middle tile letters.
        Returns a list of dicts, where each dict is {'word': word, 'tileIds': [tile_ids...]}
        """
        results = []

        for r in range(3, len(middle_tiles) + 1):
            for combo_of_tiles in itertools.combinations(middle_tiles, r):
                # Build sorted key from the combo of letters
                letters = [tile['letter'].lower() for tile in combo_of_tiles]
                key = ''.join(sorted(letters))

                if key in self.anagram_map:
                    # Prepare (letter, tileId) pairs for mapping
                    combo_data = [(tile['letter'].lower(), tile['tileId']) for tile in combo_of_tiles]

                    for word in self.anagram_map[key]:
                        # Copy combo_data so we can remove used tiles while mapping
                        available_tiles = list(combo_data)
                        mapped_tile_ids = []

                        for letter in word:
                            for i, (tile_letter, tile_id) in enumerate(available_tiles):
                                if tile_letter == letter:
                                    mapped_tile_ids.append(tile_id)
                                    available_tiles.pop(i)
                                    break
                            else:
                                # Could not find a matching tile for the letter
                                mapped_tile_ids = []
                                break

                        if mapped_tile_ids:
                            results.append({
                                'WordSubmissionType': game_service.WordSubmissionType.MIDDLE_WORD,
                                'word': word,
                                'tileIds': mapped_tile_ids
                            })

        return results

    def _get_valid_non_middle_words(self, player_words, middle_tiles):
        """
        Get all valid words that can be formed by extending player words with middle tiles.
        This logic mirrors _get_valid_middle_words by mapping each letter of a
        potential word to a specific tileId.

        Returns a list of dicts, where each dict is {'word': word, 'tileIds': [tile_ids...]}
        """
        results = []
        for existing_word in player_words:
            # only need to add one or more tiles
            for r in range(1, len(middle_tiles) + 1):
                for combo_of_tiles in itertools.combinations(middle_tiles, r):
                    # Combine letters from the existing word and the new middle tiles
                    existing_letters = list(existing_word['word'].lower())
                    middle_letters = [tile['letter'].lower() for tile in combo_of_tiles]
                    combined_letters = existing_letters + middle_letters

                    # Create the sorted key for anagram lookup
                    key = "".join(sorted(combined_letters))

                    if key in self.anagram_map:
                        # Prepare a combined list of (letter, tileId) pairs for precise mapping
                        existing_tile_data = zip(existing_word['word'].lower(), existing_word['tileIds'])
                        middle_tile_data = [(tile['letter'].lower(), tile['tileId']) for tile in combo_of_tiles]
                        combo_data = list(existing_tile_data) + middle_tile_data

                        for word in self.anagram_map[key]:
                            # Ensure it's a new word, not the same as the existing one
                            if word == existing_word['word'].lower():
                                continue

                            # Perform robust mapping of letters to tile IDs
                            available_tiles = list(combo_data)
                            mapped_tile_ids = []

                            for letter in word:
                                found_match = False
                                for i, (tile_letter, tile_id) in enumerate(available_tiles):
                                    if tile_letter == letter:
                                        mapped_tile_ids.append(tile_id)
                                        available_tiles.pop(i)
                                        found_match = True
                                        break
                                
                                if not found_match:
                                    # This should not happen if the anagram map is correct,
                                    # but serves as a safeguard.
                                    mapped_tile_ids = []
                                    break
                            
                            if mapped_tile_ids:
                                results.append({
                                    'word': word,
                                    'tileIds': mapped_tile_ids,
                                    'current_owner_user_id': existing_word['current_owner_user_id'],
                                    'originalWord': existing_word['word'],
                                })
        return results


    def determine_move_to_make(self, middle_word_options, steal_options, valid_own_improvement_options):
        """
        Determine the best move to make based on the available options.
        This is a placeholder for the actual logic that would determine the best move.
        """
        print(" ")
        print("🩵 Determining move to make...")
        print(" ")
        middle_word_options = [{'word': word['word'], 'tileIds': word['tileIds']}
                               for word in middle_word_options]
        print("🩵 Middle word options: ", middle_word_options)
        steal_options = [{'word': word['word'], 'tileIds': word['tileIds']}
                               for word in steal_options]
        print("🩵 Steal options: ", steal_options)
        print(" ")
        valid_own_improvement_options = [{'word': word['word'], 'tileIds': word['tileIds']}
                               for word in valid_own_improvement_options]
        print("🩵 Own improvement options: ", valid_own_improvement_options)
        print(" ")
        # For now, just return the first valid middle word option if available
        if not middle_word_options and not steal_options and not valid_own_improvement_options:
            print("No valid moves available!!!!!!!!!")
            return None
        
        if middle_word_options:
            # return the last middle word option (it is the longest)
            # return middle_word_options[-1]
            return random.choice(middle_word_options)
        elif steal_options:
            return random.choice(steal_options)
        elif valid_own_improvement_options:
            return random.choice(valid_own_improvement_options)
        else:
            return None

    def generate_and_submit_bot_move(self):
        game = game_service.get_game(self.game_id)
        if not game:
            return None
        valid_words = [
            {
                "word": word["word"],
                "wordId": word["wordId"],
                "tileIds": word["tileIds"],
                "current_owner_user_id": word["current_owner_user_id"]
            }
            for word in game.get("words", [])
            if word.get("status") == "valid"
        ]

        middle_tiles = [
            tile
            for tile in game['tiles']
            if tile.get('location') == 'middle'
        ]
        middle_word_options = self._get_valid_middle_words(middle_tiles)

        valid_non_middle_word_options = self._get_valid_non_middle_words(
            valid_words, middle_tiles)

        own_improvement_options = [
            word for word in valid_non_middle_word_options if word['current_owner_user_id'] == self.BOT_ID]
        steal_options = [
            word for word in valid_non_middle_word_options if word['current_owner_user_id'] != self.BOT_ID]
        word_to_submit = self.determine_move_to_make(
            middle_word_options, steal_options, own_improvement_options)
        if word_to_submit is not None:
            print("🩵 Bot move to submit: ", word_to_submit)
            game_service.submit_word(
                self.game_id, "computer", word_to_submit['tileIds'])
            self.flip_tile()
            # Update the last move time
            # firebase_service.update_last_move_time(game_id, self.BOT_ID)
        else:
            print("No valid moves available for bot to submit.")
            return