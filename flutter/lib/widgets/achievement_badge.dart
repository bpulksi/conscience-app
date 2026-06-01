import 'package:flutter/material.dart';
import '../models/achievement.dart';

class AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  final double size;

  const AchievementBadge({
    super.key,
    required this.achievement,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${achievement.title}\n${achievement.description}',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.amber.shade300,
                  Colors.amber.shade600,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              _iconForCategory(achievement.category),
              color: Colors.white,
              size: size * 0.45,
            ),
          ),
          if (achievement.isNew)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'title_unlock':    return Icons.star;
      case 'pillar_milestone': return Icons.trending_up;
      case 'streak':          return Icons.local_fire_department;
      case 'first_completion': return Icons.flag;
      case 'quest':           return Icons.emoji_events;
      default:                return Icons.workspace_premium;
    }
  }
}
