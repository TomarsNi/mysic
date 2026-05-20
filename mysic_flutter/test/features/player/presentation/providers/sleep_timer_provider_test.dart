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
      provider.startSongCountTimer(3, 0);
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

    test('onSongChanged updates remaining count in song mode', () {
      final provider = SleepTimerProvider();
      provider.startSongCountTimer(3, 0);
      expect(provider.state.remainingValue, 3);

      provider.onSongChanged(1);
      expect(provider.state.remainingValue, 2);

      provider.onSongChanged(2);
      expect(provider.state.remainingValue, 1);
    });

    test('onSongChanged does nothing in time mode', () {
      final provider = SleepTimerProvider();
      provider.startTimeTimer(5);

      provider.onSongChanged(1);
      expect(provider.state.mode, SleepTimerMode.time);
    });
  });
}
