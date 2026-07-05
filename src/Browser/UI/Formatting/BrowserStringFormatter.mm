#import "Browser/UI/Formatting/BrowserStringFormatter.h"

@implementation BabelBrowserStringFormatter

- (NSString*)queryEscapedString:(NSString*)value {
  NSCharacterSet* allowedCharacters = NSCharacterSet.URLQueryAllowedCharacterSet;
  return [value stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters] ?: @"";
}

- (NSString*)pathEscapedString:(NSString*)value {
  NSCharacterSet* allowedCharacters = NSCharacterSet.URLPathAllowedCharacterSet;
  return [value stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters] ?: @"";
}

- (NSString*)shellQuotedString:(NSString*)value {
  return [NSString stringWithFormat:@"'%@'",
                                    [value stringByReplacingOccurrencesOfString:@"'"
                                                                     withString:@"'\\''"]];
}

@end

