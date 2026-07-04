#import "Browser/NoViewerPageRenderer.h"

@implementation BabelNoViewerPageRenderer

- (NSString*)htmlForSourceURL:(NSURL*)sourceURL fallbackURLString:(NSString*)fallbackURLString {
  NSString* sourceDisplayString = sourceURL.isFileURL ? sourceURL.path : sourceURL.absoluteString;
  if (sourceDisplayString.length == 0) {
    sourceDisplayString = fallbackURLString ?: @"";
  }

  NSString* extension = sourceURL.pathExtension.lowercaseString ?: @"";
  NSString* title = @"No viewer installed for this file type";
  NSString* detail = extension.length > 0
      ? [NSString stringWithFormat:@"No enabled BabelChrome viewer module currently handles .%@ files.", extension]
      : @"No enabled BabelChrome viewer module currently handles this source.";

  return [NSString stringWithFormat:
      @"<!doctype html>"
       "<html><head><meta charset='utf-8'>"
       "<style>"
       "body{margin:0;background:#f5f6f8;color:#1f2328;font:15px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;}"
       "main{max-width:760px;margin:92px auto;padding:0 28px;}"
       "h1{font-size:28px;line-height:1.2;margin:0 0 14px;font-weight:700;}"
       "p{line-height:1.55;margin:0 0 18px;color:#59636e;}"
       "code{display:block;background:#fff;border:1px solid #d8dee4;border-radius:8px;padding:14px 16px;white-space:pre-wrap;word-break:break-all;color:#1f2328;}"
       "</style></head><body><main>"
       "<h1>%@</h1>"
       "<p>%@</p>"
       "<code>%@</code>"
       "</main></body></html>",
      [self htmlEscapedString:title],
      [self htmlEscapedString:detail],
      [self htmlEscapedString:sourceDisplayString]];
}

- (NSString*)htmlEscapedString:(NSString*)value {
  NSMutableString* result = [NSMutableString stringWithString:value ?: @""];
  [result replaceOccurrencesOfString:@"&"
                           withString:@"&amp;"
                              options:0
                                range:NSMakeRange(0, result.length)];
  [result replaceOccurrencesOfString:@"<"
                           withString:@"&lt;"
                              options:0
                                range:NSMakeRange(0, result.length)];
  [result replaceOccurrencesOfString:@">"
                           withString:@"&gt;"
                              options:0
                                range:NSMakeRange(0, result.length)];
  [result replaceOccurrencesOfString:@"\""
                           withString:@"&quot;"
                              options:0
                                range:NSMakeRange(0, result.length)];
  return result;
}

@end
