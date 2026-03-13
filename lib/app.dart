import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/audio/notification_audio_service.dart';
import 'data/ble/ble_heart_rate_service.dart';
import 'data/media/media_control_service.dart';
import 'data/platform/app_control_service.dart';
import 'data/storage/history_repository.dart';
import 'data/storage/session_storage.dart';
import 'data/storage/settings_storage.dart';
import 'core/app_strings.dart';
import 'presentation/history/history_screen.dart';
import 'presentation/home/home_bloc.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/settings/settings_screen.dart';

class CardioApp extends StatelessWidget {
  const CardioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SettingsStorage>(
      future: SharedPreferences.getInstance().then((p) => SettingsStorage(p)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final settings = snapshot.data!;
        final bleService = BleHeartRateService();
        final sessionStorage = SessionStorage();
        final audioService = NotificationAudioService();
        final mediaControlService = MediaControlService();
        final appControlService = AppControlService();
        return MultiRepositoryProvider(
          providers: [
            RepositoryProvider<BleHeartRateService>.value(value: bleService),
            RepositoryProvider<SessionStorage>.value(value: sessionStorage),
            RepositoryProvider<HistoryRepository>(
              create: (_) => HistoryRepository(sessionStorage: sessionStorage),
            ),
            RepositoryProvider<NotificationAudioService>.value(
                value: audioService),
            RepositoryProvider<MediaControlService>.value(
                value: mediaControlService),
            RepositoryProvider<AppControlService>.value(value: appControlService),
            RepositoryProvider<SettingsStorage>.value(value: settings),
          ],
          child: BlocProvider(
            create: (context) => HomeBloc(
              bleService: context.read<BleHeartRateService>(),
              sessionStorage: context.read<SessionStorage>(),
              audioService: context.read<NotificationAudioService>(),
              settingsStorage: context.read<SettingsStorage>(),
            ),
            child: MaterialApp(
              title: AppStrings.appTitle(settings.uiLanguage),
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF1B5E20),
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
              ),
              home: _AppRoot(settings: settings),
              routes: {
                '/settings': (_) => SettingsScreen(onComplete: () {}),
                '/history': (_) => const HistoryScreen(),
              },
            ),
          ),
        );
      },
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot({required this.settings});

  final SettingsStorage settings;

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late bool _showSettings;

  @override
  void initState() {
    super.initState();
    _showSettings = widget.settings.isFirstRun;
  }

  void _onSettingsComplete() {
    widget.settings.isFirstRun = false;
    widget.settings.save();
    setState(() => _showSettings = false);
  }

  @override
  Widget build(BuildContext context) {
    return _showSettings
        ? SettingsScreen(onComplete: _onSettingsComplete)
        : const HomeScreen();
  }
}
