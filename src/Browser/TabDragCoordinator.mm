#import "Browser/TabDragCoordinator.h"

#import "Browser/BrowserModels.h"
#import "Browser/BrowserViews.h"

@implementation BabelTabDragCoordinator

- (BabelBrowserGroup*)groupAtListPoint:(NSPoint)listPoint
                                groups:(NSArray<BabelBrowserGroup*>*)groups
                      groupsListBounds:(NSRect)groupsListBounds {
  if (!NSPointInRect(listPoint, groupsListBounds)) {
    return nil;
  }

  for (BabelBrowserGroup* group in groups) {
    if (NSPointInRect(listPoint, group.groupItemView.frame)) {
      return group;
    }
  }
  return nil;
}

- (NSUInteger)insertionIndexForTabStripX:(CGFloat)x tabs:(NSArray<BabelBrowserTab*>*)tabs {
  if (0 == tabs.count) {
    return 0;
  }

  for (NSUInteger index = 0; index < tabs.count; index++) {
    BabelBrowserTab* tab = tabs[index];
    if (x < NSMidX(tab.tabItemView.frame)) {
      return index;
    }
  }
  return tabs.count;
}

- (NSUInteger)targetIndexForMovingItemAtIndex:(NSUInteger)currentIndex
                             toInsertionIndex:(NSUInteger)insertionIndex
                                    itemCount:(NSUInteger)itemCount {
  if (NSNotFound == currentIndex || 0 == itemCount) {
    return 0;
  }

  NSUInteger targetIndex = MIN(insertionIndex, itemCount);
  if (targetIndex > currentIndex) {
    targetIndex--;
  }
  return targetIndex;
}

@end
