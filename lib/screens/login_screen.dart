import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/rbac_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _kRememberMe = 'remember_me';
  static const _kSavedEmail = 'saved_email';
  static const _kSavedPassword = 'saved_password';

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _rememberMe = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RbacRepository.instance.signIn(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      await _saveRememberedCredentials();
      RbacRepository.instance
          .registerDeviceToken()
          .timeout(const Duration(seconds: 8))
          .catchError((_) {});
    } on FirebaseAuthException catch (e) {
      var msg = '${e.code}${e.message == null ? '' : ': ${e.message}'}';
      if (e.code == 'unknown') {
        msg =
            'firebase_auth/unknown: verify Firebase Auth Email/Password is enabled, package id matches, and internet is available.';
      }
      setState(() {
        _error = msg;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_kRememberMe) ?? false;
    final savedEmail = prefs.getString(_kSavedEmail) ?? '';
    final savedPassword = prefs.getString(_kSavedPassword) ?? '';

    if (!mounted) {
      return;
    }
    setState(() {
      _rememberMe = remember;
      if (remember) {
        _emailCtrl.text = savedEmail;
        _passwordCtrl.text = savedPassword;
      }
    });
  }

  Future<void> _saveRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRememberMe, _rememberMe);
    if (_rememberMe) {
      await prefs.setString(_kSavedEmail, _emailCtrl.text.trim());
      await prefs.setString(_kSavedPassword, _passwordCtrl.text);
    } else {
      await prefs.remove(_kSavedEmail);
      await prefs.remove(_kSavedPassword);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text(
                'BovineTrack Sign In',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Admin and client accounts are role-locked through Firebase RBAC.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordCtrl,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                value: _rememberMe,
                onChanged: _loading
                    ? null
                    : (v) {
                        setState(() {
                          _rememberMe = v ?? false;
                        });
                      },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Remember me'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: Text(_loading ? 'Signing in...' : 'Sign In'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
