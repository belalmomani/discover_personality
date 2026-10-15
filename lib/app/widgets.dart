import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ads/ad_service.dart';
import '../data/report/report_content.dart';
import 'providers.dart';

void pushScreen(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

void showMessage(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.icon});
  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, color: t.colorScheme.primary), const SizedBox(width: 8)],
            Expanded(child: Text(title, style: t.textTheme.titleMedium)),
          ]),
          const SizedBox(height: 10),
          child,
        ]),
      ),
    );
  }
}

class ScoreBar extends StatelessWidget {
  const ScoreBar({super.key, required this.label, required this.fraction, required this.valueText, this.highlight = false});
  final String label;
  final double fraction; // 0..1
  final String valueText;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: highlight ? const TextStyle(fontWeight: FontWeight.bold) : null)),
          Text(valueText),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 10,
            color: highlight ? cs.primary : cs.secondary,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
      ]),
    );
  }
}

class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, color: cs.onTertiaryContainer),
        const SizedBox(width: 8),
        Expanded(child: Text(disclaimerShort, style: TextStyle(color: cs.onTertiaryContainer))),
      ]),
    );
  }
}

class BulletList extends StatelessWidget {
  const BulletList(this.items, {super.key});
  final List<String> items;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final i in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('• '),
                Expanded(child: Text(i)),
              ]),
            ),
        ],
      );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'جارٍ التحميل...'});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(message),
        ]),
      );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ]),
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => EmptyView(
        icon: Icons.error_outline,
        message: message,
        action: onRetry == null ? null : FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
      );
}

/// Renders nothing unless AdService returns a banner (disabled by default, consent required).
class AdBanner extends ConsumerStatefulWidget {
  const AdBanner({super.key, required this.placement});
  final AdPlacement placement;
  @override
  ConsumerState<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends ConsumerState<AdBanner> {
  Widget? _banner;

  @override
  void initState() {
    super.initState();
    final ads = ref.read(adServiceProvider);
    final consent = ref.read(settingsProvider).adsConsent;
    ads.bannerFor(widget.placement, consent: consent).then((w) {
      if (mounted && w != null) setState(() => _banner = w);
    }).catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final b = _banner;
    if (b == null) return const SizedBox.shrink();
    return SafeArea(top: false, child: SizedBox(height: 60, child: Center(child: b)));
  }
}
