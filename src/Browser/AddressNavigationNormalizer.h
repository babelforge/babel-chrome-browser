#import <Foundation/Foundation.h>

@interface BabelAddressNavigationNormalizer : NSObject

- (NSString*)navigationStringFromAddress:(NSString*)address defaultURLString:(NSString*)defaultURLString;

@end
