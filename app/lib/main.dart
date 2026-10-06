import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/core/config/api_config.dart';
import 'src/core/network/api_client.dart';
import 'src/features/transit/data/repositories/http_transit_repository.dart';

void main() {
  final apiClient = ApiClient(baseUrl: ApiConfig.baseUrl);
  final repository = HttpTransitRepository(apiClient);

  runApp(BusaoGynApp(repository: repository));
}
