#ifndef BABEL_CHROME_BROWSER_MODULES_RUNTIME_NATIVE_MODULE_RUNTIME_STATUS_PROVIDER_H_
#define BABEL_CHROME_BROWSER_MODULES_RUNTIME_NATIVE_MODULE_RUNTIME_STATUS_PROVIDER_H_

#import <Foundation/Foundation.h>

@class BabelNativeModuleManifest;

/**
 * Builds native fallback runtime diagnostics from installed module manifests.
 */
@interface BabelNativeModuleRuntimeStatusProvider : NSObject

/**
 * Returns runtime diagnostics for one manifest without starting processes.
 *
 * @param module The installed module manifest.
 * @return The runtime status dictionary.
 */
- (NSDictionary*)runtimeStatusForModule:(BabelNativeModuleManifest*)module;

@end

#endif
