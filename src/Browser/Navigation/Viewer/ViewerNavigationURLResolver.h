#ifndef BABEL_CHROME_BROWSER_VIEWER_NAVIGATION_URL_RESOLVER_H_
#define BABEL_CHROME_BROWSER_VIEWER_NAVIGATION_URL_RESOLVER_H_

#import <Foundation/Foundation.h>

@class BabelHTMLDataURLBuilder;
@class BabelNoViewerPageRenderer;
@class BabelStableViewerURLResolver;

/**
 * Resolves stable viewer URLs to current LocalServiceHost navigation URLs.
 */
@interface BabelViewerNavigationURLResolver : NSObject

/**
 * Creates a viewer navigation URL resolver.
 *
 * @param stableViewerURLResolver The stable viewer URL parser.
 * @param noViewerPageRenderer The renderer used when no viewer is installed.
 * @param htmlDataURLBuilder The builder used to convert HTML into data URLs.
 * @return The initialized resolver.
 */
- (instancetype)initWithStableViewerURLResolver:(BabelStableViewerURLResolver*)stableViewerURLResolver
                           noViewerPageRenderer:(BabelNoViewerPageRenderer*)noViewerPageRenderer
                             htmlDataURLBuilder:(BabelHTMLDataURLBuilder*)htmlDataURLBuilder;

/**
 * Converts a supported source URL into a stable BabelChrome viewer URL.
 *
 * @param urlString The source URL string.
 * @return The stable viewer URL, or nil when no viewer supports the source.
 */
- (NSString*)stableViewerURLStringForSupportedURLString:(NSString*)urlString;

/**
 * Resolves a stable viewer URL into the current runtime navigation URL.
 *
 * @param urlString The stable viewer URL.
 * @param markdownTheme The selected Markdown theme.
 * @param error The startup error when the LocalServiceHost cannot start.
 * @return The runtime navigation URL, or nil when the viewer is unsupported or cannot start.
 */
- (NSString*)navigationURLStringForStableViewerURLString:(NSString*)urlString
                                          markdownTheme:(NSString*)markdownTheme
                                                  error:(NSError**)error;

/**
 * Builds a no-viewer installed page data URL.
 *
 * @param urlString The stable viewer URL.
 * @return The data URL for the no-viewer page.
 */
- (NSString*)noViewerInstalledPageURLStringForStableViewerURLString:(NSString*)urlString;

@end

#endif
