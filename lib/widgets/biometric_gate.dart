import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

String biometricEnabledKey(String userId) => 'biometric_auth_$userId';
const biometricPendingLoginKey = 'biometric_auth_pending_login';

class BiometricGate extends StatefulWidget {
  const BiometricGate({super.key, required this.userId, required this.child});

  final String userId;
  final Widget child;

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> {
  final _auth = LocalAuthentication();
  bool _checking = true;
  bool _unlocked = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final pendingLogin = preferences.getBool(biometricPendingLoginKey);
      final userKey = biometricEnabledKey(widget.userId);
      final enabled = pendingLogin ?? preferences.getBool(userKey) ?? false;
      if (pendingLogin != null) {
        await preferences.setBool(userKey, pendingLogin);
        await preferences.remove(biometricPendingLoginKey);
      }
      if (!enabled) {
        if (mounted) setState(() => _unlocked = true);
        return;
      }
      await _authenticate();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo iniciar la biometría: $error');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _authenticate() async {
    if (mounted) setState(() => _checking = true);
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Confirma tu identidad para abrir Mr. Apache',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (!mounted) return;
      setState(() {
        _unlocked = authenticated;
        _error = authenticated ? null : 'No se confirmó tu identidad.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo verificar tu identidad: $error');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _disableAndSignOut() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(biometricEnabledKey(widget.userId), false);
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error = 'No se pudo cerrar la sesión: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fingerprint, size: 72, color: Color(0xFFC62828)),
              const SizedBox(height: 16),
              const Text(
                'Verifica tu identidad',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error ??
                    'Usa tu huella, rostro o el método de desbloqueo del dispositivo.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _checking ? null : _authenticate,
                icon: const Icon(Icons.fingerprint),
                label: Text(_checking ? 'Verificando…' : 'Intentar de nuevo'),
              ),
              TextButton(
                onPressed: _checking ? null : _disableAndSignOut,
                child: const Text('Desactivar y cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
