import 'package:flutter/material.dart';
import '../../models/or_models.dart';
import '../../stores/models_store.dart';
import 'models_extras.dart';

class ModelDetailPage extends StatelessWidget {
  final ORModel model;
  const ModelDetailPage({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    final store = ModelsScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(model.name),
        actions: [
          IconButton(
            tooltip: 'Compare',
            onPressed: () {
              store.toggleCompare(model);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(store.isInCompare(model.id) ? 'Added to compare' : 'Removed from compare')),
              );
            },
            icon: Icon(store.isInCompare(model.id) ? Icons.check_circle_rounded : Icons.compare_arrows_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(model: model),
          const SizedBox(height: 14),
          _Actions(model: model),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 12),
          _Meta(model: model),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ORModel model;
  const _Header({required this.model});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(model.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('${model.providerLabel} • ${model.id}', style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(text: 'Category: ${categoryToQuery(model.category)}'),
              _Pill(text: 'Tier: ${model.priceTier}'),
              if (model.contextLength > 0) _Pill(text: 'Context: ${model.contextLength}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _Actions extends StatelessWidget {
  final ORModel model;
  const _Actions({required this.model});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: () {
            // This will be wired to your chat creation flow in "existing files update"
            // (one model per chat session).
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => StartSessionPage(model: model)),
            );
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start session'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ModelSessionsPage(model: model)),
                  );
                },
                icon: const Icon(Icons.history_rounded),
                label: const Text('Sessions'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ManageModelPage(model: model)),
                  );
                },
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Manage'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CompareModelsPage(models: [model])),
            );
          },
          icon: const Icon(Icons.compare_arrows_rounded),
          label: const Text('Compare'),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  final ORModel model;
  const _Meta({required this.model});

  @override
  Widget build(BuildContext context) {
    final pricing = model.pricing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _kv('Provider', model.providerLabel),
        _kv('Model ID', model.id),
        _kv('Category', categoryToQuery(model.category)),
        _kv('Price tier', model.priceTier),
        if (model.contextLength > 0) _kv('Context length', '${model.contextLength}'),
        const SizedBox(height: 10),
        if (pricing != null) ...[
          const Text('Pricing (raw)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(pricing.toString(), style: TextStyle(color: Theme.of(context).hintColor)),
        ],
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
