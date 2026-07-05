#import <Foundation/Foundation.h>

@interface BabelNoViewerPageRenderer : NSObject

- (NSString*)htmlForSourceURL:(NSURL*)sourceURL fallbackURLString:(NSString*)fallbackURLString;

@end
