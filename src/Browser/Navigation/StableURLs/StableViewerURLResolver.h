#ifndef BABEL_CHROME_BROWSER_STABLE_VIEWER_URL_RESOLVER_H_
#define BABEL_CHROME_BROWSER_STABLE_VIEWER_URL_RESOLVER_H_

#import <Foundation/Foundation.h>

/**
 * Resolves stable BabelChrome viewer URLs into source metadata and display values.
 */
@interface BabelStableViewerURLResolver : NSObject

/**
 * Returns whether a URL string is a stable viewer URL.
 *
 * @param urlString The URL string to inspect.
 * @return YES when the URL is a stable viewer URL.
 */
- (BOOL)isStableViewerURLString:(NSString*)urlString;

/**
 * Resolves the source URL encoded in a stable viewer URL.
 *
 * @param urlString The stable viewer URL string.
 * @return The decoded source URL, or the original URL when no source could be decoded.
 */
- (NSURL*)sourceURLForViewerURLString:(NSString*)urlString;

/**
 * Returns the fragment suffix from a stable viewer URL.
 *
 * @param urlString The stable viewer URL string.
 * @return The fragment suffix including the leading hash, or an empty string.
 */
- (NSString*)fragmentForStableViewerURLString:(NSString*)urlString;

/**
 * Percent-encodes a stable viewer path segment.
 *
 * @param value The value to encode.
 * @return The encoded value.
 */
- (NSString*)escapedStableViewerString:(NSString*)value;

/**
 * Returns the requested viewer kind from a stable viewer URL.
 *
 * @param urlString The stable viewer URL string.
 * @return The viewer kind, or nil when the URL is not a viewer URL.
 */
- (NSString*)viewerKindForStableViewerURLString:(NSString*)urlString;

/**
 * Resolves the effective viewer kind, including generic viewer URLs.
 *
 * @param urlString The stable viewer URL string.
 * @return The effective viewer kind, or nil when no viewer can be resolved.
 */
- (NSString*)resolvedViewerKindForStableViewerURLString:(NSString*)urlString;

/**
 * Returns the source kind from a stable viewer URL.
 *
 * @param urlString The stable viewer URL string.
 * @return `file`, `url`, or nil.
 */
- (NSString*)sourceKindForStableViewerURLString:(NSString*)urlString;

/**
 * Returns the source display value for the address bar.
 *
 * @param urlString The stable viewer URL string.
 * @return The decoded display URL.
 */
- (NSString*)displayURLStringForStableViewerURLString:(NSString*)urlString;

@end

#endif
