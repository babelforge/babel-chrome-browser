#import "Browser/ViewerNavigationURLResolver.h"

#import "Browser/HTMLDataURLBuilder.h"
#import "Browser/NoViewerPageRenderer.h"
#import "Browser/StableViewerURLResolver.h"
#import "LocalServices/LocalServiceHost.h"

@implementation BabelViewerNavigationURLResolver {
  BabelStableViewerURLResolver* stableViewerURLResolver_;
  BabelNoViewerPageRenderer* noViewerPageRenderer_;
  BabelHTMLDataURLBuilder* htmlDataURLBuilder_;
}

- (instancetype)initWithStableViewerURLResolver:(BabelStableViewerURLResolver*)stableViewerURLResolver
                           noViewerPageRenderer:(BabelNoViewerPageRenderer*)noViewerPageRenderer
                             htmlDataURLBuilder:(BabelHTMLDataURLBuilder*)htmlDataURLBuilder {
  self = [super init];
  if (self) {
    stableViewerURLResolver_ = stableViewerURLResolver;
    noViewerPageRenderer_ = noViewerPageRenderer;
    htmlDataURLBuilder_ = htmlDataURLBuilder;
  }
  return self;
}

- (NSString*)stableViewerURLStringForSupportedURLString:(NSString*)urlString {
  if ([stableViewerURLResolver_ isStableViewerURLString:urlString]) {
    return urlString;
  }

  NSURL* url = [NSURL URLWithString:urlString ?: @""];
  if (!url || ![BabelLocalServiceHost.sharedHost supportsURL:url]) {
    return nil;
  }

  NSString* viewerKind = [BabelLocalServiceHost.sharedHost viewerKindForURL:url];
  if (viewerKind.length == 0) {
    return nil;
  }

  BOOL isRemoteURL = [url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"];
  NSString* sourceKind = isRemoteURL ? @"url" : @"file";
  NSString* sourceValue = isRemoteURL ? url.absoluteString : url.path;
  NSString* encodedSourceValue = [stableViewerURLResolver_ escapedStableViewerString:sourceValue];
  if (encodedSourceValue.length == 0) {
    return nil;
  }

  return [NSString stringWithFormat:@"babelchrome://%@/%@/%@",
                                    viewerKind,
                                    sourceKind,
                                    encodedSourceValue];
}

- (NSString*)navigationURLStringForStableViewerURLString:(NSString*)urlString
                                          markdownTheme:(NSString*)markdownTheme
                                                  error:(NSError**)error {
  NSURL* url = [stableViewerURLResolver_ sourceURLForViewerURLString:urlString];
  if (!url || ![BabelLocalServiceHost.sharedHost supportsURL:url]) {
    return nil;
  }

  NSError* serviceError = nil;
  if (![BabelLocalServiceHost.sharedHost startIfNeededWithError:&serviceError]) {
    if (error) {
      *error = serviceError;
    }
    return nil;
  }

  NSURL* viewerURL = [BabelLocalServiceHost.sharedHost viewerURLForURL:url];
  NSURLComponents* viewerComponents = viewerURL ? [NSURLComponents componentsWithURL:viewerURL
                                                             resolvingAgainstBaseURL:NO] : nil;
  NSString* viewerKind = [stableViewerURLResolver_ resolvedViewerKindForStableViewerURLString:urlString];
  if (viewerKind.length == 0) {
    viewerKind = [BabelLocalServiceHost.sharedHost viewerKindForURL:url];
  }
  if (viewerComponents && [viewerKind isEqualToString:@"markdown"]) {
    NSMutableArray<NSURLQueryItem*>* queryItems =
        [viewerComponents.queryItems mutableCopy] ?: [NSMutableArray array];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"theme" value:markdownTheme]];
    viewerComponents.queryItems = queryItems;
    viewerURL = viewerComponents.URL;
  }

  NSString* viewerURLString = viewerURL.absoluteString;
  NSString* fragment = [stableViewerURLResolver_ fragmentForStableViewerURLString:urlString];
  if (viewerURLString.length > 0 && fragment.length > 0) {
    return [viewerURLString stringByAppendingString:fragment];
  }

  return viewerURLString;
}

- (NSString*)noViewerInstalledPageURLStringForStableViewerURLString:(NSString*)urlString {
  NSURL* sourceURL = [stableViewerURLResolver_ sourceURLForViewerURLString:urlString];
  NSString* html = [noViewerPageRenderer_ htmlForSourceURL:sourceURL fallbackURLString:urlString];
  return [htmlDataURLBuilder_ dataURLStringForHTML:html];
}

@end
