#ifndef BABEL_CHROME_BROWSER_MODULES_RUNTIME_NATIVE_MODULE_PORT_ALLOCATOR_H_
#define BABEL_CHROME_BROWSER_MODULES_RUNTIME_NATIVE_MODULE_PORT_ALLOCATOR_H_

#import <Foundation/Foundation.h>

/**
 * Allocates available local TCP ports for module-owned processes.
 */
@interface BabelNativeModulePortAllocator : NSObject

/**
 * Allocates an available local port bound to 127.0.0.1.
 *
 * @param error The optional error pointer.
 * @return The allocated port number, or nil when no port can be allocated.
 */
- (NSNumber*)availableLocalPortWithError:(NSError**)error;

@end

#endif
