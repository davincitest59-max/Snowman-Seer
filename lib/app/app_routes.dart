import 'package:flutter/material.dart';

enum AppRoute {
  ledger(
    '账本',
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet,
  ),
  notes('笔记', Icons.edit_note_outlined, Icons.edit_note),
  todos('待办', Icons.check_circle_outline, Icons.check_circle),
  mood('心情', Icons.mood_outlined, Icons.mood),
  home('设置', Icons.settings_outlined, Icons.settings);

  const AppRoute(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
