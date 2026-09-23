import 'package:flutter/material.dart';

/// A Scaffold wrapper that automatically includes SafeArea
/// This ensures all screens respect system UI insets (status bar, notch, etc.)
class SafeScaffold extends StatelessWidget {
  final Widget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final PreferredSizeWidget? preferredSizeWidget;
  final List<Widget>? persistentFooterButtons;
  final Widget? bottomSheet;
  final bool? drawerEnableOpenDragGesture;
  final bool? endDrawerEnableOpenDragGesture;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const SafeScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.preferredSizeWidget,
    this.persistentFooterButtons,
    this.bottomSheet,
    this.drawerEnableOpenDragGesture,
    this.endDrawerEnableOpenDragGesture,
    this.scaffoldKey,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: appBar as PreferredSizeWidget?,
      body: SafeArea(
        child: body ?? const SizedBox.shrink(),
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      drawer: drawer,
      endDrawer: endDrawer,
      bottomNavigationBar: bottomNavigationBar,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      persistentFooterButtons: persistentFooterButtons,
      bottomSheet: bottomSheet,
      drawerEnableOpenDragGesture: drawerEnableOpenDragGesture ?? false,
      endDrawerEnableOpenDragGesture: endDrawerEnableOpenDragGesture ?? false,
    );
  }
}
