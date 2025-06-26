class CustomWordleKeyboard extends StatelessWidget {
  final void Function(String) onKeyTap;
  final VoidCallback onBackspace;
  final VoidCallback onEnter;

  CustomWordleKeyboard({
    required this.onKeyTap,
    required this.onBackspace,
    required this.onEnter,
  });

  static const _row1 = ['Q','W','E','R','T','Y','U','I','O','P'];
  static const _row2 = ['A','S','D','F','G','H','J','K','L'];
  static const _row3 = ['Z','X','C','V','B','N','M'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildKeyRow(_row1),
          _buildKeyRow(_row2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionKey('ENTER', flex: 2, onTap: onEnter),
              ..._row3.map((k) => _buildKey(k)).toList(),
              _buildActionKey('DEL', flex: 2, onTap: onBackspace),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyRow(List<String> letters) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: letters.map((l) => _buildKey(l)).toList(),
    );
  }

  Widget _buildKey(String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            primary: Colors.grey[800],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          onPressed: () => onKeyTap(label),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _buildActionKey(String label, {required int flex, required VoidCallback onTap}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            primary: Colors.grey[700],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          onPressed: onTap,
          child: Text(label),
        ),
      ),
    );
  }
}
