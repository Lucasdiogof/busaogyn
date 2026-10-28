// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get dockLines => 'Líneas';

  @override
  String get dockStops => 'Paradas';

  @override
  String get dockFavorites => 'Favoritos';

  @override
  String get dockTracking => 'Mi autobús';

  @override
  String dockTrackedBadge(String label) {
    return '$label, autobús en seguimiento';
  }

  @override
  String get settings => 'Ajustes';

  @override
  String get settingsSubtitle => 'Apariencia y acerca de';

  @override
  String get settingsClose => 'Cerrar ajustes';

  @override
  String get loading => 'Cargando…';

  @override
  String get refresh => 'Actualizar';

  @override
  String get refreshing => 'actualizando…';

  @override
  String get refreshArrivals => 'Actualizar llegadas';

  @override
  String get retry => 'Intentar de nuevo';

  @override
  String retryStop(String code) {
    return 'Intentar la parada $code';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get clear => 'Limpiar';

  @override
  String get close => 'Cerrar';

  @override
  String get view => 'Ver';

  @override
  String get viewArrivals => 'Ver llegadas';

  @override
  String get search => 'Buscar';

  @override
  String get searchStopAction => 'Buscar una parada';

  @override
  String get searchAnotherStop => 'Buscar otra parada';

  @override
  String get searchHint => 'Código de la parada, ej.: 30402';

  @override
  String get clearCode => 'Borrar código';

  @override
  String get backToStop => 'Volver a la parada';

  @override
  String get stopWord => 'Parada';

  @override
  String get atStopWord => 'en la parada';

  @override
  String get now => 'ahora';

  @override
  String ago(String age) {
    return 'hace $age';
  }

  @override
  String get panelHandleLabel => 'Panel. Arrastra para expandir o contraer';

  @override
  String routeNumber(String route) {
    return 'Línea $route';
  }

  @override
  String get routeNotProvided => 'Línea no informada';

  @override
  String busNumber(String number) {
    return 'Autobús $number';
  }

  @override
  String linesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count líneas',
      one: '1 línea',
      zero: '0 líneas',
    );
    return '$_temp0';
  }

  @override
  String get savedStopsNone => 'Ninguna parada guardada';

  @override
  String savedStopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paradas guardadas',
      one: '1 parada guardada',
      zero: '0 paradas guardadas',
    );
    return '$_temp0';
  }

  @override
  String get queryingArrivals => 'consultando llegadas…';

  @override
  String get queryingArrivalsSemantics => 'Consultando llegadas';

  @override
  String queryingStop(String stop) {
    return 'Consultando la parada $stop';
  }

  @override
  String get qualityRealtime => 'Tiempo real';

  @override
  String get qualityScheduled => 'Programado';

  @override
  String get qualityUnknownLong => 'Información no confirmada';

  @override
  String get qualityUnknownShort => 'No confirmado';

  @override
  String get minutesUnknown => 'tiempo no informado';

  @override
  String get minutesLessThanOne => '< 1 min';

  @override
  String get minutesLessThanOneLong => 'menos de 1 minuto';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String minutesLong(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutos',
      one: '1 minuto',
      zero: '0 minutos',
    );
    return '$_temp0';
  }

  @override
  String get punctualityOnTime => 'A tiempo';

  @override
  String get punctualityDelayed => 'Retrasado';

  @override
  String get punctualityEarly => 'Adelantado';

  @override
  String get punctualityUnknown => 'Puntualidad no informada';

  @override
  String get accessible => 'Accesible';

  @override
  String get accessibilityNotIndicated => 'Accesibilidad no indicada';

  @override
  String get accessibilityUnknown => 'Accesibilidad no informada';

  @override
  String get destinationUnknown => 'Destino no informado';

  @override
  String headingTo(String destination) {
    return 'Rumbo a $destination';
  }

  @override
  String get positionSearching => 'Buscando la posición del autobús';

  @override
  String get positionConnection => 'Conexión inestable';

  @override
  String get positionUnavailable => 'Posición temporalmente no disponible';

  @override
  String positionOutdated(String age) {
    return 'Posición desactualizada · hace $age';
  }

  @override
  String positionLive(String age) {
    return 'En vivo · hace $age';
  }

  @override
  String positionLast(String age) {
    return 'Última posición hace $age';
  }

  @override
  String positionAgeShort(String age) {
    return 'posición hace $age';
  }

  @override
  String get positionMaybeOutdated => 'Posición posiblemente desactualizada';

  @override
  String freshnessStale(String age) {
    return 'Datos temporalmente desactualizados · hace $age';
  }

  @override
  String get freshnessNow => 'Actualizado ahora';

  @override
  String freshnessAge(String age) {
    return 'Actualizado hace $age';
  }

  @override
  String get liveSearchingLabel => 'Buscando';

  @override
  String get liveSearchingDetail => 'posición';

  @override
  String get liveConnectionLabel => 'Conexión';

  @override
  String get liveConnectionDetail => 'inestable';

  @override
  String get liveLocatingLabel => 'Localizando';

  @override
  String get liveLocatingDetail => 'autobús';

  @override
  String get liveOutdated => 'Desactualizado';

  @override
  String get liveLabel => 'En vivo';

  @override
  String get livePosition => 'Posición';

  @override
  String get liveNoEstimate => 'Sin estimación';

  @override
  String get liveNoGps => 'sin GPS';

  @override
  String get liveEstimate => 'Estimación';

  @override
  String get errFormat =>
      'BusãoGyn recibió datos en un formato inesperado. Inténtalo de nuevo.';

  @override
  String get errArrivalsGeneric => 'No se pudo consultar esta parada ahora.';

  @override
  String get errPositionGeneric => 'No se pudo localizar este autobús ahora.';

  @override
  String get errTimeout =>
      'La consulta tardó más de lo esperado. Inténtalo de nuevo.';

  @override
  String get errNetwork => 'Sin conexión con BusãoGyn. Revisa tu internet.';

  @override
  String get errSourceTimeout =>
      'La RMTC tardó en responder. Inténtalo de nuevo en unos instantes.';

  @override
  String get errSourceUnavailable =>
      'La fuente de datos de la RMTC no está disponible ahora. Inténtalo de nuevo en unos instantes.';

  @override
  String get errSourceInvalidArrivals =>
      'La RMTC no devolvió datos válidos para esta parada. Revisa el código o inténtalo de nuevo.';

  @override
  String get errSourceInvalidPosition =>
      'La RMTC no devolvió datos válidos para este autobús ahora.';

  @override
  String get errInvalidStop => 'Código de parada no válido. Usa solo números.';

  @override
  String get errInvalidVehicle =>
      'Este autobús no tiene un número válido para seguirlo.';

  @override
  String get errInvalidResponse =>
      'BusãoGyn recibió una respuesta inesperada. Inténtalo de nuevo.';

  @override
  String get errRetryable =>
      'El servicio está inestable ahora. Inténtalo de nuevo en unos instantes.';

  @override
  String get errGeneric => 'No se pudo completar la consulta.';

  @override
  String get errPositionNotReported =>
      'La fuente no informó la posición de este autobús ahora.';

  @override
  String get errPositionUnavailable => 'Posición temporalmente no disponible.';

  @override
  String get searchInvalidTitle => 'Escribe el código de la parada';

  @override
  String get searchInvalidBody =>
      'Usa solo los números del letrero de la parada.';

  @override
  String get searchNotFoundTitle => 'Parada no encontrada';

  @override
  String get searchNotFoundBody => 'Revisa el código e inténtalo de nuevo.';

  @override
  String get searchTimeoutTitle => 'La consulta tardó demasiado';

  @override
  String get searchTimeoutBody => 'Inténtalo de nuevo en unos instantes.';

  @override
  String get searchOfflineTitle => 'Sin conexión';

  @override
  String get searchOfflineBody => 'Revisa tu internet e inténtalo de nuevo.';

  @override
  String get searchUnavailableTitle => 'Servicio temporalmente no disponible';

  @override
  String get searchUnavailableBody => 'Inténtalo de nuevo en unos minutos.';

  @override
  String get nextBuses => 'Próximos autobuses';

  @override
  String get sourceUnstable =>
      'La fuente está inestable. Mostrando el último dato válido.';

  @override
  String get noArrivalsNow => 'Ninguna llegada prevista ahora';

  @override
  String noArrivalsNowAt(String hour) {
    return 'Ninguna llegada prevista ahora · consulta de las $hour';
  }

  @override
  String get noArrivalsBody =>
      'La fuente no informó autobuses para esta parada en este momento. Prueba a actualizar en unos minutos.';

  @override
  String get legendRealtime =>
      ': posición informada por la RMTC, se puede seguir.';

  @override
  String get legendScheduled => ': horario de tabla, sin GPS.';

  @override
  String trackingBannerSemantics(String number) {
    return 'Autobús $number en seguimiento. Ver en Mi autobús';
  }

  @override
  String refreshFailedAt(String hour, String error) {
    return 'No se pudo actualizar ahora. Mostrando la consulta de las $hour, que puede haber perdido vigencia. $error';
  }

  @override
  String refreshFailedPrevious(String error) {
    return 'No se pudo actualizar ahora. Mostrando la consulta anterior, que puede haber perdido vigencia. $error';
  }

  @override
  String get connOfflineTitle => 'Las llegadas necesitan internet';

  @override
  String get connFailedTitle => 'No pudimos consultar las llegadas';

  @override
  String get connOfflineBody =>
      'El mapa sigue disponible, pero las próximas llegadas solo aparecen con conexión. Ninguna estimación antigua se muestra como si fuera actual.';

  @override
  String connFailedBody(String code) {
    return 'El código $code no fue el problema: la consulta no se completó. Ninguna estimación antigua se muestra como si fuera actual.';
  }

  @override
  String get connFailedBodyNoCode =>
      'El código escrito no fue el problema: la consulta no se completó. Ninguna estimación antigua se muestra como si fuera actual.';

  @override
  String get introTitle => 'Escribe el código de la parada';

  @override
  String get introBody =>
      'Ves las próximas llegadas de cada línea y sigues el autobús en el mapa.';

  @override
  String get introNote =>
      'El código está en el letrero de la parada. Solo se pueden seguir autobuses con GPS informado por la fuente.';

  @override
  String exampleStop(String code) {
    return 'Ejemplo: $code';
  }

  @override
  String exampleStopSemantics(String code) {
    return 'Consultar la parada de ejemplo $code';
  }

  @override
  String get noFollowing => 'sin siguiente';

  @override
  String get followingUpper => 'SIGUIENTE';

  @override
  String nextSemantics(String minutes, String quality) {
    return 'Próximo: $minutes, $quality';
  }

  @override
  String followingSemantics(String minutes, String quality, String number) {
    return 'Siguiente: $minutes, $quality, autobús $number';
  }

  @override
  String get trackingUnavailableSemantics =>
      'Seguimiento no disponible: llegada sin GPS de la fuente';

  @override
  String trackBus(String number) {
    return 'Seguir el autobús $number';
  }

  @override
  String trackBusSearching(String number) {
    return 'Buscando la posición del autobús $number';
  }

  @override
  String trackBusActive(String number) {
    return 'Siguiendo el autobús $number';
  }

  @override
  String trackBusUnavailable(String number) {
    return 'Autobús $number sin posición';
  }

  @override
  String trackBusFailing(String number) {
    return 'Reconectando con el autobús $number';
  }

  @override
  String get trackingHeaderSubtitle => 'Sigue un vehículo en tiempo real';

  @override
  String trackingHeaderSemantics(String number, String heading) {
    return 'Mi autobús: autobús $number, $heading';
  }

  @override
  String trackingHeaderSemanticsRoute(
    String number,
    String route,
    String heading,
  ) {
    return 'Mi autobús: autobús $number, línea $route, $heading';
  }

  @override
  String busSemantics(String number, String heading) {
    return 'Autobús $number, $heading';
  }

  @override
  String busSemanticsRoute(String number, String route, String heading) {
    return 'Autobús $number, línea $route, $heading';
  }

  @override
  String get stopTracking => 'Dejar de seguir';

  @override
  String get noTrackedBusTitle => 'Ningún autobús en seguimiento';

  @override
  String get noTrackedBusBody =>
      'Elige un autobús en tiempo real en las llegadas de una parada.';

  @override
  String get noTrackedBusNote =>
      'Solo se pueden seguir autobuses con GPS informado por la RMTC. Los horarios programados no tienen posición.';

  @override
  String get trackingSearching => 'Buscando posición';

  @override
  String get trackingFollowing => 'Siguiendo';

  @override
  String get stop => 'Detener';

  @override
  String get following => 'Siguiendo';

  @override
  String get center => 'Centrar';

  @override
  String get centerBus => 'Centrar en el autobús';

  @override
  String get centerBusFollowing =>
      'Centrar en el autobús. Siguiendo el autobús';

  @override
  String get centerBusPaused => 'Centrar en el autobús. Seguimiento en pausa';

  @override
  String get trackThisBus => 'Seguir este autobús';

  @override
  String get trackingFootnote =>
      'Posición informada por la RMTC, consultada cada 15 s. La dirección se basa en el desplazamiento observado; el rastro muestra solo por dónde ya pasó el autobús. La fuente no informa el trayecto por delante ni el orden de las próximas paradas, así que el mapa no muestra recorrido futuro.';

  @override
  String get noticeEtaStillAvailable =>
      'La estimación de llegada sigue disponible.';

  @override
  String get noticeLocatingAgain => 'Intentando localizar el autobús de nuevo.';

  @override
  String get noticeLastKnownPosition =>
      'El mapa muestra la última posición conocida.';

  @override
  String get noticeTemporaryFailure =>
      'Fallo temporal al consultar la posición.';

  @override
  String get noticeRetryEvery15 => 'Nuevo intento automático cada 15 s.';

  @override
  String busPositionSemantics(String status) {
    return 'Posición del autobús: $status';
  }

  @override
  String get busDetails => 'Detalles del autobús';

  @override
  String get busDetailsCollapseSemantics => 'Detalles del autobús. Contraer';

  @override
  String get busDetailsExpandSemantics => 'Detalles del autobús. Expandir';

  @override
  String get detailBus => 'Autobús';

  @override
  String get detailLine => 'Línea';

  @override
  String get detailDestination => 'Destino';

  @override
  String get detailReferenceStop => 'Parada de referencia';

  @override
  String get detailPosition => 'Posición';

  @override
  String get detailPunctuality => 'Puntualidad';

  @override
  String get detailAccessibility => 'Accesibilidad';

  @override
  String get detailOccupancy => 'Ocupación';

  @override
  String get detailMovement => 'Movimiento';

  @override
  String get notProvidedF => 'No informada';

  @override
  String get notProvidedM => 'No informado';

  @override
  String get notIndicatedBySource => 'No indicada por la fuente';

  @override
  String get infoUnavailable => 'Información no disponible';

  @override
  String get movementNotObserved => 'Dirección aún no observada';

  @override
  String get movementObserved =>
      'La flecha en el mapa indica la dirección observada';

  @override
  String get trailNote =>
      'Rastro basado en las posiciones observadas. Recorrido oficial aún no disponible.';

  @override
  String etaUnavailable(String stop) {
    return 'Estimación para la parada $stop no disponible.';
  }

  @override
  String etaToStopUnknown(String stop) {
    return 'estimación hasta la parada $stop';
  }

  @override
  String etaToStopMinutes(String stop) {
    return 'min hasta la parada $stop';
  }

  @override
  String etaFromQuery(String freshness) {
    return 'Estimación de la consulta de la parada · $freshness';
  }

  @override
  String mapPosition(String number) {
    return 'Mapa con la posición del autobús $number informada por la fuente';
  }

  @override
  String mapPositionStale(String number) {
    return 'Mapa con la posición del autobús $number informada por la fuente, posiblemente desactualizada';
  }

  @override
  String mapPositionPending(String number) {
    return 'Mapa. Posición del autobús $number aún no disponible';
  }

  @override
  String get mapNoBus => 'Mapa de Goiânia. Ningún autobús en seguimiento';

  @override
  String mapOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autobuses más en tiempo real de camino a la parada',
      one: '1 autobús más en tiempo real de camino a la parada',
      zero: '0 autobuses más en tiempo real de camino a la parada',
    );
    return '$_temp0';
  }

  @override
  String favoriteStopAdd(String code) {
    return 'Marcar la parada $code como favorita';
  }

  @override
  String favoriteStopRemove(String code) {
    return 'Quitar la parada $code de favoritos';
  }

  @override
  String favoriteStopsLimit(int limit) {
    return 'Límite de $limit favoritos. Quita uno para añadir otro.';
  }

  @override
  String favoriteLinesLimit(int limit) {
    return 'Límite de $limit líneas favoritas. Quita una para añadir otra.';
  }

  @override
  String favoriteLineAdd(String route) {
    return 'Marcar la línea $route como favorita en esta parada';
  }

  @override
  String favoriteLineRemove(String route, String stop) {
    return 'Quitar la línea $route de la parada $stop de favoritos';
  }

  @override
  String get favoriteLineOn => 'Línea favorita';

  @override
  String get favoriteLineOff => 'Marcar esta línea como favorita';

  @override
  String get storageNotPersistent =>
      'Este dispositivo no guardó las paradas. Valen solo hasta cerrar la app.';

  @override
  String get storageReadFailed =>
      'No se pudieron leer las paradas guardadas. Empezamos con la lista vacía.';

  @override
  String get storageWriteFailed =>
      'No se pudo guardar ahora. La lista vale hasta cerrar la app.';

  @override
  String stopOpenArrivals(String code) {
    return 'Consultar las llegadas de la parada $code';
  }

  @override
  String stopOpenArrivalsNamed(String code, String name) {
    return 'Consultar las llegadas de la parada $code, $name';
  }

  @override
  String lineOpenArrivals(String route, String stop) {
    return 'Consultar las llegadas de la línea $route en la parada $stop';
  }

  @override
  String get offlineHint =>
      'Toca una parada para consultar las llegadas. La consulta necesita internet y ninguna estimación se guarda en el dispositivo.';

  @override
  String get favoritesEmptyTitle => 'Tus paradas favoritas aparecerán aquí.';

  @override
  String get favoritesEmptyBody =>
      'Consulta una parada y toca la estrella del encabezado para marcarla como favorita.';

  @override
  String get favoriteStopsSection => 'Paradas favoritas';

  @override
  String get favoriteLinesSection => 'Líneas favoritas';

  @override
  String get clearRecentsTitle => '¿Limpiar recientes?';

  @override
  String get clearRecentsBody =>
      'Se borrará el historial de paradas consultadas en este dispositivo. Tus favoritas no cambian.';

  @override
  String get recentsSection => 'Recientes';

  @override
  String get recentsEmpty => 'Las paradas que consultes aparecerán aquí.';

  @override
  String recentStopRemove(String code) {
    return 'Quitar la parada $code de recientes';
  }

  @override
  String get loadingSavedStops => 'Cargando paradas guardadas';

  @override
  String get favoriteStatusLoading => 'Consultando…';

  @override
  String get favoriteStatusOffline =>
      'Sin conexión. Toca Actualizar cuando vuelva internet.';

  @override
  String get favoriteStatusFailed => 'No se pudo consultar ahora.';

  @override
  String get lastValidData => 'Último dato válido de la fuente';

  @override
  String lastValidDataAt(String hour) {
    return 'Último dato válido de la fuente · consulta de las $hour';
  }

  @override
  String get queriedNow => 'Consulta hecha ahora';

  @override
  String queriedAtHour(String hour) {
    return 'Consulta de las $hour';
  }

  @override
  String lineSemantics(String route, String minutes, String quality) {
    return 'Línea $route, $minutes, $quality';
  }

  @override
  String get seenLinesSection => 'Líneas vistas';

  @override
  String get seenLinesNote =>
      'Líneas vistas en tus consultas de esta sesión y en tus favoritos. La lista completa de líneas depende de la autorización de la RMTC.';

  @override
  String seenAtStop(String stop) {
    return 'en la parada $stop';
  }

  @override
  String seenAtStops(String stops) {
    return 'en las paradas $stops';
  }

  @override
  String seenAtStopsMore(String stops, int more) {
    return 'en las paradas $stops y $more más';
  }

  @override
  String seenLineSemantics(String route, String label, String stop) {
    return 'Línea $route, $label. Consultar las llegadas de la parada $stop';
  }

  @override
  String get noticeOffline =>
      'Sin conexión. Puedes abrir tus paradas, pero las llegadas solo aparecen con internet.';

  @override
  String get noticeQueryIncomplete =>
      'La última consulta no se completó. Inténtalo de nuevo en unos instantes.';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeBody => 'El mapa sigue el tema elegido.';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeNight => 'Nocturno';

  @override
  String get themeLight => 'Claro';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get settingsBusData => 'Datos de autobuses';

  @override
  String get settingsBusDataBody =>
      'App independiente, sin vínculo con la RMTC, la CMTC ni la Alcaldía. Datos de la RMTC a través de la API de BusãoGyn; las posiciones y estimaciones en tiempo real dependen del GPS informado por la fuente.';

  @override
  String get settingsMap => 'Mapa';

  @override
  String get settingsMapBody =>
      'OpenFreeMap · © OpenMapTiles · datos © OpenStreetMap';

  @override
  String get settingsTypography => 'Tipografía';

  @override
  String get settingsTypographyBody =>
      'Geist y Geist Mono · SIL Open Font License 1.1';

  @override
  String get settingsLicenses => 'Licencias';

  @override
  String get settingsLicensesBody => 'Bibliotecas y fuentes usadas por la app.';

  @override
  String get settingsPrivacy => 'Privacidad';

  @override
  String get settingsPrivacyBody => 'Qué hace la app con los datos.';

  @override
  String get privacySummary =>
      '• Sin cuenta, inicio de sesión ni registro.\n• La app no pide tu ubicación y no accede a contactos, fotos, cámara ni micrófono.\n• Sin publicidad, analítica de uso, informes de fallos ni rastreo.\n• Favoritos, recientes y el tema quedan solo en este dispositivo.\n• Para mostrar llegadas y posiciones, el código de la parada y el número del autobús van a la API de BusãoGyn (Cloudflare), que consulta la RMTC. El mapa viene de OpenFreeMap. Como en cualquier acceso a internet, estos servicios reciben datos técnicos de la conexión, como la IP.\n• Compartir abre la opción del sistema con el texto que ves; nada se envía sin tu acción.';

  @override
  String get privacyFullPolicy => 'Política completa:';

  @override
  String get privacyCopyLink => 'Copiar enlace';

  @override
  String get privacyLinkCopied => 'Enlace copiado.';

  @override
  String get privacyClose => 'Cerrar';

  @override
  String get catalogSearchHint => 'Código, calle, barrio o ciudad';

  @override
  String get catalogResultsTitle => 'Paradas en el registro';

  @override
  String catalogResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paradas',
      one: '1 parada',
      zero: 'Ninguna parada',
    );
    return '$_temp0';
  }

  @override
  String catalogResultsMore(int shown, int total) {
    return 'Mostrando $shown de $total. Refina la búsqueda para ver otras.';
  }

  @override
  String get catalogNoResultsTitle => 'Ninguna parada encontrada';

  @override
  String get catalogNoResultsBody =>
      'Revisa la escritura o usa el código impreso en la parada.';

  @override
  String get catalogSearchCodeHint =>
      'Toca una parada para ver la dirección y las líneas, o envía el código para consultar las llegadas.';

  @override
  String catalogOpenStop(String code, String place) {
    return 'Parada $code, $place. Ver detalles';
  }

  @override
  String get catalogStopNotFound =>
      'Este código no está en el registro oficial. Las llegadas pueden funcionar igualmente.';

  @override
  String get catalogStopLinesTitle => 'Líneas que atienden esta parada';

  @override
  String get catalogStopLinesNote =>
      'Registro oficial: muestra las líneas de la parada, no buses en camino. Las llegadas en tiempo real o programadas aparecen al consultar llegadas.';

  @override
  String get catalogNoLinesListed =>
      'Ninguna línea asociada a esta parada en el registro.';

  @override
  String get catalogSeeArrivals => 'Ver llegadas';

  @override
  String catalogSourceNote(String reference) {
    return 'Registro oficial CMTC · referencia $reference · disponible sin conexión';
  }

  @override
  String get catalogDevBadge => 'Datos de desarrollo, no publicados';

  @override
  String get catalogStation => 'Estación sin dirección en el registro';

  @override
  String catalogStopTitle(String code) {
    return 'Parada $code';
  }

  @override
  String get catalogPreviewClose => 'Volver a la búsqueda';

  @override
  String get catalogAddress => 'Dirección';

  @override
  String get catalogDistrict => 'Barrio';

  @override
  String get catalogCity => 'Municipio';

  @override
  String catalogLinesHeaderSubtitle(int count) {
    return '$count líneas en el registro oficial';
  }

  @override
  String get catalogLinesSearchHint => 'Número o nombre de la línea';

  @override
  String get catalogLinesNoResults => 'Ninguna línea encontrada.';

  @override
  String get catalogLinesAllTitle => 'Líneas';

  @override
  String get catalogShowMore => 'Mostrar más';

  @override
  String get catalogLineVariants => 'Variantes';

  @override
  String catalogLineStops(int count) {
    return 'Paradas registradas ($count)';
  }

  @override
  String get catalogLineStopsNote =>
      'Paradas asociadas a la línea en el registro, sin orden de recorrido ni sentido.';

  @override
  String get catalogLineStatus => 'Situación';

  @override
  String get catalogLineType => 'Tipo';

  @override
  String get catalogLineCities => 'Municipios';

  @override
  String get catalogLineOrigin => 'Origen';

  @override
  String get catalogLineDestination => 'Destino';

  @override
  String catalogValidFrom(String date) {
    return 'Vigente desde $date';
  }

  @override
  String get catalogBackToLines => 'Volver a las líneas';

  @override
  String catalogOpenLine(String line, String name) {
    return 'Línea $line, $name. Ver detalles';
  }

  @override
  String get catalogLineNotFound => 'Línea no encontrada en el registro.';

  @override
  String catalogVariantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count variantes',
      one: '1 variante',
      zero: 'Sin variantes',
    );
    return '$_temp0';
  }

  @override
  String get settingsCatalog => 'Catálogo oficial (desarrollo)';

  @override
  String settingsCatalogBody(String license, String reference, String version) {
    return 'Versión $version · referencia $reference · redistribución: $license. Activado solo en este build de desarrollo.';
  }

  @override
  String get catalogIntroTitle => 'Busca una parada';

  @override
  String get catalogIntroBody =>
      'Por el código de la placa, la calle, el barrio o la ciudad. Luego mira las próximas llegadas y sigue el bus en el mapa.';

  @override
  String get catalogDirectionOutbound => 'Ida';

  @override
  String get catalogDirectionInbound => 'Vuelta';

  @override
  String get catalogDirectionUnknown => 'Trayecto';

  @override
  String catalogRouteOnMap(String direction, String variant) {
    return 'En el mapa: $variant · $direction';
  }

  @override
  String get catalogClearRoute => 'Quitar trayecto';

  @override
  String get catalogShowRouteHint =>
      'Toca Ida o Vuelta para ver el trayecto oficial en el mapa.';

  @override
  String get catalogRouteLegend =>
      'Ida: ámbar continua · Vuelta: discontinua · Otros trayectos de la línea: gris · Anillos: paradas registradas de la línea, sin orden de parada.';

  @override
  String get catalogKmzOnlyShapes =>
      'Trayectos del KMZ sin variante en el registro';

  @override
  String catalogShowRouteSemantics(String direction, String variant) {
    return 'Mostrar en el mapa el trayecto $variant, $direction';
  }

  @override
  String get catalogMapHint =>
      'Toca una parada en el mapa para ver dirección y líneas.';

  @override
  String get trackMatchTitle => 'Trayecto oficial (experimental)';

  @override
  String trackMatchConfirmed(String direction, String variant) {
    return 'Asociado a $variant · $direction. En el mapa, el recorrido oficial aparece en gris y el tramo por delante, estimado, en ámbar discontinuo. Sin previsión de horario.';
  }

  @override
  String trackMatchPending(String variant) {
    return 'Variante $variant identificada. Esperando que el bus avance para confirmar el sentido; todavía no se dibuja ningún trayecto.';
  }

  @override
  String trackMatchAmbiguous(String reason) {
    return 'Sin asociación segura a un trayecto oficial: $reason. El mapa muestra solo la posición y el rastro observado.';
  }

  @override
  String get trackMatchNoShapes =>
      'Esta línea no tiene trayecto oficial en el catálogo.';

  @override
  String get trackMatchNoPosition =>
      'Sin posición actual del bus: no se dibuja ningún trayecto.';

  @override
  String get trackReasonRouteNameMissing =>
      'la fuente no informó el itinerario';

  @override
  String get trackReasonRouteNameNoMatch =>
      'el itinerario informado no está en el registro';

  @override
  String get trackReasonRouteNameSeveral =>
      'más de una variante tiene ese itinerario';

  @override
  String get trackReasonDirectionUnknown => 'el destino no indica el sentido';

  @override
  String get trackReasonShapeMissing =>
      'no hay un trayecto oficial único para ese sentido';

  @override
  String get trackReasonOffRoute => 'el bus está fuera del trayecto registrado';

  @override
  String get trackReasonMovingBackwards =>
      'el desplazamiento observado contradice el trayecto';

  @override
  String get scheduleTitle => 'Horarios programados';

  @override
  String get scheduleDayWeekday => 'Días hábiles';

  @override
  String get scheduleDaySaturday => 'Sábado';

  @override
  String get scheduleDaySunday => 'Domingo y feriado';

  @override
  String get scheduleAllCodes => 'Todas';

  @override
  String get scheduleNone => 'Sin cuadro de horarios para esta línea.';

  @override
  String get scheduleInsufficient =>
      'Cuadro no disponible: datos inconsistentes o insuficientes en la planilla.';

  @override
  String scheduleRecent(String date) {
    return 'Referencia del $date · vigencia no confirmada por la CMTC. Verifique antes de salir.';
  }

  @override
  String scheduleConfirmed(String date) {
    return 'Vigencia confirmada · referencia del $date.';
  }

  @override
  String scheduleOld(String date) {
    return 'Cuadro de referencia antigua ($date). Puede que ya no esté vigente.';
  }

  @override
  String get scheduleShowOld => 'Ver de todos modos';

  @override
  String scheduleSource(String oso, String source) {
    return 'Planilla: $source · OSO $oso';
  }

  @override
  String get scheduleDepartureNote =>
      'Horarios de salida, no de paso por las paradas. La planilla no indica sentido ni lugar de salida. No son previsiones en tiempo real.';

  @override
  String get scheduleEmptyDay => 'Sin salidas programadas este día.';

  @override
  String scheduleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count salidas',
      one: '1 salida',
      zero: 'Ninguna salida',
    );
    return '$_temp0';
  }

  @override
  String get scheduleLegendNextDay => '+1: después de medianoche';

  @override
  String get scheduleLegendHalf =>
      'MI: media vuelta, inicio en el retorno · MF: media vuelta, fin en el retorno';

  @override
  String get scheduleLegendRepeated => '×2: repetido en la planilla';

  @override
  String scheduleCodeUnregistered(String code) {
    return '$code (sin registro)';
  }

  @override
  String sequenceTitle(int count, String direction) {
    return 'Paradas estimadas · $direction ($count)';
  }

  @override
  String get sequenceEstimatedNote =>
      'Orden estimado por el trayecto oficial. No es la secuencia oficial de la CMTC.';

  @override
  String get sequenceUncertain => 'posición incierta';

  @override
  String get sequenceRepeated => 'pasa de nuevo';

  @override
  String sequencePartialTitle(int count) {
    return 'Paradas cerca de este trayecto ($count)';
  }

  @override
  String get sequencePartialNote =>
      'Sin confianza suficiente para ordenar las paradas: lista sin orden de recorrido.';

  @override
  String get sequenceNone =>
      'Ninguna parada del registro asociada a este trayecto.';

  @override
  String sequenceAmbiguous(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paradas quedaron fuera por ambigüedad.',
      one: '1 parada quedó fuera por ambigüedad.',
      zero: 'Ninguna parada quedó fuera por ambigüedad.',
    );
    return '$_temp0';
  }

  @override
  String sequenceShowAll(int count) {
    return 'Mostrar todas ($count)';
  }

  @override
  String get itineraryTitle => 'En el itinerario (estimado)';

  @override
  String itineraryRow(
    String direction,
    int position,
    int total,
    String variant,
  ) {
    return '$variant · $direction — parada $position de $total';
  }

  @override
  String get itineraryNote =>
      'Posición estimada por el trayecto oficial; sin horario de paso.';

  @override
  String get nextStopsTitle => 'Próximas paradas (estimado)';

  @override
  String get nextStopLabel => 'Próxima';

  @override
  String get nextStopsUncertain =>
      'Próxima parada incierta: lista en orden estimado.';

  @override
  String nextStopsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paradas hasta el final',
      one: '1 parada hasta el final',
      zero: 'Ninguna parada hasta el final',
    );
    return '$_temp0';
  }

  @override
  String get nextStopsNote =>
      'Por el trayecto oficial y la posición real. Sin previsión de llegada por parada.';

  @override
  String get nextStopsUnreliable =>
      'Sin secuencia confiable de paradas para este trayecto: solo el seguimiento en el mapa.';

  @override
  String get nextStopsEnd => 'Ómnibus al final del trayecto.';

  @override
  String get trackReasonGpsJump => 'la posición saltó a lo largo del trayecto';

  @override
  String get trackReasonRepeatedSection =>
      'el trayecto pasa dos veces por este tramo';

  @override
  String get plannerOpen => 'Planear viaje';

  @override
  String get plannerTitle => 'Planear viaje';

  @override
  String get plannerIntro =>
      'De parada a parada, con hasta dos transbordos. Funciona sin internet: usa solo el catálogo del dispositivo.';

  @override
  String get plannerOrigin => 'Origen';

  @override
  String get plannerDestination => 'Destino';

  @override
  String get plannerSearchHint => 'Código, calle, barrio o ciudad';

  @override
  String get plannerPickOnMap => 'Elegir en el mapa';

  @override
  String plannerPicking(String field) {
    return 'Toque una parada en el mapa para definir: $field.';
  }

  @override
  String get plannerSwap => 'Invertir origen y destino';

  @override
  String get plannerSearch => 'Buscar viajes';

  @override
  String get plannerClose => 'Cerrar planificador';

  @override
  String get plannerNotCovered => 'fuera del planificador';

  @override
  String get plannerNoResultTitle => 'Ningún viaje para mostrar';

  @override
  String get plannerSameStop => 'Origen y destino son la misma parada.';

  @override
  String get plannerUnknownStop => 'Parada no encontrada en el catálogo.';

  @override
  String get plannerNoCoverageOrigin =>
      'El origen aún no está en ningún trayecto con orden de paradas confiable. Pruebe una parada cercana.';

  @override
  String get plannerNoCoverageDestination =>
      'El destino aún no está en ningún trayecto con orden de paradas confiable. Pruebe una parada cercana.';

  @override
  String get plannerNoRoute =>
      'No hay viaje con evidencia suficiente y hasta dos transbordos. No significa que no haya autobús, solo que los datos actuales no lo confirman.';

  @override
  String get plannerTruncated =>
      'La búsqueda se detuvo en el límite de procesamiento; puede haber otras opciones.';

  @override
  String plannerResultsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alternativas',
      one: '1 alternativa',
      zero: 'Ninguna alternativa',
    );
    return '$_temp0';
  }

  @override
  String get plannerReliable => 'Confiable';

  @override
  String get plannerEstimated => 'Estimada';

  @override
  String plannerBuses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autobuses',
      one: '1 autobús',
      zero: 'Ningún autobús',
    );
    return '$_temp0';
  }

  @override
  String get plannerDirect => 'directo';

  @override
  String plannerTransfers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transbordos',
      one: '1 transbordo',
      zero: 'sin transbordo',
    );
    return '$_temp0';
  }

  @override
  String get plannerBoard => 'Embarque';

  @override
  String get plannerTransfer => 'Transbordo';

  @override
  String get plannerAlight => 'Bajada';

  @override
  String plannerLeg(String direction, String km, int stops, String variant) {
    return '$variant · $direction · $stops paradas · $km km por el trayecto';
  }

  @override
  String plannerWalk(int meters) {
    return 'a pie, ~$meters m en línea recta';
  }

  @override
  String get plannerShowOnMap => 'Ver en el mapa';

  @override
  String get plannerOnMap => 'En el mapa';

  @override
  String get plannerNoTimes =>
      'Sin tiempo de viaje ni horario: los cuadros no tienen vigencia confirmada. El orden de las paradas es estimado por el trayecto oficial; los km se miden en él.';

  @override
  String get plannerCautionOrder =>
      'Orden de paradas no verificado con las calles oficiales.';

  @override
  String get plannerCautionUncertain =>
      'Posición incierta de una parada de subida o bajada.';

  @override
  String get plannerCautionRepeated =>
      'El autobús pasa más de una vez por una de las paradas.';

  @override
  String get plannerCautionWalk =>
      'Transbordo a pie: cruce, vereda y accesibilidad no verificados.';

  @override
  String get plannerCautionHub =>
      'Estación o terminal: la relación con la línea es inferida (no hay registro oficial parada-línea).';

  @override
  String get plannerCautionSameStation =>
      'Cambio de plataforma en la misma estación; no se informa qué plataforma atiende cada sentido.';

  @override
  String get sequenceOrderedNote =>
      'Lista incompleta: el orden fue verificado (calles oficiales o estaciones del corredor), pero algunas paradas quedaron fuera.';

  @override
  String get catalogTerminalNote =>
      'Terminal identificado por los nombres oficiales de las líneas y el final de los trayectos oficiales (inferido). No tiene código para consultar llegadas.';

  @override
  String get catalogStationNote =>
      'Estación de corredor (carpeta oficial del KMZ). Las líneas que paran aquí se infieren por el corredor; vea \"En el itinerario\".';

  @override
  String get catalogTerminalTag => 'terminal (inferido)';

  @override
  String get dockPlan => 'Planear';

  @override
  String get dockSaved => 'Guardados';

  @override
  String trackingBarSemantics(String bus, String heading) {
    return 'Siguiendo el autobús $bus, $heading. Toque para abrir.';
  }

  @override
  String get trackingBarOpen => 'Abrir seguimiento';

  @override
  String get trackingBarStale => 'Posición antigua o sin señal';

  @override
  String get sheetShowMap => 'Ver mapa';

  @override
  String get sheetShowPanel => 'Mostrar panel';

  @override
  String get sheetHandleHint => 'Toque para expandir o recoger';

  @override
  String get plannerClear => 'Limpiar';

  @override
  String get plannerHeaderSubtitle =>
      'De parada a parada · funciona sin internet';

  @override
  String get sheetSummaryStops => 'Paradas y llegadas';

  @override
  String sheetSummaryStop(String code, String lines) {
    return 'Parada $code · $lines';
  }

  @override
  String get sheetSummaryPlan => 'Origen y destino';

  @override
  String get sheetSummaryLines => 'Catálogo de líneas';

  @override
  String sheetSummaryLine(String line) {
    return 'Línea $line';
  }

  @override
  String get sheetSummarySaved => 'Favoritos y recientes';

  @override
  String get sheetSummaryTracking => 'Seguimiento del autobús';

  @override
  String get nearbyButton => 'Cerca de mí';

  @override
  String get nearbyLocating => 'Buscando tu ubicación…';

  @override
  String get nearbyHint =>
      'Usa tu ubicación solo ahora, en el dispositivo: no se guarda ni se envía.';

  @override
  String get nearbyTitle => 'Cerca de ti';

  @override
  String get nearbyRefresh => 'Actualizar';

  @override
  String nearbyImprecise(int meters) {
    return 'Ubicación aproximada (± $meters m). Revisa el mapa.';
  }

  @override
  String get nearbyEmpty => 'Ninguna parada registrada a menos de 1 km.';

  @override
  String nearbyDistance(int meters) {
    return '$meters m en línea recta';
  }

  @override
  String get nearbyStraightLine =>
      'Distancias en línea recta: el camino a pie puede ser más largo.';

  @override
  String get nearbyDenied =>
      'Sin permiso de ubicación. Puedes buscar la parada por código, calle o barrio.';

  @override
  String get nearbyDeniedForever =>
      'La ubicación está bloqueada para BusãoGyn. Para usarla, permítela en los ajustes del dispositivo.';

  @override
  String get nearbyServiceOff =>
      'La ubicación del dispositivo está desactivada.';

  @override
  String get nearbyTimeout =>
      'No se pudo obtener tu ubicación a tiempo. Inténtalo de nuevo, mejor al aire libre.';

  @override
  String get nearbyUnavailable =>
      'Ubicación no disponible en este dispositivo o navegador.';

  @override
  String get nearbyOpenSettings => 'Abrir ajustes';

  @override
  String get shareCopied => 'Texto copiado para compartir.';

  @override
  String get shareUnavailable =>
      'No se puede compartir en este dispositivo o navegador.';

  @override
  String shareStop(String code) {
    return 'Parada de autobús $code';
  }

  @override
  String get shareFooter =>
      'Enviado desde BusãoGyn (app independiente, no oficial).';

  @override
  String shareLine(String line, String name) {
    return 'Línea $line — $name';
  }

  @override
  String get shareCatalogNote =>
      'Datos de registro; revisa horarios y recorrido antes de salir.';

  @override
  String shareTripTitle(String from, String to) {
    return 'Viaje en autobús (estimación): $from → $to';
  }

  @override
  String shareTripLeg(int step, String line, String from, String to) {
    return '$step. Línea $line: sube en $from, baja en $to';
  }

  @override
  String get shareTripNote =>
      'Estimación a partir del registro, no es un recorrido oficial. Revisa antes de salir.';

  @override
  String get shareStopAction => 'Compartir parada';

  @override
  String get shareLineAction => 'Compartir línea';

  @override
  String get shareTripAction => 'Compartir viaje';

  @override
  String get tripSave => 'Guardar viaje';

  @override
  String get tripSaved => 'Viaje guardado';

  @override
  String get tripSavedNotice => 'Viaje guardado en Guardados.';

  @override
  String tripsLimit(int count) {
    return 'Ya tienes $count viajes guardados. Quita uno para guardar otro.';
  }

  @override
  String get tripMissingStop =>
      'Una parada de este viaje no está en el registro actual.';

  @override
  String get savedTripsTitle => 'Viajes';

  @override
  String get tripRenameTitle => 'Nombre del viaje';

  @override
  String get tripRenameSave => 'Guardar';

  @override
  String get tripMenu => 'Opciones del viaje';

  @override
  String get tripRename => 'Renombrar';

  @override
  String get tripRemove => 'Quitar';

  @override
  String get catalogSearchApproximate =>
      'Nada exacto: mostrando nombres parecidos (un error de escritura).';

  @override
  String get nearbyDeniedBrowser =>
      'La ubicación está bloqueada para este sitio. Permítela en los permisos del navegador.';

  @override
  String nearbySummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paradas',
      one: '1 parada',
      zero: 'ninguna parada',
    );
    return 'Cerca de ti · $_temp0';
  }

  @override
  String get seenLinesHeader => 'Líneas de las paradas que consultaste';

  @override
  String get seenLinesEmptyTitle => 'Todavía no hay líneas aquí.';

  @override
  String get seenLinesEmptyBody =>
      'Consulta una parada: las líneas que pasan por ella aparecen aquí, con las próximas llegadas.';
}
