#import "Browser/State/Sessions/GroupSessionStore.h"

#import "Browser/UI/Models/BrowserModels.h"
#import "Configuration/Configuration.h"

@implementation BabelRestoredTabState

@synthesize identifier;
@synthesize urlString;
@synthesize requestedURLString;
@synthesize title;
@synthesize parentTabIdentifier;

@end

@implementation BabelRestoredGroupState

@synthesize identifier;
@synthesize name;
@synthesize selectedTabIdentifier;
@synthesize tabs;

@end

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

- (NSArray<BabelRestoredGroupState*>*)restoredGroupStatesFromState:(NSDictionary*)state {
  NSArray* groupStates = state[@"groups"];
  if (![groupStates isKindOfClass:NSArray.class]) {
    return @[];
  }

  NSMutableArray<BabelRestoredGroupState*>* restoredGroups = [NSMutableArray array];
  for (NSDictionary* groupState in groupStates) {
    BabelRestoredGroupState* restoredGroup = [self restoredGroupStateFromDictionary:groupState];
    if (restoredGroup) {
      [restoredGroups addObject:restoredGroup];
    }
  }
  return restoredGroups;
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
 * Converts one persisted group dictionary into a restored group state.
 *
 * @param groupState The persisted group dictionary.
 *
 * @return The restored group state, or nil when the dictionary is invalid.
 */
- (BabelRestoredGroupState*)restoredGroupStateFromDictionary:(NSDictionary*)groupState {
  if (![groupState isKindOfClass:NSDictionary.class]) {
    return nil;
  }

  NSString* groupName = groupState[@"name"];
  NSString* groupIdentifier = groupState[@"id"];
  if (0 == groupName.length || 0 == groupIdentifier.length) {
    return nil;
  }

  BabelRestoredGroupState* restoredGroup = [[BabelRestoredGroupState alloc] init];
  restoredGroup.identifier = groupIdentifier;
  restoredGroup.name = groupName;
  restoredGroup.selectedTabIdentifier = groupState[@"selectedTabId"];
  restoredGroup.tabs = [self restoredTabStatesFromArray:groupState[@"tabs"]];
  return restoredGroup;
}

/**
 * Converts persisted tab dictionaries into restored tab states.
 *
 * @param tabStates The persisted tab dictionary array.
 *
 * @return The valid restored tab states.
 */
- (NSArray<BabelRestoredTabState*>*)restoredTabStatesFromArray:(NSArray*)tabStates {
  if (![tabStates isKindOfClass:NSArray.class]) {
    return @[];
  }

  NSMutableArray<BabelRestoredTabState*>* restoredTabs = [NSMutableArray array];
  for (NSDictionary* tabState in tabStates) {
    BabelRestoredTabState* restoredTab = [self restoredTabStateFromDictionary:tabState];
    if (restoredTab) {
      [restoredTabs addObject:restoredTab];
    }
  }
  return restoredTabs;
}

/**
 * Converts one persisted tab dictionary into a restored tab state.
 *
 * @param tabState The persisted tab dictionary.
 *
 * @return The restored tab state, or nil when the dictionary is invalid.
 */
- (BabelRestoredTabState*)restoredTabStateFromDictionary:(NSDictionary*)tabState {
  if (![tabState isKindOfClass:NSDictionary.class]) {
    return nil;
  }

  NSString* urlString = tabState[@"url"];
  if (0 == urlString.length) {
    return nil;
  }

  BabelRestoredTabState* restoredTab = [[BabelRestoredTabState alloc] init];
  restoredTab.identifier = tabState[@"id"] ?: NSUUID.UUID.UUIDString;
  restoredTab.urlString = urlString;
  restoredTab.requestedURLString = tabState[@"requestedUrl"] ?: urlString;
  restoredTab.title = tabState[@"title"] ?: urlString;
  restoredTab.parentTabIdentifier = tabState[@"parentTabId"];
  return restoredTab;
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
