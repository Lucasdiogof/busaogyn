import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/settings/theme_mode_cubit.dart';
import 'core/theme/app_theme.dart';
import 'features/transit/domain/repositories/transit_repository.dart';
import 'features/transit/presentation/cubit/map_vehicles_cubit.dart';
import 'features/transit/presentation/cubit/stop_arrivals_cubit.dart';
import 'features/transit/presentation/pages/stop_arrivals_page.dart';
import 'features/transit/presentation/widgets/tracked_vehicle_map.dart';

class BusaoGynApp extends StatelessWidget {
  const BusaoGynApp({
    required this.repository,
    this.trackingRefreshInterval = const Duration(seconds: 15),
    this.secondaryRefreshInterval = const Duration(seconds: 30),
    this.mapBuilder,
    this.clock,
    this.themeStore,
    super.key,
  });

  final TransitRepository repository;
  final Duration? trackingRefreshInterval;

  /// Atualização dos outros ônibus do ponto; `null` desliga o timer.
  final Duration? secondaryRefreshInterval;
  final VehicleMapBuilder? mapBuilder;
  final DateTime Function()? clock;

  /// Sem store, o tema começa em "Sistema" e não é persistido.
  final ThemePreferenceStore? themeStore;

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
              clock: clock,
            ),
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
