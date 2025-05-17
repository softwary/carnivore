import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UpdateUsernameDialog extends StatefulWidget {
  final User currentUser; // The already authenticated user

  const UpdateUsernameDialog({super.key, required this.currentUser});

  @override
  State<UpdateUsernameDialog> createState() => _UpdateUsernameDialogState();
}

class _UpdateUsernameDialogState extends State<UpdateUsernameDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing displayName if available, otherwise empty
    _usernameController = TextEditingController(text: widget.currentUser.displayName ?? '');
  }

  Future<void> _submitUsername() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();
    final newUsername = _usernameController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.currentUser.displayName != newUsername) {
        await widget.currentUser.updateProfile(displayName: newUsername);
        await widget.currentUser.reload(); // Important to refresh the user object
      }
      if (mounted) {
        Navigator.of(context).pop(newUsername); // Pop with the new username
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? "Failed to update username.";
    } catch (e) {
      _errorMessage = "An unexpected error occurred: ${e.toString()}";
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Your Game Username'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'E.g., Player123',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a username.';
                  }
                  if (value.trim().length < 3) {
                    return 'Username must be at least 3 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: _submitUsername,
                  child: const Text('Confirm Username'),
                ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: _isLoading ? null : () {
            Navigator.of(context).pop(null); // Pop with null indicating cancellation
          },
        ),
      ],
    );
  }
}