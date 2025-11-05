# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This package provides widgets that scroll in two dimensions, built on the two-dimensional foundation of the Flutter framework. The main widgets are `TableView` and `TreeView`, both subclasses of `TwoDimensionalScrollView` that build children lazily in a `TwoDimensionalViewport`.

**Important**: Most core 2D scrolling functionality lives in Flutter framework itself (TwoDimensionalScrollView, TwoDimensionalViewport, etc.), not in this package. This package only implements the TableView and TreeView widgets.

## Commands

### Testing
```bash
# Run all tests
fvm flutter test

# Run tests for a specific file
fvm flutter test test/table_view/table_test.dart

# Run a single test by name
fvm flutter test --name "test name pattern"
```

### Code Quality
```bash
# Format code (required before commits)
fvm dart format .

# Analyze code
fvm flutter analyze
```

### Example App
```bash
cd example
fvm flutter run
```

The example app demonstrates TableView and TreeView features with multiple samples in:
- `example/lib/table_view/` - simple_table.dart, merged_table.dart, infinite_table.dart
- `example/lib/tree_view/` - simple_tree.dart, custom_tree.dart

## Architecture

### Directory Structure
```
lib/
├── two_dimensional_scrollables.dart  # Main export file
└── src/
    ├── common/
    │   └── span.dart                  # Shared Span and SpanPadding classes
    ├── table_view/
    │   ├── table.dart                 # TableView widget
    │   ├── table_cell.dart            # TableViewCell and TableVicinity
    │   ├── table_delegate.dart        # Delegate mixins and builders
    │   └── table_span.dart            # TableSpan and decorations
    └── tree_view/
        ├── tree.dart                  # TreeView widget and TreeViewNode
        ├── tree_core.dart             # Core tree state management
        ├── tree_delegate.dart         # Tree delegate and builders
        ├── tree_span.dart             # TreeViewRowSpan and decorations
        └── render_tree.dart           # RenderTree rendering logic
```

### Key Concepts

**Spans**: A span represents either a row or column. The `Span` class (in `src/common/span.dart`) defines extent, padding, decorations, and gesture handling. Both `TableSpan` and `TreeViewRowSpan` extend this base.

**Delegates**: Both widgets use delegate patterns:
- `TableView` uses `TwoDimensionalChildDelegate` with `TableCellDelegateMixin`
- `TreeView` uses `TreeViewDelegate`
- Delegates define row/column counts, extents, and build cells/nodes lazily

**Lazy Building**: Only visible cells (plus cacheExtent) are built. This enables infinite tables/trees by returning null from builders to signal the end.

**Merged Cells**: TableView supports cell merging. The same child must be returned from every vicinity the merged cell occupies, but `build()` is only called once.

**TableVicinity**: Represents a cell location with `row` and `column` indices. Used throughout TableView to identify cells.

**TreeViewNode**: Hierarchical data structure with `content`, `children`, `parent`, `depth`, and `isExpanded` state. Managed by TreeView state.

### TableView vs TreeView

**TableView**:
- Grid layout with rows and columns
- Both axes scroll independently
- Supports pinned rows/columns
- Supports merged cells
- Can be infinite in either/both dimensions

**TreeView**:
- Hierarchical tree layout
- Rows represent tree nodes with depth-based indentation
- Nodes can expand/collapse to show/hide children
- Supports animations for node expansion
- Uses `TreeViewController` for programmatic control

### Pattern: Builders and Constructors

Both widgets offer multiple constructors:
- `.builder()` - Most flexible, uses builder functions
- `.list()` - For pre-existing lists of data
- Custom constructor - Uses custom delegates

### Testing Patterns

Tests are organized by component in `test/` mirroring `lib/src/`:
- Use `flutter_test` package
- Common test helpers create spans/cells with gestures (see table_test.dart)
- Tests cover lazy building, gestures, decorations, pinning, merging

## Development Notes

This package is part of the larger Flutter packages repository at https://github.com/flutter/packages.

### Code Style
- Follows Flutter/Google Dart style
- Uses `always_specify_types` lint rule (explicit types required)
- Strict analysis options: strict-casts, strict-inference, strict-raw-types
- Format with `dart format` before committing

### Important Implementation Details

1. **Lazy building contract**: Builders receive indices and must return widgets or null (for end of table/tree)

2. **Merged cells caveat**: When merging TableViewCells, return the identical child widget from all vicinities it occupies

3. **Infinite scrolling**: When rowCount/columnCount is null, maxScrollExtent is `double.infinity` until null is returned from a builder

4. **Framework dependency**: This package requires Flutter SDK >= 3.29.0 which includes the 2D scrolling foundation

5. **TreeView node state**: TreeViewNode properties like `depth`, `parent`, and `isExpanded` are managed by TreeView state - don't modify directly

## File Locations

- Main exports: `lib/two_dimensional_scrollables.dart`
- Span base class: `lib/src/common/span.dart`
- TableView: `lib/src/table_view/table.dart`
- TreeView: `lib/src/tree_view/tree.dart`
- Examples: `example/lib/table_view/` and `example/lib/tree_view/`
- Tests mirror lib structure under `test/`
