import 'package:biomed_serv/widgets/app_drawer.dart';
import 'package:flutter/material.dart';

bool shouldUseDesktopShell(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= 1180;
}

void openDesktopAwareScreen(
  BuildContext context,
  Widget screen, {
  bool replacement = false,
}) {
  final target = shouldUseDesktopShell(context)
      ? DesktopShellScreen(
          activeScreenType: screen.runtimeType,
          child: screen,
        )
      : screen;
  final route = MaterialPageRoute(builder: (context) => target);

  if (replacement) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}

class DesktopShellScreen extends StatelessWidget {
  final Widget child;
  final Type? activeScreenType;

  const DesktopShellScreen({
    super.key,
    required this.child,
    this.activeScreenType,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 320,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: AppDrawer(
                    embedded: true,
                    activeScreenType: activeScreenType ?? child.runtimeType,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.18),
                        accent.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(1.4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(23),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
