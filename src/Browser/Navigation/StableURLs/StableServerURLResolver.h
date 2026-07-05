#ifndef BABEL_CHROME_BROWSER_STABLE_SERVER_URL_RESOLVER_H_
#define BABEL_CHROME_BROWSER_STABLE_SERVER_URL_RESOLVER_H_

#import <Foundation/Foundation.h>

/**
 * Resolves stable BabelChrome server URLs independently from runtime ports.
 */
@interface BabelStableServerURLResolver : NSObject

/**
 * Checks whether the URL string targets a stable BabelChrome URL.
 *
 * @param urlString The URL string to inspect.
 * @return YES when the URL uses the babelchrome scheme with a non-empty host.
 */
- (BOOL)isStableBabelChromeURLString:(NSString*)urlString;

/**
 * Checks whether the URL string targets a stable Project Launcher server URL.
 *
 * @param urlString The URL string to inspect.
 * @return YES when the URL targets babelchrome://server/<project>.
 */
- (BOOL)isStableServerURLString:(NSString*)urlString;

/**
 * Checks whether a stable server URL requests a server start.
 *
 * @param urlString The stable server URL string.
 * @return YES when the internal start query parameter is present and truthy.
 */
- (BOOL)stableServerURLStringRequestsStart:(NSString*)urlString;

/**
 * Extracts stable URLs that should be refreshed after a runtime action.
 *
 * @param urlString The stable URL string containing internal refresh query parameters.
 * @return The stable URL strings requested for refresh.
 */
- (NSArray<NSString*>*)refreshURLStringsForStableURLString:(NSString*)urlString;

/**
 * Removes internal BabelChrome server query parameters from a stable URL.
 *
 * @param urlString The stable URL string.
 * @return The URL string without internal start/refresh parameters.
 */
- (NSString*)stableURLStringByRemovingInternalQueryParameters:(NSString*)urlString;

/**
 * Extracts the encoded project path from stable server URL components.
 *
 * @param components The stable server URL components.
 * @return The encoded project path.
 */
- (NSString*)stableServerProjectPathForURLComponents:(NSURLComponents*)components;

/**
 * Builds the stable reload URL for a tab whose runtime URL may contain a deeper path.
 *
 * @param requestedURLString The tab requested stable URL.
 * @param actualURLString The tab current runtime URL.
 * @return The stable URL that should be reloaded.
 */
- (NSString*)stableServerReloadURLStringForRequestedURLString:(NSString*)requestedURLString
                                             actualURLString:(NSString*)actualURLString;

/**
 * Extracts the stable server project identifier.
 *
 * @param urlString The stable server URL string.
 * @return The decoded project identifier, or an empty string when unavailable.
 */
- (NSString*)serverProjectIdentifierForStableURLString:(NSString*)urlString;

@end

#endif
