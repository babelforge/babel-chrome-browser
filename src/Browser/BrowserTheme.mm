#import "Browser/BrowserTheme.h"

@interface BabelTheme ()

@property(nonatomic, strong) NSDictionary<NSString*, id>* lightTokens;
@property(nonatomic, strong) NSDictionary<NSString*, id>* darkTokens;

@end

@implementation BabelTheme

@synthesize lightTokens = _lightTokens;
@synthesize darkTokens = _darkTokens;

+ (instancetype)sharedTheme {
  static BabelTheme* sharedTheme = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedTheme = [[BabelTheme alloc] init];
  });

  return sharedTheme;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _lightTokens = [self loadThemeTokensNamed:@"light"];
    _darkTokens = [self loadThemeTokensNamed:@"dark"];
  }

  return self;
}

- (NSColor*)colorForToken:(NSString*)token view:(NSView*)view {
  id value = [self tokenValueForToken:token view:view];
  NSColor* color = [self colorFromTokenValue:value view:view];

  return color ?: NSColor.labelColor;
}

- (CGColorRef)cgColorForToken:(NSString*)token view:(NSView*)view {
  return [self colorForToken:token view:view].CGColor;
}

- (NSArray<NSColor*>*)colorListForToken:(NSString*)token view:(NSView*)view {
  id value = [self tokenValueForToken:token view:view];
  if (![value isKindOfClass:NSArray.class]) {
    return @[];
  }

  NSMutableArray<NSColor*>* colors = [NSMutableArray array];
  for (id item in (NSArray*) value) {
    NSColor* color = [self colorFromTokenValue:item view:view];
    if (color) {
      [colors addObject:color];
    }
  }

  return colors;
}

- (id)tokenValueForToken:(NSString*)token view:(NSView*)view {
  NSDictionary<NSString*, id>* tokens = [self viewUsesDarkAppearance:view] ? self.darkTokens : self.lightTokens;

  return tokens[token ?: @""];
}

- (NSDictionary<NSString*, id>*)loadThemeTokensNamed:(NSString*)name {
  NSString* path = [NSBundle.mainBundle pathForResource:name ofType:@"json" inDirectory:@"Themes"];
  if (!path) {
    return @{};
  }

  NSData* data = [NSData dataWithContentsOfFile:path];
  if (!data) {
    return @{};
  }

  NSError* error = nil;
  id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
  if (![json isKindOfClass:NSDictionary.class]) {
    NSLog(@"BabelChrome theme %@ could not be loaded: %@", name, error.localizedDescription ?: @"Invalid JSON");
    return @{};
  }

  return json;
}

- (BOOL)viewUsesDarkAppearance:(NSView*)view {
  NSAppearance* appearance = view.effectiveAppearance ?: NSApp.effectiveAppearance;
  NSAppearanceName name = [appearance bestMatchFromAppearancesWithNames:@[
    NSAppearanceNameAqua,
    NSAppearanceNameDarkAqua
  ]];

  return [name isEqualToString:NSAppearanceNameDarkAqua];
}

- (NSColor*)colorFromTokenValue:(id)value view:(NSView*)view {
  if ([value isKindOfClass:NSString.class]) {
    return [self colorFromString:value];
  }

  if ([value isKindOfClass:NSDictionary.class]) {
    NSDictionary* dictionary = value;
    NSColor* color = [self colorFromString:[dictionary[@"color"] isKindOfClass:NSString.class] ? dictionary[@"color"] : @""];
    NSNumber* alpha = [dictionary[@"alpha"] isKindOfClass:NSNumber.class] ? dictionary[@"alpha"] : nil;
    if (color && alpha) {
      return [color colorWithAlphaComponent:alpha.doubleValue];
    }

    return color;
  }

  return nil;
}

- (NSColor*)colorFromString:(NSString*)value {
  if (value.length == 0) {
    return nil;
  }

  if ([value hasPrefix:@"system."]) {
    return [self systemColorForName:[value substringFromIndex:@"system.".length]];
  }

  if ([value hasPrefix:@"#"]) {
    return [self colorFromHexString:value];
  }

  return nil;
}

- (NSColor*)systemColorForName:(NSString*)name {
  static NSDictionary<NSString*, NSColor*>* colors = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    colors = @{
      @"clear": NSColor.clearColor,
      @"controlAccent": NSColor.controlAccentColor,
      @"controlBackground": NSColor.controlBackgroundColor,
      @"grid": NSColor.gridColor,
      @"label": NSColor.labelColor,
      @"secondaryLabel": NSColor.secondaryLabelColor,
      @"separator": NSColor.separatorColor,
      @"textBackground": NSColor.textBackgroundColor,
      @"textColor": NSColor.textColor,
      @"underPageBackground": NSColor.underPageBackgroundColor,
      @"windowBackground": NSColor.windowBackgroundColor
    };
  });

  return colors[name ?: @""];
}

- (NSColor*)colorFromHexString:(NSString*)hexString {
  NSString* cleaned = [[hexString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
      stringByReplacingOccurrencesOfString:@"#" withString:@""];
  if (cleaned.length != 6 && cleaned.length != 8) {
    return nil;
  }

  unsigned int value = 0;
  NSScanner* scanner = [NSScanner scannerWithString:cleaned];
  if (![scanner scanHexInt:&value]) {
    return nil;
  }

  CGFloat red = 0.0;
  CGFloat green = 0.0;
  CGFloat blue = 0.0;
  CGFloat alpha = 1.0;
  if (cleaned.length == 8) {
    red = ((value >> 24) & 0xFF) / 255.0;
    green = ((value >> 16) & 0xFF) / 255.0;
    blue = ((value >> 8) & 0xFF) / 255.0;
    alpha = (value & 0xFF) / 255.0;
  } else {
    red = ((value >> 16) & 0xFF) / 255.0;
    green = ((value >> 8) & 0xFF) / 255.0;
    blue = (value & 0xFF) / 255.0;
  }

  return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
}

@end
