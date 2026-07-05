#import "Browser/Tabs/Movement/BrowserTabMoveCoordinator.h"

#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/Tabs/Movement/TabDragCoordinator.h"

@implementation BabelBrowserTabMoveResult

@synthesize didMove;
@synthesize movedAcrossGroups;

@end

@implementation BabelBrowserTabMoveCoordinator {
  BabelTabDragCoordinator* dragCoordinator_;
}

- (instancetype)initWithDragCoordinator:(BabelTabDragCoordinator*)dragCoordinator {
  self = [super init];
  if (self) {
    dragCoordinator_ = dragCoordinator;
  }
  return self;
}

- (BabelBrowserTabMoveResult*)moveTab:(BabelBrowserTab*)tab
                            fromGroup:(BabelBrowserGroup*)sourceGroup
                              toGroup:(BabelBrowserGroup*)destinationGroup
                        insertionIndex:(NSUInteger)insertionIndex {
  BabelBrowserTabMoveResult* result = [[BabelBrowserTabMoveResult alloc] init];
  if (!tab || !sourceGroup || !destinationGroup) {
    return result;
  }

  if (sourceGroup == destinationGroup) {
    [self moveTabInsideGroup:tab
                       group:destinationGroup
              insertionIndex:insertionIndex
                      result:result];
    return result;
  }

  [sourceGroup.tabs removeObject:tab];
  if ([sourceGroup.selectedTabIdentifier isEqualToString:tab.identifier]) {
    sourceGroup.selectedTabIdentifier = sourceGroup.tabs.lastObject.identifier ?: @"";
  }

  NSUInteger targetIndex = MIN(insertionIndex, destinationGroup.tabs.count);
  [destinationGroup.tabs insertObject:tab atIndex:targetIndex];
  destinationGroup.selectedTabIdentifier = tab.identifier;
  result.didMove = YES;
  result.movedAcrossGroups = YES;
  return result;
}

/**
 * Moves a tab inside its current group.
 *
 * @param tab The tab to move.
 * @param group The containing group.
 * @param insertionIndex The requested insertion index.
 * @param result The mutable result to update.
 */
- (void)moveTabInsideGroup:(BabelBrowserTab*)tab
                     group:(BabelBrowserGroup*)group
            insertionIndex:(NSUInteger)insertionIndex
                    result:(BabelBrowserTabMoveResult*)result {
  NSUInteger currentIndex = [group.tabs indexOfObject:tab];
  if (currentIndex == NSNotFound) {
    return;
  }

  NSUInteger targetIndex = [dragCoordinator_ targetIndexForMovingItemAtIndex:currentIndex
                                                            toInsertionIndex:insertionIndex
                                                                   itemCount:group.tabs.count];
  if (targetIndex == currentIndex) {
    return;
  }

  [group.tabs removeObjectAtIndex:currentIndex];
  targetIndex = MIN(targetIndex, group.tabs.count);
  [group.tabs insertObject:tab atIndex:targetIndex];
  result.didMove = YES;
  result.movedAcrossGroups = NO;
}

@end
