#import "Browser/InternalPageAssetProvider.h"

@implementation BabelInternalPageAssetProvider

- (NSString*)trashIconHTML {
  return @"<svg class='buttonIcon' viewBox='0 0 24 24' aria-hidden='true'>"
          "<path d='M9 3h6l1 2h4v2H4V5h4l1-2z'/>"
          "<path d='M6 9h12l-1 12H7L6 9zm4 2v8h2v-8h-2zm4 0v8h2v-8h-2z'/>"
          "</svg>";
}

- (NSString*)resourceSVGIconHTMLNamed:(NSString*)resourceName fallback:(NSString*)fallbackHTML {
  NSString* resourcePath = [NSBundle.mainBundle pathForResource:resourceName ofType:@"svg"];
  if (0 == resourcePath.length) {
    return fallbackHTML ?: @"";
  }

  NSError* error = nil;
  NSString* iconHTML = [NSString stringWithContentsOfFile:resourcePath
                                                 encoding:NSUTF8StringEncoding
                                                    error:&error];
  if (error || 0 == iconHTML.length) {
    return fallbackHTML ?: @"";
  }

  NSMutableString* normalizedIconHTML = [NSMutableString stringWithString:iconHTML];
  [normalizedIconHTML replaceOccurrencesOfString:@"<svg "
                                      withString:@"<svg class='buttonIcon gearIcon' aria-hidden='true' "
                                         options:0
                                           range:NSMakeRange(0, normalizedIconHTML.length)];
  [normalizedIconHTML replaceOccurrencesOfString:@"fill=\"#17345a\""
                                      withString:@"fill=\"currentColor\""
                                         options:0
                                           range:NSMakeRange(0, normalizedIconHTML.length)];

  return normalizedIconHTML;
}

@end

