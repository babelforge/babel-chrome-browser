#import "Browser/Address/Bar/AddressFieldNavigationResolver.h"

@implementation BabelAddressFieldNavigationResolver

- (NSString*)navigationStringForAddressString:(NSString*)addressString
                           displayedURLString:(NSString*)displayedURLString
                              actualURLString:(NSString*)actualURLString {
  NSString* normalizedAddressString = addressString ?: @"";
  if (displayedURLString.length > 0 &&
      actualURLString.length > 0 &&
      [normalizedAddressString isEqualToString:displayedURLString]) {
    return actualURLString;
  }

  return normalizedAddressString;
}

@end
