#ifndef BABEL_CHROME_BROWSER_LOCAL_DROP_PAYLOAD_BUILDER_H_
#define BABEL_CHROME_BROWSER_LOCAL_DROP_PAYLOAD_BUILDER_H_

#import <Foundation/Foundation.h>

/**
 * Builds JavaScript payload JSON for local file and folder drops.
 */
@interface BabelLocalDropPayloadBuilder : NSObject

/**
 * Builds the native local-drop payload JSON.
 *
 * @param paths The local filesystem paths.
 *
 * @return The payload JSON, or nil when no valid local path exists.
 */
- (NSString*)payloadJSONForLocalPaths:(NSArray<NSString*>*)paths;

@end

#endif
