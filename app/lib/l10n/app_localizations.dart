import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt'),
  ];

  /// No description provided for @dockLines.
  ///
  /// In pt, this message translates to:
  /// **'Linhas'**
  String get dockLines;

  /// No description provided for @dockStops.
  ///
  /// In pt, this message translates to:
  /// **'Pontos'**
  String get dockStops;

  /// No description provided for @dockFavorites.
  ///
  /// In pt, this message translates to:
  /// **'Favoritos'**
  String get dockFavorites;

  /// No description provided for @dockTracking.
  ///
  /// In pt, this message translates to:
  /// **'Meu ônibus'**
  String get dockTracking;

  /// No description provided for @dockTrackedBadge.
  ///
  /// In pt, this message translates to:
  /// **'{label}, ônibus acompanhado'**
  String dockTrackedBadge(String label);

  /// No description provided for @settings.
  ///
  /// In pt, this message translates to:
  /// **'Ajustes'**
  String get settings;

  /// No description provided for @settingsSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Aparência e sobre'**
  String get settingsSubtitle;

  /// No description provided for @settingsClose.
  ///
  /// In pt, this message translates to:
  /// **'Fechar ajustes'**
  String get settingsClose;

  /// No description provided for @comingSoon.
  ///
  /// In pt, this message translates to:
  /// **'Em breve'**
  String get comingSoon;

  /// No description provided for @loading.
  ///
  /// In pt, this message translates to:
  /// **'Carregando…'**
  String get loading;

  /// No description provided for @refresh.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar'**
  String get refresh;

  /// No description provided for @refreshing.
  ///
  /// In pt, this message translates to:
  /// **'atualizando…'**
  String get refreshing;

  /// No description provided for @refreshArrivals.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar chegadas'**
  String get refreshArrivals;

  /// No description provided for @retry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar de novo'**
  String get retry;

  /// No description provided for @retryStop.
  ///
  /// In pt, this message translates to:
  /// **'Tentar o ponto {code}'**
  String retryStop(String code);

  /// No description provided for @cancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @clear.
  ///
  /// In pt, this message translates to:
  /// **'Limpar'**
  String get clear;

  /// No description provided for @close.
  ///
  /// In pt, this message translates to:
  /// **'Fechar'**
  String get close;

  /// No description provided for @view.
  ///
  /// In pt, this message translates to:
  /// **'Ver'**
  String get view;

  /// No description provided for @viewArrivals.
  ///
  /// In pt, this message translates to:
  /// **'Ver chegadas'**
  String get viewArrivals;

  /// No description provided for @search.
  ///
  /// In pt, this message translates to:
  /// **'Buscar'**
  String get search;

  /// No description provided for @searchStopAction.
  ///
  /// In pt, this message translates to:
  /// **'Buscar um ponto'**
  String get searchStopAction;

  /// No description provided for @searchAnotherStop.
  ///
  /// In pt, this message translates to:
  /// **'Buscar outro ponto'**
  String get searchAnotherStop;

  /// No description provided for @searchHint.
  ///
  /// In pt, this message translates to:
  /// **'Código do ponto, ex.: 30402'**
  String get searchHint;

  /// No description provided for @clearCode.
  ///
  /// In pt, this message translates to:
  /// **'Limpar código'**
  String get clearCode;

  /// No description provided for @backToStop.
  ///
  /// In pt, this message translates to:
  /// **'Voltar ao ponto'**
  String get backToStop;

  /// No description provided for @stopWord.
  ///
  /// In pt, this message translates to:
  /// **'Ponto'**
  String get stopWord;

  /// No description provided for @atStopWord.
  ///
  /// In pt, this message translates to:
  /// **'no ponto'**
  String get atStopWord;

  /// No description provided for @now.
  ///
  /// In pt, this message translates to:
  /// **'agora'**
  String get now;

  /// No description provided for @ago.
  ///
  /// In pt, this message translates to:
  /// **'há {age}'**
  String ago(String age);

  /// No description provided for @panelHandleLabel.
  ///
  /// In pt, this message translates to:
  /// **'Painel. Arraste para expandir ou recolher'**
  String get panelHandleLabel;

  /// No description provided for @routeNumber.
  ///
  /// In pt, this message translates to:
  /// **'Linha {route}'**
  String routeNumber(String route);

  /// No description provided for @routeNotProvided.
  ///
  /// In pt, this message translates to:
  /// **'Linha não informada'**
  String get routeNotProvided;

  /// No description provided for @busNumber.
  ///
  /// In pt, this message translates to:
  /// **'Ônibus {number}'**
  String busNumber(String number);

  /// No description provided for @linesCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{0 linhas} =1{1 linha} other{{count} linhas}}'**
  String linesCount(int count);

  /// No description provided for @savedStopsNone.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum ponto salvo'**
  String get savedStopsNone;

  /// No description provided for @savedStopsCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{0 pontos salvos} =1{1 ponto salvo} other{{count} pontos salvos}}'**
  String savedStopsCount(int count);

  /// No description provided for @queryingArrivals.
  ///
  /// In pt, this message translates to:
  /// **'consultando chegadas…'**
  String get queryingArrivals;

  /// No description provided for @queryingArrivalsSemantics.
  ///
  /// In pt, this message translates to:
  /// **'Consultando chegadas'**
  String get queryingArrivalsSemantics;

  /// No description provided for @queryingStop.
  ///
  /// In pt, this message translates to:
  /// **'Consultando o ponto {stop}'**
  String queryingStop(String stop);

  /// No description provided for @qualityRealtime.
  ///
  /// In pt, this message translates to:
  /// **'Tempo real'**
  String get qualityRealtime;

  /// No description provided for @qualityScheduled.
  ///
  /// In pt, this message translates to:
  /// **'Programado'**
  String get qualityScheduled;

  /// No description provided for @qualityUnknownLong.
  ///
  /// In pt, this message translates to:
  /// **'Informação não confirmada'**
  String get qualityUnknownLong;

  /// No description provided for @qualityUnknownShort.
  ///
  /// In pt, this message translates to:
  /// **'Não confirmado'**
  String get qualityUnknownShort;

  /// No description provided for @minutesUnknown.
  ///
  /// In pt, this message translates to:
  /// **'tempo não informado'**
  String get minutesUnknown;

  /// No description provided for @minutesLessThanOne.
  ///
  /// In pt, this message translates to:
  /// **'< 1 min'**
  String get minutesLessThanOne;

  /// No description provided for @minutesLessThanOneLong.
  ///
  /// In pt, this message translates to:
  /// **'menos de 1 minuto'**
  String get minutesLessThanOneLong;

  /// No description provided for @minutesShort.
  ///
  /// In pt, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @minutesLong.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{0 minutos} =1{1 minuto} other{{count} minutos}}'**
  String minutesLong(int count);

  /// No description provided for @punctualityOnTime.
  ///
  /// In pt, this message translates to:
  /// **'No horário'**
  String get punctualityOnTime;

  /// No description provided for @punctualityDelayed.
  ///
  /// In pt, this message translates to:
  /// **'Atrasado'**
  String get punctualityDelayed;

  /// No description provided for @punctualityEarly.
  ///
  /// In pt, this message translates to:
  /// **'Adiantado'**
  String get punctualityEarly;

  /// No description provided for @punctualityUnknown.
  ///
  /// In pt, this message translates to:
  /// **'Pontualidade não informada'**
  String get punctualityUnknown;

  /// No description provided for @accessible.
  ///
  /// In pt, this message translates to:
  /// **'Acessível'**
  String get accessible;

  /// No description provided for @accessibilityNotIndicated.
  ///
  /// In pt, this message translates to:
  /// **'Acessibilidade não indicada'**
  String get accessibilityNotIndicated;

  /// No description provided for @accessibilityUnknown.
  ///
  /// In pt, this message translates to:
  /// **'Acessibilidade não informada'**
  String get accessibilityUnknown;

  /// No description provided for @destinationUnknown.
  ///
  /// In pt, this message translates to:
  /// **'Destino não informado'**
  String get destinationUnknown;

  /// No description provided for @headingTo.
  ///
  /// In pt, this message translates to:
  /// **'Indo para {destination}'**
  String headingTo(String destination);

  /// No description provided for @positionSearching.
  ///
  /// In pt, this message translates to:
  /// **'Buscando posição do ônibus'**
  String get positionSearching;

  /// No description provided for @positionConnection.
  ///
  /// In pt, this message translates to:
  /// **'Conexão instável'**
  String get positionConnection;

  /// No description provided for @positionUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Posição temporariamente indisponível'**
  String get positionUnavailable;

  /// No description provided for @positionOutdated.
  ///
  /// In pt, this message translates to:
  /// **'Posição desatualizada · há {age}'**
  String positionOutdated(String age);

  /// No description provided for @positionLive.
  ///
  /// In pt, this message translates to:
  /// **'Ao vivo · há {age}'**
  String positionLive(String age);

  /// No description provided for @positionLast.
  ///
  /// In pt, this message translates to:
  /// **'Última posição há {age}'**
  String positionLast(String age);

  /// No description provided for @positionAgeShort.
  ///
  /// In pt, this message translates to:
  /// **'posição há {age}'**
  String positionAgeShort(String age);

  /// No description provided for @positionMaybeOutdated.
  ///
  /// In pt, this message translates to:
  /// **'Posição possivelmente desatualizada'**
  String get positionMaybeOutdated;

  /// No description provided for @freshnessStale.
  ///
  /// In pt, this message translates to:
  /// **'Dados temporariamente desatualizados · há {age}'**
  String freshnessStale(String age);

  /// No description provided for @freshnessNow.
  ///
  /// In pt, this message translates to:
  /// **'Atualizado agora'**
  String get freshnessNow;

  /// No description provided for @freshnessAge.
  ///
  /// In pt, this message translates to:
  /// **'Atualizado há {age}'**
  String freshnessAge(String age);

  /// No description provided for @liveSearchingLabel.
  ///
  /// In pt, this message translates to:
  /// **'Buscando'**
  String get liveSearchingLabel;

  /// No description provided for @liveSearchingDetail.
  ///
  /// In pt, this message translates to:
  /// **'posição'**
  String get liveSearchingDetail;

  /// No description provided for @liveConnectionLabel.
  ///
  /// In pt, this message translates to:
  /// **'Conexão'**
  String get liveConnectionLabel;

  /// No description provided for @liveConnectionDetail.
  ///
  /// In pt, this message translates to:
  /// **'instável'**
  String get liveConnectionDetail;

  /// No description provided for @liveLocatingLabel.
  ///
  /// In pt, this message translates to:
  /// **'Localizando'**
  String get liveLocatingLabel;

  /// No description provided for @liveLocatingDetail.
  ///
  /// In pt, this message translates to:
  /// **'ônibus'**
  String get liveLocatingDetail;

  /// No description provided for @liveOutdated.
  ///
  /// In pt, this message translates to:
  /// **'Desatualizado'**
  String get liveOutdated;

  /// No description provided for @liveLabel.
  ///
  /// In pt, this message translates to:
  /// **'Ao vivo'**
  String get liveLabel;

  /// No description provided for @livePosition.
  ///
  /// In pt, this message translates to:
  /// **'Posição'**
  String get livePosition;

  /// No description provided for @liveNoEstimate.
  ///
  /// In pt, this message translates to:
  /// **'Sem previsão'**
  String get liveNoEstimate;

  /// No description provided for @liveNoGps.
  ///
  /// In pt, this message translates to:
  /// **'sem GPS'**
  String get liveNoGps;

  /// No description provided for @liveEstimate.
  ///
  /// In pt, this message translates to:
  /// **'Previsão'**
  String get liveEstimate;

  /// No description provided for @errFormat.
  ///
  /// In pt, this message translates to:
  /// **'O BusãoGyn recebeu dados em formato inesperado. Tente novamente.'**
  String get errFormat;

  /// No description provided for @errArrivalsGeneric.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível consultar este ponto agora.'**
  String get errArrivalsGeneric;

  /// No description provided for @errPositionGeneric.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível localizar este ônibus agora.'**
  String get errPositionGeneric;

  /// No description provided for @errTimeout.
  ///
  /// In pt, this message translates to:
  /// **'A consulta demorou mais que o esperado. Tente novamente.'**
  String get errTimeout;

  /// No description provided for @errNetwork.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão com o BusãoGyn. Verifique sua internet.'**
  String get errNetwork;

  /// No description provided for @errSourceTimeout.
  ///
  /// In pt, this message translates to:
  /// **'A RMTC demorou para responder. Tente novamente em instantes.'**
  String get errSourceTimeout;

  /// No description provided for @errSourceUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'A fonte de dados da RMTC está indisponível agora. Tente novamente em instantes.'**
  String get errSourceUnavailable;

  /// No description provided for @errSourceInvalidArrivals.
  ///
  /// In pt, this message translates to:
  /// **'A RMTC não retornou dados válidos para este ponto. Confira o código ou tente novamente.'**
  String get errSourceInvalidArrivals;

  /// No description provided for @errSourceInvalidPosition.
  ///
  /// In pt, this message translates to:
  /// **'A RMTC não retornou dados válidos para este ônibus agora.'**
  String get errSourceInvalidPosition;

  /// No description provided for @errInvalidStop.
  ///
  /// In pt, this message translates to:
  /// **'Código de ponto inválido. Use apenas números.'**
  String get errInvalidStop;

  /// No description provided for @errInvalidVehicle.
  ///
  /// In pt, this message translates to:
  /// **'Este ônibus não tem um número válido para acompanhamento.'**
  String get errInvalidVehicle;

  /// No description provided for @errInvalidResponse.
  ///
  /// In pt, this message translates to:
  /// **'O BusãoGyn recebeu uma resposta inesperada. Tente novamente.'**
  String get errInvalidResponse;

  /// No description provided for @errRetryable.
  ///
  /// In pt, this message translates to:
  /// **'O serviço está instável agora. Tente novamente em instantes.'**
  String get errRetryable;

  /// No description provided for @errGeneric.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível concluir a consulta.'**
  String get errGeneric;

  /// No description provided for @errPositionNotReported.
  ///
  /// In pt, this message translates to:
  /// **'A fonte não informou a posição deste ônibus agora.'**
  String get errPositionNotReported;

  /// No description provided for @errPositionUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Posição temporariamente indisponível.'**
  String get errPositionUnavailable;

  /// No description provided for @searchInvalidTitle.
  ///
  /// In pt, this message translates to:
  /// **'Digite o código do ponto'**
  String get searchInvalidTitle;

  /// No description provided for @searchInvalidBody.
  ///
  /// In pt, this message translates to:
  /// **'Use só os números da placa do ponto.'**
  String get searchInvalidBody;

  /// No description provided for @searchNotFoundTitle.
  ///
  /// In pt, this message translates to:
  /// **'Ponto não encontrado'**
  String get searchNotFoundTitle;

  /// No description provided for @searchNotFoundBody.
  ///
  /// In pt, this message translates to:
  /// **'Confira o código e tente novamente.'**
  String get searchNotFoundBody;

  /// No description provided for @searchTimeoutTitle.
  ///
  /// In pt, this message translates to:
  /// **'A consulta demorou demais'**
  String get searchTimeoutTitle;

  /// No description provided for @searchTimeoutBody.
  ///
  /// In pt, this message translates to:
  /// **'Tente novamente em instantes.'**
  String get searchTimeoutBody;

  /// No description provided for @searchOfflineTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão'**
  String get searchOfflineTitle;

  /// No description provided for @searchOfflineBody.
  ///
  /// In pt, this message translates to:
  /// **'Verifique sua internet e tente de novo.'**
  String get searchOfflineBody;

  /// No description provided for @searchUnavailableTitle.
  ///
  /// In pt, this message translates to:
  /// **'Serviço temporariamente indisponível'**
  String get searchUnavailableTitle;

  /// No description provided for @searchUnavailableBody.
  ///
  /// In pt, this message translates to:
  /// **'Tente novamente em alguns minutos.'**
  String get searchUnavailableBody;

  /// No description provided for @nextBuses.
  ///
  /// In pt, this message translates to:
  /// **'Próximos ônibus'**
  String get nextBuses;

  /// No description provided for @sourceUnstable.
  ///
  /// In pt, this message translates to:
  /// **'A fonte está instável. Mostrando o último dado válido.'**
  String get sourceUnstable;

  /// No description provided for @noArrivalsNow.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma chegada prevista agora'**
  String get noArrivalsNow;

  /// No description provided for @noArrivalsNowAt.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma chegada prevista agora · consulta das {hour}'**
  String noArrivalsNowAt(String hour);

  /// No description provided for @noArrivalsBody.
  ///
  /// In pt, this message translates to:
  /// **'A fonte não informou ônibus para este ponto neste momento. Tente atualizar em alguns minutos.'**
  String get noArrivalsBody;

  /// No description provided for @legendRealtime.
  ///
  /// In pt, this message translates to:
  /// **': posição informada pela RMTC, pode ser acompanhada.'**
  String get legendRealtime;

  /// No description provided for @legendScheduled.
  ///
  /// In pt, this message translates to:
  /// **': horário de tabela, sem GPS.'**
  String get legendScheduled;

  /// No description provided for @trackingBannerSemantics.
  ///
  /// In pt, this message translates to:
  /// **'Ônibus {number} sendo acompanhado. Ver em Meu ônibus'**
  String trackingBannerSemantics(String number);

  /// No description provided for @refreshFailedAt.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível atualizar agora. Mostrando a consulta das {hour}, que pode já não valer. {error}'**
  String refreshFailedAt(String hour, String error);

  /// No description provided for @refreshFailedPrevious.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível atualizar agora. Mostrando a consulta anterior, que pode já não valer. {error}'**
  String refreshFailedPrevious(String error);

  /// No description provided for @connOfflineTitle.
  ///
  /// In pt, this message translates to:
  /// **'Chegadas precisam de internet'**
  String get connOfflineTitle;

  /// No description provided for @connFailedTitle.
  ///
  /// In pt, this message translates to:
  /// **'Não conseguimos consultar as chegadas'**
  String get connFailedTitle;

  /// No description provided for @connOfflineBody.
  ///
  /// In pt, this message translates to:
  /// **'O mapa segue disponível, mas as próximas chegadas só aparecem com conexão. Nenhuma previsão antiga é mostrada como se fosse atual.'**
  String get connOfflineBody;

  /// No description provided for @connFailedBody.
  ///
  /// In pt, this message translates to:
  /// **'O código {code} não foi o problema: a consulta não foi concluída. Nenhuma previsão antiga é mostrada como se fosse atual.'**
  String connFailedBody(String code);

  /// No description provided for @connFailedBodyNoCode.
  ///
  /// In pt, this message translates to:
  /// **'O código digitado não foi o problema: a consulta não foi concluída. Nenhuma previsão antiga é mostrada como se fosse atual.'**
  String get connFailedBodyNoCode;

  /// No description provided for @introTitle.
  ///
  /// In pt, this message translates to:
  /// **'Digite o código do ponto'**
  String get introTitle;

  /// No description provided for @introBody.
  ///
  /// In pt, this message translates to:
  /// **'Você vê as próximas chegadas de cada linha e acompanha o ônibus no mapa.'**
  String get introBody;

  /// No description provided for @introNote.
  ///
  /// In pt, this message translates to:
  /// **'O código fica na placa do ponto. Só ônibus com GPS informado pela fonte podem ser acompanhados.'**
  String get introNote;

  /// No description provided for @exampleStop.
  ///
  /// In pt, this message translates to:
  /// **'Exemplo: {code}'**
  String exampleStop(String code);

  /// No description provided for @exampleStopSemantics.
  ///
  /// In pt, this message translates to:
  /// **'Consultar o ponto de exemplo {code}'**
  String exampleStopSemantics(String code);

  /// No description provided for @noFollowing.
  ///
  /// In pt, this message translates to:
  /// **'sem seguinte'**
  String get noFollowing;

  /// No description provided for @followingUpper.
  ///
  /// In pt, this message translates to:
  /// **'SEGUINTE'**
  String get followingUpper;

  /// No description provided for @nextSemantics.
  ///
  /// In pt, this message translates to:
  /// **'Próximo: {minutes}, {quality}'**
  String nextSemantics(String minutes, String quality);

  /// No description provided for @followingSemantics.
  ///
  /// In pt, this message translates to:
  /// **'Seguinte: {minutes}, {quality}, ônibus {number}'**
  String followingSemantics(String minutes, String quality, String number);

  /// No description provided for @trackingUnavailableSemantics.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhamento indisponível: chegada sem GPS da fonte'**
  String get trackingUnavailableSemantics;

  /// No description provided for @trackBus.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhar ônibus {number}'**
  String trackBus(String number);

  /// No description provided for @trackBusSearching.
  ///
  /// In pt, this message translates to:
  /// **'Buscando posição do ônibus {number}'**
  String trackBusSearching(String number);

  /// No description provided for @trackBusActive.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhando ônibus {number}'**
  String trackBusActive(String number);

  /// No description provided for @trackBusUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Ônibus {number} sem posição'**
  String trackBusUnavailable(String number);

  /// No description provided for @trackBusFailing.
  ///
  /// In pt, this message translates to:
  /// **'Reconectando ao ônibus {number}'**
  String trackBusFailing(String number);

  /// No description provided for @trackingHeaderSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhe um veículo em tempo real'**
  String get trackingHeaderSubtitle;

  /// No description provided for @trackingHeaderSemantics.
  ///
  /// In pt, this message translates to:
  /// **'Meu ônibus: ônibus {number}, {heading}'**
  String trackingHeaderSemantics(String number, String heading);

  /// No description provided for @trackingHeaderSemanticsRoute.
  ///
  /// In pt, this message translates to:
  /// **'Meu ônibus: ônibus {number}, linha {route}, {heading}'**
  String trackingHeaderSemanticsRoute(
    String number,
    String route,
    String heading,
  );

  /// No description provided for @busSemantics.
  ///
  /// In pt, this message translates to:
  /// **'Ônibus {number}, {heading}'**
  String busSemantics(String number, String heading);

  /// No description provided for @busSemanticsRoute.
  ///
  /// In pt, this message translates to:
  /// **'Ônibus {number}, linha {route}, {heading}'**
  String busSemanticsRoute(String number, String route, String heading);

  /// No description provided for @stopTracking.
  ///
  /// In pt, this message translates to:
  /// **'Parar de acompanhar'**
  String get stopTracking;

  /// No description provided for @noTrackedBusTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum ônibus acompanhado'**
  String get noTrackedBusTitle;

  /// No description provided for @noTrackedBusBody.
  ///
  /// In pt, this message translates to:
  /// **'Escolha um ônibus em tempo real nas chegadas de um ponto.'**
  String get noTrackedBusBody;

  /// No description provided for @noTrackedBusNote.
  ///
  /// In pt, this message translates to:
  /// **'Só ônibus com GPS informado pela RMTC podem ser acompanhados. Horários programados não têm posição.'**
  String get noTrackedBusNote;

  /// No description provided for @trackingSearching.
  ///
  /// In pt, this message translates to:
  /// **'Buscando posição'**
  String get trackingSearching;

  /// No description provided for @trackingFollowing.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhando'**
  String get trackingFollowing;

  /// No description provided for @stop.
  ///
  /// In pt, this message translates to:
  /// **'Parar'**
  String get stop;

  /// No description provided for @following.
  ///
  /// In pt, this message translates to:
  /// **'Seguindo'**
  String get following;

  /// No description provided for @center.
  ///
  /// In pt, this message translates to:
  /// **'Centralizar'**
  String get center;

  /// No description provided for @centerBus.
  ///
  /// In pt, this message translates to:
  /// **'Centralizar ônibus'**
  String get centerBus;

  /// No description provided for @centerBusFollowing.
  ///
  /// In pt, this message translates to:
  /// **'Centralizar ônibus. Seguindo o ônibus'**
  String get centerBusFollowing;

  /// No description provided for @centerBusPaused.
  ///
  /// In pt, this message translates to:
  /// **'Centralizar ônibus. Seguimento pausado'**
  String get centerBusPaused;

  /// No description provided for @trackThisBus.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhar este ônibus'**
  String get trackThisBus;

  /// No description provided for @trackingFootnote.
  ///
  /// In pt, this message translates to:
  /// **'Posição informada pela RMTC, consultada a cada 15 s. Direção baseada no deslocamento observado; o rastro mostra só por onde o ônibus já passou. A fonte não informa o trajeto à frente nem a ordem dos próximos pontos, então o mapa não mostra percurso futuro.'**
  String get trackingFootnote;

  /// No description provided for @noticeEtaStillAvailable.
  ///
  /// In pt, this message translates to:
  /// **'A previsão de chegada continua disponível.'**
  String get noticeEtaStillAvailable;

  /// No description provided for @noticeLocatingAgain.
  ///
  /// In pt, this message translates to:
  /// **'Tentando localizar o ônibus novamente.'**
  String get noticeLocatingAgain;

  /// No description provided for @noticeLastKnownPosition.
  ///
  /// In pt, this message translates to:
  /// **'O mapa mostra a última posição conhecida.'**
  String get noticeLastKnownPosition;

  /// No description provided for @noticeTemporaryFailure.
  ///
  /// In pt, this message translates to:
  /// **'Falha temporária ao consultar a posição.'**
  String get noticeTemporaryFailure;

  /// No description provided for @noticeRetryEvery15.
  ///
  /// In pt, this message translates to:
  /// **'Nova tentativa automática a cada 15 s.'**
  String get noticeRetryEvery15;

  /// No description provided for @busPositionSemantics.
  ///
  /// In pt, this message translates to:
  /// **'Posição do ônibus: {status}'**
  String busPositionSemantics(String status);

  /// No description provided for @busDetails.
  ///
  /// In pt, this message translates to:
  /// **'Detalhes do ônibus'**
  String get busDetails;

  /// No description provided for @busDetailsCollapseSemantics.
  ///
  /// In pt, this message translates to:
  /// **'Detalhes do ônibus. Recolher'**
  String get busDetailsCollapseSemantics;

  /// No description provided for @busDetailsExpandSemantics.
  ///
  /// In pt, this message translates to:
  /// **'Detalhes do ônibus. Expandir'**
  String get busDetailsExpandSemantics;

  /// No description provided for @detailBus.
  ///
  /// In pt, this message translates to:
  /// **'Ônibus'**
  String get detailBus;

  /// No description provided for @detailLine.
  ///
  /// In pt, this message translates to:
  /// **'Linha'**
  String get detailLine;

  /// No description provided for @detailDestination.
  ///
  /// In pt, this message translates to:
  /// **'Destino'**
  String get detailDestination;

  /// No description provided for @detailReferenceStop.
  ///
  /// In pt, this message translates to:
  /// **'Ponto de referência'**
  String get detailReferenceStop;

  /// No description provided for @detailPosition.
  ///
  /// In pt, this message translates to:
  /// **'Posição'**
  String get detailPosition;

  /// No description provided for @detailPunctuality.
  ///
  /// In pt, this message translates to:
  /// **'Pontualidade'**
  String get detailPunctuality;

  /// No description provided for @detailAccessibility.
  ///
  /// In pt, this message translates to:
  /// **'Acessibilidade'**
  String get detailAccessibility;

  /// No description provided for @detailOccupancy.
  ///
  /// In pt, this message translates to:
  /// **'Lotação'**
  String get detailOccupancy;

  /// No description provided for @detailMovement.
  ///
  /// In pt, this message translates to:
  /// **'Movimento'**
  String get detailMovement;

  /// No description provided for @notProvidedF.
  ///
  /// In pt, this message translates to:
  /// **'Não informada'**
  String get notProvidedF;

  /// No description provided for @notProvidedM.
  ///
  /// In pt, this message translates to:
  /// **'Não informado'**
  String get notProvidedM;

  /// No description provided for @notIndicatedBySource.
  ///
  /// In pt, this message translates to:
  /// **'Não indicada pela fonte'**
  String get notIndicatedBySource;

  /// No description provided for @infoUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Informação não disponível'**
  String get infoUnavailable;

  /// No description provided for @movementNotObserved.
  ///
  /// In pt, this message translates to:
  /// **'Direção ainda não observada'**
  String get movementNotObserved;

  /// No description provided for @movementObserved.
  ///
  /// In pt, this message translates to:
  /// **'A seta no mapa indica a direção observada'**
  String get movementObserved;

  /// No description provided for @trailNote.
  ///
  /// In pt, this message translates to:
  /// **'Rastro baseado nas posições observadas. Trajeto oficial ainda não disponível.'**
  String get trailNote;

  /// No description provided for @etaUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Previsão para o ponto {stop} indisponível.'**
  String etaUnavailable(String stop);

  /// No description provided for @etaToStopUnknown.
  ///
  /// In pt, this message translates to:
  /// **'previsão até o ponto {stop}'**
  String etaToStopUnknown(String stop);

  /// No description provided for @etaToStopMinutes.
  ///
  /// In pt, this message translates to:
  /// **'min até o ponto {stop}'**
  String etaToStopMinutes(String stop);

  /// No description provided for @etaFromQuery.
  ///
  /// In pt, this message translates to:
  /// **'Previsão da consulta do ponto · {freshness}'**
  String etaFromQuery(String freshness);

  /// No description provided for @mapPosition.
  ///
  /// In pt, this message translates to:
  /// **'Mapa com a posição do ônibus {number} informada pela fonte'**
  String mapPosition(String number);

  /// No description provided for @mapPositionStale.
  ///
  /// In pt, this message translates to:
  /// **'Mapa com a posição do ônibus {number} informada pela fonte, possivelmente desatualizada'**
  String mapPositionStale(String number);

  /// No description provided for @mapPositionPending.
  ///
  /// In pt, this message translates to:
  /// **'Mapa. Posição do ônibus {number} ainda não disponível'**
  String mapPositionPending(String number);

  /// No description provided for @mapNoBus.
  ///
  /// In pt, this message translates to:
  /// **'Mapa de Goiânia. Nenhum ônibus acompanhado'**
  String get mapNoBus;

  /// No description provided for @mapOthers.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Mais 0 ônibus em tempo real a caminho do ponto} =1{Mais 1 ônibus em tempo real a caminho do ponto} other{Mais {count} ônibus em tempo real a caminho do ponto}}'**
  String mapOthers(int count);

  /// No description provided for @favoriteStopAdd.
  ///
  /// In pt, this message translates to:
  /// **'Favoritar o ponto {code}'**
  String favoriteStopAdd(String code);

  /// No description provided for @favoriteStopRemove.
  ///
  /// In pt, this message translates to:
  /// **'Remover o ponto {code} dos favoritos'**
  String favoriteStopRemove(String code);

  /// No description provided for @favoriteStopsLimit.
  ///
  /// In pt, this message translates to:
  /// **'Limite de {limit} favoritos. Remova um para adicionar outro.'**
  String favoriteStopsLimit(int limit);

  /// No description provided for @favoriteLinesLimit.
  ///
  /// In pt, this message translates to:
  /// **'Limite de {limit} linhas favoritas. Remova uma para adicionar outra.'**
  String favoriteLinesLimit(int limit);

  /// No description provided for @favoriteLineAdd.
  ///
  /// In pt, this message translates to:
  /// **'Favoritar a linha {route} neste ponto'**
  String favoriteLineAdd(String route);

  /// No description provided for @favoriteLineRemove.
  ///
  /// In pt, this message translates to:
  /// **'Remover a linha {route} do ponto {stop} dos favoritos'**
  String favoriteLineRemove(String route, String stop);

  /// No description provided for @favoriteLineOn.
  ///
  /// In pt, this message translates to:
  /// **'Linha favorita'**
  String get favoriteLineOn;

  /// No description provided for @favoriteLineOff.
  ///
  /// In pt, this message translates to:
  /// **'Favoritar esta linha'**
  String get favoriteLineOff;

  /// No description provided for @storageNotPersistent.
  ///
  /// In pt, this message translates to:
  /// **'Este aparelho não guardou os pontos. Eles valem só até fechar o app.'**
  String get storageNotPersistent;

  /// No description provided for @storageReadFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível ler os pontos salvos. Começamos com a lista vazia.'**
  String get storageReadFailed;

  /// No description provided for @storageWriteFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível salvar agora. A lista vale até fechar o app.'**
  String get storageWriteFailed;

  /// No description provided for @stopOpenArrivals.
  ///
  /// In pt, this message translates to:
  /// **'Consultar as chegadas do ponto {code}'**
  String stopOpenArrivals(String code);

  /// No description provided for @stopOpenArrivalsNamed.
  ///
  /// In pt, this message translates to:
  /// **'Consultar as chegadas do ponto {code}, {name}'**
  String stopOpenArrivalsNamed(String code, String name);

  /// No description provided for @lineOpenArrivals.
  ///
  /// In pt, this message translates to:
  /// **'Consultar as chegadas da linha {route} no ponto {stop}'**
  String lineOpenArrivals(String route, String stop);

  /// No description provided for @offlineHint.
  ///
  /// In pt, this message translates to:
  /// **'Toque num ponto para consultar as chegadas. A consulta precisa de internet e nenhuma previsão fica salva no aparelho.'**
  String get offlineHint;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Seus pontos favoritos aparecerão aqui.'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoritesEmptyBody.
  ///
  /// In pt, this message translates to:
  /// **'Consulte um ponto e toque na estrela do cabeçalho para favoritá-lo.'**
  String get favoritesEmptyBody;

  /// No description provided for @favoriteStopsSection.
  ///
  /// In pt, this message translates to:
  /// **'Pontos favoritos'**
  String get favoriteStopsSection;

  /// No description provided for @favoriteLinesSection.
  ///
  /// In pt, this message translates to:
  /// **'Linhas favoritas'**
  String get favoriteLinesSection;

  /// No description provided for @clearRecentsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Limpar recentes?'**
  String get clearRecentsTitle;

  /// No description provided for @clearRecentsBody.
  ///
  /// In pt, this message translates to:
  /// **'O histórico de pontos consultados neste aparelho será apagado. Seus favoritos não mudam.'**
  String get clearRecentsBody;

  /// No description provided for @recentsSection.
  ///
  /// In pt, this message translates to:
  /// **'Recentes'**
  String get recentsSection;

  /// No description provided for @recentsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Os pontos que você consultar aparecerão aqui.'**
  String get recentsEmpty;

  /// No description provided for @recentStopRemove.
  ///
  /// In pt, this message translates to:
  /// **'Remover o ponto {code} dos recentes'**
  String recentStopRemove(String code);

  /// No description provided for @loadingSavedStops.
  ///
  /// In pt, this message translates to:
  /// **'Carregando pontos salvos'**
  String get loadingSavedStops;

  /// No description provided for @favoriteStatusLoading.
  ///
  /// In pt, this message translates to:
  /// **'Consultando…'**
  String get favoriteStatusLoading;

  /// No description provided for @favoriteStatusOffline.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão. Toque em Atualizar quando a internet voltar.'**
  String get favoriteStatusOffline;

  /// No description provided for @favoriteStatusFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível consultar agora.'**
  String get favoriteStatusFailed;

  /// No description provided for @lastValidData.
  ///
  /// In pt, this message translates to:
  /// **'Último dado válido da fonte'**
  String get lastValidData;

  /// No description provided for @lastValidDataAt.
  ///
  /// In pt, this message translates to:
  /// **'Último dado válido da fonte · consulta das {hour}'**
  String lastValidDataAt(String hour);

  /// No description provided for @queriedNow.
  ///
  /// In pt, this message translates to:
  /// **'Consulta feita agora'**
  String get queriedNow;

  /// No description provided for @queriedAtHour.
  ///
  /// In pt, this message translates to:
  /// **'Consulta das {hour}'**
  String queriedAtHour(String hour);

  /// No description provided for @lineSemantics.
  ///
  /// In pt, this message translates to:
  /// **'Linha {route}, {minutes}, {quality}'**
  String lineSemantics(String route, String minutes, String quality);

  /// No description provided for @linesSoonTitle.
  ///
  /// In pt, this message translates to:
  /// **'As linhas estarão disponíveis em breve.'**
  String get linesSoonTitle;

  /// No description provided for @linesSoonBody.
  ///
  /// In pt, this message translates to:
  /// **'Por enquanto, consulte as chegadas pelo código do ponto.'**
  String get linesSoonBody;

  /// No description provided for @seenLinesSection.
  ///
  /// In pt, this message translates to:
  /// **'Linhas vistas'**
  String get seenLinesSection;

  /// No description provided for @seenLinesNote.
  ///
  /// In pt, this message translates to:
  /// **'Linhas vistas nas suas consultas desta sessão e nos seus favoritos. A lista completa de linhas depende de autorização da RMTC.'**
  String get seenLinesNote;

  /// No description provided for @seenAtStop.
  ///
  /// In pt, this message translates to:
  /// **'no ponto {stop}'**
  String seenAtStop(String stop);

  /// No description provided for @seenAtStops.
  ///
  /// In pt, this message translates to:
  /// **'nos pontos {stops}'**
  String seenAtStops(String stops);

  /// No description provided for @seenAtStopsMore.
  ///
  /// In pt, this message translates to:
  /// **'nos pontos {stops} e mais {more}'**
  String seenAtStopsMore(String stops, int more);

  /// No description provided for @seenLineSemantics.
  ///
  /// In pt, this message translates to:
  /// **'Linha {route}, {label}. Consultar as chegadas do ponto {stop}'**
  String seenLineSemantics(String route, String label, String stop);

  /// No description provided for @noticeOffline.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão. Você pode abrir seus pontos, mas as chegadas só aparecem com internet.'**
  String get noticeOffline;

  /// No description provided for @noticeQueryIncomplete.
  ///
  /// In pt, this message translates to:
  /// **'A última consulta não foi concluída. Tente de novo em instantes.'**
  String get noticeQueryIncomplete;

  /// No description provided for @settingsAppearance.
  ///
  /// In pt, this message translates to:
  /// **'Aparência'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In pt, this message translates to:
  /// **'Tema'**
  String get settingsTheme;

  /// No description provided for @settingsThemeBody.
  ///
  /// In pt, this message translates to:
  /// **'O mapa acompanha o tema escolhido.'**
  String get settingsThemeBody;

  /// No description provided for @themeSystem.
  ///
  /// In pt, this message translates to:
  /// **'Sistema'**
  String get themeSystem;

  /// No description provided for @themeNight.
  ///
  /// In pt, this message translates to:
  /// **'Noturno'**
  String get themeNight;

  /// No description provided for @themeLight.
  ///
  /// In pt, this message translates to:
  /// **'Claro'**
  String get themeLight;

  /// No description provided for @settingsAbout.
  ///
  /// In pt, this message translates to:
  /// **'Sobre'**
  String get settingsAbout;

  /// No description provided for @settingsBusData.
  ///
  /// In pt, this message translates to:
  /// **'Dados de ônibus'**
  String get settingsBusData;

  /// No description provided for @settingsBusDataBody.
  ///
  /// In pt, this message translates to:
  /// **'RMTC, via API BusãoGyn. Posições e previsões em tempo real dependem do GPS informado pela fonte.'**
  String get settingsBusDataBody;

  /// No description provided for @settingsMap.
  ///
  /// In pt, this message translates to:
  /// **'Mapa'**
  String get settingsMap;

  /// No description provided for @settingsMapBody.
  ///
  /// In pt, this message translates to:
  /// **'OpenFreeMap · © OpenMapTiles · dados © OpenStreetMap'**
  String get settingsMapBody;

  /// No description provided for @settingsTypography.
  ///
  /// In pt, this message translates to:
  /// **'Tipografia'**
  String get settingsTypography;

  /// No description provided for @settingsTypographyBody.
  ///
  /// In pt, this message translates to:
  /// **'Geist e Geist Mono · SIL Open Font License 1.1'**
  String get settingsTypographyBody;

  /// No description provided for @settingsLicenses.
  ///
  /// In pt, this message translates to:
  /// **'Licenças'**
  String get settingsLicenses;

  /// No description provided for @settingsLicensesBody.
  ///
  /// In pt, this message translates to:
  /// **'Bibliotecas e fontes usadas pelo app.'**
  String get settingsLicensesBody;

  /// No description provided for @catalogSearchHint.
  ///
  /// In pt, this message translates to:
  /// **'Código, rua, bairro ou cidade'**
  String get catalogSearchHint;

  /// No description provided for @catalogResultsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Pontos no cadastro'**
  String get catalogResultsTitle;

  /// No description provided for @catalogResultsCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Nenhum ponto} =1{1 ponto} other{{count} pontos}}'**
  String catalogResultsCount(int count);

  /// No description provided for @catalogResultsMore.
  ///
  /// In pt, this message translates to:
  /// **'Mostrando {shown} de {total}. Refine a busca para ver outros.'**
  String catalogResultsMore(int shown, int total);

  /// No description provided for @catalogNoResultsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum ponto encontrado'**
  String get catalogNoResultsTitle;

  /// No description provided for @catalogNoResultsBody.
  ///
  /// In pt, this message translates to:
  /// **'Confira a grafia ou use o código impresso no ponto.'**
  String get catalogNoResultsBody;

  /// No description provided for @catalogSearchCodeHint.
  ///
  /// In pt, this message translates to:
  /// **'Toque em um ponto para ver o endereço e as linhas, ou envie o código para consultar as chegadas.'**
  String get catalogSearchCodeHint;

  /// No description provided for @catalogOpenStop.
  ///
  /// In pt, this message translates to:
  /// **'Ponto {code}, {place}. Ver detalhes'**
  String catalogOpenStop(String code, String place);

  /// No description provided for @catalogStopNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Este código não está no cadastro oficial. A consulta de chegadas pode funcionar mesmo assim.'**
  String get catalogStopNotFound;

  /// No description provided for @catalogStopLinesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Linhas que atendem este ponto'**
  String get catalogStopLinesTitle;

  /// No description provided for @catalogStopLinesNote.
  ///
  /// In pt, this message translates to:
  /// **'Cadastro oficial: mostra as linhas do ponto, não ônibus a caminho. Chegadas em tempo real ou programadas aparecem na consulta de chegadas.'**
  String get catalogStopLinesNote;

  /// No description provided for @catalogNoLinesListed.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma linha associada a este ponto no cadastro.'**
  String get catalogNoLinesListed;

  /// No description provided for @catalogSeeArrivals.
  ///
  /// In pt, this message translates to:
  /// **'Ver chegadas'**
  String get catalogSeeArrivals;

  /// No description provided for @catalogSourceNote.
  ///
  /// In pt, this message translates to:
  /// **'Cadastro oficial CMTC · referência {reference} · disponível offline'**
  String catalogSourceNote(String reference);

  /// No description provided for @catalogDevBadge.
  ///
  /// In pt, this message translates to:
  /// **'Dados de desenvolvimento, não publicados'**
  String get catalogDevBadge;

  /// No description provided for @catalogStation.
  ///
  /// In pt, this message translates to:
  /// **'Estação sem endereço no cadastro'**
  String get catalogStation;

  /// No description provided for @catalogStopTitle.
  ///
  /// In pt, this message translates to:
  /// **'Ponto {code}'**
  String catalogStopTitle(String code);

  /// No description provided for @catalogPreviewClose.
  ///
  /// In pt, this message translates to:
  /// **'Voltar à busca'**
  String get catalogPreviewClose;

  /// No description provided for @catalogAddress.
  ///
  /// In pt, this message translates to:
  /// **'Endereço'**
  String get catalogAddress;

  /// No description provided for @catalogDistrict.
  ///
  /// In pt, this message translates to:
  /// **'Bairro'**
  String get catalogDistrict;

  /// No description provided for @catalogCity.
  ///
  /// In pt, this message translates to:
  /// **'Município'**
  String get catalogCity;

  /// No description provided for @catalogLinesHeaderSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'{count} linhas no cadastro oficial'**
  String catalogLinesHeaderSubtitle(int count);

  /// No description provided for @catalogLinesSearchHint.
  ///
  /// In pt, this message translates to:
  /// **'Número ou nome da linha'**
  String get catalogLinesSearchHint;

  /// No description provided for @catalogLinesNoResults.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma linha encontrada.'**
  String get catalogLinesNoResults;

  /// No description provided for @catalogLinesAllTitle.
  ///
  /// In pt, this message translates to:
  /// **'Linhas'**
  String get catalogLinesAllTitle;

  /// No description provided for @catalogShowMore.
  ///
  /// In pt, this message translates to:
  /// **'Mostrar mais'**
  String get catalogShowMore;

  /// No description provided for @catalogLineVariants.
  ///
  /// In pt, this message translates to:
  /// **'Variantes'**
  String get catalogLineVariants;

  /// No description provided for @catalogLineStops.
  ///
  /// In pt, this message translates to:
  /// **'Pontos cadastrados ({count})'**
  String catalogLineStops(int count);

  /// No description provided for @catalogLineStopsNote.
  ///
  /// In pt, this message translates to:
  /// **'Pontos associados à linha no cadastro, sem ordem de percurso nem sentido.'**
  String get catalogLineStopsNote;

  /// No description provided for @catalogLineStatus.
  ///
  /// In pt, this message translates to:
  /// **'Situação'**
  String get catalogLineStatus;

  /// No description provided for @catalogLineType.
  ///
  /// In pt, this message translates to:
  /// **'Tipo'**
  String get catalogLineType;

  /// No description provided for @catalogLineCities.
  ///
  /// In pt, this message translates to:
  /// **'Municípios'**
  String get catalogLineCities;

  /// No description provided for @catalogLineOrigin.
  ///
  /// In pt, this message translates to:
  /// **'Origem'**
  String get catalogLineOrigin;

  /// No description provided for @catalogLineDestination.
  ///
  /// In pt, this message translates to:
  /// **'Destino'**
  String get catalogLineDestination;

  /// No description provided for @catalogValidFrom.
  ///
  /// In pt, this message translates to:
  /// **'Vigência desde {date}'**
  String catalogValidFrom(String date);

  /// No description provided for @catalogBackToLines.
  ///
  /// In pt, this message translates to:
  /// **'Voltar às linhas'**
  String get catalogBackToLines;

  /// No description provided for @catalogOpenLine.
  ///
  /// In pt, this message translates to:
  /// **'Linha {line}, {name}. Ver detalhes'**
  String catalogOpenLine(String line, String name);

  /// No description provided for @catalogLineNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Linha não encontrada no cadastro.'**
  String get catalogLineNotFound;

  /// No description provided for @catalogVariantCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Sem variantes} =1{1 variante} other{{count} variantes}}'**
  String catalogVariantCount(int count);

  /// No description provided for @settingsCatalog.
  ///
  /// In pt, this message translates to:
  /// **'Catálogo oficial (desenvolvimento)'**
  String get settingsCatalog;

  /// No description provided for @settingsCatalogBody.
  ///
  /// In pt, this message translates to:
  /// **'Versão {version} · referência {reference} · redistribuição: {license}. Ligado só neste build de desenvolvimento.'**
  String settingsCatalogBody(String license, String reference, String version);

  /// No description provided for @catalogIntroTitle.
  ///
  /// In pt, this message translates to:
  /// **'Busque um ponto'**
  String get catalogIntroTitle;

  /// No description provided for @catalogIntroBody.
  ///
  /// In pt, this message translates to:
  /// **'Pelo código da placa, pela rua, pelo bairro ou pela cidade. Depois veja as próximas chegadas e acompanhe o ônibus no mapa.'**
  String get catalogIntroBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
