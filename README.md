# free_scroll_listview

A Flutter list that supports **jumping and animating to any index**, **prepend / append data** while keeping scroll position sensible, optional **header / footer**, and **negative / unbounded-style scroll** behavior for long lists.

**Version:** see [`pubspec.yaml`](pubspec.yaml). **Changelog:** [`CHANGELOG.md`](CHANGELOG.md).

## Features

- Scroll or animate to an arbitrary index (`scrollToIndex`, `setDataAndScrollTo`, etc.).
- Insert data at head or tail (`addDataToHead`, `addDataToTail`) with internal synchronization.
- Optional header and footer widgets; item builder with index-based layout.
- Preview-based height estimation for edge cases; configurable preview wait timeout (`kPreviewItemsTimeout` in `src/free_scroll_preview.dart`).
- Uses [`synchronized`](https://pub.dev/packages/synchronized) for safe concurrent updates to list state.

## Requirements

- **Dart SDK:** `^3.0.0`
- **Flutter:** `>=3.3.0`

## Installation

Add to your `pubspec.yaml` (use the [pub.dev](https://pub.dev/packages/free_scroll_listview) page or your target version):

```yaml
dependencies:
  free_scroll_listview: ^2.0.0
```

Then run `flutter pub get`.

## Usage

```dart
import 'package:free_scroll_listview/free_scroll_listview.dart';
import 'package:flutter/material.dart';

final _controller = FreeScrollListViewController<String>();

// Optionally seed data and scroll to an index:
// await _controller.setDataAndScrollTo(items, index: 35, align: FreeScrollType.directJumpTo);

@override
Widget build(BuildContext context) {
  return FreeScrollListView<String>(
    controller: _controller,
    headerView: Container(height: 60, color: Colors.redAccent),
    footerView: Container(height: 60, color: Colors.blue),
    reverse: false,
    builder: (context, index) {
      return Container(
        height: 75,
        alignment: Alignment.center,
        child: Text(_controller.dataList[index]),
      );
    },
  );
}

// Later: scroll to an index
await _controller.scrollToIndex(80);
```

A fuller demo lives under [`example/`](example/).

## Main APIs

| Area | Notes |
|------|--------|
| `FreeScrollListViewController<T>` | Holds data, scroll position logic, `scrollToIndex`, `setDataAndScrollTo`, `addDataToHead`, `addDataToTail`, `dataList` getter/setter, etc. |
| `FreeScrollListView<T>` | The widget; pass `controller`, `builder`, optional `headerView` / `footerView`. |
| `FreeScrollType` | Alignment / jump modes (`topToBottom`, `bottomToTop`, `directJumpTo`). |

Internal listeners are wired by the package; if you fork the library, avoid calling locked controller methods synchronously from inside those listeners.

## Dependencies

- [`synchronized`](https://pub.dev/packages/synchronized) — async mutual exclusion for list mutations.

## 中文简介

长列表支持**按索引跳转 / 动画滚动**、**头部或尾部批量插入数据**，并可配合 header / footer；复杂场景下通过预览测量辅助高度计算。完整交互见 [`example/`](example/) 示例工程。

## License

BSD-style license — see [`LICENSE`](LICENSE).

## Links

- **Homepage / source:** <https://github.com/flappygod/free_scroll_listview>
