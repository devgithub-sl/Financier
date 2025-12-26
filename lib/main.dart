
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'screens/dashboard_screen.dart';
import 'providers/currency_provider.dart';
import 'services/settings_service.dart';

late AppDatabase database;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService().init();
  database = AppDatabase();
  await database.populateInitialCategories();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Database Providers
        Provider<AppDatabase>.value(value: database),
        Provider<TransactionDao>(create: (_) => database.transactionDao),
        Provider<CategoryDao>(create: (_) => database.categoryDao),
        
        // Theme Provider
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        // Currency Provider
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Financier',
            debugShowCheckedModeBanner: false,
            // Theme Application
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            
            home: const DashboardScreen(),
          );
        },
      ),
    );
  }
}