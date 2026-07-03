#ifndef BABEL_CHROME_BROWSER_RUNTIME_REFRESH_COORDINATOR_H_
#define BABEL_CHROME_BROWSER_RUNTIME_REFRESH_COORDINATOR_H_

#import <Foundation/Foundation.h>

/**
 * Tracks pending stable URL refresh requests by runtime browser identifier.
 */
@interface BabelRuntimeRefreshCoordinator : NSObject

/**
 * Stores refresh URL strings for a runtime browser identifier.
 *
 * @param refreshURLStrings The stable URL strings to refresh later.
 * @param browserIdentifier The runtime CEF browser identifier.
 */
- (void)enqueueRefreshURLStrings:(NSArray<NSString*>*)refreshURLStrings
            forBrowserIdentifier:(NSInteger)browserIdentifier;

/**
 * Consumes and removes refresh URL strings for a runtime browser identifier.
 *
 * @param browserIdentifier The runtime CEF browser identifier.
 * @return The pending stable URL strings, or an empty array.
 */
- (NSArray<NSString*>*)consumeRefreshURLStringsForBrowserIdentifier:(NSInteger)browserIdentifier;

@end

#endif
