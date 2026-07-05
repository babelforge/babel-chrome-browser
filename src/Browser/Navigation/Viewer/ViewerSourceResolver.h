#ifndef BABEL_CHROME_BROWSER_VIEWER_SOURCE_RESOLVER_H_
#define BABEL_CHROME_BROWSER_VIEWER_SOURCE_RESOLVER_H_

#import <Foundation/Foundation.h>

@class BabelBrowserTab;
@class BabelStableViewerURLResolver;

/**
 * Resolves local source files behind stable viewer tabs.
 */
@interface BabelViewerSourceResolver : NSObject

/**
 * Initializes the resolver.
 *
 * @param stableViewerURLResolver The stable viewer URL resolver.
 *
 * @return The initialized resolver.
 */
- (instancetype)initWithStableViewerURLResolver:(BabelStableViewerURLResolver*)stableViewerURLResolver;

/**
 * Returns the local source file URL for a tab.
 *
 * @param tab The tab to inspect.
 *
 * @return The local source file URL, or nil.
 */
- (NSURL*)viewerSourceFileURLForTab:(BabelBrowserTab*)tab;

@end

#endif
