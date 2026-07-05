#ifndef BABEL_CHROME_BROWSER_TAB_URL_MATCHER_H_
#define BABEL_CHROME_BROWSER_TAB_URL_MATCHER_H_

#import <Foundation/Foundation.h>

@class BabelBrowserTab;

/**
 * Compares browser tabs against URL strings using BabelChrome matching rules.
 */
@interface BabelTabURLMatcher : NSObject

/**
 * Returns whether a tab matches a URL string.
 *
 * @param tab The tab to inspect.
 * @param urlString The URL string to match.
 *
 * @return YES when the tab matches the URL string.
 */
- (BOOL)tab:(BabelBrowserTab*)tab matchesURLString:(NSString*)urlString;

@end

#endif
