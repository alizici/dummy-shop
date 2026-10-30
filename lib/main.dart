import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/dependencies.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App(dependencies: AppDependencies.create()));
}
