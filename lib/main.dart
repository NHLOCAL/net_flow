import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'browser/services/netfree_browser_policy.dart';
import 'browser/widgets/compact_browser_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterDownloader.initialize(
    debug: kDebugMode,
    ignoreSsl: const NetfreeBrowserPolicy().ignoreDownloadSsl,
  );

  await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  runApp(const NetFlowApp());
}

class NetFlowApp extends StatelessWidget {
  const NetFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Net Flow',
      debugShowCheckedModeBanner: false,
      locale: const Locale('he'),
      supportedLocales: const [Locale('he')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF256D85),
          brightness: Brightness.light,
        ),
        visualDensity: VisualDensity.compact,
      ),
      home: const CompactBrowserPage(),
    );
  }
}
