import 'package:flutter/material.dart';

class GoalSettingScreen extends StatefulWidget {
  final void Function(Map<String, String> goals) onContinue;
  final String archetypeLabel;

  const GoalSettingScreen({
    super.key,
    required this.onContinue,
    required this.archetypeLabel,
  });

  @override
  State<GoalSettingScreen> createState() => _GoalSettingScreenState();
}

class _GoalSettingScreenState extends State<GoalSettingScreen> {
  final _controllers = {
    'body':   TextEditingController(),
    'mind':   TextEditingController(),
    'spirit': TextEditingController(),
    'career': TextEditingController(),
    'karma':  TextEditingController(),
  };

  static const _questions = {
    'body':   ('Body', Icons.fitness_center, Color(0xFFE53935), 'What do you want your body to be capable of?'),
    'mind':   ('Mind', Icons.menu_book, Color(0xFF1E88E5), 'What do you want to understand or master?'),
    'spirit': ('Spirit', Icons.self_improvement, Color(0xFF8E24AA), 'How do you want to feel, within yourself?'),
    'career': ('Career', Icons.rocket_launch, Color(0xFFFB8C00), 'What legacy are you building?'),
    'karma':  ('Karma', Icons.volunteer_activism, Color(0xFF43A047), 'How do you want to show up for others?'),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Name your\nintentions.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'These are for you, not the system. Skip any you\'re not ready to name.',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: _questions.entries.map((entry) {
                    final data = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(data.$2, color: data.$3, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                data.$1,
                                style: TextStyle(color: data.$3, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _controllers[entry.key],
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: data.$4,
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFF1A1A2E),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: data.$3.withOpacity(0.2)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: data.$3),
                              ),
                              contentPadding: const EdgeInsets.all(14),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final goals = _controllers.map(
                      (key, ctrl) => MapEntry(key, ctrl.text.trim()),
                    );
                    widget.onContinue(goals);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
