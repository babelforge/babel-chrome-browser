#import "Browser/Utilities/HTML/HTMLDataURLBuilder.h"

@implementation BabelHTMLDataURLBuilder

- (NSString*)dataURLStringForHTML:(NSString*)html {
  NSData* data = [html dataUsingEncoding:NSUTF8StringEncoding];
  NSString* encodedHTML = [data base64EncodedStringWithOptions:0];
  return [NSString stringWithFormat:@"data:text/html;charset=utf-8;base64,%@", encodedHTML];
}

@end
