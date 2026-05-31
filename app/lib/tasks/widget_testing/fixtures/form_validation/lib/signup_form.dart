import 'package:flutter/material.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key, required this.onSubmit});

  final void Function({required String email, required String password})
  onSubmit;

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _valid = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_revalidate);
    _passwordCtrl.addListener(_revalidate);
  }

  void _revalidate() {
    final ok =
        SignupForm.validateEmail(_emailCtrl.text) == null &&
        SignupForm.validatePassword(_passwordCtrl.text) == null;
    if (ok != _valid) setState(() => _valid = ok);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSubmit(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          TextFormField(
            key: const Key('email'),
            controller: _emailCtrl,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: SignupForm.validateEmail,
          ),
          TextFormField(
            key: const Key('password'),
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            validator: SignupForm.validatePassword,
          ),
          ElevatedButton(
            key: const Key('submit'),
            onPressed: _valid ? _submit : null,
            child: const Text('Sign up'),
          ),
        ],
      ),
    );
  }
}
