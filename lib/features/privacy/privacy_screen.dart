import 'package:flutter/material.dart';

import '../../core/config.dart';
import 'privacy_text.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final text = privacyPolicyAr.replaceAll('ADD_CONTACT_EMAIL_BEFORE_PUBLISHING', AppConfig.privacyContactEmail);
    return Scaffold(
      appBar: AppBar(title: const Text('سياسة الخصوصية')),
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: SelectableText(text))),
    );
  }
}
