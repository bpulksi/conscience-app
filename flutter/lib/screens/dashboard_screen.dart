import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pillar.dart';
import '../models/user_profile.dart';
import '../models/pillar_stats.dart';
import '../models/quest.dart';
import '../services/profile_service.dart';
import '../services/quest_service.dart';
import '../services/achievement_service.dart';
import '../widgets/pillar_card.dart';
import '../widgets/quest_card.dart';
import '../widgets/title_display.dart';
import '../widgets/ascent_score_ring.dart';
import 'quest_list_screen.dart';
import 'quest_detail_screen.dart';
import 'profile_screen.dart';
import 'achievements_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _profileService = ProfileService();
  final _questService = QuestService();
  final _achievementService = AchievementService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: SafeArea(
        child: StreamBuilder<UserProfile>(
          stream: _profileService.watchProfile(),
          builder: (context, profileSnap) {
            if (!profileSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final profile = profileSnap.data!;

            return StreamBuilder<List<PillarStats>>(
              stream: _profileService.watchAllPillars(),
              builder: (context, pillarSnap) {
                final pillars = pillarSnap.data ?? allPillars.map(PillarStats.initial).toList();

                return StreamBuilder<List<UserQuest>>(
                  stream: _questService.watchActiveAndAvailableQuests(),
                  builder: (context, questSnap) {
                    final activeQuests = (questSnap.data ?? [])
                        .where((q) => q.status == QuestStatus.active)
                        .take(5)
                        .toList();

                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildHeader(profile, pillars)),
                        SliverToBoxAdapter(child: _buildPillarRow(pillars)),
                        SliverToBoxAdapter(child: _buildStreakBadge(profile.currentStreak)),
                        SliverToBoxAdapter(child: _buildSectionHeader('Active Quests', onSeeAll: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestListScreen()));
                        })),
                        if (activeQuests.isEmpty)
                          SliverToBoxAdapter(child: _buildEmptyQuests())
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: QuestCard(
                                  quest: activeQuests[i],
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => QuestDetailScreen(quest: activeQuests[i]),
                                    ),
                                  ),
                                ),
                              ),
                              childCount: activeQuests.length,
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildHeader(UserProfile profile, List<PillarStats> pillars) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TitleDisplay(
              customTitle: profile.customTitle,
              displayName: profile.displayName,
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: AscentScoreRing(score: profile.totalAscentScore, size: 80),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarRow(List<PillarStats> pillars) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Text('Your Pillars', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        SizedBox(
          height: 150,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: pillars.map((p) => PillarCard(
              stats: p,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => QuestListScreen(initialPillar: p.pillar)),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStreakBadge(int streak) {
    if (streak == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF9A3C)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              '$streak day streak — keep the flame alive',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text('See All', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyQuests() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.deepPurple.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            const Icon(Icons.add_task, color: Colors.deepPurple, size: 32),
            const SizedBox(height: 8),
            const Text('No active quests', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Browse quests and activate one to begin your ascent.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestListScreen())),
              child: const Text('Browse Quests'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNav() {
    return NavigationBar(
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.list_alt), label: 'Quests'),
        NavigationDestination(icon: Icon(Icons.emoji_events), label: 'Achievements'),
        NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
      ],
      selectedIndex: 0,
      onDestinationSelected: (i) {
        if (i == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestListScreen()));
        if (i == 2) Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen()));
        if (i == 3) Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
      },
    );
  }
}
