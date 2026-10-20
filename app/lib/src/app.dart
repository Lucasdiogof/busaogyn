import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/l10n/l10n.dart';
import 'core/settings/theme_mode_cubit.dart';
import 'core/theme/app_theme.dart';
import 'features/saved_stops/data/memory_saved_stops_store.dart';
import 'features/saved_stops/domain/saved_stops_store.dart';
import 'features/saved_stops/presentation/cubit/favorite_arrivals_cubit.dart';
import 'features/saved_stops/presentation/cubit/saved_stops_cubit.dart';
import 'features/transit/domain/repositories/transit_repository.dart';
import 'features/transit/presentation/cubit/map_vehicles_cubit.dart';
import 'features/transit/presentation/cubit/stop_arrivals_cubit.dart';
import 'features/transit/presentation/pages/stop_arrivals_page.dart';
import 'features/transit/presentation/widgets/tracked_vehicle_map.dart';

class BusaoGynApp extends StatelessWidget {
  const BusaoGynApp({
    required this.repository,
    this.trackingRefreshInterval = const Duration(seconds: 15),
    this.arrivalsRefreshInterval = const Duration(seconds: 30),
    this.secondaryRefreshInterval = const Duration(seconds: 30),
    this.mapBuilder,
    this.clock,
    this.themeStore,
    this.savedStopsStore,
    this.locale,
    super.key,
  });

  final TransitRepository repository;
  final Duration? trackingRefreshInterval;

  /// Atualização automática das chegadas com a aba Chegadas à vista; `null`
  /// desliga.
  final Duration? arrivalsRefreshInterval;

  /// Atualização dos outros ônibus do ponto; `null` desliga o timer.
  final Duration? secondaryRefreshInterval;
  final VehicleMapBuilder? mapBuilder;
  final DateTime Function()? clock;

  /// Sem store, o tema começa em "Sistema" e não é persistido.
  final ThemePreferenceStore? themeStore;

  /// Onde favoritos e recentes ficam. Sem store, ficam
  /// em memória.
  final SavedStopsStore? savedStopsStore;

  /// Força o idioma (pt, en ou es). Sem ele vale o do aparelho, com
  /// português quando o do aparelho não é atendido.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<TransitRepository>.value(
      value: repository,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                ThemeModeCubit(themeStore ?? MemoryThemePreferenceStore()),
          ),
          BlocProvider(
            create: (_) => StopArrivalsCubit(
              repository,
              trackingRefreshInterval: trackingRefreshInterval,
              arrivalsRefreshInterval: arrivalsRefreshInterval,
              clock: clock,
            ),
          ),
          // Criado só quando a navegação v2 o pede (lazy): sem a flag, nada é
          // lido nem gravado.
          BlocProvider(
            create: (_) => SavedStopsCubit(
              savedStopsStore ?? MemorySavedStopsStore(),
              clock: clock,
            ),
          ),
          BlocProvider(
            create: (_) => FavoriteArrivalsCubit(repository, clock: clock),
          ),
          BlocProvider(
            create: (_) => MapVehiclesCubit(
              repository,
              refreshInterval: secondaryRefreshInterval,
              clock: clock,
            ),
          ),
        ],
        child: BlocBuilder<ThemeModeCubit, ThemeMode>(
          builder: (context, themeMode) => MaterialApp(
            title: 'BusãoGyn',
            debugShowCheckedModeBanner: false,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            localeListResolutionCallback: (locales, supported) =>
                resolveAppLocale(locales?.firstOrNull),
            // Os textos de formatadores e cubits vêm do idioma global; trocar
            // de idioma recria a árvore para que todos sejam relidos.
            builder: (context, child) {
              final locale = Localizations.localeOf(context);
              useLocale(locale);
              return KeyedSubtree(
                key: ValueKey(locale.languageCode),
                child: child!,
              );
            },
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            home: StopArrivalsPage(mapBuilder: mapBuilder, clock: clock),
          ),
        ),
      ),
    );
  }
}
