import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const TowerStackApp());

class TowerStackApp extends StatelessWidget {
  const TowerStackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.elegantSerif,
      title: 'Tower Stack',
      tagline: 'Stack moving blocks into the tallest tower',
      emoji: '🗼',
      slug: 'towerstack',
      howToPlay:
          '• The crane block swings side to side — tap to drop it.\n• Overhang gets sliced off! Miss the tower completely and it\'s over.\n• Perfect drops snap on and build your combo.\n• How tall can you stack?',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => TowerStackScreen(players: players, callbacks: cb),
    );
  }
}
