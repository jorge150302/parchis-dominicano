import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/language_provider.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _openWebPolicy(String langCode) async {
    final Uri url = Uri.parse(
      'https://baylee-nondissolving-fredrick.ngrok-free.dev/privacy?lang=$langCode',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // silently ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown.shade900,
      appBar: AppBar(
        title: Text(
          context.translate('privacy_policy'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.brown.shade700,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.black87,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
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
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.translate('privacy_policy_title'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.translate('privacy_last_updated'),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const Divider(height: 28),
                    Text(
                      context.translate('privacy_intro'),
                      style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    _policySection(
                      context.translate('privacy_s1_title'),
                      context.translate('privacy_s1_body'),
                    ),
                    _policySection(
                      context.translate('privacy_s2_title'),
                      context.translate('privacy_s2_body'),
                    ),
                    _policySection(
                      context.translate('privacy_s3_title'),
                      context.translate('privacy_s3_body'),
                    ),
                    _policySection(
                      context.translate('privacy_s4_title'),
                      context.translate('privacy_s4_body'),
                    ),
                    _policySection(
                      context.translate('privacy_s5_title'),
                      context.translate('privacy_s5_body'),
                    ),
                    _highlightSection(
                      context.translate('privacy_s6_title'),
                      context.translate('privacy_s6_body'),
                    ),
                    _policySection(
                      context.translate('privacy_s7_title'),
                      context.translate('privacy_s7_body'),
                    ),
                    _policySection(
                      context.translate('privacy_s8_title'),
                      context.translate('privacy_s8_body'),
                    ),
                    _policySection(
                      context.translate('privacy_s9_title'),
                      context.translate('privacy_s9_body'),
                    ),
                    _policySection(
                      context.translate('privacy_s10_title'),
                      context.translate('privacy_s10_body'),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          final lang = context.read<LanguageProvider>().currentLanguage;
                          _openWebPolicy(lang == Language.en ? 'en' : 'es');
                        },
                        icon: const Icon(Icons.open_in_browser, size: 18),
                        label: Text(context.translate('privacy_view_web')),
                        style: TextButton.styleFrom(foregroundColor: Colors.brown.shade700),
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
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _highlightSection(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: Colors.brown.shade400, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.brown.shade700),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(fontSize: 13, color: Colors.brown.shade800, height: 1.6),
          ),
        ],
      ),
    );
  }
}
