#ifndef BABEL_CHROME_BROWSER_RUNTIME_REFRESH_TAB_MATCHER_H_
#define BABEL_CHROME_BROWSER_RUNTIME_REFRESH_TAB_MATCHER_H_

#import <Foundation/Foundation.h>

@class BabelLocalServiceURLClassifier;
@class BabelStableServerURLResolver;

/**
 * Matches tabs that should be refreshed after a stable runtime action.
 */
@interface BabelRuntimeRefreshTabMatcher : NSObject

/**
 * Creates a refresh tab matcher.
 *
 * @param stableServerURLResolver The stable server URL resolver.
 * @param localServiceURLClassifier The local service URL classifier.
 *
 * @return The initialized matcher.
 */
- (instancetype)initWithStableServerURLResolver:(BabelStableServerURLResolver*)stableServerURLResolver
                      localServiceURLClassifier:(BabelLocalServiceURLClassifier*)localServiceURLClassifier;

/**
 * Returns whether a tab matches a requested refresh URL string.
 *
 * @param tabRequestedURLString The tab requested URL string.
 * @param tabActualURLString The tab actual URL string.
 * @param requestedURLString The requested refresh URL string.
 *
 * @return YES when the tab should be refreshed.
 */
- (BOOL)tabRequestedURLString:(NSString*)tabRequestedURLString
           tabActualURLString:(NSString*)tabActualURLString
    matchesRefreshURLString:(NSString*)requestedURLString;

@end

#endif
