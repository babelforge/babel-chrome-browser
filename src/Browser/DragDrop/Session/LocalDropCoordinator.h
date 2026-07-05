#ifndef BABEL_CHROME_BROWSER_LOCAL_DROP_COORDINATOR_H_
#define BABEL_CHROME_BROWSER_LOCAL_DROP_COORDINATOR_H_

#import <Foundation/Foundation.h>

/**
 * Tracks pending local file drops by browser identifier.
 */
@interface BabelLocalDropCoordinator : NSObject

/**
 * Marks a browser as having a pending local drop.
 *
 * @param browserIdentifier The CEF browser identifier.
 */
- (void)markPendingLocalDropForBrowserIdentifier:(NSNumber*)browserIdentifier;

/**
 * Returns whether a browser has a non-expired pending local drop.
 *
 * @param browserIdentifier The CEF browser identifier.
 *
 * @return YES when a non-expired drop is pending.
 */
- (BOOL)hasPendingLocalDropForBrowserIdentifier:(NSNumber*)browserIdentifier;

/**
 * Clears a pending local drop marker.
 *
 * @param browserIdentifier The CEF browser identifier.
 */
- (void)clearPendingLocalDropForBrowserIdentifier:(NSNumber*)browserIdentifier;

@end

#endif
