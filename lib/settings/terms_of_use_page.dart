// lib/settings/terms_of_use_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  static const _email = 'gpmai.app@gmail.com';
  static const _policyUrl = 'https://YOUR-DOMAIN/privacy'; // same URL as policy page

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Use')),
      body: SafeArea(
        child: Markdown(
          data: _markdown,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          onTapLink: (text, href, title) {
            if (href == null) return;
            final uri = Uri.parse(href);
            launchUrl(uri, mode: LaunchMode.externalApplication);
          },
        ),
      ),
    );
  }

  static const _markdown = '''
# Terms of Use

By using **GPMai**, you agree to these terms.

## What GPMai Does
GPMai provides AI-powered assistance, including optional OCR and an orb that lets you **Ask about this screen**. Screen capture occurs **only when you choose to**, and a notification is shown while processing is active.

## Your Content
- You retain ownership of the text/files you submit.
- You grant us a limited license to process your content solely to provide the requested features.

## Acceptable Use
You agree not to misuse the service (e.g., illegal content, abuse, reverse engineering, disrupting operation).

## AI Output
AI results can be inaccurate or incomplete. Use judgment; verify important information. This is not professional advice.

## Privacy
Your use is also governed by our [Privacy Policy](${_policyUrl}). Key points:
- No background monitoring.
- One-time screenshots used only after you tap **Ask**.
- We respect secure/FLAG_SECURE screens and do not bypass them.

## Changes & Availability
We may update features or this document. Continued use means you accept updates.

## Limitation of Liability
To the fullest extent permitted by law, we are not liable for indirect, incidental, special, or consequential damages, or data loss/profit loss arising from use of the app.

## Contact
Questions? Email us at [$_email](mailto:$_email).
''';
}
