import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/transit/domain/repositories/transit_repository.dart';
import 'features/transit/presentation/cubit/stop_arrivals_cubit.dart';
import 'features/transit/presentation/pages/stop_arrivals_page.dart';

class BusaoGynApp extends StatelessWidget {
  const BusaoGynApp({
    required this.repository,
    this.trackingRefreshInterval = const Duration(seconds: 15),
    super.key,
  });

  final TransitRepository repository;
  final Duration? trackingRefreshInterval;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<TransitRepository>.value(
      value: repository,
      child: MaterialApp(
        title: 'BusãoGyn',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
          ),
          useMaterial3: true,
        ),
        home: BlocProvider(
          create: (_) => StopArrivalsCubit(
            repository,
            trackingRefreshInterval: trackingRefreshInterval,
          ),
          child: const StopArrivalsPage(),
        ),
      ),
    );
  }
}
