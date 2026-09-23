import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemeToggle extends StatelessWidget {
  final bool showLabel;
  final bool compact;

  const ThemeToggle({
    super.key,
    this.showLabel = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (compact) {
      return IconButton(
        icon: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        ),
        onPressed: () => themeProvider.toggleTheme(),
        tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
      );
    }

    return ListTile(
      leading: Icon(
        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        showLabel ? (isDark ? 'Light Mode' : 'Dark Mode') : '',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: Switch(
        value: isDark,
        onChanged: (_) => themeProvider.toggleTheme(),
        activeColor: Theme.of(context).colorScheme.primary,
      ),
      onTap: () => themeProvider.toggleTheme(),
    );
  }
}

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentMode = themeProvider.themeMode;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme Mode',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildThemeOption(
            context,
            themeProvider,
            ThemeMode.light,
            'Light',
            Icons.light_mode_rounded,
            currentMode == ThemeMode.light,
          ),
          const SizedBox(height: 8),
          _buildThemeOption(
            context,
            themeProvider,
            ThemeMode.dark,
            'Dark',
            Icons.dark_mode_rounded,
            currentMode == ThemeMode.dark,
          ),
          const SizedBox(height: 8),
          _buildThemeOption(
            context,
            themeProvider,
            ThemeMode.system,
            'System',
            Icons.settings_suggest_rounded,
            currentMode == ThemeMode.system,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeProvider themeProvider,
    ThemeMode mode,
    String label,
    IconData icon,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () {
        themeProvider.setThemeMode(mode);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

// Quick theme toggle button for app bars
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Theme.of(context).brightness == Brightness.dark
            ? Icons.light_mode_rounded
            : Icons.dark_mode_rounded,
      ),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => const ThemeSelector(),
        );
      },
      tooltip: 'Change Theme',
    );
  }
}

