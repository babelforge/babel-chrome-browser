#ifndef BABEL_CHROME_BROWSER_MODULES_RUNTIME_NATIVE_MODULE_PROCESS_RUNTIME_MANAGER_H_
#define BABEL_CHROME_BROWSER_MODULES_RUNTIME_NATIVE_MODULE_PROCESS_RUNTIME_MANAGER_H_

#import <Foundation/Foundation.h>

@class BabelNativeModuleManifest;
@class BabelNativeModuleRequiredSettingsService;

/**
 * Prepares native process runtime diagnostics and process launch inputs.
 */
@interface BabelNativeModuleProcessRuntimeManager : NSObject

/**
 * Creates a process runtime manager.
 *
 * @param requiredSettingsService The service resolving host-rendered module runtime settings.
 * @return The initialized runtime manager.
 */
- (instancetype)initWithRequiredSettingsService:(BabelNativeModuleRequiredSettingsService*)requiredSettingsService;

/**
 * Returns runtime diagnostics for one manifest without starting processes.
 *
 * @param module The installed module manifest.
 * @return The runtime status dictionary.
 */
- (NSDictionary*)runtimeStatusForModule:(BabelNativeModuleManifest*)module;

/**
 * Restarts one process-web module runtime.
 *
 * @param module The installed module manifest.
 * @param error The optional error pointer.
 * @return The runtime status after restart, or nil when the process cannot start.
 */
- (NSDictionary*)restartProcessWebRuntimeForModule:(BabelNativeModuleManifest*)module
                                             error:(NSError**)error;

/**
 * Starts one process-web runtime when it is not already running.
 *
 * @param module The installed module manifest.
 * @param error The optional error pointer.
 * @return The running runtime status, or nil when the process cannot start.
 */
- (NSDictionary*)startProcessWebRuntimeIfNeededForModule:(BabelNativeModuleManifest*)module
                                                   error:(NSError**)error;
- (NSDictionary*)startProcessWebRuntimeIfNeededForModule:(BabelNativeModuleManifest*)module
                                   additionalEnvironment:(NSDictionary<NSString*, NSString*>*)additionalEnvironment
                                                   error:(NSError**)error;

/**
 * Executes one process-runtime module route.
 *
 * @param module The installed module manifest.
 * @param route The requested module route.
 * @param sourceURL The original source URL forwarded to the module.
 * @param localServiceBaseURL The native local service base URL.
 * @param localServiceToken The native local service token.
 * @param queryItems The request query items.
 * @param fileTypes The enabled BabelChrome file type handlers.
 * @param hook The optional lifecycle hook name.
 * @param error The optional error pointer.
 * @return The response dictionary, or nil when execution fails.
 */
- (NSDictionary*)executeProcessRuntimeForModule:(BabelNativeModuleManifest*)module
                                          route:(NSString*)route
                                      sourceURL:(NSString*)sourceURL
                            localServiceBaseURL:(NSString*)localServiceBaseURL
                              localServiceToken:(NSString*)localServiceToken
                                     queryItems:(NSArray<NSURLQueryItem*>*)queryItems
                                      fileTypes:(NSString*)fileTypes
                                           hook:(NSString*)hook
                                          error:(NSError**)error;

/**
 * Stops one module runtime.
 *
 * @param module The installed module manifest.
 * @param error The optional error pointer.
 * @return The runtime status after stop, or nil when the runtime cannot be stopped.
 */
- (NSDictionary*)stopRuntimeForModule:(BabelNativeModuleManifest*)module
                                error:(NSError**)error;

/**
 * Stops a module runtime by identifier.
 *
 * @param moduleIdentifier The module identifier.
 */
- (void)stopRuntimeForModuleIdentifier:(NSString*)moduleIdentifier;

/**
 * Stops every native runtime process owned by this manager.
 */
- (void)stopAllRuntimes;

/**
 * Allocates the local port that a process-web module would receive.
 *
 * @param error The optional error pointer.
 * @return The allocated port number, or nil when no port can be allocated.
 */
- (NSNumber*)allocateProcessWebPortWithError:(NSError**)error;

/**
 * Resolves a process-web command line for a module and allocated port.
 *
 * @param module The installed module manifest.
 * @param port The allocated local port.
 * @return The resolved command line, or an empty array when unavailable.
 */
- (NSArray<NSString*>*)resolvedProcessWebCommandForModule:(BabelNativeModuleManifest*)module
                                                     port:(NSInteger)port;

/**
 * Resolves a process-web readiness URL for a module and allocated port.
 *
 * @param module The installed module manifest.
 * @param port The allocated local port.
 * @return The resolved readiness URL, or an empty string when unavailable.
 */
- (NSString*)resolvedProcessWebReadyURLForModule:(BabelNativeModuleManifest*)module
                                            port:(NSInteger)port;

/**
 * Resolves a module process working directory.
 *
 * @param module The installed module manifest.
 * @param cwd The manifest cwd value.
 * @param error The optional error pointer.
 * @return The resolved working directory path, or nil when invalid.
 */
- (NSString*)resolvedWorkingDirectoryForModule:(BabelNativeModuleManifest*)module
                                           cwd:(NSString*)cwd
                                         error:(NSError**)error;

@end

#endif
