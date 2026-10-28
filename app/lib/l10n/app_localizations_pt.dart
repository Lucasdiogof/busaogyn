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
      zero: '0 linhas',
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
      zero: '0 pontos salvos',
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
      zero: '0 minutos',
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
      zero: 'Mais 0 ônibus em tempo real a caminho do ponto',
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

  @override
  String get catalogSearchHint => 'Código, rua, bairro ou cidade';

  @override
  String get catalogResultsTitle => 'Pontos no cadastro';

  @override
  String catalogResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pontos',
      one: '1 ponto',
      zero: 'Nenhum ponto',
    );
    return '$_temp0';
  }

  @override
  String catalogResultsMore(int shown, int total) {
    return 'Mostrando $shown de $total. Refine a busca para ver outros.';
  }

  @override
  String get catalogNoResultsTitle => 'Nenhum ponto encontrado';

  @override
  String get catalogNoResultsBody =>
      'Confira a grafia ou use o código impresso no ponto.';

  @override
  String get catalogSearchCodeHint =>
      'Toque em um ponto para ver o endereço e as linhas, ou envie o código para consultar as chegadas.';

  @override
  String catalogOpenStop(String code, String place) {
    return 'Ponto $code, $place. Ver detalhes';
  }

  @override
  String get catalogStopNotFound =>
      'Este código não está no cadastro oficial. A consulta de chegadas pode funcionar mesmo assim.';

  @override
  String get catalogStopLinesTitle => 'Linhas que atendem este ponto';

  @override
  String get catalogStopLinesNote =>
      'Cadastro oficial: mostra as linhas do ponto, não ônibus a caminho. Chegadas em tempo real ou programadas aparecem na consulta de chegadas.';

  @override
  String get catalogNoLinesListed =>
      'Nenhuma linha associada a este ponto no cadastro.';

  @override
  String get catalogSeeArrivals => 'Ver chegadas';

  @override
  String catalogSourceNote(String reference) {
    return 'Cadastro oficial CMTC · referência $reference · disponível offline';
  }

  @override
  String get catalogDevBadge => 'Dados de desenvolvimento, não publicados';

  @override
  String get catalogStation => 'Estação sem endereço no cadastro';

  @override
  String catalogStopTitle(String code) {
    return 'Ponto $code';
  }

  @override
  String get catalogPreviewClose => 'Voltar à busca';

  @override
  String get catalogAddress => 'Endereço';

  @override
  String get catalogDistrict => 'Bairro';

  @override
  String get catalogCity => 'Município';

  @override
  String catalogLinesHeaderSubtitle(int count) {
    return '$count linhas no cadastro oficial';
  }

  @override
  String get catalogLinesSearchHint => 'Número ou nome da linha';

  @override
  String get catalogLinesNoResults => 'Nenhuma linha encontrada.';

  @override
  String get catalogLinesAllTitle => 'Linhas';

  @override
  String get catalogShowMore => 'Mostrar mais';

  @override
  String get catalogLineVariants => 'Variantes';

  @override
  String catalogLineStops(int count) {
    return 'Pontos cadastrados ($count)';
  }

  @override
  String get catalogLineStopsNote =>
      'Pontos associados à linha no cadastro, sem ordem de percurso nem sentido.';

  @override
  String get catalogLineStatus => 'Situação';

  @override
  String get catalogLineType => 'Tipo';

  @override
  String get catalogLineCities => 'Municípios';

  @override
  String get catalogLineOrigin => 'Origem';

  @override
  String get catalogLineDestination => 'Destino';

  @override
  String catalogValidFrom(String date) {
    return 'Vigência desde $date';
  }

  @override
  String get catalogBackToLines => 'Voltar às linhas';

  @override
  String catalogOpenLine(String line, String name) {
    return 'Linha $line, $name. Ver detalhes';
  }

  @override
  String get catalogLineNotFound => 'Linha não encontrada no cadastro.';

  @override
  String catalogVariantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count variantes',
      one: '1 variante',
      zero: 'Sem variantes',
    );
    return '$_temp0';
  }

  @override
  String get settingsCatalog => 'Catálogo oficial (desenvolvimento)';

  @override
  String settingsCatalogBody(String license, String reference, String version) {
    return 'Versão $version · referência $reference · redistribuição: $license. Ligado só neste build de desenvolvimento.';
  }

  @override
  String get catalogIntroTitle => 'Busque um ponto';

  @override
  String get catalogIntroBody =>
      'Pelo código da placa, pela rua, pelo bairro ou pela cidade. Depois veja as próximas chegadas e acompanhe o ônibus no mapa.';

  @override
  String get catalogDirectionOutbound => 'Ida';

  @override
  String get catalogDirectionInbound => 'Volta';

  @override
  String get catalogDirectionUnknown => 'Trajeto';

  @override
  String catalogRouteOnMap(String direction, String variant) {
    return 'No mapa: $variant · $direction';
  }

  @override
  String get catalogClearRoute => 'Limpar trajeto';

  @override
  String get catalogShowRouteHint =>
      'Toque em Ida ou Volta para ver o trajeto oficial no mapa.';

  @override
  String get catalogRouteLegend =>
      'Ida: âmbar contínua · Volta: tracejada · Outros trajetos da linha: cinza · Anéis: pontos cadastrados da linha, sem ordem de parada.';

  @override
  String get catalogKmzOnlyShapes => 'Trajetos do KMZ sem variante no cadastro';

  @override
  String catalogShowRouteSemantics(String direction, String variant) {
    return 'Mostrar no mapa o trajeto $variant, $direction';
  }

  @override
  String get catalogMapHint =>
      'Toque num ponto do mapa para ver endereço e linhas.';

  @override
  String get trackMatchTitle => 'Trajeto oficial (experimental)';

  @override
  String trackMatchConfirmed(String direction, String variant) {
    return 'Associado a $variant · $direction. No mapa, o percurso oficial aparece em cinza e o trecho à frente, estimado, em âmbar tracejado. Sem previsão de horário.';
  }

  @override
  String trackMatchPending(String variant) {
    return 'Variante $variant identificada. Aguardando o ônibus andar para confirmar o sentido; nenhum trajeto é desenhado ainda.';
  }

  @override
  String trackMatchAmbiguous(String reason) {
    return 'Sem associação segura a um trajeto oficial: $reason. O mapa mostra só a posição e o rastro observado.';
  }

  @override
  String get trackMatchNoShapes =>
      'Esta linha não tem trajeto oficial no catálogo.';

  @override
  String get trackMatchNoPosition =>
      'Sem posição atual do ônibus: nenhum trajeto é desenhado.';

  @override
  String get trackReasonRouteNameMissing => 'a fonte não informou o itinerário';

  @override
  String get trackReasonRouteNameNoMatch =>
      'o itinerário informado não está no cadastro';

  @override
  String get trackReasonRouteNameSeveral =>
      'mais de uma variante tem esse itinerário';

  @override
  String get trackReasonDirectionUnknown => 'o destino não indica o sentido';

  @override
  String get trackReasonShapeMissing =>
      'não há trajeto oficial único para esse sentido';

  @override
  String get trackReasonOffRoute => 'o ônibus está fora do trajeto cadastrado';

  @override
  String get trackReasonMovingBackwards =>
      'o deslocamento observado contraria o trajeto';

  @override
  String get scheduleTitle => 'Horários programados';

  @override
  String get scheduleDayWeekday => 'Dias úteis';

  @override
  String get scheduleDaySaturday => 'Sábado';

  @override
  String get scheduleDaySunday => 'Domingo e feriado';

  @override
  String get scheduleAllCodes => 'Todas';

  @override
  String get scheduleNone => 'Sem quadro de horários para esta linha.';

  @override
  String get scheduleInsufficient =>
      'Quadro indisponível: dados inconsistentes ou insuficientes na planilha.';

  @override
  String scheduleRecent(String date) {
    return 'Referência de $date · vigência não confirmada pela CMTC. Confira antes de sair.';
  }

  @override
  String scheduleConfirmed(String date) {
    return 'Vigência confirmada · referência de $date.';
  }

  @override
  String scheduleOld(String date) {
    return 'Quadro de referência antiga ($date). Pode não estar mais em vigor.';
  }

  @override
  String get scheduleShowOld => 'Ver mesmo assim';

  @override
  String scheduleSource(String oso, String source) {
    return 'Planilha: $source · OSO $oso';
  }

  @override
  String get scheduleDepartureNote =>
      'Horários de partida, não de passagem nos pontos. A planilha não informa sentido nem local de partida. Não são previsões em tempo real.';

  @override
  String get scheduleEmptyDay => 'Sem partidas programadas neste dia.';

  @override
  String scheduleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partidas',
      one: '1 partida',
      zero: 'Nenhuma partida',
    );
    return '$_temp0';
  }

  @override
  String get scheduleLegendNextDay => '+1: depois da meia-noite';

  @override
  String get scheduleLegendHalf =>
      'MI: meia viagem, início no retorno · MF: meia viagem, fim no retorno';

  @override
  String get scheduleLegendRepeated => '×2: repetido na planilha';

  @override
  String scheduleCodeUnregistered(String code) {
    return '$code (sem cadastro)';
  }

  @override
  String sequenceTitle(int count, String direction) {
    return 'Paradas estimadas · $direction ($count)';
  }

  @override
  String get sequenceEstimatedNote =>
      'Ordem estimada pelo trajeto oficial. Não é a sequência oficial da CMTC.';

  @override
  String get sequenceUncertain => 'posição incerta';

  @override
  String get sequenceRepeated => 'passa de novo';

  @override
  String sequencePartialTitle(int count) {
    return 'Pontos perto deste trajeto ($count)';
  }

  @override
  String get sequencePartialNote =>
      'Sem confiança suficiente para ordenar as paradas: lista sem ordem de percurso.';

  @override
  String get sequenceNone =>
      'Nenhum ponto do cadastro associado a este trajeto.';

  @override
  String sequenceAmbiguous(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pontos ficaram de fora por ambiguidade.',
      one: '1 ponto ficou de fora por ambiguidade.',
      zero: 'Nenhum ponto ficou de fora por ambiguidade.',
    );
    return '$_temp0';
  }

  @override
  String sequenceShowAll(int count) {
    return 'Mostrar todas ($count)';
  }

  @override
  String get itineraryTitle => 'No itinerário (estimado)';

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
      'Posição estimada pelo trajeto oficial; sem horário de passagem.';

  @override
  String get nextStopsTitle => 'Próximos pontos (estimado)';

  @override
  String get nextStopLabel => 'Próximo';

  @override
  String get nextStopsUncertain =>
      'Próximo ponto incerto: lista em ordem estimada.';

  @override
  String nextStopsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pontos até o fim do trajeto',
      one: '1 ponto até o fim do trajeto',
      zero: 'Nenhum ponto até o fim do trajeto',
    );
    return '$_temp0';
  }

  @override
  String get nextStopsNote =>
      'Pelo trajeto oficial e a posição real. Sem previsão de chegada por ponto.';

  @override
  String get nextStopsUnreliable =>
      'Sem sequência confiável de paradas para este trajeto: só o acompanhamento no mapa.';

  @override
  String get nextStopsEnd => 'Ônibus no fim do trajeto.';

  @override
  String get trackReasonGpsJump => 'a posição saltou ao longo do trajeto';

  @override
  String get trackReasonRepeatedSection =>
      'o trajeto passa duas vezes por este trecho';

  @override
  String get plannerOpen => 'Planejar viagem';

  @override
  String get plannerTitle => 'Planejar viagem';

  @override
  String get plannerIntro =>
      'De ponto a ponto, com até uma baldeação. Funciona sem internet: usa só o catálogo do aparelho.';

  @override
  String get plannerOrigin => 'Origem';

  @override
  String get plannerDestination => 'Destino';

  @override
  String get plannerSearchHint => 'Código, rua, bairro ou cidade';

  @override
  String get plannerPickOnMap => 'Escolher no mapa';

  @override
  String plannerPicking(String field) {
    return 'Toque num ponto no mapa para definir: $field.';
  }

  @override
  String get plannerSwap => 'Inverter origem e destino';

  @override
  String get plannerSearch => 'Buscar viagens';

  @override
  String get plannerClose => 'Fechar planejador';

  @override
  String get plannerNotCovered => 'fora do planejador';

  @override
  String get plannerNoResultTitle => 'Nenhuma viagem para mostrar';

  @override
  String get plannerSameStop => 'Origem e destino são o mesmo ponto.';

  @override
  String get plannerUnknownStop => 'Ponto não encontrado no catálogo.';

  @override
  String get plannerNoCoverageOrigin =>
      'A origem ainda não está em nenhum trajeto com ordem de paradas confiável. Tente um ponto próximo.';

  @override
  String get plannerNoCoverageDestination =>
      'O destino ainda não está em nenhum trajeto com ordem de paradas confiável. Tente um ponto próximo.';

  @override
  String get plannerNoRoute =>
      'Não há viagem com evidência suficiente com até uma baldeação. Isso não quer dizer que não exista ônibus: só que não dá para afirmar com os dados atuais.';

  @override
  String get plannerTruncated =>
      'A busca parou no limite de processamento; pode haver outras opções.';

  @override
  String plannerResultsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alternativas',
      one: '1 alternativa',
      zero: 'Nenhuma alternativa',
    );
    return '$_temp0';
  }

  @override
  String get plannerReliable => 'Confiável';

  @override
  String get plannerEstimated => 'Estimada';

  @override
  String plannerBuses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ônibus',
      one: '1 ônibus',
      zero: 'Nenhum ônibus',
    );
    return '$_temp0';
  }

  @override
  String get plannerDirect => 'direto';

  @override
  String plannerTransfers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count baldeações',
      one: '1 baldeação',
      zero: 'sem baldeação',
    );
    return '$_temp0';
  }

  @override
  String get plannerBoard => 'Embarque';

  @override
  String get plannerTransfer => 'Baldeação';

  @override
  String get plannerAlight => 'Desembarque';

  @override
  String plannerLeg(String direction, String km, int stops, String variant) {
    return '$variant · $direction · $stops paradas · $km km pelo trajeto';
  }

  @override
  String plannerWalk(int meters) {
    return 'a pé, ~$meters m em linha reta';
  }

  @override
  String get plannerShowOnMap => 'Ver no mapa';

  @override
  String get plannerOnMap => 'No mapa';

  @override
  String get plannerNoTimes =>
      'Sem tempo de viagem nem horário: os quadros não têm vigência confirmada. A ordem das paradas é estimada pelo trajeto oficial; o km é medido nele.';

  @override
  String get plannerCautionOrder =>
      'Ordem das paradas não conferida com os logradouros oficiais.';

  @override
  String get plannerCautionUncertain =>
      'Posição incerta de um ponto de embarque ou desembarque.';

  @override
  String get plannerCautionRepeated =>
      'O ônibus passa mais de uma vez por um dos pontos.';

  @override
  String get plannerCautionWalk =>
      'Baldeação a pé: travessia, calçada e acessibilidade não verificadas.';
}
