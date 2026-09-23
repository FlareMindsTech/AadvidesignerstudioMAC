import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/lazy_loading_widgets.dart';
import '../widgets/theme_toggle.dart';
import '../utils/responsive_helper.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        automaticallyImplyLeading: false,
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navigate to create event screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Create event feature coming soon!')),
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
              onRefresh: () => provider.refreshEvents(),
              child: LazyEventList(
                events: provider.events,
                isLoading: provider.isLoadingEvents,
                onLoadMore: () {
                  // Load more events when scrolling to bottom
                  if (!provider.isLoadingEvents) {
                    provider.loadEvents();
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
