import 'package:flutter/material.dart';

class PrivacyConsentScreen extends StatefulWidget {
  const PrivacyConsentScreen({
    super.key,
    required this.onAccept,
    required this.onViewPolicy,
    required this.policyVersion,
    this.acceptedAt,
  });

  final Future<void> Function() onAccept;
  final VoidCallback onViewPolicy;
  final String policyVersion;
  final DateTime? acceptedAt;

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen> {
  bool _hasConfirmed = false;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Commitment'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Before you continue, please review how AGiXT handles your data.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _policyPoint(
                        context,
                        title: 'Transparent Data Practices',
                        message:
                            'We only collect information that you supply or connect (calendars, checklists, notes, device telemetry) to deliver AGiXT features.',
                      ),
                      _policyPoint(
                        context,
                        title: 'AI Personalization',
                        message:
                            'Content you provide powers AGiXT automations and responses. We do not sell your information, and third parties only receive it when necessary to run the service.',
                      ),
                      _policyPoint(
                        context,
                        title: 'Your Controls',
                        message:
                            'You can request deletion of your data at any time by emailing support@devxt.com.',
                      ),
                      _policyPoint(
                        context,
                        title: 'Retention',
                        message:
                            'User-generated content is kept, unless you request us to delete it, or we remove it to manage storage.',
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: widget.onViewPolicy,
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Read the full Privacy Policy'),
                      ),
                      if (widget.acceptedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'You accepted version ${widget.policyVersion} on ${_formatDate(widget.acceptedAt!)}.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _hasConfirmed,
                onChanged: (value) => setState(() {
                  _hasConfirmed = value ?? false;
                }),
                title: const Text(
                  'I have read and agree to the AGiXT Privacy Policy.',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _hasConfirmed && !_isSubmitting ? _submit : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Agree and Continue'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Policy version ${widget.policyVersion}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onAccept();
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _policyPoint(BuildContext context,
      {required String title, required String message}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2.0),
            child: Icon(Icons.check_circle_outline, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(message, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
