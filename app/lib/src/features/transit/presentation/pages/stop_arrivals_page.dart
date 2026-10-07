import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/arrival.dart';
import '../../domain/entities/tracked_vehicle.dart';
import '../cubit/stop_arrivals_cubit.dart';
import '../widgets/tracked_vehicle_map.dart';

class StopArrivalsPage extends StatefulWidget {
  const StopArrivalsPage({this.mapBuilder, super.key});

  final VehicleMapBuilder? mapBuilder;

  @override
  State<StopArrivalsPage> createState() => _StopArrivalsPageState();
}

class _StopArrivalsPageState extends State<StopArrivalsPage>
    with WidgetsBindingObserver {
  final _stopController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final cubit = context.read<StopArrivalsCubit>();

    switch (state) {
      case AppLifecycleState.resumed:
        cubit.resumeTracking();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        cubit.pauseTracking();
        return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopController.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    context.read<StopArrivalsCubit>().load(_stopController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BusãoGyn',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stopController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        labelText: 'Código do ponto',
                        hintText: 'Ex.: 30402',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _search, child: const Text('Buscar')),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<StopArrivalsCubit, StopArrivalsState>(
                builder: (context, state) {
                  return switch (state) {
                    StopArrivalsInitial() => const _EmptyState(),
                    StopArrivalsLoading() => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    StopArrivalsFailure(:final message) => _FailureState(
                      message: message,
                      onRetry: _search,
                    ),
                    StopArrivalsLoaded() => _LoadedState(
                      state: state,
                      mapBuilder: widget.mapBuilder,
                    ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Informe o código RMTC de um ponto para ver os próximos ônibus.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadedState extends StatelessWidget {
  const _LoadedState({required this.state, this.mapBuilder});

  final StopArrivalsLoaded state;
  final VehicleMapBuilder? mapBuilder;

  @override
  Widget build(BuildContext context) {
    final arrivals = state.arrivals.data;
    final trackedVehicle = state.trackedVehicle?.data;

    return RefreshIndicator(
      onRefresh: () => context.read<StopArrivalsCubit>().load(state.stopId),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Ponto ${state.stopId}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            state.arrivals.stale
                ? 'Dados temporariamente desatualizados · ${state.arrivals.ageSeconds}s'
                : 'Atualizado agora',
          ),
          if (state.arrivals.stale) ...[
            const SizedBox(height: 8),
            const _StaleBanner(),
          ],
          if (state.trackingError != null) ...[
            const SizedBox(height: 8),
            Text(
              state.trackingError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          _TransitMapPanel(vehicle: trackedVehicle, mapBuilder: mapBuilder),
          if (trackedVehicle != null) ...[
            const SizedBox(height: 12),
            _TrackedVehicleCard(
              vehicle: trackedVehicle,
              stale: state.trackedVehicle!.stale,
            ),
          ],
          const SizedBox(height: 16),
          if (arrivals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('Nenhum ônibus encontrado para este ponto agora.'),
              ),
            )
          else
            for (final group in arrivals) ...[
              _ArrivalGroupCard(
                group: group,
                trackingVehicleNumber: state.trackingVehicleNumber,
                hasTrackedPosition: trackedVehicle != null,
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.tertiary,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'A fonte está instável. Mostrando o último dado válido.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrivalGroupCard extends StatelessWidget {
  const _ArrivalGroupCard({
    required this.group,
    required this.trackingVehicleNumber,
    required this.hasTrackedPosition,
  });

  final ArrivalGroup group;
  final String? trackingVehicleNumber;
  final bool hasTrackedPosition;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  group.routeId,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    group.destination ?? 'Destino não informado',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _ArrivalRow(
              label: 'Próximo',
              arrival: group.next,
              tracking: trackingVehicleNumber == group.next.vehicleNumber,
              hasTrackedPosition: hasTrackedPosition,
            ),
            if (group.following != null) ...[
              const SizedBox(height: 12),
              _ArrivalRow(
                label: 'Seguinte',
                arrival: group.following!,
                tracking:
                    trackingVehicleNumber == group.following!.vehicleNumber,
                hasTrackedPosition: hasTrackedPosition,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ArrivalRow extends StatelessWidget {
  const _ArrivalRow({
    required this.label,
    required this.arrival,
    required this.tracking,
    required this.hasTrackedPosition,
  });

  final String label;
  final Arrival arrival;
  final bool tracking;
  final bool hasTrackedPosition;

  String get _minutes {
    if (arrival.minutes == null) return '—';
    if (arrival.minutes == 0) return '< 1 min';
    return '${arrival.minutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final canTrack = arrival.realtime && arrival.vehicleNumber != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(
                _minutes,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              _ArrivalSourceBadge(realtime: arrival.realtime),
              if (arrival.vehicleNumber != null)
                Text(
                  'Ônibus ${arrival.vehicleNumber}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        if (canTrack)
          OutlinedButton.icon(
            onPressed: tracking
                ? null
                : () => context.read<StopArrivalsCubit>().track(
                    arrival.vehicleNumber!,
                  ),
            icon: tracking && !hasTrackedPosition
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.gps_fixed_rounded),
            label: Text(
              !tracking
                  ? 'Acompanhar'
                  : hasTrackedPosition
                  ? 'Acompanhando'
                  : 'Buscando…',
            ),
          ),
      ],
    );
  }
}

/// Origem da previsão com ícone e texto, sem depender só de cor nem de
/// glifos que faltam em fontes do Web.
class _ArrivalSourceBadge extends StatelessWidget {
  const _ArrivalSourceBadge({required this.realtime});

  final bool realtime;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final color = realtime
        ? Theme.of(context).colorScheme.primary
        : style?.color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          realtime ? Icons.sensors_rounded : Icons.schedule_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(realtime ? 'Tempo real' : 'Programado', style: style),
      ],
    );
  }
}

class _TransitMapPanel extends StatelessWidget {
  const _TransitMapPanel({required this.vehicle, this.mapBuilder});

  final TrackedVehicle? vehicle;
  final VehicleMapBuilder? mapBuilder;

  @override
  Widget build(BuildContext context) {
    final trackedVehicle = vehicle;
    if (trackedVehicle?.position != null) {
      return TrackedVehicleMap(
        vehicle: trackedVehicle!,
        mapBuilder: mapBuilder,
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 42),
            SizedBox(height: 12),
            Text(
              'Acompanhe um ônibus em tempo real para ver sua posição no mapa.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackedVehicleCard extends StatelessWidget {
  const _TrackedVehicleCard({required this.vehicle, required this.stale});

  final TrackedVehicle vehicle;
  final bool stale;

  String get _punctuality {
    return switch (vehicle.punctuality) {
      VehiclePunctuality.onTime => 'No horário',
      VehiclePunctuality.delayed => 'Atrasado',
      VehiclePunctuality.early => 'Adiantado',
      VehiclePunctuality.unknown => 'Situação desconhecida',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ônibus ${vehicle.vehicleNumber}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (vehicle.routeId != null) 'Linha ${vehicle.routeId}',
                if (vehicle.destination != null) vehicle.destination!,
              ].join(' · '),
            ),
            const SizedBox(height: 8),
            Text(_punctuality),
            Text(
              vehicle.accessible == true
                  ? 'Acessível'
                  : vehicle.accessible == false
                  ? 'Acessibilidade não indicada'
                  : 'Acessibilidade desconhecida',
            ),
            if (vehicle.position != null) ...[
              const SizedBox(height: 8),
              Text(
                'Posição: '
                '${vehicle.position!.latitude.toStringAsFixed(6)}, '
                '${vehicle.position!.longitude.toStringAsFixed(6)}',
              ),
            ],
            if (stale)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Posição temporariamente desatualizada'),
              ),
          ],
        ),
      ),
    );
  }
}
