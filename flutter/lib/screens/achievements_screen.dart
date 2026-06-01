import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../services/achievement_service.dart';
import '../widgets/achievement_badge.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _service = AchievementService();

  @override
  void initState() {
    super.initState();
    // Mark all viewed when screen opens
    _service.markAllViewed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: const Text('Achievements', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<Achievement>>(
        stream: _service.watchAchievements(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final achievements = snap.data ?? [];

          if (achievements.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events, size: 64, color: Colors.grey.shade200),
                    const SizedBox(height: 16),
                    const Text(
                      'No achievements yet',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete quests and reach milestones to earn badges and titles.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            );
          }

          // Group by category
          final grouped = <String, List<Achievement>>{};
          for (final a in achievements) {
            (grouped[a.category] ??= []).add(a);
          }

          final categoryOrder = ['title_unlock', 'pillar_milestone', 'streak', 'first_completion', 'quest'];
          final categoryLabels = {
            'title_unlock':    'Title Unlocks',
            'pillar_milestone': 'Pillar Milestones',
            'streak':          'Streak Milestones',
            'first_completion': 'First Completions',
            'quest':           'Quest Milestones',
          };

          return ListView(
            padding: const EdgeInsets.all(20),
            children: categoryOrder
                .where((cat) => grouped.containsKey(cat))
                .expand((cat) {
                  final list = grouped[cat]!;
                  return [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, top: 8),
                      child: Text(
                        categoryLabels[cat] ?? cat,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: list.length,
                      itemBuilder: (ctx, i) {
                        final a = list[i];
                        return Column(
                          children: [
                            AchievementBadge(achievement: a, size: 60),
                            const SizedBox(height: 6),
                            Text(
                              a.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        );
                      },
                    ),
                  ];
                })
                .toList(),
          );
        },
      ),
    );
  }
}
