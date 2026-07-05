#import "Browser/State/Favicons/FaviconStore.h"

@implementation BabelFaviconStore {
  NSURL* storeFileURL_;
  NSMutableDictionary<NSString*, NSImage*>* faviconImagesByOrigin_;
}

- (instancetype)initWithStoreFileURL:(NSURL*)storeFileURL {
  self = [super init];
  if (self) {
    storeFileURL_ = storeFileURL;
    faviconImagesByOrigin_ = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)restore {
  NSData* data = [NSData dataWithContentsOfURL:storeFileURL_];
  if (data.length == 0) {
    return;
  }

  NSDictionary* state = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  NSDictionary* icons = [state isKindOfClass:NSDictionary.class] ? state[@"icons"] : nil;
  if (![icons isKindOfClass:NSDictionary.class]) {
    return;
  }

  [faviconImagesByOrigin_ removeAllObjects];
  for (NSString* originKey in icons) {
    NSString* base64Icon = icons[originKey];
    if (![originKey isKindOfClass:NSString.class] ||
        ![base64Icon isKindOfClass:NSString.class]) {
      continue;
    }

    NSData* iconData = [[NSData alloc] initWithBase64EncodedString:base64Icon options:0];
    NSImage* iconImage = [[NSImage alloc] initWithData:iconData];
    if (!iconImage) {
      continue;
    }

    iconImage.size = NSMakeSize(16.0, 16.0);
    faviconImagesByOrigin_[originKey] = iconImage;
  }
}

- (void)cacheFaviconImage:(NSImage*)faviconImage forURLString:(NSString*)urlString {
  NSString* originKey = [self faviconOriginKeyForURLString:urlString];
  if (originKey.length == 0 || !faviconImage) {
    return;
  }

  faviconImagesByOrigin_[originKey] = faviconImage;
  [self save];
}

- (NSImage*)faviconImageForURLString:(NSString*)urlString {
  NSString* originKey = [self faviconOriginKeyForURLString:urlString];
  if (originKey.length == 0) {
    return nil;
  }

  return faviconImagesByOrigin_[originKey];
}

- (NSImage*)faviconImageMatchingNormalizedTitle:(NSString*)normalizedTitle {
  if (normalizedTitle.length == 0) {
    return nil;
  }

  for (NSString* originKey in faviconImagesByOrigin_) {
    NSString* host = [NSURLComponents componentsWithString:originKey].host.lowercaseString;
    if (host.length == 0) {
      continue;
    }

    NSString* normalizedHost = [self normalizedFaviconHostString:host];
    if (normalizedHost.length > 0 &&
        ([normalizedTitle isEqualToString:normalizedHost] ||
         [normalizedTitle hasPrefix:[normalizedHost stringByAppendingString:@" "]])) {
      return faviconImagesByOrigin_[originKey];
    }
  }

  return nil;
}

- (NSString*)faviconOriginKeyForURLString:(NSString*)urlString {
  if (urlString.length == 0 ||
      [urlString hasPrefix:@"babelchrome://"] ||
      [urlString hasPrefix:@"data:"] ||
      [urlString hasPrefix:@"view-source:"]) {
    return nil;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:urlString];
  if (components.scheme.length == 0 || components.host.length == 0) {
    return nil;
  }

  NSString* scheme = components.scheme.lowercaseString;
  NSString* host = components.host.lowercaseString;
  if (components.port) {
    return [NSString stringWithFormat:@"%@://%@:%@", scheme, host, components.port];
  }

  return [NSString stringWithFormat:@"%@://%@", scheme, host];
}

- (NSString*)normalizedFaviconHostString:(NSString*)host {
  NSString* normalizedHost = host.lowercaseString ?: @"";
  if ([normalizedHost hasPrefix:@"www."]) {
    normalizedHost = [normalizedHost substringFromIndex:4];
  }

  NSArray<NSString*>* parts = [normalizedHost componentsSeparatedByString:@"."];
  return parts.count > 0 ? parts.firstObject : normalizedHost;
}

- (void)save {
  NSMutableDictionary<NSString*, NSString*>* encodedIcons = [NSMutableDictionary dictionary];
  for (NSString* originKey in faviconImagesByOrigin_) {
    NSString* base64Icon = [self PNGBase64StringForImage:faviconImagesByOrigin_[originKey]];
    if (base64Icon.length == 0) {
      continue;
    }

    encodedIcons[originKey] = base64Icon;
  }

  NSDictionary* state = @{@"icons": encodedIcons};
  [NSFileManager.defaultManager createDirectoryAtURL:storeFileURL_.URLByDeletingLastPathComponent
                         withIntermediateDirectories:YES
                                          attributes:nil
                                               error:nil];
  NSData* data = [NSJSONSerialization dataWithJSONObject:state
                                                 options:NSJSONWritingPrettyPrinted
                                                   error:nil];
  [data writeToURL:storeFileURL_ atomically:YES];
}

- (NSString*)PNGBase64StringForImage:(NSImage*)image {
  NSData* TIFFData = image.TIFFRepresentation;
  if (TIFFData.length == 0) {
    return nil;
  }

  NSBitmapImageRep* imageRep = [NSBitmapImageRep imageRepWithData:TIFFData];
  NSData* PNGData = [imageRep representationUsingType:NSBitmapImageFileTypePNG
                                           properties:@{}];
  return [PNGData base64EncodedStringWithOptions:0];
}

@end
