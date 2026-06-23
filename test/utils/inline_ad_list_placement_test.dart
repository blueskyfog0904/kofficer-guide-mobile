import 'package:flutter_test/flutter_test.dart';
import 'package:kofficer_guide/utils/inline_ad_list_placement.dart';

void main() {
  group('InlineAdListPlacement', () {
    test('counts ads after 5 items and every 10 items after that', () {
      expect(InlineAdListPlacement.adCountForItemCount(0), 0);
      expect(InlineAdListPlacement.adCountForItemCount(4), 0);
      expect(InlineAdListPlacement.adCountForItemCount(5), 1);
      expect(InlineAdListPlacement.adCountForItemCount(14), 1);
      expect(InlineAdListPlacement.adCountForItemCount(15), 2);
      expect(InlineAdListPlacement.adCountForItemCount(24), 2);
      expect(InlineAdListPlacement.adCountForItemCount(25), 3);
      expect(InlineAdListPlacement.adCountForItemCount(35), 4);
    });

    test('marks rendered ad rows after content positions 5, 15, 25', () {
      final adIndices = <int>[
        for (var index = 0; index < 30; index += 1)
          if (InlineAdListPlacement.isAdIndex(index)) index,
      ];

      expect(adIndices, [5, 16, 27]);
    });

    test('maps rendered rows back to content indices', () {
      expect(InlineAdListPlacement.contentIndexForRenderedIndex(0), 0);
      expect(InlineAdListPlacement.contentIndexForRenderedIndex(4), 4);
      expect(InlineAdListPlacement.contentIndexForRenderedIndex(6), 5);
      expect(InlineAdListPlacement.contentIndexForRenderedIndex(15), 14);
      expect(InlineAdListPlacement.contentIndexForRenderedIndex(17), 15);
      expect(InlineAdListPlacement.contentIndexForRenderedIndex(28), 25);
    });

    test('maps content indices to rendered rows with preceding ads', () {
      expect(InlineAdListPlacement.renderedIndexForContentIndex(0), 0);
      expect(InlineAdListPlacement.renderedIndexForContentIndex(4), 4);
      expect(InlineAdListPlacement.renderedIndexForContentIndex(5), 6);
      expect(InlineAdListPlacement.renderedIndexForContentIndex(14), 15);
      expect(InlineAdListPlacement.renderedIndexForContentIndex(15), 17);
      expect(InlineAdListPlacement.renderedIndexForContentIndex(25), 28);
    });

    test('adds ad rows to total list item count', () {
      expect(InlineAdListPlacement.totalItemCount(4), 4);
      expect(InlineAdListPlacement.totalItemCount(5), 6);
      expect(InlineAdListPlacement.totalItemCount(15), 17);
      expect(InlineAdListPlacement.totalItemCount(25), 28);
    });
  });
}
