#import "Browser/Navigation/Commands/ChromeCommandParser.h"

static NSString* const kCompactCommandOpaquePrefix = @"babelchrome:group:";
static NSString* const kCompactCommandHierarchicalPrefix = @"babelchrome://command/group:";

@implementation BabelChromeCommand

@synthesize groupName;
@synthesize urlString;

@end

@implementation BabelChromeCommandParser {
  NSString* defaultGroupName_;
  NSString* defaultURLString_;
}

- (instancetype)initWithDefaultGroupName:(NSString*)defaultGroupName
                        defaultURLString:(NSString*)defaultURLString {
  self = [super init];
  if (self) {
    defaultGroupName_ = [defaultGroupName copy] ?: @"default";
    defaultURLString_ = [defaultURLString copy] ?: @"";
  }
  return self;
}

- (BabelChromeCommand*)commandFromURL:(NSURL*)url {
  BabelChromeCommand* compactCommand = [self compactCommandFromURLString:url.absoluteString];
  if (compactCommand) {
    return compactCommand;
  }

  NSURLComponents* components = [NSURLComponents componentsWithURL:url
                                           resolvingAgainstBaseURL:NO];
  NSString* groupName = defaultGroupName_;
  NSString* targetURLString = nil;

  for (NSURLQueryItem* item in components.queryItems) {
    if ([item.name isEqualToString:@"group"] && item.value.length > 0) {
      groupName = item.value;
      continue;
    }

    if ([item.name isEqualToString:@"url"] && item.value.length > 0) {
      targetURLString = item.value;
    }
  }

  if (targetURLString.length == 0) {
    targetURLString = defaultURLString_;
  }

  return [self commandWithGroupName:groupName urlString:targetURLString];
}

- (BabelChromeCommand*)compactCommandFromURLString:(NSString*)urlString {
  NSString* payload = nil;
  if ([urlString hasPrefix:kCompactCommandOpaquePrefix]) {
    payload = [urlString substringFromIndex:kCompactCommandOpaquePrefix.length];
  } else if ([urlString hasPrefix:kCompactCommandHierarchicalPrefix]) {
    payload = [urlString substringFromIndex:kCompactCommandHierarchicalPrefix.length];
  }

  if (!payload) {
    return nil;
  }

  NSArray<NSString*>* separators = @[
    @"::|::url:",
    @"::%7C::url:",
    @"::%7c::url:"
  ];

  NSRange separatorRange = NSMakeRange(NSNotFound, 0);
  for (NSString* separator in separators) {
    separatorRange = [payload rangeOfString:separator];
    if (separatorRange.location != NSNotFound) {
      break;
    }
  }

  if (separatorRange.location == NSNotFound) {
    return nil;
  }

  NSString* encodedGroupName = [payload substringToIndex:separatorRange.location];
  NSString* targetURLString =
      [payload substringFromIndex:separatorRange.location + separatorRange.length];
  NSString* groupName = encodedGroupName.stringByRemovingPercentEncoding ?: encodedGroupName;
  if (groupName.length == 0) {
    groupName = defaultGroupName_;
  }

  if (targetURLString.length == 0) {
    targetURLString = defaultURLString_;
  }

  return [self commandWithGroupName:groupName urlString:targetURLString];
}

- (BabelChromeCommand*)commandWithGroupName:(NSString*)groupName urlString:(NSString*)urlString {
  BabelChromeCommand* command = [[BabelChromeCommand alloc] init];
  command.groupName = groupName.length > 0 ? groupName : defaultGroupName_;
  command.urlString = urlString.length > 0 ? urlString : defaultURLString_;
  return command;
}

@end
