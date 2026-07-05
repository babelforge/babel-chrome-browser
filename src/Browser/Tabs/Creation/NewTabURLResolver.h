#ifndef BABEL_CHROME_BROWSER_NEW_TAB_URL_RESOLVER_H_
#define BABEL_CHROME_BROWSER_NEW_TAB_URL_RESOLVER_H_

#import <Foundation/Foundation.h>

/**
 * Resolves a supported viewer URL for a source URL.
 *
 * @param urlString The source URL string.
 *
 * @return The stable viewer URL string, or nil when no viewer applies.
 */
typedef NSString* (^BabelSupportedViewerURLResolverBlock)(NSString* urlString);

/**
 * Resolves the navigation URL for a stable BabelChrome URL.
 *
 * @param urlString The requested URL string.
 *
 * @return The runtime navigation URL string, or nil when it cannot be resolved.
 */
typedef NSString* (^BabelStableNavigationURLResolverBlock)(NSString* urlString);

/**
 * Checks whether a URL string is a stable viewer URL.
 *
 * @param urlString The URL string to inspect.
 *
 * @return YES when the URL is a stable viewer URL.
 */
typedef BOOL (^BabelStableViewerURLPredicateBlock)(NSString* urlString);

/**
 * Represents the URL pair used to open a new tab.
 */
@interface BabelNewTabURLResolution : NSObject

@property(nonatomic, assign) BOOL shouldOpen;
@property(nonatomic, strong) NSString* requestedURLString;
@property(nonatomic, strong) NSString* navigationURLString;

@end

/**
 * Resolves requested and navigation URLs for new tabs.
 */
@interface BabelNewTabURLResolver : NSObject

/**
 * Initializes the resolver.
 *
 * @param supportedViewerURLResolver The block resolving supported viewer URLs.
 * @param stableNavigationURLResolver The block resolving stable runtime navigation URLs.
 * @param stableViewerURLPredicate The block checking stable viewer URLs.
 *
 * @return The initialized resolver.
 */
- (instancetype)initWithSupportedViewerURLResolver:(BabelSupportedViewerURLResolverBlock)supportedViewerURLResolver
                      stableNavigationURLResolver:(BabelStableNavigationURLResolverBlock)stableNavigationURLResolver
                         stableViewerURLPredicate:(BabelStableViewerURLPredicateBlock)stableViewerURLPredicate;

/**
 * Resolves the requested and navigation URLs for a new tab.
 *
 * @param urlString The user or page supplied URL string.
 *
 * @return The resolution result.
 */
- (BabelNewTabURLResolution*)resolveURLString:(NSString*)urlString;

@end

#endif
