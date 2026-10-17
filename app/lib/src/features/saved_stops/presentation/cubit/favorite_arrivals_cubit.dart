import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../transit/domain/entities/arrival.dart';
import '../../../transit/domain/repositories/transit_repository.dart';

/// Máximo de pontos consultados de uma vez na aba Favoritos. Protege a fonte
/// (ADR-0003): o resto continua a um toque de distância.
const maxFavoriteStopsQueried = 10;

/// Reabrir a aba dentro desta janela reaproveita a consulta recente, em vez
/// de consultar de novo (cada ponto mostra a hora da sua consulta).
const favoriteArrivalsFreshness = Duration(seconds: 30);

/// Consultas simultâneas. Mesma política dos ônibus secundários do mapa.
const _concurrency = 3;

enum FavoriteStopStatus { loading, ready, offline, failed }

/// Resultado da consulta de um ponto favorito. Vive só em memória: nenhuma
/// previsão é gravada no aparelho.
@immutable
class FavoriteStopArrivals {
  const FavoriteStopArrivals(
    this.status, {
    this.groups = const [],
    this.fetchedAt,
    this.stale = false,
  });

  final FavoriteStopStatus status;
  final List<ArrivalGroup> groups;

  /// Hora em que a consulta voltou, sempre mostrada junto da previsão.
  final DateTime? fetchedAt;

  /// A fonte devolveu o último dado válido, não um novo.
  final bool stale;
}

@immutable
class FavoriteArrivalsState {
  const FavoriteArrivalsState({
    this.byStop = const {},
    this.refreshing = false,
  });

  final Map<String, FavoriteStopArrivals> byStop;
  final bool refreshing;
}

/// Próximas chegadas dos pontos favoritos, consultadas quando a aba abre ou o
/// usuário toca em atualizar. Sem repetição automática, sem cache em disco e
/// sem apresentar resposta velha como atual: cada ponto mostra a hora da sua
/// consulta, e uma consulta nova descarta as respostas da anterior.
class FavoriteArrivalsCubit extends Cubit<FavoriteArrivalsState> {
  FavoriteArrivalsCubit(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const FavoriteArrivalsState());

  final TransitRepository _repository;
  final DateTime Function() _clock;
  int _generation = 0;
  String _signature = '';
  DateTime? _lastRefresh;

  /// Consulta os pontos. Sem [force], repetir o mesmo conjunto dentro de
  /// [favoriteArrivalsFreshness] não faz nada.
  Future<void> refresh(Iterable<String> stops, {bool force = false}) async {
    final queue = <String>[
      ...{...stops},
    ].take(maxFavoriteStopsQueried).toList();
    final signature = queue.join(',');
    final now = _clock();
    final last = _lastRefresh;
    if (!force &&
        signature == _signature &&
        last != null &&
        now.difference(last) < favoriteArrivalsFreshness) {
      return;
    }
    _signature = signature;
    _lastRefresh = now;
    final generation = ++_generation;
    if (queue.isEmpty) {
      emit(const FavoriteArrivalsState());
      return;
    }
    emit(
      FavoriteArrivalsState(
        refreshing: true,
        byStop: {
          for (final stop in queue)
            stop: const FavoriteStopArrivals(FavoriteStopStatus.loading),
        },
      ),
    );

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final stop = queue.removeAt(0);
        final result = await _fetch(stop);
        if (isClosed || generation != _generation) return;
        emit(
          FavoriteArrivalsState(
            refreshing: true,
            byStop: {...state.byStop, stop: result},
          ),
        );
      }
    }

    await Future.wait([for (var i = 0; i < _concurrency; i++) worker()]);
    if (isClosed || generation != _generation) return;
    emit(FavoriteArrivalsState(byStop: state.byStop));
  }

  Future<FavoriteStopArrivals> _fetch(String stop) async {
    try {
      final snapshot = await _repository.getArrivals(stop);
      return FavoriteStopArrivals(
        FavoriteStopStatus.ready,
        groups: snapshot.data,
        fetchedAt: _clock(),
        stale: snapshot.stale,
      );
    } on ApiException catch (error) {
      return FavoriteStopArrivals(
        error.code == ApiClient.networkErrorCode
            ? FavoriteStopStatus.offline
            : FavoriteStopStatus.failed,
      );
    } catch (_) {
      return const FavoriteStopArrivals(FavoriteStopStatus.failed);
    }
  }
}
