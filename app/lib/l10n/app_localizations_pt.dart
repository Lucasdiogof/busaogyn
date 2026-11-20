// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get dockLines => 'Linhas';

  @override
  String get dockStops => 'Pontos';

  @override
  String get dockFavorites => 'Favoritos';

  @override
  String get dockTracking => 'Meu ônibus';

  @override
  String dockTrackedBadge(String label) {
    return '$label, ônibus acompanhado';
  }

  @override
  String get settings => 'Ajustes';

  @override
  String get settingsSubtitle => 'Aparência e sobre';

  @override
  String get settingsClose => 'Fechar ajustes';

  @override
  String get comingSoon => 'Em breve';

  @override
  String get loading => 'Carregando…';

  @override
  String get refresh => 'Atualizar';

  @override
  String get refreshing => 'atualizando…';

  @override
  String get refreshArrivals => 'Atualizar chegadas';

  @override
  String get retry => 'Tentar de novo';

  @override
  String retryStop(String code) {
    return 'Tentar o ponto $code';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get clear => 'Limpar';

  @override
  String get close => 'Fechar';

  @override
  String get view => 'Ver';

  @override
  String get viewArrivals => 'Ver chegadas';

  @override
  String get search => 'Buscar';

  @override
  String get searchStopAction => 'Buscar um ponto';

  @override
  String get searchAnotherStop => 'Buscar outro ponto';

  @override
  String get searchHint => 'Código do ponto, ex.: 30402';

  @override
  String get clearCode => 'Limpar código';

  @override
  String get backToStop => 'Voltar ao ponto';

  @override
  String get stopWord => 'Ponto';

  @override
  String get atStopWord => 'no ponto';

  @override
  String get now => 'agora';

  @override
  String ago(String age) {
    return 'há $age';
  }

  @override
  String get panelHandleLabel => 'Painel. Arraste para expandir ou recolher';

  @override
  String routeNumber(String route) {
    return 'Linha $route';
  }

  @override
  String get routeNotProvided => 'Linha não informada';

  @override
  String busNumber(String number) {
    return 'Ônibus $number';
  }

  @override
  String linesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count linhas',
      one: '1 linha',
    );
    return '$_temp0';
  }

  @override
  String get savedStopsNone => 'Nenhum ponto salvo';

  @override
  String savedStopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pontos salvos',
      one: '1 ponto salvo',
    );
    return '$_temp0';
  }

  @override
  String get queryingArrivals => 'consultando chegadas…';

  @override
  String get queryingArrivalsSemantics => 'Consultando chegadas';

  @override
  String queryingStop(String stop) {
    return 'Consultando o ponto $stop';
  }

  @override
  String get qualityRealtime => 'Tempo real';

  @override
  String get qualityScheduled => 'Programado';

  @override
  String get qualityUnknownLong => 'Informação não confirmada';

  @override
  String get qualityUnknownShort => 'Não confirmado';

  @override
  String get minutesUnknown => 'tempo não informado';

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
    );
    return '$_temp0';
  }

  @override
  String get punctualityOnTime => 'No horário';

  @override
  String get punctualityDelayed => 'Atrasado';

  @override
  String get punctualityEarly => 'Adiantado';

  @override
  String get punctualityUnknown => 'Pontualidade não informada';

  @override
  String get accessible => 'Acessível';

  @override
  String get accessibilityNotIndicated => 'Acessibilidade não indicada';

  @override
  String get accessibilityUnknown => 'Acessibilidade não informada';

  @override
  String get destinationUnknown => 'Destino não informado';

  @override
  String headingTo(String destination) {
    return 'Indo para $destination';
  }

  @override
  String get positionSearching => 'Buscando posição do ônibus';

  @override
  String get positionConnection => 'Conexão instável';

  @override
  String get positionUnavailable => 'Posição temporariamente indisponível';

  @override
  String positionOutdated(String age) {
    return 'Posição desatualizada · há $age';
  }

  @override
  String positionLive(String age) {
    return 'Ao vivo · há $age';
  }

  @override
  String positionLast(String age) {
    return 'Última posição há $age';
  }

  @override
  String positionAgeShort(String age) {
    return 'posição há $age';
  }

  @override
  String get positionMaybeOutdated => 'Posição possivelmente desatualizada';

  @override
  String freshnessStale(String age) {
    return 'Dados temporariamente desatualizados · há $age';
  }

  @override
  String get freshnessNow => 'Atualizado agora';

  @override
  String freshnessAge(String age) {
    return 'Atualizado há $age';
  }

  @override
  String get liveSearchingLabel => 'Buscando';

  @override
  String get liveSearchingDetail => 'posição';

  @override
  String get liveConnectionLabel => 'Conexão';

  @override
  String get liveConnectionDetail => 'instável';

  @override
  String get liveLocatingLabel => 'Localizando';

  @override
  String get liveLocatingDetail => 'ônibus';

  @override
  String get liveOutdated => 'Desatualizado';

  @override
  String get liveLabel => 'Ao vivo';

  @override
  String get livePosition => 'Posição';

  @override
  String get liveNoEstimate => 'Sem previsão';

  @override
  String get liveNoGps => 'sem GPS';

  @override
  String get liveEstimate => 'Previsão';

  @override
  String get errFormat =>
      'O BusãoGyn recebeu dados em formato inesperado. Tente novamente.';

  @override
  String get errArrivalsGeneric =>
      'Não foi possível consultar este ponto agora.';

  @override
  String get errPositionGeneric =>
      'Não foi possível localizar este ônibus agora.';

  @override
  String get errTimeout =>
      'A consulta demorou mais que o esperado. Tente novamente.';

  @override
  String get errNetwork =>
      'Sem conexão com o BusãoGyn. Verifique sua internet.';

  @override
  String get errSourceTimeout =>
      'A RMTC demorou para responder. Tente novamente em instantes.';

  @override
  String get errSourceUnavailable =>
      'A fonte de dados da RMTC está indisponível agora. Tente novamente em instantes.';

  @override
  String get errSourceInvalidArrivals =>
      'A RMTC não retornou dados válidos para este ponto. Confira o código ou tente novamente.';

  @override
  String get errSourceInvalidPosition =>
      'A RMTC não retornou dados válidos para este ônibus agora.';

  @override
  String get errInvalidStop => 'Código de ponto inválido. Use apenas números.';

  @override
  String get errInvalidVehicle =>
      'Este ônibus não tem um número válido para acompanhamento.';

  @override
  String get errInvalidResponse =>
      'O BusãoGyn recebeu uma resposta inesperada. Tente novamente.';

  @override
  String get errRetryable =>
      'O serviço está instável agora. Tente novamente em instantes.';

  @override
  String get errGeneric => 'Não foi possível concluir a consulta.';

  @override
  String get errPositionNotReported =>
      'A fonte não informou a posição deste ônibus agora.';

  @override
  String get errPositionUnavailable => 'Posição temporariamente indisponível.';

  @override
  String get searchInvalidTitle => 'Digite o código do ponto';

  @override
  String get searchInvalidBody => 'Use só os números da placa do ponto.';

  @override
  String get searchNotFoundTitle => 'Ponto não encontrado';

  @override
  String get searchNotFoundBody => 'Confira o código e tente novamente.';

  @override
  String get searchTimeoutTitle => 'A consulta demorou demais';

  @override
  String get searchTimeoutBody => 'Tente novamente em instantes.';

  @override
  String get searchOfflineTitle => 'Sem conexão';

  @override
  String get searchOfflineBody => 'Verifique sua internet e tente de novo.';

  @override
  String get searchUnavailableTitle => 'Serviço temporariamente indisponível';

  @override
  String get searchUnavailableBody => 'Tente novamente em alguns minutos.';

  @override
  String get nextBuses => 'Próximos ônibus';

  @override
  String get sourceUnstable =>
      'A fonte está instável. Mostrando o último dado válido.';

  @override
  String get noArrivalsNow => 'Nenhuma chegada prevista agora';

  @override
  String noArrivalsNowAt(String hour) {
    return 'Nenhuma chegada prevista agora · consulta das $hour';
  }

  @override
  String get noArrivalsBody =>
      'A fonte não informou ônibus para este ponto neste momento. Tente atualizar em alguns minutos.';

  @override
  String get legendRealtime =>
      ': posição informada pela RMTC, pode ser acompanhada.';

  @override
  String get legendScheduled => ': horário de tabela, sem GPS.';

  @override
  String trackingBannerSemantics(String number) {
    return 'Ônibus $number sendo acompanhado. Ver em Meu ônibus';
  }

  @override
  String refreshFailedAt(String hour, String error) {
    return 'Não foi possível atualizar agora. Mostrando a consulta das $hour, que pode já não valer. $error';
  }

  @override
  String refreshFailedPrevious(String error) {
    return 'Não foi possível atualizar agora. Mostrando a consulta anterior, que pode já não valer. $error';
  }

  @override
  String get connOfflineTitle => 'Chegadas precisam de internet';

  @override
  String get connFailedTitle => 'Não conseguimos consultar as chegadas';

  @override
  String get connOfflineBody =>
      'O mapa segue disponível, mas as próximas chegadas só aparecem com conexão. Nenhuma previsão antiga é mostrada como se fosse atual.';

  @override
  String connFailedBody(String code) {
    return 'O código $code não foi o problema: a consulta não foi concluída. Nenhuma previsão antiga é mostrada como se fosse atual.';
  }

  @override
  String get connFailedBodyNoCode =>
      'O código digitado não foi o problema: a consulta não foi concluída. Nenhuma previsão antiga é mostrada como se fosse atual.';

  @override
  String get introTitle => 'Digite o código do ponto';

  @override
  String get introBody =>
      'Você vê as próximas chegadas de cada linha e acompanha o ônibus no mapa.';

  @override
  String get introNote =>
      'O código fica na placa do ponto. Só ônibus com GPS informado pela fonte podem ser acompanhados.';

  @override
  String exampleStop(String code) {
    return 'Exemplo: $code';
  }

  @override
  String exampleStopSemantics(String code) {
    return 'Consultar o ponto de exemplo $code';
  }

  @override
  String get noFollowing => 'sem seguinte';

  @override
  String get followingUpper => 'SEGUINTE';

  @override
  String nextSemantics(String minutes, String quality) {
    return 'Próximo: $minutes, $quality';
  }

  @override
  String followingSemantics(String minutes, String quality, String number) {
    return 'Seguinte: $minutes, $quality, ônibus $number';
  }

  @override
  String get trackingUnavailableSemantics =>
      'Acompanhamento indisponível: chegada sem GPS da fonte';

  @override
  String trackBus(String number) {
    return 'Acompanhar ônibus $number';
  }

  @override
  String trackBusSearching(String number) {
    return 'Buscando posição do ônibus $number';
  }

  @override
  String trackBusActive(String number) {
    return 'Acompanhando ônibus $number';
  }

  @override
  String trackBusUnavailable(String number) {
    return 'Ônibus $number sem posição';
  }

  @override
  String trackBusFailing(String number) {
    return 'Reconectando ao ônibus $number';
  }

  @override
  String get trackingHeaderSubtitle => 'Acompanhe um veículo em tempo real';

  @override
  String trackingHeaderSemantics(String number, String heading) {
    return 'Meu ônibus: ônibus $number, $heading';
  }

  @override
  String trackingHeaderSemanticsRoute(
    String number,
    String route,
    String heading,
  ) {
    return 'Meu ônibus: ônibus $number, linha $route, $heading';
  }

  @override
  String busSemantics(String number, String heading) {
    return 'Ônibus $number, $heading';
  }

  @override
  String busSemanticsRoute(String number, String route, String heading) {
    return 'Ônibus $number, linha $route, $heading';
  }

  @override
  String get stopTracking => 'Parar de acompanhar';

  @override
  String get noTrackedBusTitle => 'Nenhum ônibus acompanhado';

  @override
  String get noTrackedBusBody =>
      'Escolha um ônibus em tempo real nas chegadas de um ponto.';

  @override
  String get noTrackedBusNote =>
      'Só ônibus com GPS informado pela RMTC podem ser acompanhados. Horários programados não têm posição.';

  @override
  String get trackingSearching => 'Buscando posição';

  @override
  String get trackingFollowing => 'Acompanhando';

  @override
  String get stop => 'Parar';

  @override
  String get following => 'Seguindo';

  @override
  String get center => 'Centralizar';

  @override
  String get centerBus => 'Centralizar ônibus';

  @override
  String get centerBusFollowing => 'Centralizar ônibus. Seguindo o ônibus';

  @override
  String get centerBusPaused => 'Centralizar ônibus. Seguimento pausado';

  @override
  String get trackThisBus => 'Acompanhar este ônibus';

  @override
  String get trackingFootnote =>
      'Posição informada pela RMTC, consultada a cada 15 s. Direção baseada no deslocamento observado; o rastro mostra só por onde o ônibus já passou. A fonte não informa o trajeto à frente nem a ordem dos próximos pontos, então o mapa não mostra percurso futuro.';

  @override
  String get noticeEtaStillAvailable =>
      'A previsão de chegada continua disponível.';

  @override
  String get noticeLocatingAgain => 'Tentando localizar o ônibus novamente.';

  @override
  String get noticeLastKnownPosition =>
      'O mapa mostra a última posição conhecida.';

  @override
  String get noticeTemporaryFailure =>
      'Falha temporária ao consultar a posição.';

  @override
  String get noticeRetryEvery15 => 'Nova tentativa automática a cada 15 s.';

  @override
  String busPositionSemantics(String status) {
    return 'Posição do ônibus: $status';
  }

  @override
  String get busDetails => 'Detalhes do ônibus';

  @override
  String get busDetailsCollapseSemantics => 'Detalhes do ônibus. Recolher';

  @override
  String get busDetailsExpandSemantics => 'Detalhes do ônibus. Expandir';

  @override
  String get detailBus => 'Ônibus';

  @override
  String get detailLine => 'Linha';

  @override
  String get detailDestination => 'Destino';

  @override
  String get detailReferenceStop => 'Ponto de referência';

  @override
  String get detailPosition => 'Posição';

  @override
  String get detailPunctuality => 'Pontualidade';

  @override
  String get detailAccessibility => 'Acessibilidade';

  @override
  String get detailOccupancy => 'Lotação';

  @override
  String get detailMovement => 'Movimento';

  @override
  String get notProvidedF => 'Não informada';

  @override
  String get notProvidedM => 'Não informado';

  @override
  String get notIndicatedBySource => 'Não indicada pela fonte';

  @override
  String get infoUnavailable => 'Informação não disponível';

  @override
  String get movementNotObserved => 'Direção ainda não observada';

  @override
  String get movementObserved => 'A seta no mapa indica a direção observada';

  @override
  String get trailNote =>
      'Rastro baseado nas posições observadas. Trajeto oficial ainda não disponível.';

  @override
  String etaUnavailable(String stop) {
    return 'Previsão para o ponto $stop indisponível.';
  }

  @override
  String etaToStopUnknown(String stop) {
    return 'previsão até o ponto $stop';
  }

  @override
  String etaToStopMinutes(String stop) {
    return 'min até o ponto $stop';
  }

  @override
  String etaFromQuery(String freshness) {
    return 'Previsão da consulta do ponto · $freshness';
  }

  @override
  String mapPosition(String number) {
    return 'Mapa com a posição do ônibus $number informada pela fonte';
  }

  @override
  String mapPositionStale(String number) {
    return 'Mapa com a posição do ônibus $number informada pela fonte, possivelmente desatualizada';
  }

  @override
  String mapPositionPending(String number) {
    return 'Mapa. Posição do ônibus $number ainda não disponível';
  }

  @override
  String get mapNoBus => 'Mapa de Goiânia. Nenhum ônibus acompanhado';

  @override
  String mapOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mais $count ônibus em tempo real a caminho do ponto',
      one: 'Mais 1 ônibus em tempo real a caminho do ponto',
    );
    return '$_temp0';
  }

  @override
  String favoriteStopAdd(String code) {
    return 'Favoritar o ponto $code';
  }

  @override
  String favoriteStopRemove(String code) {
    return 'Remover o ponto $code dos favoritos';
  }

  @override
  String favoriteStopsLimit(int limit) {
    return 'Limite de $limit favoritos. Remova um para adicionar outro.';
  }

  @override
  String favoriteLinesLimit(int limit) {
    return 'Limite de $limit linhas favoritas. Remova uma para adicionar outra.';
  }

  @override
  String favoriteLineAdd(String route) {
    return 'Favoritar a linha $route neste ponto';
  }

  @override
  String favoriteLineRemove(String route, String stop) {
    return 'Remover a linha $route do ponto $stop dos favoritos';
  }

  @override
  String get favoriteLineOn => 'Linha favorita';

  @override
  String get favoriteLineOff => 'Favoritar esta linha';

  @override
  String get storageNotPersistent =>
      'Este aparelho não guardou os pontos. Eles valem só até fechar o app.';

  @override
  String get storageReadFailed =>
      'Não foi possível ler os pontos salvos. Começamos com a lista vazia.';

  @override
  String get storageWriteFailed =>
      'Não foi possível salvar agora. A lista vale até fechar o app.';

  @override
  String stopOpenArrivals(String code) {
    return 'Consultar as chegadas do ponto $code';
  }

  @override
  String stopOpenArrivalsNamed(String code, String name) {
    return 'Consultar as chegadas do ponto $code, $name';
  }

  @override
  String lineOpenArrivals(String route, String stop) {
    return 'Consultar as chegadas da linha $route no ponto $stop';
  }

  @override
  String get offlineHint =>
      'Toque num ponto para consultar as chegadas. A consulta precisa de internet e nenhuma previsão fica salva no aparelho.';

  @override
  String get favoritesEmptyTitle => 'Seus pontos favoritos aparecerão aqui.';

  @override
  String get favoritesEmptyBody =>
      'Consulte um ponto e toque na estrela do cabeçalho para favoritá-lo.';

  @override
  String get favoriteStopsSection => 'Pontos favoritos';

  @override
  String get favoriteLinesSection => 'Linhas favoritas';

  @override
  String get clearRecentsTitle => 'Limpar recentes?';

  @override
  String get clearRecentsBody =>
      'O histórico de pontos consultados neste aparelho será apagado. Seus favoritos não mudam.';

  @override
  String get recentsSection => 'Recentes';

  @override
  String get recentsEmpty => 'Os pontos que você consultar aparecerão aqui.';

  @override
  String recentStopRemove(String code) {
    return 'Remover o ponto $code dos recentes';
  }

  @override
  String get loadingSavedStops => 'Carregando pontos salvos';

  @override
  String get favoriteStatusLoading => 'Consultando…';

  @override
  String get favoriteStatusOffline =>
      'Sem conexão. Toque em Atualizar quando a internet voltar.';

  @override
  String get favoriteStatusFailed => 'Não foi possível consultar agora.';

  @override
  String get lastValidData => 'Último dado válido da fonte';

  @override
  String lastValidDataAt(String hour) {
    return 'Último dado válido da fonte · consulta das $hour';
  }

  @override
  String get queriedNow => 'Consulta feita agora';

  @override
  String queriedAtHour(String hour) {
    return 'Consulta das $hour';
  }

  @override
  String lineSemantics(String route, String minutes, String quality) {
    return 'Linha $route, $minutes, $quality';
  }

  @override
  String get linesSoonTitle => 'As linhas estarão disponíveis em breve.';

  @override
  String get linesSoonBody =>
      'Por enquanto, consulte as chegadas pelo código do ponto.';

  @override
  String get seenLinesSection => 'Linhas vistas';

  @override
  String get seenLinesNote =>
      'Linhas vistas nas suas consultas desta sessão e nos seus favoritos. A lista completa de linhas depende de autorização da RMTC.';

  @override
  String seenAtStop(String stop) {
    return 'no ponto $stop';
  }

  @override
  String seenAtStops(String stops) {
    return 'nos pontos $stops';
  }

  @override
  String seenAtStopsMore(String stops, int more) {
    return 'nos pontos $stops e mais $more';
  }

  @override
  String seenLineSemantics(String route, String label, String stop) {
    return 'Linha $route, $label. Consultar as chegadas do ponto $stop';
  }

  @override
  String get noticeOffline =>
      'Sem conexão. Você pode abrir seus pontos, mas as chegadas só aparecem com internet.';

  @override
  String get noticeQueryIncomplete =>
      'A última consulta não foi concluída. Tente de novo em instantes.';

  @override
  String get settingsAppearance => 'Aparência';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeBody => 'O mapa acompanha o tema escolhido.';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeNight => 'Noturno';

  @override
  String get themeLight => 'Claro';

  @override
  String get settingsAbout => 'Sobre';

  @override
  String get settingsBusData => 'Dados de ônibus';

  @override
  String get settingsBusDataBody =>
      'RMTC, via API BusãoGyn. Posições e previsões em tempo real dependem do GPS informado pela fonte.';

  @override
  String get settingsMap => 'Mapa';

  @override
  String get settingsMapBody =>
      'OpenFreeMap · © OpenMapTiles · dados © OpenStreetMap';

  @override
  String get settingsTypography => 'Tipografia';

  @override
  String get settingsTypographyBody =>
      'Geist e Geist Mono · SIL Open Font License 1.1';

  @override
  String get settingsLicenses => 'Licenças';

  @override
  String get settingsLicensesBody => 'Bibliotecas e fontes usadas pelo app.';
}
