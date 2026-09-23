import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/lazy_loading_widgets.dart';
import '../widgets/theme_toggle.dart';
import '../utils/responsive_helper.dart';

class LaunchListScreen extends StatefulWidget {
  const LaunchListScreen({super.key});

  @override
  State<LaunchListScreen> createState() => _LaunchListScreenState();
}

class _LaunchListScreenState extends State<LaunchListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadLaunches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Launch'),
        automaticallyImplyLeading: false,
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navigate to create launch screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Create launch feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveHelper.responsiveWrapper(
          child: Consumer<AppProvider>(
          builder: (context, provider, child) {
            return RefreshIndicator(
              onRefresh: () => provider.refreshLaunches(),
              child: LazyLaunchList(
                launches: provider.launches,
                isLoading: provider.isLoadingLaunches,
                onLoadMore: () {
                  // Load more launches when scrolling to bottom
                  if (!provider.isLoadingLaunches) {
                    provider.loadLaunches();
                  }
                },
                hasMore: true,
              ),
            );
          },
        ),
        ),
      ),
    );
  }
}
