#import "Browser/AddressNavigationNormalizer.h"

@implementation BabelAddressNavigationNormalizer

- (NSString*)navigationStringFromAddress:(NSString*)address defaultURLString:(NSString*)defaultURLString {
  NSString* trimmedAddress =
      [address stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmedAddress.length == 0) {
    return defaultURLString;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:trimmedAddress];
  if (components.scheme.length > 0) {
    return trimmedAddress;
  }

  if ([trimmedAddress containsString:@"."] || [trimmedAddress hasPrefix:@"localhost"]) {
    return [@"https://" stringByAppendingString:trimmedAddress];
  }

  NSString* encodedQuery =
      [trimmedAddress stringByAddingPercentEncodingWithAllowedCharacters:
                          NSCharacterSet.URLQueryAllowedCharacterSet];
  return [@"https://www.google.com/search?q=" stringByAppendingString:(encodedQuery ?: @"")];
}

@end
