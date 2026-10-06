import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/vehicle.dart';
import '../cubit/route_vehicles_cubit.dart';
import '../cubit/route_vehicles_state.dart';

final class Mvp020Page extends StatelessWidget {
  const Mvp020Page({super.key});

  static const _goianiaCenter = LatLng(-16.6869, -49.2648);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<RouteVehiclesCubit, RouteVehiclesState>(
        builder: (context, state) {
          final vehicles = state.snapshot?.vehicles ?? const <Vehicle>[];
          final markers = vehicles
              .where((vehicle) => vehicle.position != null)
              .map(
                (vehicle) => _vehicleMarker(
                  context,
                  vehicle,
                  selected: vehicle.id == state.selectedVehicleId,
                ),
              )
              .toList(growable: false);

          return Stack(
            children: [
              FlutterMap(
                options: const MapOptions(
                  initialCenter: _goianiaCenter,
                  initialZoom: 11.8,
                  minZoom: 9,
                  maxZoom: 19,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.lucasdiogof.busaogyn',
                    maxZoom: 19,
                  ),
                  MarkerLayer(markers: markers),
                  const SimpleAttributionWidget(
                    source: Text('© OpenStreetMap contributors'),
                  ),
                ],
              ),
              _TopStatusCard(state: state),
              _BottomPanel(state: state),
              if (state.status == RouteVehiclesStatus.loading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          );
        },
      ),
    );
  }

  Marker _vehicleMarker(
    BuildContext context,
    Vehicle vehicle, {
    required bool selected,
  }) {
    final position = vehicle.position!;
    final scheme = Theme.of(context).colorScheme;

    return Marker(
      point: LatLng(position.latitude, position.longitude),
      width: 54,
      height: 54,
      alignment: Alignment.bottomCenter,
      child: Semantics(
        button: true,
        label: 'Ônibus ${vehicle.vehicleNumber}, linha 020',
        child: GestureDetector(
          onTap: () =>
              context.read<RouteVehiclesCubit>().selectVehicle(vehicle.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: selected ? scheme.primary : scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? scheme.onPrimary : scheme.primary,
                width: selected ? 2 : 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 8,
                  offset: Offset(0, 3),
                  color: Color(0x33000000),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '020',
              style: TextStyle(
                color: selected ? scheme.onPrimary : scheme.primary,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _TopStatusCard extends StatelessWidget {
  const _TopStatusCard({required this.state});

  final RouteVehiclesState state;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot;
    final isStale = state.status == RouteVehiclesStatus.stale ||
        (snapshot?.stale ?? false);
    final count = snapshot?.vehicles.length;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          elevation: 5,
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                const Icon(Icons.directions_bus_filled_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'BusãoGyn · Linha 020',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(
                          isStale: isStale,
                          count: count,
                          ageSeconds: snapshot?.ageSeconds,
                          status: state.status,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: isStale
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Atualizar',
                  onPressed: () =>
                      context.read<RouteVehiclesCubit>().refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle({
    required bool isStale,
    required int? count,
    required int? ageSeconds,
    required RouteVehiclesStatus status,
  }) {
    if (status == RouteVehiclesStatus.failure) {
      return 'Tempo real indisponível no momento';
    }
    if (status == RouteVehiclesStatus.loading && count == null) {
      return 'Carregando ônibus em tempo real…';
    }
    if (count == null) return 'Aguardando dados';
    if (isStale) {
      return 'Dados desatualizados · última atualização há ${ageSeconds ?? 0}s';
    }
    if (count == 0) return 'Nenhum ônibus localizado agora';
    if ((ageSeconds ?? 0) < 10) return '$count ônibus · atualizado agora';
    return '$count ônibus · atualizado há ${ageSeconds}s';
  }
}

final class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.state});

  final RouteVehiclesState state;

  @override
  Widget build(BuildContext context) {
    final vehicle = state.selectedVehicle;
    if (vehicle == null) {
      return Positioned(
        left: 12,
        right: 12,
        bottom: 20,
        child: SafeArea(
          top: false,
          child: Material(
            elevation: 5,
            borderRadius: BorderRadius.circular(20),
            color:
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.touch_app_rounded),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Toque em um ônibus da linha 020 para acompanhar os detalhes.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: 12,
      right: 12,
      bottom: 20,
      child: SafeArea(
        top: false,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Text(
                    vehicle.vehicleNumber.length > 2
                        ? vehicle.vehicleNumber.substring(
                            vehicle.vehicleNumber.length - 2,
                          )
                        : vehicle.vehicleNumber,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ônibus ${vehicle.vehicleNumber}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        vehicle.destination ?? 'Destino não informado',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          const _InfoChip(
                            icon: Icons.route_rounded,
                            label: 'Linha 020',
                          ),
                          if (vehicle.accessible == true)
                            const _InfoChip(
                              icon: Icons.accessible_rounded,
                              label: 'Acessível',
                            ),
                          _InfoChip(
                            icon: Icons.circle,
                            label: _statusLabel(vehicle.status),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar detalhes',
                  onPressed: () =>
                      context.read<RouteVehiclesCubit>().clearSelection(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(VehicleStatus status) {
    return switch (status) {
      VehicleStatus.inService => 'Em operação',
      VehicleStatus.interval => 'Intervalo',
      VehicleStatus.outOfService => 'Fora de serviço',
      VehicleStatus.unknown => 'Status não informado',
    };
  }
}

final class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
