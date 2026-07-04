#import "Browser/BrowserPresentationFormatter.h"

@implementation BabelBrowserPresentationFormatter

- (NSString*)windowTitleWithApplicationName:(NSString*)applicationName pageTitle:(NSString*)pageTitle {
  if (pageTitle.length == 0) {
    return applicationName ?: @"";
  }

  return [NSString stringWithFormat:@"%@ - %@", applicationName ?: @"", pageTitle];
}

- (NSString*)compactTitleForString:(NSString*)value {
  if (value.length <= 28) {
    return value ?: @"";
  }

  return [[value substringToIndex:25] stringByAppendingString:@"..."];
}

- (NSColor*)colorFromHexString:(NSString*)hexString fallbackColor:(NSColor*)fallbackColor {
  NSString* normalizedHex =
      [hexString ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if ([normalizedHex hasPrefix:@"#"]) {
    normalizedHex = [normalizedHex substringFromIndex:1];
  }

  if (normalizedHex.length != 6) {
    return fallbackColor;
  }

  unsigned int colorValue = 0;
  NSScanner* scanner = [NSScanner scannerWithString:normalizedHex];
  if (![scanner scanHexInt:&colorValue]) {
    return fallbackColor;
  }

  CGFloat red = ((colorValue >> 16) & 0xff) / 255.0;
  CGFloat green = ((colorValue >> 8) & 0xff) / 255.0;
  CGFloat blue = (colorValue & 0xff) / 255.0;

  return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0];
}

@end
