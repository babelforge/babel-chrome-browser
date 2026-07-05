#ifndef BABEL_CHROME_BROWSER_GROUP_SESSION_STORE_H_
#define BABEL_CHROME_BROWSER_GROUP_SESSION_STORE_H_

#import <Foundation/Foundation.h>

@class BabelBrowserGroup;
@class BabelBrowserTab;

/**
 * Represents one tab restored from persisted session state.
 */
@interface BabelRestoredTabState : NSObject

@property(nonatomic, strong) NSString* identifier;
@property(nonatomic, strong) NSString* urlString;
@property(nonatomic, strong) NSString* requestedURLString;
@property(nonatomic, strong) NSString* title;
@property(nonatomic, strong) NSString* parentTabIdentifier;

@end

/**
 * Represents one group restored from persisted session state.
 */
@interface BabelRestoredGroupState : NSObject

@property(nonatomic, strong) NSString* identifier;
@property(nonatomic, strong) NSString* name;
@property(nonatomic, strong) NSString* selectedTabIdentifier;
@property(nonatomic, strong) NSArray<BabelRestoredTabState*>* tabs;

@end

/**
 * Decides whether a tab should be excluded from persisted group session state.
 *
 * @param tab The tab being serialized.
 *
 * @return YES when the tab should not be persisted.
 */
typedef BOOL (^BabelGroupSessionTabExclusionBlock)(BabelBrowserTab* tab);

/**
 * Persists and reads the browser group and tab session state.
 */
@interface BabelGroupSessionStore : NSObject

/**
 * Reads the persisted group session state data.
 *
 * @return The persisted JSON data, or nil when no state exists.
 */
- (NSData*)persistedGroupsAndTabsStateData;

/**
 * Parses persisted group session state data.
 *
 * @param data The persisted JSON data.
 *
 * @return A dictionary state, or an empty dictionary when data is missing or invalid.
 */
- (NSDictionary*)persistedGroupsAndTabsStateFromData:(NSData*)data;

/**
 * Reads the selected group identifier from persisted state.
 *
 * @param state The persisted group session state.
 * @param fallbackIdentifier The identifier to return when no selected group is persisted.
 *
 * @return The selected group identifier.
 */
- (NSString*)selectedGroupIdentifierFromState:(NSDictionary*)state
                           fallbackIdentifier:(NSString*)fallbackIdentifier;

/**
 * Reads restored group state objects from persisted state.
 *
 * @param state The persisted group session state.
 *
 * @return The valid restored group states.
 */
- (NSArray<BabelRestoredGroupState*>*)restoredGroupStatesFromState:(NSDictionary*)state;

/**
 * Saves group and tab session state.
 *
 * @param groups The groups to serialize.
 * @param selectedGroupIdentifier The currently selected group identifier.
 * @param fallbackSelectedGroupIdentifier The fallback identifier used when no selected group exists.
 * @param exclusionBlock The block deciding whether a tab should be excluded.
 */
- (void)saveGroups:(NSArray<BabelBrowserGroup*>*)groups
    selectedGroupIdentifier:(NSString*)selectedGroupIdentifier
fallbackSelectedGroupIdentifier:(NSString*)fallbackSelectedGroupIdentifier
    excludingTabsMatching:(BabelGroupSessionTabExclusionBlock)exclusionBlock;

@end

#endif
