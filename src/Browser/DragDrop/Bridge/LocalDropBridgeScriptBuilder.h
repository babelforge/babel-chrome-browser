#ifndef BABEL_CHROME_BROWSER_LOCAL_DROP_BRIDGE_SCRIPT_BUILDER_H_
#define BABEL_CHROME_BROWSER_LOCAL_DROP_BRIDGE_SCRIPT_BUILDER_H_

#import <Foundation/Foundation.h>

/**
 * Builds the JavaScript bridge used to dispatch local file drops to web modules.
 */
@interface BabelLocalDropBridgeScriptBuilder : NSObject

/**
 * Builds the local-drop bridge script.
 *
 * @param payloadJSON The optional JSON payload assigned before dispatch.
 *
 * @return The JavaScript source to execute in the page.
 */
- (NSString*)scriptWithPayloadJSON:(NSString*)payloadJSON;

@end

#endif
