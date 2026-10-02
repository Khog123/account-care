import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class AccountCareApp extends StatelessWidget {
  const AccountCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Account Care',
      debugShowCheckedModeBanner: false,
      theme: AccountCareTheme.light(),
      routerConfig: appRouter,
    );
  }
} 