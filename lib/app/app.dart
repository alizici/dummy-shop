import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/bloc/session_cubit.dart';
import 'dependencies.dart';
import 'router.dart';
import 'theme.dart';

class App extends StatefulWidget {
  const App({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final SessionCubit _session = SessionCubit(widget.dependencies.auth)..restore();
  late final GoRouter _router = buildRouter(_session);

  @override
  void dispose() {
    _router.dispose();
    unawaited(_session.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.dependencies;
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: deps.auth),
        RepositoryProvider.value(value: deps.products),
      ],
      child: BlocProvider.value(
        value: _session,
        child: MaterialApp.router(
          title: 'Dummy Shop',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: _router,
        ),
      ),
    );
  }
}
