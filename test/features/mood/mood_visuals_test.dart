import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_baby/features/mood/domain/mood_entry.dart';
import 'package:ocean_baby/features/mood/ui/mood_visuals.dart';

void main() {
  test('今日心情颜色与用户要求一致', () {
    expect(moodColor(MoodType.happy), Colors.green);
    expect(moodColor(MoodType.angry), Colors.red);
    expect(moodColor(MoodType.sad), Colors.black);
  });

  test('未记录心情使用中性色', () {
    expect(moodColor(null), Colors.grey);
  });
}
