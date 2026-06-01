import 'package:flutter/material.dart';

class _Archetype {
  final String id;
  final String label;
  final String prefix;
  final String tagline;
  final String primaryPillar;
  final String secondaryPillar;
  final IconData icon;
  final Color color;

  const _Archetype({
    required this.id,
    required this.label,
    required this.prefix,
    required this.tagline,
    required this.primaryPillar,
    required this.secondaryPillar,
    required this.icon,
    required this.color,
  });
}

const _archetypes = [
  _Archetype(
    id: 'scholar',
    label: 'The Scholar',
    prefix: 'The Wandering',
    tagline: 'Drawn to understanding the world through study and curiosity',
    primaryPillar: 'Mind',
    secondaryPillar: 'Spirit',
    icon: Icons.menu_book,
    color: Color(0xFF1E88E5),
  ),
  _Archetype(
    id: 'warrior',
    label: 'The Warrior',
    prefix: 'The Iron',
    tagline: 'Forged through discipline, physical challenge, and relentless growth',
    primaryPillar: 'Body',
    secondaryPillar: 'Career',
    icon: Icons.fitness_center,
    color: Color(0xFFE53935),
  ),
  _Archetype(
    id: 'monk',
    label: 'The Monk',
    prefix: 'The Silent',
    tagline: 'Seeking stillness, inner mastery, and presence in every moment',
    primaryPillar: 'Spirit',
    secondaryPillar: 'Body',
    icon: Icons.self_improvement,
    color: Color(0xFF8E24AA),
  ),
  _Archetype(
    id: 'builder',
    label: 'The Builder',
    prefix: 'The Rising',
    tagline: 'Creating lasting work, systems, and legacies that outlive the moment',
    primaryPillar: 'Career',
    secondaryPillar: 'Mind',
    icon: Icons.rocket_launch,
    color: Color(0xFFFB8C00),
  ),
  _Archetype(
    id: 'sage',
    label: 'The Sage',
    prefix: 'The Ancient',
    tagline: 'Giving wisdom freely, lifting others, embodying altruism as a way of life',
    primaryPillar: 'Karma',
    secondaryPillar: 'Spirit',
    icon: Icons.volunteer_activism,
    color: Color(0xFF43A047),
  ),
];

class ArchetypeSelectionScreen extends StatefulWidget {
  final void Function(String archetype, String label, String prefix) onSelected;

  const ArchetypeSelectionScreen({super.key, required this.onSelected});

  @override
  State<ArchetypeSelectionScreen> createState() => _ArchetypeSelectionScreenState();
}

class _ArchetypeSelectionScreenState extends State<ArchetypeSelectionScreen> {
  String? _selected;

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
                'Who are you\nbecoming?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the archetype that resonates most with your current self.',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: _archetypes.map((a) {
                    final selected = _selected == a.id;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = a.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selected ? a.color.withOpacity(0.15) : const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected ? a.color : Colors.white.withOpacity(0.08),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: a.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(a.icon, color: a.color, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.label,
                                    style: TextStyle(
                                      color: selected ? a.color : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    a.tagline,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _PillarTag(label: a.primaryPillar, color: a.color, isPrimary: true),
                                      const SizedBox(width: 6),
                                      _PillarTag(label: a.secondaryPillar, color: a.color, isPrimary: false),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(Icons.check_circle, color: a.color, size: 22),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected == null
                      ? null
                      : () {
                          final a = _archetypes.firstWhere((x) => x.id == _selected);
                          widget.onSelected(a.id, a.label, a.prefix);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    disabledBackgroundColor: Colors.white.withOpacity(0.1),
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

class _PillarTag extends StatelessWidget {
  final String label;
  final Color color;
  final bool isPrimary;
  const _PillarTag({required this.label, required this.color, required this.isPrimary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(isPrimary ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isPrimary ? '$label ●' : label,
        style: TextStyle(fontSize: 10, color: color.withOpacity(isPrimary ? 1 : 0.6), fontWeight: FontWeight.w600),
      ),
    );
  }
}
