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
            const Icon(
              Icons.energy_savings_leaf_rounded,
              size: 64,
              color: Color(0xFF16834B),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Color(0xFF16834B)),
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
