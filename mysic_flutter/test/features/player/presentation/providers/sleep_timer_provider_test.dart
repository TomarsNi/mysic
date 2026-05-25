import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/player/presentation/providers/sleep_timer_provider.dart';
import 'package:mysic_flutter/features/player/data/services/sleep_timer_service.dart';

void main() {
  group('SleepTimerProvider', () {
    test('initial state is inactive', () {
      final provider = SleepTimerProvider();
      expect(provider.state.isActive, isFalse);
    });

    test('startTimeTimer sets active state', () {
      final provider = SleepTimerProvider();
      provider.startTimeTimer(5);
      expect(provider.state.isActive, isTrue);
      expect(provider.state.mode, SleepTimerMode.time);
      expect(provider.state.targetValue, 5);
    });

    test('startSongCountTimer sets active state', () {
      final provider = SleepTimerProvider();
      provider.startSongCountTimer(3);
      expect(provider.state.isActive, isTrue);
      expect(provider.state.mode, SleepTimerMode.songCount);
      expect(provider.state.targetValue, 3);
    });

    test('cancel resets state to inactive', () {
      final provider = SleepTimerProvider();
      provider.startTimeTimer(5);
      expect(provider.state.isActive, isTrue);

      provider.cancel();
      expect(provider.state.isActive, isFalse);
    });

    test('onSongCompleted decrements remaining count in song mode', () {
      final provider = SleepTimerProvider();
      provider.startSongCountTimer(3);
      expect(provider.state.remainingValue, 3);

      provider.onSongCompleted();
      expect(provider.state.remainingValue, 2);

      provider.onSongCompleted();
      expect(provider.state.remainingValue, 1);
    });

    test('onSongCompleted completes timer when remaining reaches 0', () {
      final provider = SleepTimerProvider();
      provider.startSongCountTimer(1);
      expect(provider.state.remainingValue, 1);

      provider.onSongCompleted();
      expect(provider.state.isActive, isFalse);
    });

    test('onSongCompleted does nothing in time mode', () {
      final provider = SleepTimerProvider();
      provider.startTimeTimer(5);

      provider.onSongCompleted();
      expect(provider.state.mode, SleepTimerMode.time);
    });
  });
}