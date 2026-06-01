import 'package:flutter/material.dart';
import '../models/pillar.dart';
import '../models/pillar_stats.dart';
import 'stat_bar.dart';

class PillarCard extends StatelessWidget {
  final PillarStats stats;
  final VoidCallback? onTap;

  const PillarCard({super.key, required this.stats, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pillar = stats.pillar;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pillar.lightColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pillar.color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(pillar.icon, color: pillar.color, size: 22),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: pillar.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Lv.${stats.level}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: pillar.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              pillar.shortLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: pillar.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              stats.levelTitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            StatBar(progress: stats.progressFraction, color: pillar.color, height: 4),
            const SizedBox(height: 4),
            Text(
              '${stats.xpToNextLevel} XP to next',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
