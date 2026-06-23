/// Calculates inline ad positions for restaurant lists.
///
/// Ads are inserted after the 5th restaurant, then after every 10 restaurants:
/// 5, 15, 25, 35...
class InlineAdListPlacement {
  const InlineAdListPlacement._();

  static const int firstAdAfterItemCount = 5;
  static const int subsequentAdInterval = 10;

  // Rendered list indices are spaced by 11 because each previous ad also
  // occupies one rendered row: 5, 16, 27...
  static const int _renderedAdInterval = subsequentAdInterval + 1;

  static int adCountForItemCount(int itemCount) {
    if (itemCount < firstAdAfterItemCount) {
      return 0;
    }

    return ((itemCount - firstAdAfterItemCount) ~/ subsequentAdInterval) + 1;
  }

  static int totalItemCount(int contentItemCount) {
    return contentItemCount + adCountForItemCount(contentItemCount);
  }

  static bool isAdIndex(int renderedIndex) {
    if (renderedIndex < firstAdAfterItemCount) {
      return false;
    }

    return (renderedIndex - firstAdAfterItemCount) % _renderedAdInterval == 0;
  }

  static int contentIndexForRenderedIndex(int renderedIndex) {
    return renderedIndex - adCountBeforeRenderedIndex(renderedIndex);
  }

  static int renderedIndexForContentIndex(int contentIndex) {
    return contentIndex + adCountForItemCount(contentIndex);
  }

  static int adCountBeforeRenderedIndex(int renderedIndex) {
    if (renderedIndex <= firstAdAfterItemCount) {
      return 0;
    }

    return ((renderedIndex - firstAdAfterItemCount - 1) ~/
            _renderedAdInterval) +
        1;
  }
}
