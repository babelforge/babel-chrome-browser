#ifndef BABEL_CHROME_BROWSER_MODULES_RUNTIME_NATIVE_MODULE_HTTP_HOST_H_
#define BABEL_CHROME_BROWSER_MODULES_RUNTIME_NATIVE_MODULE_HTTP_HOST_H_

#import <Foundation/Foundation.h>

@class BabelNativeModuleProcessRuntimeManager;
@class BabelNativeModuleRegistry;
@class BabelViewerSourceRegistry;

/**
 * Serves native module runtime HTTP routes on a loopback-only port.
 */
@interface BabelNativeModuleHTTPHost : NSObject

/**
 * Creates a native module HTTP host.
 *
 * @param moduleRegistry The native module registry.
 * @param runtimeManager The native process runtime manager.
 * @param sourceRegistry The viewer source registry.
 * @return The initialized host.
 */
- (instancetype)initWithModuleRegistry:(BabelNativeModuleRegistry*)moduleRegistry
                        runtimeManager:(BabelNativeModuleProcessRuntimeManager*)runtimeManager
                         sourceRegistry:(BabelViewerSourceRegistry*)sourceRegistry;

/**
 * Returns a local native host URL for a module route.
 *
 * @param moduleIdentifier The module identifier.
 * @param route The module route.
 * @param sourceURLString The source URL to forward to the module.
 * @param error The optional error pointer.
 * @return The local runtime URL, or nil when the host cannot be started.
 */
- (NSURL*)moduleURLForIdentifier:(NSString*)moduleIdentifier
                           route:(NSString*)route
                 sourceURLString:(NSString*)sourceURLString
                           error:(NSError**)error;

/**
 * Returns a local native host URL for a module route with additional query items.
 *
 * @param moduleIdentifier The module identifier.
 * @param route The module route.
 * @param sourceURLString The source URL to forward to the module.
 * @param queryItems Additional query items to forward.
 * @param error The optional error pointer.
 * @return The local runtime URL, or nil when the host cannot be started.
 */
- (NSURL*)moduleURLForIdentifier:(NSString*)moduleIdentifier
                           route:(NSString*)route
                 sourceURLString:(NSString*)sourceURLString
                      queryItems:(NSArray<NSURLQueryItem*>*)queryItems
                           error:(NSError**)error;

/**
 * Stops the native HTTP host.
 */
- (void)stop;

@end

#endif
