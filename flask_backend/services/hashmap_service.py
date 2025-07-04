# build_map.py
from collections import defaultdict
import os
import pickle

def build_anagram_map(dict_path, out_path='anagram_map.pkl'):
    """Builds a map of sorted letter combinations to words from a dictionary file.

    Args:
        dict_path (str): Path to the dictionary file.
        out_path (str): Path to save the output pickle file.
    """
    anagram_map = defaultdict(list)
    with open(dict_path, 'r') as f:
        for line in f:
            w = line.strip()
            if len(w) >= 3:                     # skip 1-letter “words”
                key = ''.join(sorted(w))
                anagram_map[key].append(w)
    with open(out_path, 'wb') as f:
        pickle.dump(anagram_map, f)
    print(f"Built map with {len(anagram_map)} keys.")

if __name__ == '__main__':

    base_dir = os.path.dirname(os.path.abspath(__file__))
    word_file_path = os.path.abspath(
        os.path.join(base_dir, '..', 'word_validation', 'dictionary.txt')
    )
    build_anagram_map(word_file_path)