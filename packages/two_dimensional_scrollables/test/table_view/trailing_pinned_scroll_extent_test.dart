// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

/// Regression tests for trailing pinned columns and scroll extent calculation.
///
/// Bug: When trailing pinned columns are used and total column widths exceed
/// the viewport, the last scrollable column before the trailing pinned column
/// cannot be scrolled to because maxScrollExtent is computed as 0.
///
/// Root cause: In performLayout, _updateScrollBounds() is called BEFORE
/// _updateTrailingPinnedExtents(), so it uses a stale cached value of 0
/// for the trailing pinned extent on the first layout pass.
///
/// The formula:
///   maxScrollExtent = lastScrollableColumn.trailingOffset
///                     - viewportWidth
///                     + trailingPinnedColumnsExtent
///
/// With trailingPinnedColumnsExtent = 0 (stale cache):
///   maxScrollExtent = 1080 - 800 + 0 = 280  (if > 0, but ...)
///   Actually for narrow cases: e.g. 960 - 800 + 0 = 160 (seems fine)
///   But the real issue is the first layout after a rebuild.
void main() {
  group('Trailing pinned columns - scroll extent', () {
    testWidgets(
      'maxScrollExtent accounts for trailing pinned columns on first layout',
      (WidgetTester tester) async {
        // 10 columns × 120px = 1200px total
        // Default test viewport is 800×600
        // 1 trailing pinned column (column 9) = 120px
        // 9 scrollable columns × 120px = 1080px of scrollable content
        // Scrollable viewport = 800 - 120 = 680px
        // Expected maxScrollExtent = 1080 - 680 = 400
        //   (formula: lastScrollable.trailingOffset - viewportWidth + trailingPinnedExtent)
        //   = 1080 - 800 + 120 = 400
        //
        // Bug: with stale trailingPinnedExtent = 0:
        //   maxScrollExtent = 1080 - 800 + 0 = 280 (WRONG, 120px short)
        //   This means the last scrollable column (column 8) cannot be fully
        //   scrolled into view - it's hidden behind the trailing pinned column.

        final ScrollController horizontalController = ScrollController();
        const double columnWidth = 120.0;
        const int columnCount = 10;
        const int trailingPinned = 1;

        final tableView = TableView.builder(
          rowCount: 5,
          columnCount: columnCount,
          columnBuilder: (_) => const TableSpan(
            extent: FixedTableSpanExtent(columnWidth),
          ),
          rowBuilder: (_) => const TableSpan(
            extent: FixedTableSpanExtent(50),
          ),
          cellBuilder: (_, TableVicinity vicinity) {
            return TableViewCell(
              child: SizedBox(
                width: columnWidth,
                height: 50,
                child: Text('R${vicinity.row}C${vicinity.column}'),
              ),
            );
          },
          horizontalDetails: ScrollableDetails.horizontal(
            controller: horizontalController,
          ),
          trailingPinnedColumnCount: trailingPinned,
        );

        await tester.pumpWidget(MaterialApp(home: tableView));
        await tester.pumpAndSettle();

        // The trailing pinned column (column 9) should always be visible
        expect(find.text('R0C9'), findsOneWidget);

        // Verify maxScrollExtent is correct (not 0 or too small)
        // Expected: 9 * 120 - 800 + 120 = 400
        final expectedMaxScroll =
            (columnCount - trailingPinned) * columnWidth // scrollable content
            - (800.0 - trailingPinned * columnWidth); // scrollable viewport
        expect(
          horizontalController.position.maxScrollExtent,
          expectedMaxScroll, // 400.0
          reason:
              'maxScrollExtent should account for trailing pinned column width',
        );

        // Scroll to max and verify the last scrollable column (column 8) is visible
        horizontalController.jumpTo(
          horizontalController.position.maxScrollExtent,
        );
        await tester.pump();

        // Column 8 (last scrollable) should be visible
        expect(
          find.text('R0C8'),
          findsOneWidget,
          reason:
              'Last scrollable column before trailing pinned should be reachable',
        );
        // Trailing pinned column should still be visible
        expect(find.text('R0C9'), findsOneWidget);
      },
    );

    testWidgets(
      'maxScrollExtent correct after widget rebuild (delegate change)',
      (WidgetTester tester) async {
        // Simulates what happens after context.replaceNamed triggers a rebuild:
        // The TableView gets a new delegate, which causes needsDelegateRebuild,
        // clearing metrics and recomputing from scratch.
        //
        // On the SECOND layout, _updateScrollBounds should use the trailing
        // pinned extent cached from the first layout's _updateTrailingPinnedExtents.

        final ScrollController horizontalController = ScrollController();
        const double columnWidth = 120.0;
        const int columnCount = 10;
        const int trailingPinned = 1;

        Widget buildTable({required int rowCount}) {
          return MaterialApp(
            home: TableView.builder(
              rowCount: rowCount,
              columnCount: columnCount,
              columnBuilder: (_) => const TableSpan(
                extent: FixedTableSpanExtent(columnWidth),
              ),
              rowBuilder: (_) => const TableSpan(
                extent: FixedTableSpanExtent(50),
              ),
              cellBuilder: (_, TableVicinity vicinity) {
                return TableViewCell(
                  child: SizedBox(
                    width: columnWidth,
                    height: 50,
                    child: Text('R${vicinity.row}C${vicinity.column}'),
                  ),
                );
              },
              horizontalDetails: ScrollableDetails.horizontal(
                controller: horizontalController,
              ),
              trailingPinnedColumnCount: trailingPinned,
            ),
          );
        }

        // First build
        await tester.pumpWidget(buildTable(rowCount: 5));
        await tester.pumpAndSettle();

        final expectedMaxScroll =
            (columnCount - trailingPinned) * columnWidth -
            (800.0 - trailingPinned * columnWidth);

        expect(
          horizontalController.position.maxScrollExtent,
          expectedMaxScroll,
          reason: 'First build: maxScrollExtent should be correct',
        );

        // Rebuild with different row count (simulates data refresh after sort)
        // This creates a new delegate, triggering needsDelegateRebuild
        await tester.pumpWidget(buildTable(rowCount: 10));
        await tester.pumpAndSettle();

        expect(
          horizontalController.position.maxScrollExtent,
          expectedMaxScroll,
          reason:
              'After rebuild: maxScrollExtent should still account for trailing pinned',
        );

        // Scroll to max - last scrollable column should be reachable
        horizontalController.jumpTo(
          horizontalController.position.maxScrollExtent,
        );
        await tester.pump();

        expect(
          find.text('R0C8'),
          findsOneWidget,
          reason: 'Column 8 should be visible after scrolling to max',
        );
        expect(find.text('R0C9'), findsOneWidget);
      },
    );

    testWidgets(
      'maxScrollExtent correct with leading AND trailing pinned columns',
      (WidgetTester tester) async {
        // 10 columns × 120px = 1200px total
        // 1 leading pinned (column 0) + 1 trailing pinned (column 9) = 240px pinned
        // 8 scrollable columns × 120px = 960px scrollable content
        // Scrollable viewport = 800 - 240 = 560px
        // Expected maxScrollExtent = 960 - 560 = 400
        //   (formula: lastScrollable.trailingOffset - viewportWidth + trailingPinnedExtent)
        //   lastScrollable = column 8, trailingOffset = 9 * 120 = 1080
        //   = 1080 - 800 + 120 = 400

        final ScrollController horizontalController = ScrollController();
        const double columnWidth = 120.0;
        const int columnCount = 10;

        final tableView = TableView.builder(
          rowCount: 5,
          columnCount: columnCount,
          columnBuilder: (_) => const TableSpan(
            extent: FixedTableSpanExtent(columnWidth),
          ),
          rowBuilder: (_) => const TableSpan(
            extent: FixedTableSpanExtent(50),
          ),
          cellBuilder: (_, TableVicinity vicinity) {
            return TableViewCell(
              child: SizedBox(
                width: columnWidth,
                height: 50,
                child: Text('R${vicinity.row}C${vicinity.column}'),
              ),
            );
          },
          horizontalDetails: ScrollableDetails.horizontal(
            controller: horizontalController,
          ),
          pinnedColumnCount: 1,
          trailingPinnedColumnCount: 1,
        );

        await tester.pumpWidget(MaterialApp(home: tableView));
        await tester.pumpAndSettle();

        // Leading pinned column always visible
        expect(find.text('R0C0'), findsOneWidget);
        // Trailing pinned column always visible
        expect(find.text('R0C9'), findsOneWidget);

        // maxScrollExtent = 1080 - 800 + 120 = 400
        expect(
          horizontalController.position.maxScrollExtent,
          400.0,
          reason:
              'maxScrollExtent should account for both leading and trailing pinned',
        );

        // Scroll to max
        horizontalController.jumpTo(
          horizontalController.position.maxScrollExtent,
        );
        await tester.pump();

        // Last scrollable column (column 8) should be visible
        expect(
          find.text('R0C8'),
          findsOneWidget,
          reason:
              'Last scrollable column should be visible after scrolling to max',
        );
        // Both pinned columns still visible
        expect(find.text('R0C0'), findsOneWidget);
        expect(find.text('R0C9'), findsOneWidget);
      },
    );

    testWidgets(
      'columns barely overflowing viewport with trailing pinned',
      (WidgetTester tester) async {
        // Edge case: total column width barely exceeds viewport
        // 8 columns × 100px = 800px = viewport width exactly
        // But with 1 trailing pinned column, the scrollable area is only 700px
        // 7 scrollable columns × 100px = 700px = scrollable viewport exactly
        // maxScrollExtent should be 0 (everything fits)
        //
        // Now add 1px to each column: 8 × 101 = 808
        // scrollable content = 7 × 101 = 707
        // scrollable viewport = 800 - 101 = 699
        // maxScrollExtent = 707 - 699 = 8
        //   (formula: 7 * 101 - 800 + 101 = 8)

        final ScrollController horizontalController = ScrollController();
        const double columnWidth = 101.0;
        const int columnCount = 8;
        const int trailingPinned = 1;

        final tableView = TableView.builder(
          rowCount: 3,
          columnCount: columnCount,
          columnBuilder: (_) => const TableSpan(
            extent: FixedTableSpanExtent(columnWidth),
          ),
          rowBuilder: (_) => const TableSpan(
            extent: FixedTableSpanExtent(50),
          ),
          cellBuilder: (_, TableVicinity vicinity) {
            return TableViewCell(
              child: SizedBox(
                width: columnWidth,
                height: 50,
                child: Text('R${vicinity.row}C${vicinity.column}'),
              ),
            );
          },
          horizontalDetails: ScrollableDetails.horizontal(
            controller: horizontalController,
          ),
          trailingPinnedColumnCount: trailingPinned,
        );

        await tester.pumpWidget(MaterialApp(home: tableView));
        await tester.pumpAndSettle();

        // Expected maxScrollExtent = 7 * 101 - 800 + 101 = 8
        expect(
          horizontalController.position.maxScrollExtent,
          moreOrLessEquals(8.0, epsilon: 0.1),
          reason:
              'Barely overflowing table should have small but non-zero maxScrollExtent',
        );
      },
    );

    testWidgets(
      'columns fit exactly in viewport with trailing pinned - no scroll needed',
      (WidgetTester tester) async {
        // 8 columns × 100px = 800px = viewport width exactly
        // 1 trailing pinned column = 100px
        // 7 scrollable columns × 100px = 700px
        // scrollable viewport = 800 - 100 = 700px
        // maxScrollExtent = 0 (perfect fit)

        final ScrollController horizontalController = ScrollController();
        const double columnWidth = 100.0;
        const int columnCount = 8;

        final tableView = TableView.builder(
          rowCount: 3,
          columnCount: columnCount,
          columnBuilder: (_) => const TableSpan(
            extent: FixedTableSpanExtent(columnWidth),
          ),
          rowBuilder: (_) => const TableSpan(
            extent: FixedTableSpanExtent(50),
          ),
          cellBuilder: (_, TableVicinity vicinity) {
            return TableViewCell(
              child: SizedBox(
                width: columnWidth,
                height: 50,
                child: Text('R${vicinity.row}C${vicinity.column}'),
              ),
            );
          },
          horizontalDetails: ScrollableDetails.horizontal(
            controller: horizontalController,
          ),
          trailingPinnedColumnCount: 1,
        );

        await tester.pumpWidget(MaterialApp(home: tableView));
        await tester.pumpAndSettle();

        expect(
          horizontalController.position.maxScrollExtent,
          0.0,
          reason: 'All columns fit exactly, no scrolling needed',
        );

        // All columns should be visible without scrolling
        for (int c = 0; c < columnCount; c++) {
          expect(find.text('R0C$c'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'trailing pinned columns with varying column widths',
      (WidgetTester tester) async {
        // Mixed column widths to test realistic scenarios
        // Columns 0-7: 100px each = 800px (scrollable)
        // Column 8: 150px (trailing pinned)
        // Total = 950px, viewport = 800px
        // maxScrollExtent = 800 - 800 + 150 = 150
        //   (lastScrollable.trailingOffset = 800, viewport = 800, trailingPinned = 150)

        final ScrollController horizontalController = ScrollController();

        final columnWidths = [
          100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, // scrollable
          150.0, // trailing pinned
        ];

        final tableView = TableView.builder(
          rowCount: 3,
          columnCount: 9,
          columnBuilder: (index) => TableSpan(
            extent: FixedTableSpanExtent(columnWidths[index]),
          ),
          rowBuilder: (_) => const TableSpan(
            extent: FixedTableSpanExtent(50),
          ),
          cellBuilder: (_, TableVicinity vicinity) {
            return TableViewCell(
              child: SizedBox(
                width: columnWidths[vicinity.column],
                height: 50,
                child: Text('R${vicinity.row}C${vicinity.column}'),
              ),
            );
          },
          horizontalDetails: ScrollableDetails.horizontal(
            controller: horizontalController,
          ),
          trailingPinnedColumnCount: 1,
        );

        await tester.pumpWidget(MaterialApp(home: tableView));
        await tester.pumpAndSettle();

        // maxScrollExtent = 800 - 800 + 150 = 150
        expect(
          horizontalController.position.maxScrollExtent,
          150.0,
          reason: 'maxScrollExtent should use actual trailing pinned column width',
        );

        // Scroll to max - last scrollable column (7) should be visible
        horizontalController.jumpTo(
          horizontalController.position.maxScrollExtent,
        );
        await tester.pump();

        expect(
          find.text('R0C7'),
          findsOneWidget,
          reason: 'Last scrollable column should be visible at max scroll',
        );
        // Trailing pinned always visible
        expect(find.text('R0C8'), findsOneWidget);
      },
    );
  });
}