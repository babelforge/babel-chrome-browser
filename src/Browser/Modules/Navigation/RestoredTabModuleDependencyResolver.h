#ifndef BABEL_CHROME_BROWSER_MODULES_NAVIGATION_RESTORED_TAB_MODULE_DEPENDENCY_RESOLVER_H_
#define BABEL_CHROME_BROWSER_MODULES_NAVIGATION_RESTORED_TAB_MODULE_DEPENDENCY_RESOLVER_H_

#import <Foundation/Foundation.h>

@class BabelModuleActionService;
@class BabelStableServerURLResolver;
@class BabelStableViewerURLResolver;

/**
 * Resolves the module needed before a restored tab can load its first page.
 */
@interface BabelRestoredTabModuleDependencyResolver : NSObject

/**
 * Creates a restored tab module dependency resolver.
 *
 * @param moduleActionService The module action service.
 * @param stableViewerURLResolver The stable viewer URL resolver.
 * @param stableServerURLResolver The stable server URL resolver.
 * @return The initialized resolver.
 */
- (instancetype)initWithModuleActionService:(BabelModuleActionService*)moduleActionService
                    stableViewerURLResolver:(BabelStableViewerURLResolver*)stableViewerURLResolver
                     stableServerURLResolver:(BabelStableServerURLResolver*)stableServerURLResolver;

/**
 * Returns the module identifier required by a restored URL.
 *
 * @param urlString The stable or runtime URL string stored in the restored tab.
 * @return The module identifier, or nil when the URL does not depend on a module runtime.
 */
- (NSString*)moduleIdentifierForRestoredURLString:(NSString*)urlString;

@end

#endif
