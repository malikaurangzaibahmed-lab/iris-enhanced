import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:async';
import '../services/memory_manager.dart';
import '../services/smart_api_client.dart';

/// Smart widget that rebuilds only when dependencies change
abstract class SmartStatefulWidget extends StatefulWidget {
  const SmartStatefulWidget({super.key});

  @override
  State<SmartStatefulWidget> createState();
}

/// Base state for smart widgets with built-in optimization
abstract class SmartState<T extends SmartStatefulWidget> extends State<T> {
  final MemoryManager _memoryManager = MemoryManager();
  final Map<String, dynamic> _previousDeps = {};
  final Debouncer _debouncer = Debouncer();
  
  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  /// Called when dependencies might have changed
  /// Override this instead of didUpdateWidget for smarter change detection
  Future<void> onDependenciesChanged(Map<String, dynamic> newDeps) async {}

  /// Safely set state with mounted check
  void safeSetState(VoidCallback fn) {
    if (mounted) {
      try {
        setState(fn);
      } catch (e) {
        debugPrint('❌ Error in setState: $e');
      }
    }
  }

  /// Debounced setState for frequent updates (search, scroll, etc.)
  void debouncedSetState(VoidCallback fn) {
    _debouncer.call(() => safeSetState(fn));
  }

  /// Register a resource for automatic cleanup when state is disposed
  void registerResource(MemoryResource resource) {
    _memoryManager.registerResource(resource);
  }

  /// Safely execute async operation with mounted checks.
  /// Type parameter 'R' prevents shadowing the class-level type parameter 'T'.
  Future<R> safeAsync<R>(Future<R> Function() operation) async {
    try {
      if (!mounted) return null as R;
      return await operation();
    } catch (e) {
      debugPrint('❌ Error in async operation: $e');
      return null as R;
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _previousDeps.clear();
    super.dispose();
  }
}

/// Optimized ListView builder with smart caching
class SmartListView extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final VoidCallback? onEndReached;
  final ScrollController? scrollController;
  final Duration retrimDuration;

  const SmartListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.onEndReached,
    this.scrollController,
    this.retrimDuration = const Duration(seconds: 30),
  });

  @override
  State<SmartListView> createState() => _SmartListViewState();
}

class _SmartListViewState extends State<SmartListView> {
  late ScrollController _controller;
  final Map<int, Widget> _widgetCache = {};
  Timer? _trimTimer;

  @override
  void initState() {
    super.initState();
    _controller = widget.scrollController ?? ScrollController();
    _controller.addListener(_onScroll);
    
    // Periodically trim cache to prevent memory bloat
    _trimTimer = Timer.periodic(widget.retrimDuration, (_) => _trimCache());
  }

  void _onScroll() {
    if (_controller.position.pixels >= _controller.position.maxScrollExtent * 0.9) {
      widget.onEndReached?.call();
    }
  }

  void _trimCache() {
    if (_widgetCache.length > 50) {
      // Keep only widgets that are likely visible
      final visibleRange = _getVisibleRange();
      _widgetCache.removeWhere((index, _) =>
          index < visibleRange.$1 - 10 || index > visibleRange.$2 + 10);
      
      debugPrint('🗑️ Trimmed list cache to ${_widgetCache.length} items');
    }
  }

  (int, int) _getVisibleRange() {
    final metrics = _controller.position;
    if (metrics.pixels == 0) return (0, 10);
    
    // Rough estimate: assume ~60px per item
    final startIndex = (metrics.pixels / 60).floor();
    final endIndex = startIndex + 15;
    
    return (startIndex, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _controller,
      itemCount: widget.itemCount,
      itemBuilder: (context, index) {
        return _widgetCache.putIfAbsent(
          index,
          () => AnimatedListItem(
            index: index,
            child: widget.itemBuilder(context, index),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _trimTimer?.cancel();
    if (widget.scrollController == null) {
      _controller.dispose();
    }
    _widgetCache.clear();
    super.dispose();
  }
}

/// Optimized GridView with smart caching
class SmartGridView extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final SliverGridDelegate gridDelegate;
  final ScrollController? scrollController;

  const SmartGridView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.gridDelegate,
    this.scrollController,
  });

  @override
  State<SmartGridView> createState() => _SmartGridViewState();
}

class _SmartGridViewState extends State<SmartGridView> {
  late ScrollController _controller;
  final Map<int, Widget> _widgetCache = {};

  @override
  void initState() {
    super.initState();
    _controller = widget.scrollController ?? ScrollController();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: _controller,
      gridDelegate: widget.gridDelegate,
      itemCount: widget.itemCount,
      itemBuilder: (context, index) {
        return _widgetCache.putIfAbsent(
          index,
          () => AnimatedListItem(
            index: index,
            child: widget.itemBuilder(context, index),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _controller.dispose();
    }
    _widgetCache.clear();
    super.dispose();
  }
}

/// Performance monitoring widget
class PerformanceMonitor extends StatefulWidget {
  final Widget child;
  final String label;

  const PerformanceMonitor({
    super.key,
    required this.child,
    required this.label,
  });

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  final Stopwatch _buildStopwatch = Stopwatch();

  @override
  Widget build(BuildContext context) {
    _buildStopwatch
      ..reset()
      ..start();

    return widget.child;
  }

  @override
  void deactivate() {
    _buildStopwatch.stop();
    debugPrint('⏱️ ${widget.label}: Built times, last build: ${_buildStopwatch.elapsedMilliseconds}ms');
    super.deactivate();
  }
}

/// Similar widget to prevent unnecessary rebuilds
class SmartRepaintBoundary extends SingleChildRenderObjectWidget {
  const SmartRepaintBoundary({
    super.key,
    required Widget child,
  }) : super(child: child);

  @override
  RenderRepaintBoundary createRenderObject(BuildContext context) {
    return RenderRepaintBoundary();
  }
}


/// Staggered Entrance Animation for Smart Lists
class AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const AnimatedListItem({super.key, required this.index, required this.child});

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0.0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.index < 8) {
      final delay = widget.index * 25;
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
