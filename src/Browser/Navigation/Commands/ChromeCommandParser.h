#ifndef BABEL_CHROME_BROWSER_CHROME_COMMAND_PARSER_H_
#define BABEL_CHROME_BROWSER_CHROME_COMMAND_PARSER_H_

#import <Foundation/Foundation.h>

/**
 * Parses BabelChrome command URLs into tab-opening instructions.
 */
@interface BabelChromeCommand : NSObject

/**
 * The target group name.
 */
@property(nonatomic, copy) NSString* groupName;

/**
 * The target URL string.
 */
@property(nonatomic, copy) NSString* urlString;

@end

/**
 * Owns parsing for supported BabelChrome command URL formats.
 */
@interface BabelChromeCommandParser : NSObject

/**
 * Creates a command parser.
 *
 * @param defaultGroupName The group name used when a command omits a group.
 * @param defaultURLString The URL used when a command omits a target URL.
 * @return The initialized parser.
 */
- (instancetype)initWithDefaultGroupName:(NSString*)defaultGroupName
                        defaultURLString:(NSString*)defaultURLString;

/**
 * Parses any supported command URL.
 *
 * @param url The command URL.
 * @return The parsed command, or nil when the URL is not a command.
 */
- (BabelChromeCommand*)commandFromURL:(NSURL*)url;

/**
 * Parses the compact command URL syntax.
 *
 * @param urlString The URL string to parse.
 * @return The parsed command, or nil when the string is not compact command syntax.
 */
- (BabelChromeCommand*)compactCommandFromURLString:(NSString*)urlString;

@end

#endif
