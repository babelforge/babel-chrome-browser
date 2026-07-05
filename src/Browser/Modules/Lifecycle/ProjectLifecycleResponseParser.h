#ifndef BABEL_CHROME_BROWSER_PROJECT_LIFECYCLE_RESPONSE_PARSER_H_
#define BABEL_CHROME_BROWSER_PROJECT_LIFECYCLE_RESPONSE_PARSER_H_

#import <Foundation/Foundation.h>

/**
 * Parses Project Launcher lifecycle hook responses.
 */
@interface BabelProjectLifecycleResponseParser : NSObject

/**
 * Extracts restored project identifiers from a lifecycle hook response.
 *
 * @param response The decoded JSON response dictionary.
 *
 * @return The unique restored project identifiers in response order.
 */
- (NSArray<NSString*>*)restoredProjectIdentifiersFromLifecycleResponse:(NSDictionary*)response;

@end

#endif
