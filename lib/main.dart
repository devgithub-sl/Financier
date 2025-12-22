import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/provider.dart';
import 'database.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'screens/dashboard_screen.dart';

late AppDatabase database;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  database = AppDatabase();
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