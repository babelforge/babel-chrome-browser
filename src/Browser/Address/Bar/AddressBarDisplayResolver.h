#ifndef BABEL_CHROME_BROWSER_ADDRESS_BAR_DISPLAY_RESOLVER_H_
#define BABEL_CHROME_BROWSER_ADDRESS_BAR_DISPLAY_RESOLVER_H_

#import <Foundation/Foundation.h>

@class BabelBrowserTab;
@class BabelModuleActionService;
@class BabelStableViewerURLResolver;

/**
 * Checks whether a tab displays an internal BabelChrome page.
 *
 * @param tab The tab to inspect.
 *
 * @return YES when the tab is an internal page.
 */
typedef BOOL (^BabelInternalPageTabPredicateBlock)(BabelBrowserTab* tab);

/**
 * Resolves address bar display values for browser tabs.
 */
@interface BabelAddressBarDisplayResolver : NSObject

/**
 * Initializes the resolver.
 *
 * @param stableViewerURLResolver The stable viewer URL resolver.
 * @param moduleActionService The module action service.
 * @param internalPageTabPredicate The block checking internal page tabs.
 *
 * @return The initialized resolver.
 */
- (instancetype)initWithStableViewerURLResolver:(BabelStableViewerURLResolver*)stableViewerURLResolver
                            moduleActionService:(BabelModuleActionService*)moduleActionService
                       internalPageTabPredicate:(BabelInternalPageTabPredicateBlock)internalPageTabPredicate;

/**
 * Returns the URL string that should be displayed in the address bar for a tab.
 *
 * @param tab The tab to inspect.
 *
 * @return The display URL string.
 */
- (NSString*)displayURLStringForTab:(BabelBrowserTab*)tab;

/**
 * Returns the viewer badge metadata for a tab.
 *
 * @param tab The tab to inspect.
 *
 * @return The badge metadata, or nil when no badge should be displayed.
 */
- (NSDictionary*)addressBadgeForTab:(BabelBrowserTab*)tab;

@end

#endif
