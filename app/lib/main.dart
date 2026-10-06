import 'package:flutter/material.dart';

import 'app/busaogyn_app.dart';
import 'core/config/app_config.dart';
import 'features/transit/data/repositories/api_transit_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final repository = ApiTransitRepository(baseUri: config.apiBaseUri);

  runApp(
    BusaoGynApp(
      repository: repository,
    ),
  );
}
