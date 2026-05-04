// lib/settings/privacy_policy_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyPage extends StatelessWidget {
  static const String contactEmail = 'gpmai.app@gmail.com';
  static const String policyWebUrl = 'https://YOUR-DOMAIN/privacy'; // <-- host this text

  final String lastUpdated;
  const PrivacyPolicyPage({super.key, this.lastUpdated = '2025-09-11'});

  @override
  Widget build(BuildContext context) {
    final md = _markdown(lastUpdated);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: Markdown(
        data: md,
        selectable: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        onTapLink: (text, href, title) async {
          if (href == null) return;
          final uri = Uri.parse(href);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
      ),
    );
  }

  static String _markdown(String last) => """
# GPMai Privacy Policy

We respect your privacy. This notice explains what we collect and why, including how the **Ask about this screen** feature works.

**Web version:** [${policyWebUrl}](${policyWebUrl})  
**Contact:** [${contactEmail}](mailto:${contactEmail})  
_Last updated: ${last}_

---

## What the app does
GPMai provides AI chat and optional tools like OCR and “Ask about this screen”. Screen content is only captured **after you choose to** use that feature.

## Information we collect
We collect the minimum necessary to run the app:

- **Content you provide** — chat messages and files/screenshots you choose to send for analysis.
- **App diagnostics** — crash/error logs and performance metrics (aggregated).
- **Device basics** — device model, OS version, language/region; approximate IP for security.

We **do not** sell your personal information.

## “Ask about this screen”
- A **one-time screenshot** is taken **only after you tap Ask**.  
- A visible, ongoing **notification** indicates that capture/processing is active.  
- We **respect secure screens** (e.g., FLAG_SECURE) and do not attempt to bypass them.  
- You can stop at any time using the **STOP** action in the notification or by closing the panel.

### What is sent off-device?
- The screenshot (and/or extracted text) you chose to submit may be sent to our **AI model provider** to generate an answer.
- **OCR** is performed **on-device** using Google ML Kit’s on-device text recognition.

## Service providers (processors)
We use reputable processors to operate features:
- **AI model inference** — your submitted text/images may be processed by our model provider to return answers (e.g., OpenAI). Processing is limited to your request. See their privacy terms for details.  
- **On-device OCR** — Google ML Kit on-device text recognition (no image upload to Google for this feature).

We do not share data with unrelated third parties for advertising.

## Retention
- **Screenshots for Ask** — used transiently for analysis and **not stored** by us after answering.  
- **Chats** — stored **locally on your device** unless you delete them.  
- **Diagnostics** — retained only as long as needed for stability and support.

## Security
- Data in transit uses industry-standard encryption (HTTPS/TLS).
- We do not attempt to capture protected/secure windows.
- Please avoid using the feature on highly sensitive pages (e.g., banking/OTP/password).

## Your choices & controls
- Delete local chats from the Inbox screen (long-press → Delete).
- Don’t start “Ask” if you don’t want to share the current screen.
- You can revoke microphone/screen permissions in system settings at any time.

## Children
GPMai is not intended for children under the age permitted by local law.

## Contact
Questions or requests: [${contactEmail}](mailto:${contactEmail})
""";
}
