#ifndef BABEL_CHROME_BROWSER_PASTEBOARD_WRITER_H_
#define BABEL_CHROME_BROWSER_PASTEBOARD_WRITER_H_

#import <Cocoa/Cocoa.h>

/**
 * Writes browser values to the system pasteboard.
 */
@interface BabelBrowserPasteboardWriter : NSObject

/**
 * Copies a URL string to the general pasteboard.
 *
 * @param urlString The URL string to copy.
 */
- (void)copyURLStringToPasteboard:(NSString*)urlString;

@end

#endif
