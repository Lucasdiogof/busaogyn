// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get dockLines => 'Lines';

  @override
  String get dockStops => 'Stops';

  @override
  String get dockFavorites => 'Favorites';

  @override
  String get dockTracking => 'My bus';

  @override
  String dockTrackedBadge(String label) {
    return '$label, bus being followed';
  }

  @override
  String get settings => 'Settings';

  @override
  String get settingsSubtitle => 'Appearance and about';

  @override
  String get settingsClose => 'Close settings';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get loading => 'Loading…';

  @override
  String get refresh => 'Refresh';

  @override
  String get refreshing => 'refreshing…';

  @override
  String get refreshArrivals => 'Refresh arrivals';

  @override
  String get retry => 'Try again';

  @override
  String retryStop(String code) {
    return 'Try stop $code';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get clear => 'Clear';

  @override
  String get close => 'Close';

  @override
  String get view => 'View';

  @override
  String get viewArrivals => 'View arrivals';

  @override
  String get search => 'Search';

  @override
  String get searchStopAction => 'Find a stop';

  @override
  String get searchAnotherStop => 'Find another stop';

  @override
  String get searchHint => 'Stop code, e.g. 30402';

  @override
  String get clearCode => 'Clear code';

  @override
  String get backToStop => 'Back to the stop';

  @override
  String get stopWord => 'Stop';

  @override
  String get atStopWord => 'at stop';

  @override
  String get now => 'now';

  @override
  String ago(String age) {
    return '$age ago';
  }

  @override
  String get panelHandleLabel => 'Panel. Drag to expand or collapse';

  @override
  String routeNumber(String route) {
    return 'Line $route';
  }

  @override
  String get routeNotProvided => 'Line not provided';

  @override
  String busNumber(String number) {
    return 'Bus $number';
  }

  @override
  String linesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
      zero: '0 lines',
    );
    return '$_temp0';
  }

  @override
  String get savedStopsNone => 'No saved stops';

  @override
  String savedStopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved stops',
      one: '1 saved stop',
      zero: '0 saved stops',
    );
    return '$_temp0';
  }

  @override
  String get queryingArrivals => 'checking arrivals…';

  @override
  String get queryingArrivalsSemantics => 'Checking arrivals';

  @override
  String queryingStop(String stop) {
    return 'Checking stop $stop';
  }

  @override
  String get qualityRealtime => 'Real time';

  @override
  String get qualityScheduled => 'Scheduled';

  @override
  String get qualityUnknownLong => 'Unconfirmed information';

  @override
  String get qualityUnknownShort => 'Unconfirmed';

  @override
  String get minutesUnknown => 'time not provided';

  @override
  String get minutesLessThanOne => '< 1 min';

  @override
  String get minutesLessThanOneLong => 'less than 1 minute';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String minutesLong(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
      zero: '0 minutes',
    );
    return '$_temp0';
  }

  @override
  String get punctualityOnTime => 'On time';

  @override
  String get punctualityDelayed => 'Delayed';

  @override
  String get punctualityEarly => 'Early';

  @override
  String get punctualityUnknown => 'Punctuality not provided';

  @override
  String get accessible => 'Accessible';

  @override
  String get accessibilityNotIndicated => 'Accessibility not indicated';

  @override
  String get accessibilityUnknown => 'Accessibility not provided';

  @override
  String get destinationUnknown => 'Destination not provided';

  @override
  String headingTo(String destination) {
    return 'Heading to $destination';
  }

  @override
  String get positionSearching => 'Looking for the bus position';

  @override
  String get positionConnection => 'Unstable connection';

  @override
  String get positionUnavailable => 'Position temporarily unavailable';

  @override
  String positionOutdated(String age) {
    return 'Outdated position · $age ago';
  }

  @override
  String positionLive(String age) {
    return 'Live · $age ago';
  }

  @override
  String positionLast(String age) {
    return 'Last position $age ago';
  }

  @override
  String positionAgeShort(String age) {
    return 'position $age ago';
  }

  @override
  String get positionMaybeOutdated => 'Position possibly outdated';

  @override
  String freshnessStale(String age) {
    return 'Data temporarily outdated · $age ago';
  }

  @override
  String get freshnessNow => 'Updated just now';

  @override
  String freshnessAge(String age) {
    return 'Updated $age ago';
  }

  @override
  String get liveSearchingLabel => 'Searching';

  @override
  String get liveSearchingDetail => 'position';

  @override
  String get liveConnectionLabel => 'Connection';

  @override
  String get liveConnectionDetail => 'unstable';

  @override
  String get liveLocatingLabel => 'Locating';

  @override
  String get liveLocatingDetail => 'bus';

  @override
  String get liveOutdated => 'Outdated';

  @override
  String get liveLabel => 'Live';

  @override
  String get livePosition => 'Position';

  @override
  String get liveNoEstimate => 'No estimate';

  @override
  String get liveNoGps => 'no GPS';

  @override
  String get liveEstimate => 'Estimate';

  @override
  String get errFormat =>
      'BusãoGyn received data in an unexpected format. Please try again.';

  @override
  String get errArrivalsGeneric => 'Could not check this stop right now.';

  @override
  String get errPositionGeneric => 'Could not locate this bus right now.';

  @override
  String get errTimeout =>
      'The request took longer than expected. Please try again.';

  @override
  String get errNetwork => 'No connection to BusãoGyn. Check your internet.';

  @override
  String get errSourceTimeout =>
      'RMTC took too long to respond. Please try again shortly.';

  @override
  String get errSourceUnavailable =>
      'The RMTC data source is unavailable right now. Please try again shortly.';

  @override
  String get errSourceInvalidArrivals =>
      'RMTC did not return valid data for this stop. Check the code or try again.';

  @override
  String get errSourceInvalidPosition =>
      'RMTC did not return valid data for this bus right now.';

  @override
  String get errInvalidStop => 'Invalid stop code. Use digits only.';

  @override
  String get errInvalidVehicle => 'This bus has no valid number to follow.';

  @override
  String get errInvalidResponse =>
      'BusãoGyn received an unexpected response. Please try again.';

  @override
  String get errRetryable =>
      'The service is unstable right now. Please try again shortly.';

  @override
  String get errGeneric => 'Could not complete the request.';

  @override
  String get errPositionNotReported =>
      'The source did not report this bus position right now.';

  @override
  String get errPositionUnavailable => 'Position temporarily unavailable.';

  @override
  String get searchInvalidTitle => 'Enter the stop code';

  @override
  String get searchInvalidBody => 'Use only the digits on the stop sign.';

  @override
  String get searchNotFoundTitle => 'Stop not found';

  @override
  String get searchNotFoundBody => 'Check the code and try again.';

  @override
  String get searchTimeoutTitle => 'The request took too long';

  @override
  String get searchTimeoutBody => 'Please try again shortly.';

  @override
  String get searchOfflineTitle => 'No connection';

  @override
  String get searchOfflineBody => 'Check your internet and try again.';

  @override
  String get searchUnavailableTitle => 'Service temporarily unavailable';

  @override
  String get searchUnavailableBody => 'Please try again in a few minutes.';

  @override
  String get nextBuses => 'Next buses';

  @override
  String get sourceUnstable =>
      'The source is unstable. Showing the last valid data.';

  @override
  String get noArrivalsNow => 'No arrivals expected right now';

  @override
  String noArrivalsNowAt(String hour) {
    return 'No arrivals expected right now · checked at $hour';
  }

  @override
  String get noArrivalsBody =>
      'The source reported no buses for this stop at the moment. Try refreshing in a few minutes.';

  @override
  String get legendRealtime => ': position reported by RMTC, can be followed.';

  @override
  String get legendScheduled => ': timetable schedule, no GPS.';

  @override
  String trackingBannerSemantics(String number) {
    return 'Bus $number is being followed. View in My bus';
  }

  @override
  String refreshFailedAt(String hour, String error) {
    return 'Could not refresh right now. Showing the query from $hour, which may no longer be valid. $error';
  }

  @override
  String refreshFailedPrevious(String error) {
    return 'Could not refresh right now. Showing the previous query, which may no longer be valid. $error';
  }

  @override
  String get connOfflineTitle => 'Arrivals need internet';

  @override
  String get connFailedTitle => 'We could not check the arrivals';

  @override
  String get connOfflineBody =>
      'The map is still available, but upcoming arrivals only appear with a connection. No old estimate is shown as if it were current.';

  @override
  String connFailedBody(String code) {
    return 'Code $code was not the problem: the request did not complete. No old estimate is shown as if it were current.';
  }

  @override
  String get connFailedBodyNoCode =>
      'The code you entered was not the problem: the request did not complete. No old estimate is shown as if it were current.';

  @override
  String get introTitle => 'Enter the stop code';

  @override
  String get introBody =>
      'See the next arrivals of each line and follow the bus on the map.';

  @override
  String get introNote =>
      'The code is on the stop sign. Only buses with GPS reported by the source can be followed.';

  @override
  String exampleStop(String code) {
    return 'Example: $code';
  }

  @override
  String exampleStopSemantics(String code) {
    return 'Check the example stop $code';
  }

  @override
  String get noFollowing => 'no next one';

  @override
  String get followingUpper => 'NEXT';

  @override
  String nextSemantics(String minutes, String quality) {
    return 'Next: $minutes, $quality';
  }

  @override
  String followingSemantics(String minutes, String quality, String number) {
    return 'Following: $minutes, $quality, bus $number';
  }

  @override
  String get trackingUnavailableSemantics =>
      'Tracking unavailable: arrival without GPS from the source';

  @override
  String trackBus(String number) {
    return 'Follow bus $number';
  }

  @override
  String trackBusSearching(String number) {
    return 'Looking for the position of bus $number';
  }

  @override
  String trackBusActive(String number) {
    return 'Following bus $number';
  }

  @override
  String trackBusUnavailable(String number) {
    return 'Bus $number has no position';
  }

  @override
  String trackBusFailing(String number) {
    return 'Reconnecting to bus $number';
  }

  @override
  String get trackingHeaderSubtitle => 'Follow a vehicle in real time';

  @override
  String trackingHeaderSemantics(String number, String heading) {
    return 'My bus: bus $number, $heading';
  }

  @override
  String trackingHeaderSemanticsRoute(
    String number,
    String route,
    String heading,
  ) {
    return 'My bus: bus $number, line $route, $heading';
  }

  @override
  String busSemantics(String number, String heading) {
    return 'Bus $number, $heading';
  }

  @override
  String busSemanticsRoute(String number, String route, String heading) {
    return 'Bus $number, line $route, $heading';
  }

  @override
  String get stopTracking => 'Stop following';

  @override
  String get noTrackedBusTitle => 'No bus being followed';

  @override
  String get noTrackedBusBody => 'Pick a real-time bus in a stop\'s arrivals.';

  @override
  String get noTrackedBusNote =>
      'Only buses with GPS reported by RMTC can be followed. Scheduled times have no position.';

  @override
  String get trackingSearching => 'Looking for position';

  @override
  String get trackingFollowing => 'Following';

  @override
  String get stop => 'Stop';

  @override
  String get following => 'Following';

  @override
  String get center => 'Center';

  @override
  String get centerBus => 'Center on the bus';

  @override
  String get centerBusFollowing => 'Center on the bus. Following the bus';

  @override
  String get centerBusPaused => 'Center on the bus. Following paused';

  @override
  String get trackThisBus => 'Follow this bus';

  @override
  String get trackingFootnote =>
      'Position reported by RMTC, checked every 15 s. Direction is based on the observed movement; the trail shows only where the bus has already been. The source does not report the route ahead or the order of the next stops, so the map shows no future path.';

  @override
  String get noticeEtaStillAvailable =>
      'The arrival estimate is still available.';

  @override
  String get noticeLocatingAgain => 'Trying to locate the bus again.';

  @override
  String get noticeLastKnownPosition =>
      'The map shows the last known position.';

  @override
  String get noticeTemporaryFailure =>
      'Temporary failure while checking the position.';

  @override
  String get noticeRetryEvery15 => 'Automatic retry every 15 s.';

  @override
  String busPositionSemantics(String status) {
    return 'Bus position: $status';
  }

  @override
  String get busDetails => 'Bus details';

  @override
  String get busDetailsCollapseSemantics => 'Bus details. Collapse';

  @override
  String get busDetailsExpandSemantics => 'Bus details. Expand';

  @override
  String get detailBus => 'Bus';

  @override
  String get detailLine => 'Line';

  @override
  String get detailDestination => 'Destination';

  @override
  String get detailReferenceStop => 'Reference stop';

  @override
  String get detailPosition => 'Position';

  @override
  String get detailPunctuality => 'Punctuality';

  @override
  String get detailAccessibility => 'Accessibility';

  @override
  String get detailOccupancy => 'Occupancy';

  @override
  String get detailMovement => 'Movement';

  @override
  String get notProvidedF => 'Not provided';

  @override
  String get notProvidedM => 'Not provided';

  @override
  String get notIndicatedBySource => 'Not indicated by the source';

  @override
  String get infoUnavailable => 'Information not available';

  @override
  String get movementNotObserved => 'Direction not observed yet';

  @override
  String get movementObserved =>
      'The arrow on the map shows the observed direction';

  @override
  String get trailNote =>
      'Trail based on observed positions. Official route not available yet.';

  @override
  String etaUnavailable(String stop) {
    return 'Estimate for stop $stop unavailable.';
  }

  @override
  String etaToStopUnknown(String stop) {
    return 'estimate to stop $stop';
  }

  @override
  String etaToStopMinutes(String stop) {
    return 'min to stop $stop';
  }

  @override
  String etaFromQuery(String freshness) {
    return 'Estimate from the stop query · $freshness';
  }

  @override
  String mapPosition(String number) {
    return 'Map with the position of bus $number reported by the source';
  }

  @override
  String mapPositionStale(String number) {
    return 'Map with the position of bus $number reported by the source, possibly outdated';
  }

  @override
  String mapPositionPending(String number) {
    return 'Map. Position of bus $number not available yet';
  }

  @override
  String get mapNoBus => 'Map of Goiânia. No bus being followed';

  @override
  String mapOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more real-time buses on their way to the stop',
      one: '1 more real-time bus on its way to the stop',
      zero: '0 more real-time buses on their way to the stop',
    );
    return '$_temp0';
  }

  @override
  String favoriteStopAdd(String code) {
    return 'Favorite stop $code';
  }

  @override
  String favoriteStopRemove(String code) {
    return 'Remove stop $code from favorites';
  }

  @override
  String favoriteStopsLimit(int limit) {
    return 'Limit of $limit favorites. Remove one to add another.';
  }

  @override
  String favoriteLinesLimit(int limit) {
    return 'Limit of $limit favorite lines. Remove one to add another.';
  }

  @override
  String favoriteLineAdd(String route) {
    return 'Favorite line $route at this stop';
  }

  @override
  String favoriteLineRemove(String route, String stop) {
    return 'Remove line $route at stop $stop from favorites';
  }

  @override
  String get favoriteLineOn => 'Favorite line';

  @override
  String get favoriteLineOff => 'Favorite this line';

  @override
  String get storageNotPersistent =>
      'This device did not keep the stops. They last only until you close the app.';

  @override
  String get storageReadFailed =>
      'Could not read the saved stops. We started with an empty list.';

  @override
  String get storageWriteFailed =>
      'Could not save right now. The list lasts until you close the app.';

  @override
  String stopOpenArrivals(String code) {
    return 'Check arrivals at stop $code';
  }

  @override
  String stopOpenArrivalsNamed(String code, String name) {
    return 'Check arrivals at stop $code, $name';
  }

  @override
  String lineOpenArrivals(String route, String stop) {
    return 'Check arrivals of line $route at stop $stop';
  }

  @override
  String get offlineHint =>
      'Tap a stop to check arrivals. Checking needs internet and no estimate is saved on the device.';

  @override
  String get favoritesEmptyTitle => 'Your favorite stops will appear here.';

  @override
  String get favoritesEmptyBody =>
      'Check a stop and tap the star in the header to favorite it.';

  @override
  String get favoriteStopsSection => 'Favorite stops';

  @override
  String get favoriteLinesSection => 'Favorite lines';

  @override
  String get clearRecentsTitle => 'Clear recents?';

  @override
  String get clearRecentsBody =>
      'The history of stops checked on this device will be erased. Your favorites do not change.';

  @override
  String get recentsSection => 'Recents';

  @override
  String get recentsEmpty => 'The stops you check will appear here.';

  @override
  String recentStopRemove(String code) {
    return 'Remove stop $code from recents';
  }

  @override
  String get loadingSavedStops => 'Loading saved stops';

  @override
  String get favoriteStatusLoading => 'Checking…';

  @override
  String get favoriteStatusOffline =>
      'No connection. Tap Refresh when the internet is back.';

  @override
  String get favoriteStatusFailed => 'Could not check right now.';

  @override
  String get lastValidData => 'Last valid data from the source';

  @override
  String lastValidDataAt(String hour) {
    return 'Last valid data from the source · checked at $hour';
  }

  @override
  String get queriedNow => 'Checked just now';

  @override
  String queriedAtHour(String hour) {
    return 'Checked at $hour';
  }

  @override
  String lineSemantics(String route, String minutes, String quality) {
    return 'Line $route, $minutes, $quality';
  }

  @override
  String get linesSoonTitle => 'Lines will be available soon.';

  @override
  String get linesSoonBody => 'For now, check arrivals by the stop code.';

  @override
  String get seenLinesSection => 'Lines seen';

  @override
  String get seenLinesNote =>
      'Lines seen in your checks this session and in your favorites. The full list of lines depends on authorization from RMTC.';

  @override
  String seenAtStop(String stop) {
    return 'at stop $stop';
  }

  @override
  String seenAtStops(String stops) {
    return 'at stops $stops';
  }

  @override
  String seenAtStopsMore(String stops, int more) {
    return 'at stops $stops and $more more';
  }

  @override
  String seenLineSemantics(String route, String label, String stop) {
    return 'Line $route, $label. Check arrivals at stop $stop';
  }

  @override
  String get noticeOffline =>
      'No connection. You can open your stops, but arrivals only appear with internet.';

  @override
  String get noticeQueryIncomplete =>
      'The last request did not complete. Please try again shortly.';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeBody => 'The map follows the chosen theme.';

  @override
  String get themeSystem => 'System';

  @override
  String get themeNight => 'Night';

  @override
  String get themeLight => 'Light';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsBusData => 'Bus data';

  @override
  String get settingsBusDataBody =>
      'RMTC, via the BusãoGyn API. Real-time positions and estimates depend on the GPS reported by the source.';

  @override
  String get settingsMap => 'Map';

  @override
  String get settingsMapBody =>
      'OpenFreeMap · © OpenMapTiles · data © OpenStreetMap';

  @override
  String get settingsTypography => 'Typography';

  @override
  String get settingsTypographyBody =>
      'Geist and Geist Mono · SIL Open Font License 1.1';

  @override
  String get settingsLicenses => 'Licenses';

  @override
  String get settingsLicensesBody => 'Libraries and fonts used by the app.';

  @override
  String get catalogSearchHint => 'Code, street, district or city';

  @override
  String get catalogResultsTitle => 'Stops in the registry';

  @override
  String catalogResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops',
      one: '1 stop',
      zero: 'No stops',
    );
    return '$_temp0';
  }

  @override
  String catalogResultsMore(int shown, int total) {
    return 'Showing $shown of $total. Refine the search to see others.';
  }

  @override
  String get catalogNoResultsTitle => 'No stop found';

  @override
  String get catalogNoResultsBody =>
      'Check the spelling or use the code printed at the stop.';

  @override
  String get catalogSearchCodeHint =>
      'Tap a stop to see its address and lines, or submit the code to check arrivals.';

  @override
  String catalogOpenStop(String code, String place) {
    return 'Stop $code, $place. View details';
  }

  @override
  String get catalogStopNotFound =>
      'This code is not in the official registry. Arrivals may still work.';

  @override
  String get catalogStopLinesTitle => 'Lines serving this stop';

  @override
  String get catalogStopLinesNote =>
      'Official registry: lists the stop\'s lines, not buses on the way. Real-time or scheduled arrivals appear when you check arrivals.';

  @override
  String get catalogNoLinesListed =>
      'No line linked to this stop in the registry.';

  @override
  String get catalogSeeArrivals => 'See arrivals';

  @override
  String catalogSourceNote(String reference) {
    return 'Official CMTC registry · reference $reference · available offline';
  }

  @override
  String get catalogDevBadge => 'Development data, not published';

  @override
  String get catalogStation => 'Station without address in the registry';

  @override
  String catalogStopTitle(String code) {
    return 'Stop $code';
  }

  @override
  String get catalogPreviewClose => 'Back to search';

  @override
  String get catalogAddress => 'Address';

  @override
  String get catalogDistrict => 'District';

  @override
  String get catalogCity => 'City';

  @override
  String catalogLinesHeaderSubtitle(int count) {
    return '$count lines in the official registry';
  }

  @override
  String get catalogLinesSearchHint => 'Line number or name';

  @override
  String get catalogLinesNoResults => 'No line found.';

  @override
  String get catalogLinesAllTitle => 'Lines';

  @override
  String get catalogShowMore => 'Show more';

  @override
  String get catalogLineVariants => 'Variants';

  @override
  String catalogLineStops(int count) {
    return 'Registered stops ($count)';
  }

  @override
  String get catalogLineStopsNote =>
      'Stops linked to the line in the registry, with no route order or direction.';

  @override
  String get catalogLineStatus => 'Status';

  @override
  String get catalogLineType => 'Type';

  @override
  String get catalogLineCities => 'Cities';

  @override
  String get catalogLineOrigin => 'Origin';

  @override
  String get catalogLineDestination => 'Destination';

  @override
  String catalogValidFrom(String date) {
    return 'In force since $date';
  }

  @override
  String get catalogBackToLines => 'Back to lines';

  @override
  String catalogOpenLine(String line, String name) {
    return 'Line $line, $name. View details';
  }

  @override
  String get catalogLineNotFound => 'Line not found in the registry.';

  @override
  String catalogVariantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count variants',
      one: '1 variant',
      zero: 'No variants',
    );
    return '$_temp0';
  }

  @override
  String get settingsCatalog => 'Official catalog (development)';

  @override
  String settingsCatalogBody(String license, String reference, String version) {
    return 'Version $version · reference $reference · redistribution: $license. Enabled only in this development build.';
  }

  @override
  String get catalogIntroTitle => 'Find a stop';

  @override
  String get catalogIntroBody =>
      'By the code on the sign, the street, the district or the city. Then see the next arrivals and follow the bus on the map.';

  @override
  String get catalogDirectionOutbound => 'Outbound';

  @override
  String get catalogDirectionInbound => 'Inbound';

  @override
  String get catalogDirectionUnknown => 'Route';

  @override
  String catalogRouteOnMap(String direction, String variant) {
    return 'On the map: $variant · $direction';
  }

  @override
  String get catalogClearRoute => 'Clear route';

  @override
  String get catalogShowRouteHint =>
      'Tap Outbound or Inbound to see the official route on the map.';

  @override
  String get catalogRouteLegend =>
      'Outbound: solid amber · Inbound: dashed · Other routes of the line: grey · Rings: registered stops of the line, in no stopping order.';

  @override
  String get catalogKmzOnlyShapes =>
      'KMZ routes without a variant in the registry';

  @override
  String catalogShowRouteSemantics(String direction, String variant) {
    return 'Show route $variant, $direction on the map';
  }

  @override
  String get catalogMapHint =>
      'Tap a stop on the map to see its address and lines.';

  @override
  String get trackMatchTitle => 'Official route (experimental)';

  @override
  String trackMatchConfirmed(String direction, String variant) {
    return 'Matched to $variant · $direction. On the map, the official route is grey and the stretch ahead, estimated, is dashed amber. No time prediction.';
  }

  @override
  String trackMatchPending(String variant) {
    return 'Variant $variant identified. Waiting for the bus to move to confirm the direction; no route is drawn yet.';
  }

  @override
  String trackMatchAmbiguous(String reason) {
    return 'No reliable match to an official route: $reason. The map shows only the position and the observed trail.';
  }

  @override
  String get trackMatchNoShapes =>
      'This line has no official route in the catalog.';

  @override
  String get trackMatchNoPosition =>
      'No current bus position: no route is drawn.';

  @override
  String get trackReasonRouteNameMissing =>
      'the source did not report the itinerary';

  @override
  String get trackReasonRouteNameNoMatch =>
      'the reported itinerary is not in the registry';

  @override
  String get trackReasonRouteNameSeveral =>
      'more than one variant has this itinerary';

  @override
  String get trackReasonDirectionUnknown =>
      'the destination does not indicate the direction';

  @override
  String get trackReasonShapeMissing =>
      'there is no single official route for that direction';

  @override
  String get trackReasonOffRoute => 'the bus is off the registered route';

  @override
  String get trackReasonMovingBackwards =>
      'the observed movement contradicts the route';

  @override
  String get scheduleTitle => 'Scheduled departures';

  @override
  String get scheduleDayWeekday => 'Weekdays';

  @override
  String get scheduleDaySaturday => 'Saturday';

  @override
  String get scheduleDaySunday => 'Sunday & holiday';

  @override
  String get scheduleAllCodes => 'All';

  @override
  String get scheduleNone => 'No timetable for this line.';

  @override
  String get scheduleInsufficient =>
      'Timetable unavailable: the spreadsheet data is inconsistent or incomplete.';

  @override
  String scheduleRecent(String date) {
    return 'Reference date $date · validity not confirmed by CMTC. Double-check before you go.';
  }

  @override
  String scheduleConfirmed(String date) {
    return 'Validity confirmed · reference date $date.';
  }

  @override
  String scheduleOld(String date) {
    return 'Old timetable (reference $date). It may no longer apply.';
  }

  @override
  String get scheduleShowOld => 'Show anyway';

  @override
  String scheduleSource(String oso, String source) {
    return 'Spreadsheet: $source · OSO $oso';
  }

  @override
  String get scheduleDepartureNote =>
      'Departure times, not times at each stop. The spreadsheet gives neither direction nor departure point. These are not real-time predictions.';

  @override
  String get scheduleEmptyDay => 'No scheduled departures on this day.';

  @override
  String scheduleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count departures',
      one: '1 departure',
      zero: 'No departures',
    );
    return '$_temp0';
  }

  @override
  String get scheduleLegendNextDay => '+1: after midnight';

  @override
  String get scheduleLegendHalf =>
      'MI: half trip starting at the turnaround · MF: half trip ending at the turnaround';

  @override
  String get scheduleLegendRepeated => '×2: repeated in the spreadsheet';

  @override
  String scheduleCodeUnregistered(String code) {
    return '$code (not registered)';
  }

  @override
  String sequenceTitle(int count, String direction) {
    return 'Estimated stops · $direction ($count)';
  }

  @override
  String get sequenceEstimatedNote =>
      'Order estimated from the official route. Not the official CMTC stop sequence.';

  @override
  String get sequenceUncertain => 'uncertain position';

  @override
  String get sequenceRepeated => 'passed again';

  @override
  String sequencePartialTitle(int count) {
    return 'Stops near this route ($count)';
  }

  @override
  String get sequencePartialNote =>
      'Not enough confidence to order the stops: listed without route order.';

  @override
  String get sequenceNone => 'No registered stop matched to this route.';

  @override
  String sequenceAmbiguous(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops left out as ambiguous.',
      one: '1 stop left out as ambiguous.',
      zero: 'No stop left out as ambiguous.',
    );
    return '$_temp0';
  }

  @override
  String sequenceShowAll(int count) {
    return 'Show all ($count)';
  }

  @override
  String get itineraryTitle => 'On the route (estimated)';

  @override
  String itineraryRow(
    String direction,
    int position,
    int total,
    String variant,
  ) {
    return '$variant · $direction — stop $position of $total';
  }

  @override
  String get itineraryNote =>
      'Position estimated from the official route; no passing time.';

  @override
  String get nextStopsTitle => 'Next stops (estimated)';

  @override
  String get nextStopLabel => 'Next';

  @override
  String get nextStopsUncertain =>
      'Next stop uncertain: list in estimated order.';

  @override
  String nextStopsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops to the end of the route',
      one: '1 stop to the end of the route',
      zero: 'No stops to the end of the route',
    );
    return '$_temp0';
  }

  @override
  String get nextStopsNote =>
      'From the official route and the real position. No arrival time per stop.';

  @override
  String get nextStopsUnreliable =>
      'No reliable stop sequence for this route: map tracking only.';

  @override
  String get nextStopsEnd => 'Bus at the end of the route.';

  @override
  String get trackReasonGpsJump => 'the position jumped along the route';

  @override
  String get trackReasonRepeatedSection =>
      'the route passes this section twice';

  @override
  String get plannerOpen => 'Plan a trip';

  @override
  String get plannerTitle => 'Plan a trip';

  @override
  String get plannerIntro =>
      'Stop to stop, with up to two transfers. Works offline: uses only the catalog on this device.';

  @override
  String get plannerOrigin => 'From';

  @override
  String get plannerDestination => 'To';

  @override
  String get plannerSearchHint => 'Code, street, district or city';

  @override
  String get plannerPickOnMap => 'Pick on the map';

  @override
  String plannerPicking(String field) {
    return 'Tap a stop on the map to set: $field.';
  }

  @override
  String get plannerSwap => 'Swap origin and destination';

  @override
  String get plannerSearch => 'Find trips';

  @override
  String get plannerClose => 'Close planner';

  @override
  String get plannerNotCovered => 'not covered by the planner';

  @override
  String get plannerNoResultTitle => 'No trip to show';

  @override
  String get plannerSameStop => 'Origin and destination are the same stop.';

  @override
  String get plannerUnknownStop => 'Stop not found in the catalog.';

  @override
  String get plannerNoCoverageOrigin =>
      'The origin is not yet on any route with a reliable stop order. Try a nearby stop.';

  @override
  String get plannerNoCoverageDestination =>
      'The destination is not yet on any route with a reliable stop order. Try a nearby stop.';

  @override
  String get plannerNoRoute =>
      'No trip with enough evidence and up to two transfers. That does not mean there is no bus, only that current data cannot confirm one.';

  @override
  String get plannerTruncated =>
      'The search stopped at its processing limit; there may be other options.';

  @override
  String plannerResultsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count options',
      one: '1 option',
      zero: 'No options',
    );
    return '$_temp0';
  }

  @override
  String get plannerReliable => 'Reliable';

  @override
  String get plannerEstimated => 'Estimated';

  @override
  String plannerBuses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count buses',
      one: '1 bus',
      zero: 'No bus',
    );
    return '$_temp0';
  }

  @override
  String get plannerDirect => 'direct';

  @override
  String plannerTransfers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transfers',
      one: '1 transfer',
      zero: 'no transfer',
    );
    return '$_temp0';
  }

  @override
  String get plannerBoard => 'Board';

  @override
  String get plannerTransfer => 'Transfer';

  @override
  String get plannerAlight => 'Get off';

  @override
  String plannerLeg(String direction, String km, int stops, String variant) {
    return '$variant · $direction · $stops stops · $km km along the route';
  }

  @override
  String plannerWalk(int meters) {
    return 'on foot, ~$meters m in a straight line';
  }

  @override
  String get plannerShowOnMap => 'Show on map';

  @override
  String get plannerOnMap => 'On the map';

  @override
  String get plannerNoTimes =>
      'No travel time or schedule: timetables have no confirmed validity. Stop order is estimated from the official route; km are measured along it.';

  @override
  String get plannerCautionOrder =>
      'Stop order not cross-checked with the official street list.';

  @override
  String get plannerCautionUncertain =>
      'Uncertain position of a boarding or alighting stop.';

  @override
  String get plannerCautionRepeated =>
      'The bus passes one of the stops more than once.';

  @override
  String get plannerCautionWalk =>
      'Walking transfer: crossing, sidewalk and accessibility not verified.';

  @override
  String get plannerCautionHub =>
      'Station or terminal: its link to the line is inferred (no official stop-line record).';

  @override
  String get plannerCautionSameStation =>
      'Platform change within the same station; which platform serves each direction is not stated.';

  @override
  String get sequenceOrderedNote =>
      'Incomplete list: the order was cross-checked (official streets or corridor stations), but some stops were left out.';

  @override
  String get catalogTerminalNote =>
      'Terminal identified from official line names and the ends of official routes (inferred). It has no code for arrival lookups.';

  @override
  String get catalogStationNote =>
      'Corridor station (official KMZ folder). Lines stopping here are inferred from the corridor; see \"On the route\".';

  @override
  String get catalogTerminalTag => 'terminal (inferred)';

  @override
  String get dockPlan => 'Plan';

  @override
  String get dockSaved => 'Saved';

  @override
  String trackingBarSemantics(String bus, String heading) {
    return 'Tracking bus $bus, $heading. Tap to open.';
  }

  @override
  String get trackingBarOpen => 'Open tracking';

  @override
  String get trackingBarStale => 'Old position or no signal';

  @override
  String get sheetShowMap => 'Show map';

  @override
  String get sheetShowPanel => 'Show panel';

  @override
  String get sheetHandleHint => 'Tap to expand or collapse';

  @override
  String get plannerClear => 'Clear';

  @override
  String get plannerHeaderSubtitle => 'Stop to stop · works offline';

  @override
  String get sheetSummaryStops => 'Stops and arrivals';

  @override
  String sheetSummaryStop(String code, String lines) {
    return 'Stop $code · $lines';
  }

  @override
  String get sheetSummaryPlan => 'Origin and destination';

  @override
  String get sheetSummaryLines => 'Line catalog';

  @override
  String sheetSummaryLine(String line) {
    return 'Line $line';
  }

  @override
  String get sheetSummarySaved => 'Favorites and recent';

  @override
  String get sheetSummaryTracking => 'Bus tracking';
}
