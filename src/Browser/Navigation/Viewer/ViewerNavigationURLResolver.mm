#import "Browser/Navigation/Viewer/ViewerNavigationURLResolver.h"

#import "Browser/Modules/Core/ModuleActionService.h"
#import "Browser/Utilities/HTML/HTMLDataURLBuilder.h"
#import "Browser/InternalPages/Rendering/NoViewerPageRenderer.h"
#import "Browser/Navigation/StableURLs/StableViewerURLResolver.h"

@implementation BabelViewerNavigationURLResolver {
  BabelStableViewerURLResolver* stableViewerURLResolver_;
  BabelModuleActionService* moduleActionService_;
  BabelNoViewerPageRenderer* noViewerPageRenderer_;
  BabelHTMLDataURLBuilder* htmlDataURLBuilder_;
}

- (instancetype)initWithStableViewerURLResolver:(BabelStableViewerURLResolver*)stableViewerURLResolver
                            moduleActionService:(BabelModuleActionService*)moduleActionService
                           noViewerPageRenderer:(BabelNoViewerPageRenderer*)noViewerPageRenderer
                             htmlDataURLBuilder:(BabelHTMLDataURLBuilder*)htmlDataURLBuilder {
  self = [super init];
  if (self) {
    stableViewerURLResolver_ = stableViewerURLResolver;
    moduleActionService_ = moduleActionService;
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
  if (!url || ![moduleActionService_ supportsViewerURL:url]) {
    return nil;
  }

  BOOL isRemoteURL = [url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"];
  NSString* sourceKind = isRemoteURL ? @"url" : @"file";
  NSString* sourceValue = isRemoteURL ? url.absoluteString : url.path;
  NSString* encodedSourceValue = [stableViewerURLResolver_ escapedStableViewerString:sourceValue];
  if (encodedSourceValue.length == 0) {
    return nil;
  }

  return [NSString stringWithFormat:@"babelchrome://viewer/%@/%@",
                                    sourceKind,
                                    encodedSourceValue];
}

- (NSString*)navigationURLStringForStableViewerURLString:(NSString*)urlString
                                          markdownTheme:(NSString*)markdownTheme
                                                  error:(NSError**)error {
  NSURL* url = [stableViewerURLResolver_ sourceURLForViewerURLString:urlString];
  if (!url || ![moduleActionService_ supportsViewerURL:url]) {
    return nil;
  }

  NSString* preferredViewerKind = [stableViewerURLResolver_ resolvedViewerKindForStableViewerURLString:urlString];
  NSURL* viewerURL = [moduleActionService_ viewerURLForURL:url
                                       preferredViewerKind:preferredViewerKind
                                             markdownTheme:markdownTheme
                                                     error:error];

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
