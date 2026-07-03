#ifndef BABEL_CHROME_BROWSER_LOCAL_DROP_LOG_WRITER_H_
#define BABEL_CHROME_BROWSER_LOCAL_DROP_LOG_WRITER_H_

#import <Foundation/Foundation.h>

/**
 * Writes local-drop diagnostic log lines.
 */
@interface BabelLocalDropLogWriter : NSObject

/**
 * Initializes the writer.
 *
 * @param logURL The log file URL.
 *
 * @return The initialized writer.
 */
- (instancetype)initWithLogURL:(NSURL*)logURL;

/**
 * Appends one line to the local-drop log.
 *
 * @param line The log line.
 */
- (void)appendLine:(NSString*)line;

@end

#endif
