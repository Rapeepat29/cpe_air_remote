import '../../localization/localized_material.dart';

class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/brand/rmutt_save_energy_icon.png',
              width: 72,
              height: 72,
              filterQuality: FilterQuality.medium,
              semanticLabel: 'RMUTT Save Energy',
            ),
            const SizedBox(height: 20),
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('Checking your session...'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
