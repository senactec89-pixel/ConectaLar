import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'services/service_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppServices.instance.auth.inicializarSessao();
  runApp(const ConectaLarApp());
}
