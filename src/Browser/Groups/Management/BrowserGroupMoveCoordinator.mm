#import "Browser/Groups/Management/BrowserGroupMoveCoordinator.h"

#import "Browser/UI/Models/BrowserModels.h"

@implementation BabelBrowserGroupMoveCoordinator

- (BOOL)moveGroup:(BabelBrowserGroup*)group
         inGroups:(NSMutableArray<BabelBrowserGroup*>*)groups
 insertionIndex:(NSUInteger)insertionIndex {
  if (!group || 0 == groups.count) {
    return NO;
  }

  NSUInteger currentIndex = [groups indexOfObject:group];
  if (currentIndex == NSNotFound) {
    return NO;
  }

  NSUInteger targetIndex = insertionIndex;
  if (targetIndex > currentIndex) {
    targetIndex--;
  }
  targetIndex = MIN(targetIndex, groups.count - 1);
  if (targetIndex == currentIndex) {
    return NO;
  }

  [groups removeObjectAtIndex:currentIndex];
  [groups insertObject:group atIndex:targetIndex];
  return YES;
}

@end
