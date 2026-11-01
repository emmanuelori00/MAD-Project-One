import 'package:flutter/material.dart';

import '../data/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final SettingsController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _equipment;
  int? _effort;
  bool? _reducedMotion;
  String? _message;

  Future<void> _save() async {
    final saved = widget.controller.value;
    final success = await widget.controller.save(
      AppSettings(
        equipment: _equipment ?? saved.equipment,
        defaultEffort: _effort ?? saved.defaultEffort,
        reducedMotion: _reducedMotion ?? saved.reducedMotion,
      ),
    );
    if (!mounted) return;
    setState(() {
      _message = success ? 'Settings saved.' : null;
      if (success) {
        _equipment = null;
        _effort = null;
        _reducedMotion = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        if (!controller.loaded) {
          return Center(
            child: controller.busy
                ? const CircularProgressIndicator(
                    semanticsLabel: 'Loading settings',
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(controller.error ?? 'Settings are unavailable.'),
                      TextButton(
                        onPressed: controller.load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
          );
        }
        final settings = controller.value;
        final effort = _effort ?? settings.defaultEffort;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _equipment ?? settings.equipment,
              decoration: const InputDecoration(
                labelText: 'Equipment preference',
              ),
              isExpanded: true,
              items: equipmentChoices
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: controller.busy
                  ? null
                  : (value) => setState(() {
                      _equipment = value;
                      _message = null;
                    }),
            ),
            const SizedBox(height: 24),
            Text('Default effort: $effort of 5'),
            Semantics(
              label: 'Default effort',
              child: Slider(
                value: effort.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '$effort of 5',
                semanticFormatterCallback: (value) => '${value.round()} of 5',
                onChanged: controller.busy
                    ? null
                    : (value) => setState(() {
                        _effort = value.round();
                        _message = null;
                      }),
              ),
            ),
            const Text(
              'Defaults apply to new plans. Existing plans stay the same.',
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reduce motion'),
              subtitle: const Text(
                'Use less animation when moving between screens.',
              ),
              value: _reducedMotion ?? settings.reducedMotion,
              onChanged: controller.busy
                  ? null
                  : (value) => setState(() {
                      _reducedMotion = value;
                      _message = null;
                    }),
            ),
            if (controller.error != null)
              Semantics(liveRegion: true, child: Text(controller.error!)),
            if (_message != null)
              Semantics(liveRegion: true, child: Text(_message!)),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: controller.busy ? null : _save,
                child: Text(controller.busy ? 'Saving…' : 'Save settings'),
              ),
            ),
          ],
        );
      },
    );
  }
}
