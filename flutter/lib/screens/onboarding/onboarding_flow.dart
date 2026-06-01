import 'package:flutter/material.dart';
import 'archetype_selection_screen.dart';
import 'goal_setting_screen.dart';
import 'name_title_screen.dart';
import '../../services/profile_service.dart';

class OnboardingState {
  String archetype;
  String archetypeLabel;
  String archetypePrefix;
  Map<String, String> goals;
  String displayName;
  String customTitle;

  OnboardingState({
    this.archetype = '',
    this.archetypeLabel = '',
    this.archetypePrefix = '',
    this.goals = const {},
    this.displayName = '',
    this.customTitle = '',
  });
}

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _pageController = PageController();
  final _state = OnboardingState();
  bool _saving = false;

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _onArchetypeSelected(String archetype, String label, String prefix) {
    _state.archetype = archetype;
    _state.archetypeLabel = label;
    _state.archetypePrefix = prefix;
    _state.customTitle = '$prefix $label'.replaceAll('The ', '').trim();
    _nextPage();
  }

  void _onGoalsSet(Map<String, String> goals) {
    _state.goals = goals;
    _nextPage();
  }

  void _onNameSet(String name) {
    _state.displayName = name;
    _nextPage();
  }

  Future<void> _finishOnboarding() async {
    setState(() => _saving = true);
    try {
      await ProfileService().completeOnboarding(
        displayName: _state.displayName.trim().isEmpty ? 'Ascendant' : _state.displayName,
        archetype: _state.archetype,
        archetypeLabel: _state.archetypeLabel,
        customTitle: _state.archetypeLabel,
        goals: _state.goals,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _SplashPage(onBegin: _nextPage),
          ArchetypeSelectionScreen(onSelected: _onArchetypeSelected),
          GoalSettingScreen(onContinue: _onGoalsSet, archetypeLabel: _state.archetypeLabel),
          NameTitleScreen(
            onContinue: _onNameSet,
            archetypeLabel: _state.archetypeLabel,
          ),
          _PillarPreviewPage(
            state: _state,
            saving: _saving,
            onStart: _finishOnboarding,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _SplashPage extends StatelessWidget {
  final VoidCallback onBegin;
  const _SplashPage({required this.onBegin});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0533), Color(0xFF2D1B69), Color(0xFF1A0533)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(Icons.arrow_circle_up, color: Colors.white, size: 80),
              const SizedBox(height: 32),
              const Text(
                'The Open Ascent',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'What will you become?',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Text(
                'Body. Mind. Spirit. Career. Karma.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onBegin,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2D1B69),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Begin Your Ascent',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillarPreviewPage extends StatelessWidget {
  final OnboardingState state;
  final bool saving;
  final VoidCallback onStart;

  const _PillarPreviewPage({
    required this.state,
    required this.saving,
    required this.onStart,
  });

  static const _pillars = [
    ('Body', Icons.fitness_center, Color(0xFFE53935)),
    ('Mind', Icons.menu_book, Color(0xFF1E88E5)),
    ('Spirit', Icons.self_improvement, Color(0xFF8E24AA)),
    ('Career', Icons.rocket_launch, Color(0xFFFB8C00)),
    ('Karma', Icons.volunteer_activism, Color(0xFF43A047)),
  ];

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
              const SizedBox(height: 24),
              const Text(
                'Your journey\nbegins now.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.archetypeLabel,
                style: TextStyle(
                  color: Colors.deepPurple.shade300,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Column(
                  children: _pillars.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: p.$3.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(p.$2, color: p.$3, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(p.$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                  Text('Level 1', style: TextStyle(color: p.$3, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: 0.0,
                                  backgroundColor: p.$3.withOpacity(0.15),
                                  valueColor: AlwaysStoppedAnimation(p.$3),
                                  minHeight: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Start Ascending', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
