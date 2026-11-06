import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/employee_home_screen.dart';
import 'services/reimbursement_api_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
  }
  runApp(const ConswareEmployeeApp());
}

class ConswareEmployeeApp extends StatelessWidget {
  final ReimbursementApiService? apiService;

  const ConswareEmployeeApp({
    super.key,
    this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Consware Reembolsos · Colaborador',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(),
      locale: const Locale('es', 'CO'),
      supportedLocales: const <Locale>[
        Locale('es', 'CO'),
        Locale('es'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: EmployeeHomeScreen(
        apiService: apiService ?? ReimbursementApiService(),
      ),
    );
  }
}
