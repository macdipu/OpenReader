import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/presentation/widgets/document/document_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final sample = DocumentModel(
  id: '/fixtures/report.pdf',
  path: '/fixtures/report.pdf',
  displayName: 'report.pdf',
  extension: 'pdf',
  category: DocumentCategory.pdf,
  sizeBytes: 100,
  modifiedAt: DateTime(2026),
  lastSeenAt: DateTime(2026),
);

Future<void> pumpTile(WidgetTester tester, DocumentListTile tile) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: tile)));
}

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
}

void main() {
  DocumentListTile tileWith({
    VoidCallback? onShare,
    VoidCallback? onShowInfo,
    VoidCallback? onOpenWith,
    VoidCallback? onRemoveFromRecent,
  }) {
    return DocumentListTile(
      document: sample,
      isFavorite: false,
      onTap: () {},
      onToggleFavorite: (_) {},
      onShare: onShare,
      onShowInfo: onShowInfo,
      onOpenWith: onOpenWith,
      onRemoveFromRecent: onRemoveFromRecent,
    );
  }

  testWidgets('hides Share/File Information/Open With/Remove when their callback is null', (tester) async {
    await pumpTile(tester, tileWith());
    await openMenu(tester);

    expect(find.text('Share'), findsNothing);
    expect(find.text('File Information'), findsNothing);
    expect(find.text('Open With'), findsNothing);
    expect(find.text('Remove from Recent'), findsNothing);
    // Favorite is a dedicated star icon button (not a menu item) and is
    // always shown regardless of the other callbacks.
    expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
  });

  testWidgets('shows Share only when onShare is provided and invokes it', (tester) async {
    var tapped = false;
    await pumpTile(tester, tileWith(onShare: () => tapped = true));
    await openMenu(tester);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('File Information'), findsNothing);
    expect(find.text('Open With'), findsNothing);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('shows File Information only when onShowInfo is provided and invokes it', (tester) async {
    var tapped = false;
    await pumpTile(tester, tileWith(onShowInfo: () => tapped = true));
    await openMenu(tester);
    expect(find.text('File Information'), findsOneWidget);
    expect(find.text('Share'), findsNothing);

    await tester.tap(find.text('File Information'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('shows Open With only when onOpenWith is provided and invokes it', (tester) async {
    var tapped = false;
    await pumpTile(tester, tileWith(onOpenWith: () => tapped = true));
    await openMenu(tester);
    expect(find.text('Open With'), findsOneWidget);
    expect(find.text('Share'), findsNothing);

    await tester.tap(find.text('Open With'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('shows Remove from Recent only when onRemoveFromRecent is provided and invokes it', (tester) async {
    var tapped = false;
    await pumpTile(tester, tileWith(onRemoveFromRecent: () => tapped = true));
    await openMenu(tester);
    expect(find.text('Remove from Recent'), findsOneWidget);

    await tester.tap(find.text('Remove from Recent'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('shows all four actions together when all callbacks are provided', (tester) async {
    await pumpTile(
      tester,
      tileWith(onShare: () {}, onShowInfo: () {}, onOpenWith: () {}, onRemoveFromRecent: () {}),
    );
    await openMenu(tester);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('File Information'), findsOneWidget);
    expect(find.text('Open With'), findsOneWidget);
    expect(find.text('Remove from Recent'), findsOneWidget);
  });
}
