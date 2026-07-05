#ifndef BABEL_CHROME_BROWSER_SESSION_RESTORATION_COORDINATOR_H_
#define BABEL_CHROME_BROWSER_SESSION_RESTORATION_COORDINATOR_H_

#import <Foundation/Foundation.h>

@class BabelBrowserGroup;
@class BabelBrowserTab;
@class BabelGroupSessionStore;
@class BabelTabContentViewAttacher;
@class NSView;

typedef BabelBrowserGroup* (^BabelSessionGroupLookupProvider)(NSString* identifier);
typedef BabelBrowserGroup* (^BabelSessionGroupCreateHandler)(NSString* name, NSString* identifier);
typedef BabelBrowserTab* (^BabelSessionTabLookupProvider)(NSString* urlString, BabelBrowserGroup* group);
typedef BabelBrowserTab* (^BabelSessionTabCreateHandler)(NSString* urlString, NSString* identifier, NSString* title);
typedef NSString* (^BabelSessionStableURLResolver)(NSString* urlString);
typedef BOOL (^BabelSessionStableURLPredicate)(NSString* urlString);
typedef void (^BabelSessionGroupSelectionHandler)(BabelBrowserGroup* group);
typedef void (^BabelSessionStateSaveHandler)(void);

/**
 * Restores persisted groups and native tab models from stored browser session state.
 */
@interface BabelBrowserSessionRestorationCoordinator : NSObject

/**
 * Creates a browser session restoration coordinator.
 *
 * @param groupSessionStore The persisted group session store.
 * @param tabContentViewAttacher The native tab content attacher.
 * @param pagesPanel The panel that owns page containers.
 * @param defaultGroupIdentifier The fallback default group identifier.
 * @param defaultGroupName The fallback default group name.
 * @param groupLookupProvider The group lookup provider.
 * @param groupCreateHandler The group creation callback.
 * @param tabLookupProvider The existing tab lookup provider.
 * @param tabCreateHandler The tab creation callback.
 * @param stableURLResolver The resolver for stable BabelChrome URLs.
 * @param stableURLPredicate The predicate for stable BabelChrome URLs.
 * @param selectGroupHandler The callback used to select the restored group.
 * @param saveStateHandler The callback used to persist restored state.
 * @return The initialized coordinator.
 */
- (instancetype)initWithGroupSessionStore:(BabelGroupSessionStore*)groupSessionStore
                  tabContentViewAttacher:(BabelTabContentViewAttacher*)tabContentViewAttacher
                              pagesPanel:(NSView*)pagesPanel
                  defaultGroupIdentifier:(NSString*)defaultGroupIdentifier
                         defaultGroupName:(NSString*)defaultGroupName
                     groupLookupProvider:(BabelSessionGroupLookupProvider)groupLookupProvider
                       groupCreateHandler:(BabelSessionGroupCreateHandler)groupCreateHandler
                        tabLookupProvider:(BabelSessionTabLookupProvider)tabLookupProvider
                         tabCreateHandler:(BabelSessionTabCreateHandler)tabCreateHandler
                        stableURLResolver:(BabelSessionStableURLResolver)stableURLResolver
                       stableURLPredicate:(BabelSessionStableURLPredicate)stableURLPredicate
                       selectGroupHandler:(BabelSessionGroupSelectionHandler)selectGroupHandler
                         saveStateHandler:(BabelSessionStateSaveHandler)saveStateHandler;

/**
 * Restores the selected group after all persisted groups have been created.
 *
 * @param state The persisted session state.
 */
- (void)restoreSelectedGroupFromState:(NSDictionary*)state;

/**
 * Restores persisted groups and native tab shells.
 *
 * @param state The persisted session state.
 */
- (void)restoreGroupsFromState:(NSDictionary*)state;

@end

#endif
