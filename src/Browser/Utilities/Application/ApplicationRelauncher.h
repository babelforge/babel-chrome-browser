#ifndef BABEL_CHROME_BROWSER_APPLICATION_RELAUNCHER_H_
#define BABEL_CHROME_BROWSER_APPLICATION_RELAUNCHER_H_

#import <Foundation/Foundation.h>

/**
 * Starts a detached relaunch task for the current application bundle.
 */
@interface BabelApplicationRelauncher : NSObject

/**
 * Schedules the current bundle to reopen after the current process exits.
 *
 * @param bundlePath The current application bundle path.
 * @param processIdentifier The current process identifier.
 *
 * @return YES when the relaunch task was started.
 */
- (BOOL)scheduleRelaunchForBundlePath:(NSString*)bundlePath
                    processIdentifier:(int)processIdentifier;

@end

#endif
