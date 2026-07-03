#import "Browser/GroupListCoordinator.h"

#import "Browser/BrowserModels.h"
#import "Browser/BrowserTheme.h"
#import "Browser/BrowserViews.h"

static const CGFloat kBabelGroupListRowHeight = 30.0;
static const CGFloat kBabelGroupListRowPitch = 34.0;

@implementation BabelGroupListCoordinator

- (NSColor*)accentColorForGroup:(BabelBrowserGroup*)group
                         groups:(NSArray<BabelBrowserGroup*>*)groups
                           view:(NSView*)view {
  NSArray<NSColor*>* palette = [BabelTheme.sharedTheme colorListForToken:@"group.accentPalette"
                                                                    view:view];
  if (0 == palette.count) {
    palette = @[NSColor.controlAccentColor];
  }

  NSUInteger groupIndex = [groups indexOfObject:group];
  if (NSNotFound == groupIndex) {
    return palette.firstObject;
  }
  return palette[groupIndex % palette.count];
}

- (void)layoutGroups:(NSArray<BabelBrowserGroup*>*)groups
    inGroupsListView:(NSView*)groupsListView
           collapsed:(BOOL)collapsed
                view:(NSView*)view {
  CGFloat y = 0.0;
  CGFloat width = MAX(0.0, groupsListView.bounds.size.width);
  for (BabelBrowserGroup* group in groups) {
    group.groupItemView.accentColor = [self accentColorForGroup:group groups:groups view:view];
    group.groupItemView.collapsed = collapsed;
    group.groupItemView.frame = NSMakeRect(0, y, width, kBabelGroupListRowHeight);
    y += kBabelGroupListRowPitch;
  }
}

- (NSUInteger)insertionIndexForListY:(CGFloat)y groupCount:(NSUInteger)groupCount {
  if (0 == groupCount) {
    return 0;
  }

  NSInteger targetIndex = (NSInteger)floor((y + (kBabelGroupListRowPitch / 2.0)) /
                                           kBabelGroupListRowPitch);
  if (targetIndex < 0) {
    return 0;
  }
  return MIN((NSUInteger)targetIndex, groupCount);
}

@end
