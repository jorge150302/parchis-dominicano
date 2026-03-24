import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/language_provider.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _openWebPolicy() async {
    final Uri url = Uri.parse('https://baylee-nondissolving-fredrick.ngrok-free.dev/privacy');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // Ignorar error silenciosamente o mostrar snackbar
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown.shade900,
      appBar: AppBar(
        title: Text(context.translate('privacy_policy')),
        backgroundColor: Colors.brown.shade800,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/menu_background.png'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'POLÍTICA DE PRIVACIDAD',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown),
                    ),
                    const Divider(height: 30),
                    _policySection(
                      '1. Datos Recolectados',
                      'Recopilamos un identificador único de dispositivo (UUID) y el nombre de jugador que elijas. Estos datos son necesarios para gestionar las partidas multijugador.',
                    ),
                    _policySection(
                      '2. Uso de la Información',
                      'Tu información se utiliza exclusivamente para sincronizar tu progreso en las partidas, permitir la comunicación por chat y mostrar tu nombre en el tablero.',
                    ),
                    _policySection(
                      '3. Seguridad y Cifrado',
                      'Toda la comunicación entre la aplicación y nuestros servidores se realiza de forma segura mediante protocolos de cifrado (SSL/WSS).',
                    ),
                    _policySection(
                      '4. Control y Eliminación',
                      'Tienes el control total sobre tus datos. Puedes eliminar tu identidad y toda la información asociada permanentemente usando el botón "Eliminar Cuenta" en los Ajustes.',
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton.icon(
                        onPressed: _openWebPolicy,
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('Ver versión web completa'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _policySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.4)),
        ],
      ),
    );
  }
}
