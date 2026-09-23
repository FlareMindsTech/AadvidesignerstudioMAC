import '../models/submodule.dart';

class SubModuleTreeBuilder {
  /// Converts a flat list of submodules (from the API) into a nested tree structure
  static List<SubModule> buildTree(List<SubModule> flatList) {
    // Map to hold all submodules by their ID for easy lookup
    final Map<String, SubModule> lookup = {};
    for (var sub in flatList) {
      if (sub.id != null) {
        // Initialize subModules list if null
        sub.subModules = [];
        lookup[sub.id!] = sub;
      }
    }

    final List<SubModule> rootNodes = [];

    // Build the tree
    for (var sub in flatList) {
      if (sub.parentSubModuleId == null || sub.parentSubModuleId!.isEmpty) {
        // It's a root node
        rootNodes.add(sub);
      } else {
        // It's a child node, add it to its parent's subModules list
        final parent = lookup[sub.parentSubModuleId!];
        if (parent != null) {
          parent.subModules?.add(sub);
        } else {
          // Fallback if parent is missing from the list
          rootNodes.add(sub);
        }
      }
    }

    // Optional: Sort children by order
    _sortTree(rootNodes);
    
    return rootNodes;
  }

  static void _sortTree(List<SubModule> nodes) {
    nodes.sort((a, b) => a.order.compareTo(b.order));
    for (var node in nodes) {
      if (node.subModules != null && node.subModules!.isNotEmpty) {
        _sortTree(node.subModules!);
      }
    }
  }
}
