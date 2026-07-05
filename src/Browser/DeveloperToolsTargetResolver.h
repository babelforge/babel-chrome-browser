#ifndef BABEL_CHROME_BROWSER_DEVELOPER_TOOLS_TARGET_RESOLVER_H_
#define BABEL_CHROME_BROWSER_DEVELOPER_TOOLS_TARGET_RESOLVER_H_

#import <Foundation/Foundation.h>

/**
 * Resolves CEF remote-debugging targets for embedded Developer Tools.
 */
@interface BabelDeveloperToolsTargetResolver : NSObject

/**
 * Builds the embedded Developer Tools URL for an inspected page URL.
 *
 * @param inspectedURLString The inspected page URL.
 * @param port The remote debugging port.
 * @return The Developer Tools URL or an error data URL.
 */
- (NSString*)developerToolsURLStringForInspectedURLString:(NSString*)inspectedURLString
                                                    port:(int)port;

@end

#endif
