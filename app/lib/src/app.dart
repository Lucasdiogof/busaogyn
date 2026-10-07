import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'features/transit/domain/repositories/transit_repository.dart';
import 'features/transit/presentation/cubit/stop_arrivals_cubit.dart';
import 'features/transit/presentation/pages/stop_arrivals_page.dart';
import 'features/transit/presentation/widgets/tracked_vehicle_map.dart';

class BusaoGynApp extends StatelessWidget {
  const BusaoGynApp({
    required this.repository,
    this.trackingRefreshInterval = const Duration(seconds: 15),
    this.mapBuilder,
    this.clock,
    this.themeMode = ThemeMode.system,
    super.key,
  });

  final TransitRepository repository;
  final Duration? trackingRefreshInterval;
  final VehicleMapBuilder? mapBuilder;
  final DateTime Function()? clock;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<TransitRepository>.value(
      value: repository,
      child: MaterialApp(
        title: 'BusãoGyn',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: BlocProvider(
          create: (_) => StopArrivalsCubit(
            repository,
            trackingRefreshInterval: trackingRefreshInterval,
            clock: clock,
          ),
          child: StopArrivalsPage(mapBuilder: mapBuilder, clock: clock),
        ),
      ),
    );
  }
}
