// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

void main() {
  testWidgets('PinnedTableView builds with trailing pinned columns',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableView.builder(
            columnCount: 10,
            rowCount: 10,
            pinnedColumnCount: 2,
            trailingPinnedColumnCount: 2,
            pinnedRowCount: 2,
            trailingPinnedRowCount: 2,
            cellBuilder: (BuildContext context, TableVicinity vicinity) {
              return TableViewCell(
                child: Center(
                  child: Text('C${vicinity.column}, R${vicinity.row}'),
                ),
              );
            },
            columnBuilder: (int index) {
              return const TableSpan(
                extent: FixedTableSpanExtent(100),
              );
            },
            rowBuilder: (int index) {
              return const TableSpan(
                extent: FixedTableSpanExtent(80),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify leading pinned cells are visible
    expect(find.text('C0, R0'), findsOneWidget);
    expect(find.text('C1, R0'), findsOneWidget);
    expect(find.text('C0, R1'), findsOneWidget);

    // Verify trailing pinned cells are visible
    expect(find.text('C8, R0'), findsOneWidget);
    expect(find.text('C9, R0'), findsOneWidget);
    expect(find.text('C0, R8'), findsOneWidget);
    expect(find.text('C0, R9'), findsOneWidget);
    expect(find.text('C9, R9'), findsOneWidget);
  });

  testWidgets('PinnedTableView can scroll with trailing pinned columns',
      (WidgetTester tester) async {
    final ScrollController horizontalController = ScrollController();
    final ScrollController verticalController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableView.builder(
            horizontalDetails: ScrollableDetails.horizontal(
              controller: horizontalController,
            ),
            verticalDetails: ScrollableDetails.vertical(
              controller: verticalController,
            ),
            columnCount: 20,
            rowCount: 20,
            pinnedColumnCount: 2,
            trailingPinnedColumnCount: 2,
            pinnedRowCount: 2,
            trailingPinnedRowCount: 2,
            cellBuilder: (BuildContext context, TableVicinity vicinity) {
              return TableViewCell(
                child: Center(
                  child: Text('C${vicinity.column}, R${vicinity.row}'),
                ),
              );
            },
            columnBuilder: (int index) {
              return const TableSpan(
                extent: FixedTableSpanExtent(100),
              );
            },
            rowBuilder: (int index) {
              return const TableSpan(
                extent: FixedTableSpanExtent(80),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially, leading pinned cells should be visible
    expect(find.text('C0, R0'), findsOneWidget);
    expect(find.text('C1, R0'), findsOneWidget);

    // Trailing pinned cells should be visible
    expect(find.text('C18, R0'), findsOneWidget);
    expect(find.text('C19, R0'), findsOneWidget);

    // Scroll horizontally to middle
    horizontalController.jumpTo(500);
    await tester.pumpAndSettle();

    // Leading pinned cells still visible
    expect(find.text('C0, R0'), findsOneWidget);
    expect(find.text('C1, R0'), findsOneWidget);

    // Trailing pinned cells still visible
    expect(find.text('C18, R0'), findsOneWidget);
    expect(find.text('C19, R0'), findsOneWidget);

    // Scroll to the end horizontally
    horizontalController.jumpTo(horizontalController.position.maxScrollExtent);
    await tester.pumpAndSettle();

    // Leading and trailing pinned cells still visible
    expect(find.text('C0, R0'), findsOneWidget);
    expect(find.text('C1, R0'), findsOneWidget);
    expect(find.text('C18, R0'), findsOneWidget);
    expect(find.text('C19, R0'), findsOneWidget);

    // Clean up
    horizontalController.dispose();
    verticalController.dispose();
  });

  testWidgets('PinnedTableView scrolls to end vertically with trailing rows',
      (WidgetTester tester) async {
    final ScrollController verticalController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableView.builder(
            verticalDetails: ScrollableDetails.vertical(
              controller: verticalController,
            ),
            columnCount: 10,
            rowCount: 30,
            pinnedRowCount: 2,
            trailingPinnedRowCount: 2,
            cellBuilder: (BuildContext context, TableVicinity vicinity) {
              return TableViewCell(
                child: Center(
                  child: Text('C${vicinity.column}, R${vicinity.row}'),
                ),
              );
            },
            columnBuilder: (int index) {
              return const TableSpan(
                extent: FixedTableSpanExtent(100),
              );
            },
            rowBuilder: (int index) {
              return const TableSpan(
                extent: FixedTableSpanExtent(80),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Leading pinned rows visible
    expect(find.text('C0, R0'), findsOneWidget);
    expect(find.text('C0, R1'), findsOneWidget);

    // Trailing pinned rows visible
    expect(find.text('C0, R28'), findsOneWidget);
    expect(find.text('C0, R29'), findsOneWidget);

    // Scroll to end
    verticalController.jumpTo(verticalController.position.maxScrollExtent);
    await tester.pumpAndSettle();

    // Leading and trailing pinned rows still visible
    expect(find.text('C0, R0'), findsOneWidget);
    expect(find.text('C0, R1'), findsOneWidget);
    expect(find.text('C0, R28'), findsOneWidget);
    expect(find.text('C0, R29'), findsOneWidget);

    // Clean up
    verticalController.dispose();
  });

  testWidgets('PinnedTableView with only trailing pinned columns',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableView.builder(
            columnCount: 10,
            rowCount: 10,
            trailingPinnedColumnCount: 2,
            trailingPinnedRowCount: 2,
            cellBuilder: (BuildContext context, TableVicinity vicinity) {
              return TableViewCell(
                child: Center(
                  child: Text('C${vicinity.column}, R${vicinity.row}'),
                ),
              );
            },
            columnBuilder: (int index) {
              return const TableSpan(
                extent: FixedTableSpanExtent(100),
              );
            },
            rowBuilder: (int index) {
              return const TableSpan(
                extent: FixedTableSpanExtent(80),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Trailing pinned cells should be visible
    expect(find.text('C8, R0'), findsOneWidget);
    expect(find.text('C9, R0'), findsOneWidget);
    expect(find.text('C0, R8'), findsOneWidget);
    expect(find.text('C0, R9'), findsOneWidget);

    // No leading pinned cells at position 0 with pinned status
    // (they're just regular scrollable cells now)
    expect(find.text('C0, R0'), findsOneWidget);
  });

  testWidgets('PinnedTableView with both leading and trailing pinned',
      (WidgetTester tester) async {
    final ScrollController horizontalController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableView.builder(
            horizontalDetails: ScrollableDetails.horizontal(
              controller: horizontalController,
            ),
            columnCount: 20,
            rowCount: 10,
            pinnedColumnCount: 3,
            trailingPinnedColumnCount: 3,
            pinnedRowCount: 2,
            trailingPinnedRowCount: 2,
            cellBuilder: (BuildContext context, TableVicinity vicinity) {
              return TableViewCell(
                child: Center(
                  child: Text('C${vicinity.column}, R${vicinity.row}'),
                ),
              );
            },
            columnBuilder: (int index) {
              return const TableSpan(
                extent: FixedTableSpanExtent(100),
              );
            },
            rowBuilder: (int index) {
              return const TableSpan(
                extent: FixedTableSpanExtent(80),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Leading pinned columns (0-2)
    expect(find.text('C0, R0'), findsOneWidget);
    expect(find.text('C1, R0'), findsOneWidget);
    expect(find.text('C2, R0'), findsOneWidget);

    // Trailing pinned columns (17-19)
    expect(find.text('C17, R0'), findsOneWidget);
    expect(find.text('C18, R0'), findsOneWidget);
    expect(find.text('C19, R0'), findsOneWidget);

    // Scroll to middle
    horizontalController.jumpTo(500);
    await tester.pumpAndSettle();

    // Both leading and trailing still visible
    expect(find.text('C0, R0'), findsOneWidget);
    expect(find.text('C2, R0'), findsOneWidget);
    expect(find.text('C17, R0'), findsOneWidget);
    expect(find.text('C19, R0'), findsOneWidget);

    // Clean up
    horizontalController.dispose();
  });

  testWidgets('PinnedTableView with all columns pinned (no scrollable)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableView.builder(
            columnCount: 6,
            rowCount: 6,
            pinnedColumnCount: 3,
            trailingPinnedColumnCount: 3,
            pinnedRowCount: 3,
            trailingPinnedRowCount: 3,
            cellBuilder: (BuildContext context, TableVicinity vicinity) {
              return TableViewCell(
                child: Center(
                  child: Text('C${vicinity.column}, R${vicinity.row}'),
                ),
              );
            },
            columnBuilder: (int index) {
              return const TableSpan(
                extent: FixedTableSpanExtent(100),
              );
            },
            rowBuilder: (int index) {
              return const TableSpan(
                extent: FixedTableSpanExtent(80),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // All cells should be visible since everything is pinned
    expect(find.text('C0, R0'), findsOneWidget);
    expect(find.text('C5, R5'), findsOneWidget);
  });

  testWidgets('PinnedTableView viewport size smaller than pinned regions',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 200,
            child: TableView.builder(
              columnCount: 10,
              rowCount: 10,
              pinnedColumnCount: 2,
              trailingPinnedColumnCount: 2,
              pinnedRowCount: 2,
              trailingPinnedRowCount: 2,
              cellBuilder: (BuildContext context, TableVicinity vicinity) {
                return TableViewCell(
                  child: Center(
                    child: Text('C${vicinity.column}, R${vicinity.row}'),
                  ),
                );
              },
              columnBuilder: (int index) {
                return const TableSpan(
                  extent: FixedTableSpanExtent(100),
                );
              },
              rowBuilder: (int index) {
                return const TableSpan(
                  extent: FixedTableSpanExtent(80),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Even with small viewport, pinned cells should be visible
    expect(find.text('C0, R0'), findsOneWidget);
    expect(find.text('C1, R0'), findsOneWidget);
    expect(find.text('C8, R0'), findsOneWidget);
    expect(find.text('C9, R0'), findsOneWidget);
  });
}
