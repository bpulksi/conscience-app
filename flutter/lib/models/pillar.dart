import 'package:flutter/material.dart';

enum PillarType { body, mind, spirit, career, karma }

extension PillarTypeExt on PillarType {
  String get id => name;

  String get label {
    switch (this) {
      case PillarType.body:    return 'Body';
      case PillarType.mind:    return 'Mind';
      case PillarType.spirit:  return 'Spirit';
      case PillarType.career:  return 'Career & Legacy';
      case PillarType.karma:   return 'Karma & Charisma';
    }
  }

  String get shortLabel {
    switch (this) {
      case PillarType.body:    return 'Body';
      case PillarType.mind:    return 'Mind';
      case PillarType.spirit:  return 'Spirit';
      case PillarType.career:  return 'Career';
      case PillarType.karma:   return 'Karma';
    }
  }

  Color get color {
    switch (this) {
      case PillarType.body:    return const Color(0xFFE53935);
      case PillarType.mind:    return const Color(0xFF1E88E5);
      case PillarType.spirit:  return const Color(0xFF8E24AA);
      case PillarType.career:  return const Color(0xFFFB8C00);
      case PillarType.karma:   return const Color(0xFF43A047);
    }
  }

  Color get lightColor {
    switch (this) {
      case PillarType.body:    return const Color(0xFFFFEBEE);
      case PillarType.mind:    return const Color(0xFFE3F2FD);
      case PillarType.spirit:  return const Color(0xFFF3E5F5);
      case PillarType.career:  return const Color(0xFFFFF3E0);
      case PillarType.karma:   return const Color(0xFFE8F5E9);
    }
  }

  IconData get icon {
    switch (this) {
      case PillarType.body:    return Icons.fitness_center;
      case PillarType.mind:    return Icons.menu_book;
      case PillarType.spirit:  return Icons.self_improvement;
      case PillarType.career:  return Icons.rocket_launch;
      case PillarType.karma:   return Icons.volunteer_activism;
    }
  }

  String get description {
    switch (this) {
      case PillarType.body:    return 'Physical fitness, yoga, and vitality';
      case PillarType.mind:    return 'Studying, skills, and mental sharpness';
      case PillarType.spirit:  return 'Meditation, breathwork, and inner peace';
      case PillarType.career:  return 'Deep work, projects, and legacy';
      case PillarType.karma:   return 'Good deeds, mentoring, and giving back';
    }
  }

  static PillarType fromId(String id) {
    return PillarType.values.firstWhere((p) => p.name == id, orElse: () => PillarType.body);
  }
}

const List<PillarType> allPillars = PillarType.values;
