import 'package:flutter/material.dart';
import 'package:ludo_pay_app/l10n/app_localizations.dart';

class PrinterScreen extends StatelessWidget {
  const PrinterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.printerScreenTitle)),
      body: Center(child: Text(l10n.printerSettingsPlaceholder)),
    );
  }
}
