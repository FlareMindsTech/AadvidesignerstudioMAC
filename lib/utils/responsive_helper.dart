import 'package:flutter/material.dart';

class ResponsiveHelper {
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 768 &&
        MediaQuery.of(context).size.width < 1024;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024;
  }

  static double getResponsiveWidth(
    BuildContext context, {
    double mobile = 1.0,
    double tablet = 0.8,
    double desktop = 0.6,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (isMobile(context)) {
      return screenWidth * mobile;
    } else if (isTablet(context)) {
      return screenWidth * tablet;
    } else {
      return screenWidth * desktop;
    }
  }

  static int getGridCrossAxisCount(BuildContext context) {
    if (isMobile(context)) {
      return 1;
    } else if (isTablet(context)) {
      return 2;
    } else {
      return 3;
    }
  }

  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(24.0);
    } else {
      return const EdgeInsets.all(32.0);
    }
  }

  static double getResponsiveFontSize(
    BuildContext context, {
    double mobile = 14.0,
    double tablet = 16.0,
    double desktop = 18.0,
  }) {
    if (isMobile(context)) {
      return mobile;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return desktop;
    }
  }

  static Widget responsiveWrapper({
    required Widget child,
    double? maxWidth,
    EdgeInsets? padding,
  }) {
    return Builder(
      builder: (context) {
        return Container(
          width: double.infinity,
          padding: padding ?? getResponsivePadding(context),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth ?? getResponsiveWidth(context),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  static Widget responsiveGrid({
    required List<Widget> children,
    int? mobileColumns,
    int? tabletColumns,
    int? desktopColumns,
    double? childAspectRatio,
    double? crossAxisSpacing,
    double? mainAxisSpacing,
  }) {
    return Builder(
      builder: (context) {
        int columns;

        if (isMobile(context)) {
          columns = mobileColumns ?? 1;
        } else if (isTablet(context)) {
          columns = tabletColumns ?? 2;
        } else {
          columns = desktopColumns ?? 3;
        }

        // If no childAspectRatio is provided, use layout that supports dynamic heights
        if (childAspectRatio == null) {
          // Build rows of items based on columns
          final List<Widget> rows = [];
          for (int i = 0; i < children.length; i += columns) {
            final rowChildren = children.sublist(
              i,
              i + columns > children.length ? children.length : i + columns,
            );
            rows.add(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rowChildren.map((child) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: (rowChildren.indexOf(child) < rowChildren.length - 1)
                            ? (crossAxisSpacing ?? 16.0) / 2
                            : 0,
                        left: rowChildren.indexOf(child) > 0
                            ? (crossAxisSpacing ?? 16.0) / 2
                            : 0,
                        bottom: (i + columns) < children.length
                            ? (mainAxisSpacing ?? 16.0)
                            : 0,
                      ),
                      child: child,
                    ),
                  );
                }).toList(),
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: rows,
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: crossAxisSpacing ?? 16.0,
            mainAxisSpacing: mainAxisSpacing ?? 16.0,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }

  static Widget responsiveRow({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
    MainAxisSize mainAxisSize = MainAxisSize.max,
  }) {
    return Builder(
      builder: (context) {
        if (isMobile(context)) {
          return Column(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            mainAxisSize: MainAxisSize.min, // ✅ Fixed here
            children: children,
          );
        } else {
          return Row(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            mainAxisSize: mainAxisSize,
            children: children,
          );
        }
      },
    );
  }

  static Widget adaptiveContainer({
    required Widget child,
    double? mobileWidth,
    double? tabletWidth,
    double? desktopWidth,
    EdgeInsets? padding,
    Color? color,
    BoxDecoration? decoration,
  }) {
    return Builder(
      builder: (context) {
        double width;

        if (isMobile(context)) {
          width = mobileWidth ?? MediaQuery.of(context).size.width;
        } else if (isTablet(context)) {
          width = tabletWidth ?? MediaQuery.of(context).size.width * 0.8;
        } else {
          width = desktopWidth ?? MediaQuery.of(context).size.width * 0.6;
        }

        return Container(
          width: width,
          padding: padding ?? getResponsivePadding(context),
          color: color,
          decoration: decoration,
          child: child,
        );
      },
    );
  }
}
