import 'package:flutter/material.dart';
import 'package:ludo_pay_app/l10n/app_localizations.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(AppLocalizations.of(context)!.reportPlaceholder),
    );
  }
}
