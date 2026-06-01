import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/pillar.dart';
import '../models/pillar_stats.dart';
import '../services/profile_service.dart';
import '../widgets/ascent_score_ring.dart';
import '../widgets/stat_bar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileService = ProfileService();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<UserProfile>(
        stream: profileService.watchProfile(),
        builder: (context, profileSnap) {
          if (!profileSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = profileSnap.data!;

          return StreamBuilder<List<PillarStats>>(
            stream: profileService.watchAllPillars(),
            builder: (context, pillarSnap) {
              final pillars = pillarSnap.data ?? allPillars.map(PillarStats.initial).toList();

              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeroSection(profile),
                    const SizedBox(height: 24),
                    _buildStatsSection(profile),
                    const SizedBox(height: 24),
                    _buildPillarDetails(pillars),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeroSection(UserProfile profile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0533), Color(0xFF2D1B69)],
        ),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            profile.customTitle,
            style: const TextStyle(
              color: Colors.deepPurpleAccent,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          AscentScoreRing(score: profile.totalAscentScore),
        ],
      ),
    );
  }

  Widget _buildStatsSection(UserProfile profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _StatTile(
            icon: Icons.local_fire_department,
            value: '${profile.currentStreak}',
            label: 'Day Streak',
            color: Colors.orange,
          ),
          const SizedBox(width: 12),
          _StatTile(
            icon: Icons.emoji_events,
            value: '${profile.longestStreak}',
            label: 'Best Streak',
            color: Colors.amber,
          ),
          const SizedBox(width: 12),
          _StatTile(
            icon: Icons.arrow_circle_up,
            value: '${profile.totalAscentScore}',
            label: 'Ascent Score',
            color: Colors.deepPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildPillarDetails(List<PillarStats> pillars) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pillar Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...pillars.map((p) => _PillarDetailRow(stats: p)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatTile({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _PillarDetailRow extends StatelessWidget {
  final PillarStats stats;
  const _PillarDetailRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(stats.pillar.icon, color: stats.pillar.color, size: 16),
                  const SizedBox(width: 6),
                  Text(stats.pillar.shortLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Level ${stats.level}', style: TextStyle(fontWeight: FontWeight.bold, color: stats.pillar.color, fontSize: 13)),
                  Text(stats.levelTitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          StatBar(progress: stats.progressFraction, color: stats.pillar.color),
          const SizedBox(height: 4),
          Text(
            '${stats.xp} XP · ${stats.xpToNextLevel} to next level',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
