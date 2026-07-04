#ifndef BABEL_CHROME_BROWSER_MODULE_LIFECYCLE_DISPATCHER_H_
#define BABEL_CHROME_BROWSER_MODULE_LIFECYCLE_DISPATCHER_H_

#import <Foundation/Foundation.h>

@class BabelProjectLifecycleResponseParser;

typedef void (^BabelModuleLifecycleRestoredProjectsHandler)(NSArray<NSString*>* projectIdentifiers);

/**
 * Dispatches application lifecycle hooks to installed PHP modules.
 */
@interface BabelModuleLifecycleDispatcher : NSObject

/**
 * Creates a module lifecycle dispatcher.
 *
 * @param projectLifecycleResponseParser The parser used to extract project lifecycle data.
 * @return The initialized module lifecycle dispatcher.
 */
- (instancetype)initWithProjectLifecycleResponseParser:
    (BabelProjectLifecycleResponseParser*)projectLifecycleResponseParser;

/**
 * Dispatches the application start lifecycle hook.
 *
 * @param handler The main-thread handler called with restored project identifiers.
 */
- (void)dispatchApplicationDidStartWithRestoredProjectsHandler:
    (BabelModuleLifecycleRestoredProjectsHandler)handler;

/**
 * Dispatches the application quit lifecycle hook.
 */
- (void)dispatchApplicationWillQuit;

@end

#endif
