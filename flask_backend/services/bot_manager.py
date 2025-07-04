
from services import bot_service

class BotManager:
    _instance = None
    _bot_services = {}
    _anagram_map_path = None

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            cls._instance = super(BotManager, cls).__new__(cls)
        return cls._instance

    def configure(self, anagram_map_path):
        """Configure the manager with the path to the anagram map."""
        if not self._anagram_map_path:
            self._anagram_map_path = anagram_map_path

    def get_service(self, game_id):
        """Get or create a BotService for a given game_id."""
        if game_id not in self._bot_services:
            if not self._anagram_map_path:
                raise Exception("BotManager must be configured with an anagram_map_path before use.")
            
            print(f"Creating new BotService for game_id: {game_id}")
            self._bot_services[game_id] = bot_service.BotService(
                game_id=game_id,
                anagram_map=self._anagram_map_path
            )
        return self._bot_services[game_id]

    def remove_service(self, game_id):
        """Remove a BotService when a game is finished."""
        if game_id in self._bot_services:
            print(f"Cleaning up BotService for game_id: {game_id}")
            del self._bot_services[game_id]

# Create a single, global instance of the manager
bot_manager = BotManager()

