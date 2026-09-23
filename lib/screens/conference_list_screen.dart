import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/lazy_loading_widgets.dart';
import '../widgets/theme_toggle.dart';
import '../utils/responsive_helper.dart';

class ConferenceListScreen extends StatefulWidget {
  const ConferenceListScreen({super.key});

  @override
  State<ConferenceListScreen> createState() => _ConferenceListScreenState();
}

class _ConferenceListScreenState extends State<ConferenceListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadConferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conferences'),
        automaticallyImplyLeading: false,
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navigate to create conference screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Create conference feature coming soon!')),
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
              onRefresh: () => provider.refreshConferences(),
              child: LazyConferenceList(
                conferences: provider.conferences,
                isLoading: provider.isLoadingConferences,
                onLoadMore: () {
                  // Load more conferences when scrolling to bottom
                  if (!provider.isLoadingConferences) {
                    provider.loadConferences();
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
