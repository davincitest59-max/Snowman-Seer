import 'package:flutter/material.dart';

import '../domain/mood_entry.dart';

String moodLabel(MoodType mood) {
  return switch (mood) {
    MoodType.happy => '开心',
    MoodType.angry => '生气',
    MoodType.sad => '伤心',
  };
}

Color moodColor(MoodType? mood) {
  return switch (mood) {
    MoodType.happy => Colors.green,
    MoodType.angry => Colors.red,
    MoodType.sad => Colors.black,
    null => Colors.grey,
  };
}
