import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/transit/domain/repositories/transit_repository.dart';
import '../features/transit/presentation/cubit/route_vehicles_cubit.dart';
import '../features/transit/presentation/pages/mvp_020_page.dart';

final class BusaoGynApp extends StatelessWidget {
  const BusaoGynApp({
    required this.repository,
    super.key,
  });

  final TransitRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BusãoGyn',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF126B55),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (_) => RouteVehiclesCubit(repository: repository)..start('020'),
        child: const Mvp020Page(),
      ),
    );
  }
}
