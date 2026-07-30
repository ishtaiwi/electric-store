import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_secrets.dart';
import 'core/theme/app_theme.dart';
import 'data/auth_product_repos.dart';
import 'data/customer_repository.dart';
import 'data/sales_repository.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_shell.dart';
import 'data/models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseSecrets.url,
    publishableKey: SupabaseSecrets.anonKey,
  );
  runApp(const MobileStoreApp());
}

class MobileStoreApp extends StatefulWidget {
  const MobileStoreApp({super.key});

  @override
  State<MobileStoreApp> createState() => _MobileStoreAppState();
}

class _MobileStoreAppState extends State<MobileStoreApp> {
  late final AuthRepository _auth =
      AuthRepository(Supabase.instance.client);
  late final ProductRepository _products =
      ProductRepository(Supabase.instance.client);
  late final CustomerRepository _customers =
      CustomerRepository(Supabase.instance.client);
  late final SalesRepository _sales =
      SalesRepository(Supabase.instance.client);

  AppUser? _user;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Electrical Store',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: _user == null
          ? LoginPage(
              auth: _auth,
              onLoggedIn: (u) => setState(() => _user = u),
            )
          : HomeShell(
              user: _user!,
              products: _products,
              customers: _customers,
              sales: _sales,
              onLogout: () {
                _auth.logout();
                setState(() => _user = null);
              },
            ),
    );
  }
}
