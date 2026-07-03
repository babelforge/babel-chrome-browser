#import "Browser/BrowserTabInsertionCoordinator.h"

#import "Browser/BrowserModels.h"
#import "Browser/BrowserTabCollection.h"
#import "Browser/TabPlacementPolicy.h"

@implementation BabelBrowserTabInsertionCoordinator {
  BabelTabPlacementPolicy* placementPolicy_;
  BabelBrowserTabCollection* tabCollection_;
}

- (instancetype)initWithPlacementPolicy:(BabelTabPlacementPolicy*)placementPolicy
                          tabCollection:(BabelBrowserTabCollection*)tabCollection {
  self = [super init];
  if (self) {
    placementPolicy_ = placementPolicy;
    tabCollection_ = tabCollection;
  }
  return self;
}

- (void)insertTab:(BabelBrowserTab*)tab
          inGroup:(BabelBrowserGroup*)group
        parentTab:(BabelBrowserTab*)parentTab
         strategy:(NSString*)strategy
respectingUserStrategy:(BOOL)respectingUserStrategy {
  if (!tab || !group) {
    return;
  }

  NSArray<NSString*>* tabIdentifiers = [tabCollection_ tabIdentifiersForGroup:group];
  NSString* parentTabIdentifier = parentTab.identifier ?: @"";
  if ([placementPolicy_ shouldAppendTabWithParentIdentifier:parentTabIdentifier
                                             tabIdentifiers:tabIdentifiers
                                                   strategy:strategy
                                     respectingUserStrategy:respectingUserStrategy]) {
    [group.tabs addObject:tab];
    return;
  }

  NSDictionary<NSString*, NSString*>* parentIdentifiers =
      [tabCollection_ parentIdentifiersByTabIdentifierForGroup:group];
  NSUInteger insertionIndex =
      [placementPolicy_ insertionIndexForNewChildOfParentIdentifier:parentTabIdentifier
                                                     tabIdentifiers:tabIdentifiers
                                   parentIdentifiersByTabIdentifier:parentIdentifiers
                                                           strategy:strategy];
  [group.tabs insertObject:tab atIndex:MIN(insertionIndex, group.tabs.count)];
}

@end
