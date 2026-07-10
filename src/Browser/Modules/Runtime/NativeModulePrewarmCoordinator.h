#ifndef BABEL_CHROME_BROWSER_MODULES_RUNTIME_NATIVE_MODULE_PREWARM_COORDINATOR_H_
#define BABEL_CHROME_BROWSER_MODULES_RUNTIME_NATIVE_MODULE_PREWARM_COORDINATOR_H_

#import <Foundation/Foundation.h>

@class BabelNativeModuleManifest;
@class BabelNativeModuleProcessRuntimeManager;

/**
 * Coordinates best-effort prewarming for process-web module runtimes.
 */
@interface BabelNativeModulePrewarmCoordinator : NSObject

/**
 * Creates a prewarm coordinator.
 *
 * @param runtimeManager The process runtime manager used to start modules.
 * @return The initialized coordinator.
 */
- (instancetype)initWithRuntimeManager:(BabelNativeModuleProcessRuntimeManager*)runtimeManager;

/**
 * Starts one process-web module runtime when prewarming is useful.
 *
 * @param module The module manifest to prewarm.
 * @param error The optional error pointer.
 * @return The runtime status after prewarm, or nil when prewarm fails.
 */
- (NSDictionary*)prewarmModule:(BabelNativeModuleManifest*)module error:(NSError**)error;

/**
 * Schedules background prewarm for modules in the provided order.
 *
 * @param modules The process-web modules to prewarm.
 * @param excludedIdentifiers Module identifiers that must not be scheduled again.
 */
- (void)schedulePrewarmModules:(NSArray<BabelNativeModuleManifest*>*)modules
           excludingIdentifiers:(NSSet<NSString*>*)excludedIdentifiers;

/**
 * Returns the last known prewarm status for one module.
 *
 * @param moduleIdentifier The module identifier.
 * @return The prewarm status dictionary, or nil when no prewarm was attempted.
 */
- (NSDictionary*)prewarmStatusForModuleIdentifier:(NSString*)moduleIdentifier;

@end

#endif
