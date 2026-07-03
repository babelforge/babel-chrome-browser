#import "Browser/BrowserTabCollection.h"

#import "Browser/BrowserModels.h"

@implementation BabelBrowserTabCollection

- (BabelBrowserTab*)tabWithIdentifier:(NSString*)identifier
                              inGroup:(BabelBrowserGroup*)group {
  if (identifier.length == 0) {
    return nil;
  }

  for (BabelBrowserTab* tab in group.tabs) {
    if ([tab.identifier isEqualToString:identifier]) {
      return tab;
    }
  }
  return nil;
}

- (BabelBrowserTab*)tabWithIdentifier:(NSString*)identifier
                               groups:(NSArray<BabelBrowserGroup*>*)groups {
  for (BabelBrowserGroup* group in groups) {
    BabelBrowserTab* tab = [self tabWithIdentifier:identifier inGroup:group];
    if (tab) {
      return tab;
    }
  }
  return nil;
}

- (BabelBrowserGroup*)groupContainingTab:(BabelBrowserTab*)tab
                                  groups:(NSArray<BabelBrowserGroup*>*)groups {
  if (!tab) {
    return nil;
  }

  for (BabelBrowserGroup* group in groups) {
    if ([group.tabs containsObject:tab]) {
      return group;
    }
  }
  return nil;
}

- (NSArray<NSString*>*)tabIdentifiersForGroup:(BabelBrowserGroup*)group {
  NSMutableArray<NSString*>* tabIdentifiers = [NSMutableArray array];
  for (BabelBrowserTab* tab in group.tabs) {
    if (tab.identifier.length > 0) {
      [tabIdentifiers addObject:tab.identifier];
    }
  }
  return tabIdentifiers;
}

- (NSDictionary<NSString*, NSString*>*)parentIdentifiersByTabIdentifierForGroup:(BabelBrowserGroup*)group {
  NSMutableDictionary<NSString*, NSString*>* parentIdentifiers = [NSMutableDictionary dictionary];
  for (BabelBrowserTab* tab in group.tabs) {
    if (tab.identifier.length > 0 && tab.parentTabIdentifier.length > 0) {
      parentIdentifiers[tab.identifier] = tab.parentTabIdentifier;
    }
  }
  return parentIdentifiers;
}

@end
