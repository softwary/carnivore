import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_frontend/services/auth_service.dart';

class LoginSignUpDialog extends StatefulWidget {
  final String gameId;

  const LoginSignUpDialog({super.key, required this.gameId});

  @override
  State<LoginSignUpDialog> createState() => _LoginSignUpDialogState();
}

class _LoginSignUpDialogState extends State<LoginSignUpDialog> {
  final _formKey = GlobalKey<FormState>(); // Keep for username validation
  final _usernameController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin(Future<User?> Function() loginMethod) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save(); // Save the form data (username)

    final enteredUsername = _usernameController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      User? user = await loginMethod();
      if (user != null) {
        // ALWAYS try to update displayName with what was entered in THIS dialog,
        // as this is the username they intend to use for THIS game session.
        if (enteredUsername.isNotEmpty) {
          // Only update if different or if current displayName is null/empty,
          // to respect what was explicitly entered.
          if (user.displayName != enteredUsername ||
              user.displayName == null ||
              user.displayName!.isEmpty) {
            await user.updateProfile(displayName: enteredUsername);
            await user.reload(); // Ensure the user object is updated
            print(
                "LoginSignUpDialog: displayName updated to '$enteredUsername'");
          }
        } else {
          // This case should ideally not happen due to form validation.
          print(
              "LoginSignUpDialog: Warning - enteredUsername was empty after validation, displayName not updated.");
        }

        if (mounted) {
          Navigator.of(context).pop(enteredUsername);
        }
      } else if (mounted) {
        _errorMessage = "Login failed. Please try again.";
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? "An authentication error occurred.";
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
    final String dialogTitle =
        'Join Game ${widget.gameId.length > 6 ? "${widget.gameId.substring(0, 6)}..." : widget.gameId}';

    return AlertDialog(
      title: Text(dialogTitle),
      content: SingleChildScrollView(
        child: Form(
          // Wrap content in a Form for username validation
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Enter Your Username',
                  hintText: 'E.g., Player123',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a username.';
                  }
                  if (value.trim().length < 3) {
                    return 'Username must be at least 3 characters.';
                  }
                  // You could add more validation here (e.g., no special characters)
                  return null;
                },
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                )
              else ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.no_accounts),
                  label: const Text('Login Anonymously'),
                  onPressed: () => _handleLogin(() async {
                    await _authService.loginAnonymously();
                    return FirebaseAuth.instance.currentUser;
                  }),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 36)),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(
                      Icons.login), // Replace with Google icon if available
                  label: const Text('Login with Google'),
                  onPressed: () => _handleLogin(() async {
                    await _authService.loginWithGoogle();
                    return FirebaseAuth.instance.currentUser;
                  }),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 36)),
                ),
              ],
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: _isLoading
              ? null
              : () {
                  Navigator.of(context)
                      .pop(false); // Pop with false indicating cancellation
                },
        ),
      ],
    );
  }
}
