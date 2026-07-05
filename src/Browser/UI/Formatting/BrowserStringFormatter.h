#ifndef BABEL_CHROME_BROWSER_STRING_FORMATTER_H_
#define BABEL_CHROME_BROWSER_STRING_FORMATTER_H_

#import <Foundation/Foundation.h>

/**
 * Formats strings for browser-internal URLs and shell commands.
 */
@interface BabelBrowserStringFormatter : NSObject

/**
 * Percent-encodes a value for URL query usage.
 *
 * @param value The value to encode.
 *
 * @return The encoded value.
 */
- (NSString*)queryEscapedString:(NSString*)value;

/**
 * Percent-encodes a value for URL path usage.
 *
 * @param value The value to encode.
 *
 * @return The encoded value.
 */
- (NSString*)pathEscapedString:(NSString*)value;

/**
 * Quotes a string for a POSIX shell command.
 *
 * @param value The value to quote.
 *
 * @return The quoted value.
 */
- (NSString*)shellQuotedString:(NSString*)value;

@end

#endif
