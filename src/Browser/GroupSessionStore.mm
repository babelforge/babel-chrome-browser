#import "Browser/GroupSessionStore.h"

#import "Browser/BrowserModels.h"
#import "Configuration/Configuration.h"

@implementation BabelGroupSessionStore

- (NSData*)persistedGroupsAndTabsStateData {
  return [NSData dataWithContentsOfURL:BabelChromeConfiguration.groupsStateFileURL];
}

- (NSDictionary*)persistedGroupsAndTabsStateFromData:(NSData*)data {
  if (0 == data.length) {
    return @{};
  }

  NSError* error = nil;
  NSDictionary* state = [NSJSONSerialization JSONObjectWithData:data
                                                        options:0
                                                          error:&error];
  return [state isKindOfClass:NSDictionary.class] ? state : @{};
}

- (NSString*)selectedGroupIdentifierFromState:(NSDictionary*)state
                           fallbackIdentifier:(NSString*)fallbackIdentifier {
  NSString* selectedGroupIdentifier = state[@"selectedGroupId"];
  return selectedGroupIdentifier.length > 0 ? selectedGroupIdentifier : fallbackIdentifier;
}

- (void)saveGroups:(NSArray<BabelBrowserGroup*>*)groups
    selectedGroupIdentifier:(NSString*)selectedGroupIdentifier
fallbackSelectedGroupIdentifier:(NSString*)fallbackSelectedGroupIdentifier
    excludingTabsMatching:(BabelGroupSessionTabExclusionBlock)exclusionBlock {
  NSMutableArray<NSDictionary*>* groupStates = [NSMutableArray array];
  for (BabelBrowserGroup* group in groups) {
    [groupStates addObject:[self stateForGroup:group excludingTabsMatching:exclusionBlock]];
  }

  NSDictionary* state = @{
    @"selectedGroupId": selectedGroupIdentifier ?: fallbackSelectedGroupIdentifier ?: @"",
    @"groups": groupStates
  };

  NSURL* stateURL = BabelChromeConfiguration.groupsStateFileURL;
  [NSFileManager.defaultManager createDirectoryAtURL:stateURL.URLByDeletingLastPathComponent
                         withIntermediateDirectories:YES
                                          attributes:nil
                                               error:nil];
  NSData* data = [NSJSONSerialization dataWithJSONObject:state
                                                 options:NSJSONWritingPrettyPrinted
                                                   error:nil];
  [data writeToURL:stateURL atomically:YES];
}

/**
 * Serializes one group into the persisted JSON shape.
 *
 * @param group The group to serialize.
 * @param exclusionBlock The block deciding whether a tab should be excluded.
 *
 * @return The persisted group dictionary.
 */
- (NSDictionary*)stateForGroup:(BabelBrowserGroup*)group
         excludingTabsMatching:(BabelGroupSessionTabExclusionBlock)exclusionBlock {
  NSMutableArray<NSDictionary*>* tabStates = [NSMutableArray array];
  for (BabelBrowserTab* tab in group.tabs) {
    if (exclusionBlock && exclusionBlock(tab)) {
      continue;
    }
    [tabStates addObject:[self stateForTab:tab]];
  }

  return @{
    @"id": group.identifier ?: @"",
    @"name": group.name ?: @"",
    @"selectedTabId": group.selectedTabIdentifier ?: @"",
    @"tabs": tabStates
  };
}

/**
 * Serializes one tab into the persisted JSON shape.
 *
 * @param tab The tab to serialize.
 *
 * @return The persisted tab dictionary.
 */
- (NSDictionary*)stateForTab:(BabelBrowserTab*)tab {
  return @{
    @"id": tab.identifier ?: @"",
    @"url": tab.urlString ?: @"",
    @"requestedUrl": tab.requestedURLString ?: tab.urlString ?: @"",
    @"title": tab.title ?: tab.urlString ?: @"",
    @"parentTabId": tab.parentTabIdentifier ?: @""
  };
}

@end
