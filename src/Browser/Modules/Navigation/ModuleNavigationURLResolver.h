#ifndef BABEL_CHROME_BROWSER_MODULE_NAVIGATION_URL_RESOLVER_H_
#define BABEL_CHROME_BROWSER_MODULE_NAVIGATION_URL_RESOLVER_H_

#import <Foundation/Foundation.h>

@class BabelModuleActionService;

/**
 * Resolves stable BabelChrome module URLs into current local service URLs.
 */
@interface BabelModuleNavigationURLResolver : NSObject

/**
 * Creates a module navigation URL resolver.
 *
 * @param moduleActionService The module action service used to resolve custom routes.
 * @return The initialized module navigation URL resolver.
 */
- (instancetype)initWithModuleActionService:(BabelModuleActionService*)moduleActionService;

/**
 * Returns the current local service URL for a stable BabelChrome module URL.
 *
 * @param urlString The stable BabelChrome URL string.
 * @return The local service URL string, or nil when the URL cannot be resolved.
 */
- (NSString*)navigationURLStringForStableBabelChromeURLString:(NSString*)urlString;

@end

#endif
