#ifndef BABEL_CHROME_BROWSER_LOCAL_DROP_SUPPORT_RESOLVER_H_
#define BABEL_CHROME_BROWSER_LOCAL_DROP_SUPPORT_RESOLVER_H_

#import <Foundation/Foundation.h>

@class BabelModuleActionService;

/**
 * Resolves whether a URL belongs to a module accepting local path drops.
 */
@interface BabelLocalDropSupportResolver : NSObject

/**
 * Creates a local drop support resolver.
 *
 * @param moduleActionService The module action service used to resolve runtime module URLs.
 *
 * @return The initialized resolver.
 */
- (instancetype)initWithModuleActionService:(BabelModuleActionService*)moduleActionService;

/**
 * Returns whether the URL string supports local path drops.
 *
 * @param urlString The URL string to inspect.
 *
 * @return YES when an enabled module route with the local drop hook matches the URL.
 */
- (BOOL)URLStringSupportsLocalDropPaths:(NSString*)urlString;

@end

#endif
