#ifndef BABEL_CHROME_BROWSER_STABLE_URL_TAB_RELOADER_H_
#define BABEL_CHROME_BROWSER_STABLE_URL_TAB_RELOADER_H_

#import <Foundation/Foundation.h>

@class BabelBrowserGroup;
@class BabelBrowserTab;
@class BabelRuntimeRefreshTabMatcher;
@class BabelStableServerURLResolver;

typedef NSString* (^BabelStableURLNavigationResolverBlock)(NSString* stableURLString);

/**
 * Reloads tabs that point to stable BabelChrome URLs.
 */
@interface BabelStableURLTabReloader : NSObject

/**
 * Creates a stable URL tab reloader.
 *
 * @param stableServerURLResolver The resolver for stable Project Launcher URLs.
 * @param refreshTabMatcher The matcher used to select tabs to refresh.
 * @param navigationResolverBlock The block resolving stable URLs to runtime URLs.
 * @return The initialized reloader.
 */
- (instancetype)initWithStableServerURLResolver:(BabelStableServerURLResolver*)stableServerURLResolver
                              refreshTabMatcher:(BabelRuntimeRefreshTabMatcher*)refreshTabMatcher
                        navigationResolverBlock:(BabelStableURLNavigationResolverBlock)navigationResolverBlock;

/**
 * Reloads tabs matching a stable URL string.
 *
 * @param requestedURLString The stable requested URL.
 * @param excludedTab The tab to skip.
 * @param groups The groups to inspect.
 * @return YES when at least one tab was changed.
 */
- (BOOL)reloadTabsWithRequestedURLString:(NSString*)requestedURLString
                            excludingTab:(BabelBrowserTab*)excludedTab
                                  groups:(NSArray<BabelBrowserGroup*>*)groups;

/**
 * Reloads all server tabs matching project identifiers.
 *
 * @param projectIdentifiers The project identifiers to refresh.
 * @param groups The groups to inspect.
 * @return YES when at least one tab was changed.
 */
- (BOOL)reloadServerTabsWithProjectIdentifiers:(NSArray<NSString*>*)projectIdentifiers
                                        groups:(NSArray<BabelBrowserGroup*>*)groups;

@end

#endif
