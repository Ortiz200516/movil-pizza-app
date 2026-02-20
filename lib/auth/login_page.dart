import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import '../home/home_admin.dart';
import '../home/home_cliente.dart';
import '../home/home_cocinero.dart';
import '../home/home_mesero.dart';
import '../home/home_repartidor.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final String rol = await _authService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      Widget destino;
      final rolLower = rol.toLowerCase();
      
      if (rolLower == 'cliente') {
        destino = HomeCliente();
      } else if (rolLower == 'cocinero') {
        destino = HomeCocinero();
      } else if (rolLower == 'repartidor') {
        destino = HomeRepartidor();
      } else if (rolLower == 'mesero') {
        destino = HomeMesero();
      } else if (rolLower == 'admin') {
        destino = HomeAdmin();
      } else {
        destino = HomeCliente();
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => destino),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_pizza, size: 100, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Pizzería App',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 10),
                const Text('Inicia sesión para continuar', style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 40),

                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Por favor ingrese su correo';
                    if (!value.contains('@')) return 'Correo inválido';
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                TextFormField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Por favor ingrese su contraseña';
                    if (value.length < 6) return 'La contraseña debe tener al menos 6 caracteres';
                    return null;
                  },
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('INICIAR SESIÓN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('¿No tienes cuenta? '),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                      child: const Text('Regístrate aquí', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}