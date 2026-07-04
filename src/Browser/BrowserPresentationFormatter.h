#import <Cocoa/Cocoa.h>

@interface BabelBrowserPresentationFormatter : NSObject

- (NSString*)windowTitleWithApplicationName:(NSString*)applicationName pageTitle:(NSString*)pageTitle;

- (NSString*)compactTitleForString:(NSString*)value;

- (NSColor*)colorFromHexString:(NSString*)hexString fallbackColor:(NSColor*)fallbackColor;

@end
