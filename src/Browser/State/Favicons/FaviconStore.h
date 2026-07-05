#ifndef BABEL_CHROME_BROWSER_FAVICON_STORE_H_
#define BABEL_CHROME_BROWSER_FAVICON_STORE_H_

#import <Cocoa/Cocoa.h>

/**
 * Persists and resolves favicons by normalized URL origin.
 */
@interface BabelFaviconStore : NSObject

/**
 * Creates a favicon store backed by a JSON file.
 *
 * @param storeFileURL The JSON file URL used for persistence.
 * @return The initialized favicon store.
 */
- (instancetype)initWithStoreFileURL:(NSURL*)storeFileURL;

/**
 * Loads persisted favicons from disk.
 */
- (void)restore;

/**
 * Stores a favicon for the URL origin and persists the store.
 *
 * @param faviconImage The favicon image to cache.
 * @param urlString The URL string whose origin owns the favicon.
 */
- (void)cacheFaviconImage:(NSImage*)faviconImage forURLString:(NSString*)urlString;

/**
 * Finds the favicon for a URL string.
 *
 * @param urlString The URL string to resolve.
 * @return The cached favicon image, or nil when no favicon exists.
 */
- (NSImage*)faviconImageForURLString:(NSString*)urlString;

/**
 * Finds a favicon by comparing a normalized suggestion title with known hosts.
 *
 * @param normalizedTitle The normalized suggestion title.
 * @return The matching favicon image, or nil when no host matches.
 */
- (NSImage*)faviconImageMatchingNormalizedTitle:(NSString*)normalizedTitle;

@end

#endif
