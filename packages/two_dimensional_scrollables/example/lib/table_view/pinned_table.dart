// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

/// Demonstrates pinned columns and rows, including the new trailing pinned
/// columns and rows feature.
class PinnedTableExample extends StatefulWidget {
  /// Creates a screen that demonstrates pinned columns and rows in TableView.
  const PinnedTableExample({super.key});

  @override
  State<PinnedTableExample> createState() => _PinnedTableExampleState();
}

class _PinnedTableExampleState extends State<PinnedTableExample> {
  late final ScrollController _verticalController = ScrollController();
  late final ScrollController _horizontalController = ScrollController();

  int _pinnedColumnCount = 2;
  int _pinnedRowCount = 2;
  int _trailingPinnedColumnCount = 2;
  int _trailingPinnedRowCount = 2;

  final int _totalColumns = 50;
  final int _totalRows = 200;

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: TableView.builder(
          verticalDetails: ScrollableDetails.vertical(
            controller: _verticalController,
          ),
          horizontalDetails: ScrollableDetails.horizontal(
            controller: _horizontalController,
          ),
          cellBuilder: _buildCell,
          columnCount: _totalColumns,
          columnBuilder: _buildColumnSpan,
          rowCount: _totalRows,
          rowBuilder: _buildRowSpan,
          pinnedColumnCount: _pinnedColumnCount,
          pinnedRowCount: _pinnedRowCount,
          trailingPinnedColumnCount: _trailingPinnedColumnCount,
          trailingPinnedRowCount: _trailingPinnedRowCount,
        ),
      ),
      persistentFooterButtons: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Wrap(
                spacing: 20,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  // Leading pinned columns
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('Leading Pinned Columns'),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed:
                                _pinnedColumnCount > 0
                                    ? () => setState(() => _pinnedColumnCount--)
                                    : null,
                          ),
                          Text('$_pinnedColumnCount'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed:
                                _pinnedColumnCount +
                                            _trailingPinnedColumnCount <
                                        _totalColumns
                                    ? () => setState(() => _pinnedColumnCount++)
                                    : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Trailing pinned columns
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('Trailing Pinned Columns'),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed:
                                _trailingPinnedColumnCount > 0
                                    ? () => setState(
                                      () => _trailingPinnedColumnCount--,
                                    )
                                    : null,
                          ),
                          Text('$_trailingPinnedColumnCount'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed:
                                _pinnedColumnCount +
                                            _trailingPinnedColumnCount <
                                        _totalColumns
                                    ? () => setState(
                                      () => _trailingPinnedColumnCount++,
                                    )
                                    : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Leading pinned rows
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('Leading Pinned Rows'),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed:
                                _pinnedRowCount > 0
                                    ? () => setState(() => _pinnedRowCount--)
                                    : null,
                          ),
                          Text('$_pinnedRowCount'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed:
                                _pinnedRowCount + _trailingPinnedRowCount <
                                        _totalRows
                                    ? () => setState(() => _pinnedRowCount++)
                                    : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Trailing pinned rows
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('Trailing Pinned Rows'),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed:
                                _trailingPinnedRowCount > 0
                                    ? () => setState(
                                      () => _trailingPinnedRowCount--,
                                    )
                                    : null,
                          ),
                          Text('$_trailingPinnedRowCount'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed:
                                _pinnedRowCount + _trailingPinnedRowCount <
                                        _totalRows
                                    ? () => setState(
                                      () => _trailingPinnedRowCount++,
                                    )
                                    : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Legend
              Wrap(
                spacing: 15,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  _buildLegendItem(Colors.blue[100]!, 'Leading Pinned'),
                  _buildLegendItem(Colors.orange[100]!, 'Trailing Pinned'),
                  _buildLegendItem(Colors.purple[50]!, 'Scrollable'),
                  _buildLegendItem(
                    Colors.green[100]!,
                    'Corner (Leading × Trailing)',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.black26),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  TableViewCell _buildCell(BuildContext context, TableVicinity vicinity) {
    final bool isLeadingPinnedColumn = vicinity.column < _pinnedColumnCount;
    final bool isTrailingPinnedColumn =
        vicinity.column >= _totalColumns - _trailingPinnedColumnCount;
    final bool isLeadingPinnedRow = vicinity.row < _pinnedRowCount;
    final bool isTrailingPinnedRow =
        vicinity.row >= _totalRows - _trailingPinnedRowCount;

    final bool isPinnedColumn = isLeadingPinnedColumn || isTrailingPinnedColumn;
    final bool isPinnedRow = isLeadingPinnedRow || isTrailingPinnedRow;

    // Determine cell color based on pinning status
    Color? cellColor;
    if (isLeadingPinnedColumn && isTrailingPinnedRow ||
        isTrailingPinnedColumn && isLeadingPinnedRow) {
      // Corner cells where leading and trailing meet
      cellColor = Colors.green[100];
    } else if (isLeadingPinnedColumn || isLeadingPinnedRow) {
      // Leading pinned cells
      cellColor = Colors.blue[100];
    } else if (isTrailingPinnedColumn || isTrailingPinnedRow) {
      // Trailing pinned cells
      cellColor = Colors.orange[100];
    } else {
      // Regular scrollable cells
      cellColor = Colors.purple[50];
    }

    String cellLabel = 'C${vicinity.column}, R${vicinity.row}';
    if (isPinnedColumn || isPinnedRow) {
      if (isLeadingPinnedColumn && isLeadingPinnedRow) {
        cellLabel = 'LP×LP\n$cellLabel';
      } else if (isLeadingPinnedColumn && isTrailingPinnedRow) {
        cellLabel = 'LP×TP\n$cellLabel';
      } else if (isTrailingPinnedColumn && isLeadingPinnedRow) {
        cellLabel = 'TP×LP\n$cellLabel';
      } else if (isTrailingPinnedColumn && isTrailingPinnedRow) {
        cellLabel = 'TP×TP\n$cellLabel';
      } else if (isLeadingPinnedColumn) {
        cellLabel = 'Leading Pin\n$cellLabel';
      } else if (isTrailingPinnedColumn) {
        cellLabel = 'Trailing Pin\n$cellLabel';
      } else if (isLeadingPinnedRow) {
        cellLabel = 'Leading Pin\n$cellLabel';
      } else if (isTrailingPinnedRow) {
        cellLabel = 'Trailing Pin\n$cellLabel';
      }
    }

    return TableViewCell(
      child: Container(
        color: cellColor,
        child: Center(
          child: Text(
            cellLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  isPinnedColumn || isPinnedRow
                      ? FontWeight.bold
                      : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  TableSpan _buildColumnSpan(int index) {
    final bool isLeadingPinned = index < _pinnedColumnCount;
    final bool isTrailingPinned =
        index >= _totalColumns - _trailingPinnedColumnCount;

    return TableSpan(
      foregroundDecoration: TableSpanDecoration(
        border: TableSpanBorder(
          trailing: BorderSide(
            color:
                isLeadingPinned || isTrailingPinned
                    ? Colors.black54
                    : Colors.black12,
            width: isLeadingPinned || isTrailingPinned ? 2 : 1,
          ),
        ),
      ),
      extent: const FixedTableSpanExtent(120),
    );
  }

  TableSpan _buildRowSpan(int index) {
    final bool isLeadingPinned = index < _pinnedRowCount;
    final bool isTrailingPinned = index >= _totalRows - _trailingPinnedRowCount;

    return TableSpan(
      foregroundDecoration: TableSpanDecoration(
        border: TableSpanBorder(
          trailing: BorderSide(
            color:
                isLeadingPinned || isTrailingPinned
                    ? Colors.black54
                    : Colors.black12,
            width: isLeadingPinned || isTrailingPinned ? 2 : 1,
          ),
        ),
      ),
      extent: const FixedTableSpanExtent(80),
    );
  }
}
