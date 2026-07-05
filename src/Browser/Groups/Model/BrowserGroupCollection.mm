#import "Browser/Groups/Model/BrowserGroupCollection.h"

#import "Browser/UI/Models/BrowserModels.h"

@implementation BabelBrowserGroupCollection

- (BabelBrowserGroup*)groupWithIdentifier:(NSString*)identifier
                                   groups:(NSArray<BabelBrowserGroup*>*)groups {
  if (identifier.length == 0) {
    return nil;
  }

  for (BabelBrowserGroup* group in groups) {
    if ([group.identifier isEqualToString:identifier]) {
      return group;
    }
  }
  return nil;
}

- (BabelBrowserGroup*)groupWithName:(NSString*)name
                             groups:(NSArray<BabelBrowserGroup*>*)groups {
  for (BabelBrowserGroup* group in groups) {
    if ([group.name isEqualToString:name]) {
      return group;
    }
  }
  return nil;
}

- (NSString*)nextManualGroupNameForGroups:(NSArray<BabelBrowserGroup*>*)groups {
  NSUInteger index = 1;
  while ([self groupWithName:[NSString stringWithFormat:@"Group %lu", (unsigned long)index]
                      groups:groups]) {
    index++;
  }
  return [NSString stringWithFormat:@"Group %lu", (unsigned long)index];
}

- (BabelBrowserGroup*)groupToSelectAfterDeletingGroupAtIndex:(NSUInteger)groupIndex
                                                      groups:(NSArray<BabelBrowserGroup*>*)groups {
  if (groups.count <= 1) {
    return nil;
  }

  NSUInteger nextIndex = groupIndex > 0 ? groupIndex - 1 : 1;
  return groups[nextIndex];
}

@end
