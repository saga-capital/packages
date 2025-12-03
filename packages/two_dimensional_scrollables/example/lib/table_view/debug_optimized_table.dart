// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

/// Example showing performance optimizations for debug mode.
///
/// This example demonstrates patterns that make TableView usable in debug mode
/// while maintaining full visual fidelity in release builds.
class DebugOptimizedTableExample extends StatefulWidget {
  /// Creates a debug-optimized table example.
  const DebugOptimizedTableExample({super.key});

  @override
  State<DebugOptimizedTableExample> createState() =>
      _DebugOptimizedTableExampleState();
}

class _DebugOptimizedTableExampleState
    extends State<DebugOptimizedTableExample> {
  final int _rowCount = 100;
  final int _columnCount = 50;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug-Optimized TableView'),
        backgroundColor: Colors.blue,
        actions: <Widget>[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                kDebugMode ? 'DEBUG MODE' : 'RELEASE MODE',
                style: TextStyle(
                  color: kDebugMode ? Colors.yellow : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildInfoBanner(),
          Expanded(
            child: _buildOptimizedTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      color: kDebugMode ? Colors.yellow[100] : Colors.green[100],
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Icon(
            kDebugMode ? Icons.speed : Icons.check_circle,
            color: kDebugMode ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              kDebugMode
                  ? 'Running in DEBUG mode - simplified UI for better performance'
                  : 'Running in RELEASE mode - full visual effects enabled',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimizedTable() {
    return TableView.builder(
      columnCount: _columnCount,
      rowCount: _rowCount,
      // OPTIMIZATION 1: Reduce cache extent in debug mode
      // This means fewer cells are built off-screen
      cacheExtent: kDebugMode ? 100.0 : 250.0,
      pinnedColumnCount: 1,
      pinnedRowCount: 1,
      // OPTIMIZATION 2: Use const constructors
      // This prevents creating new span objects on every build
      columnBuilder: (int index) => const TableSpan(
        extent: FixedTableSpanExtent(120),
      ),
      rowBuilder: (int index) => const TableSpan(
        extent: FixedTableSpanExtent(48),
      ),
      cellBuilder: _buildOptimizedCell,
    );
  }

  TableViewCell _buildOptimizedCell(
    BuildContext context,
    TableVicinity vicinity,
  ) {
    final bool isPinnedRow = vicinity.row == 0;
    final bool isPinnedColumn = vicinity.column == 0;
    final bool isPinned = isPinnedRow || isPinnedColumn;

    // OPTIMIZATION 3: Simplify decorations in debug mode
    // Complex decorations (gradients, shadows, border radius) are expensive
    return TableViewCell(
      child: Container(
        decoration: _getCellDecoration(isPinned, vicinity),
        padding: const EdgeInsets.all(8),
        alignment: Alignment.centerLeft,
        // OPTIMIZATION 4: Flatten widget tree
        // Avoid unnecessary nesting of Container/Padding/Center
        child: _getCellContent(isPinned, vicinity),
      ),
    );
  }

  BoxDecoration _getCellDecoration(bool isPinned, TableVicinity vicinity) {
    if (kDebugMode) {
      // DEBUG MODE: Simple, fast decoration
      return BoxDecoration(
        color: isPinned
            ? Colors.blue[50]
            : (vicinity.row.isEven ? Colors.white : Colors.grey[50]),
        // Simple borders instead of Border.all() which creates new objects
        border: const Border(
          right: BorderSide(color: Colors.grey, width: 0.5),
          bottom: BorderSide(color: Colors.grey, width: 0.5),
        ),
      );
    } else {
      // RELEASE MODE: Full visual effects
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPinned
              ? <Color>[Colors.blue[100]!, Colors.blue[200]!]
              : <Color>[
                  vicinity.row.isEven ? Colors.white : Colors.grey[50]!,
                  vicinity.row.isEven ? Colors.grey[50]! : Colors.grey[100]!,
                ],
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: isPinned
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      );
    }
  }

  Widget _getCellContent(bool isPinned, TableVicinity vicinity) {
    if (vicinity.row == 0 && vicinity.column == 0) {
      // Top-left corner cell
      return const Icon(Icons.table_chart, size: 20, color: Colors.blue);
    }

    if (vicinity.row == 0) {
      // Header row
      return _buildHeaderCell('Column ${vicinity.column}', isPinned);
    }

    if (vicinity.column == 0) {
      // Header column
      return _buildHeaderCell('Row ${vicinity.row}', isPinned);
    }

    // Data cells
    return _buildDataCell(vicinity);
  }

  Widget _buildHeaderCell(String label, bool isPinned) {
    return Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: isPinned ? Colors.blue[700] : Colors.black87,
      ),
    );
  }

  Widget _buildDataCell(TableVicinity vicinity) {
    // OPTIMIZATION 5: Pre-compute expensive operations
    // Instead of formatting dates or doing calculations in the builder,
    // do them once and cache the results
    final String cellValue = _getCellValue(vicinity);

    if (kDebugMode) {
      // DEBUG MODE: Simple text
      return Text(
        cellValue,
        style: const TextStyle(fontSize: 13),
      );
    } else {
      // RELEASE MODE: Rich formatting with icons
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            _getCellIcon(vicinity),
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              cellValue,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
  }

  // OPTIMIZATION 6: Simple computation instead of expensive operations
  String _getCellValue(TableVicinity vicinity) {
    // In a real app, you might have:
    // - Date formatting: DateFormat('yyyy-MM-dd').format(date)
    // - Number formatting: NumberFormat.currency().format(value)
    // - Complex calculations
    //
    // Pre-compute these outside the builder and cache them
    return 'Cell ${vicinity.row},${vicinity.column}';
  }

  IconData _getCellIcon(TableVicinity vicinity) {
    // Simple logic to show different icons
    final int sum = vicinity.row + vicinity.column;
    if (sum % 3 == 0) {
      return Icons.star;
    }
    if (sum % 3 == 1) {
      return Icons.favorite;
    }
    return Icons.check_circle;
  }
}

/// Alternative pattern: Use a separate widget with RepaintBoundary
/// for complex cells that don't change often.
class OptimizedDataCell extends StatelessWidget {
  /// Creates an optimized data cell widget.
  const OptimizedDataCell({
    super.key,
    required this.vicinity,
    required this.value,
  });

  /// The table cell location.
  final TableVicinity vicinity;

  /// The cell's display value.
  final String value;

  @override
  Widget build(BuildContext context) {
    // OPTIMIZATION 7: RepaintBoundary prevents unnecessary repaints
    // Use this for complex cells that don't change when neighbors update
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Text(value),
      ),
    );
  }
}

/// Pattern for handling expensive data loading.
class LazyLoadedCell extends StatefulWidget {
  /// Creates a lazy-loaded cell widget.
  const LazyLoadedCell({
    super.key,
    required this.vicinity,
  });

  /// The table cell location.
  final TableVicinity vicinity;

  @override
  State<LazyLoadedCell> createState() => _LazyLoadedCellState();
}

class _LazyLoadedCellState extends State<LazyLoadedCell> {
  String? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // OPTIMIZATION 8: Load expensive data asynchronously
    // This prevents blocking the UI thread during initial render
    await Future<void>.delayed(Duration.zero);

    if (!mounted) {
      return;
    }

    // Simulate expensive operation (database query, API call, etc.)
    final String data = await _fetchExpensiveData();

    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
    }
  }

  Future<String> _fetchExpensiveData() async {
    // Simulate expensive operation
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return 'Data ${widget.vicinity.row},${widget.vicinity.column}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Text(_data ?? '');
  }
}
