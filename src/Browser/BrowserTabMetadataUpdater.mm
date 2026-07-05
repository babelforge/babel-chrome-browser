#import "Browser/BrowserTabMetadataUpdater.h"

#import "Browser/BrowserModels.h"
#import "Browser/BrowserViews.h"
#import "Browser/FaviconStore.h"

@implementation BabelBrowserTabMetadataUpdater

- (BOOL)updateTab:(BabelBrowserTab*)tab
        withTitle:(NSString*)title
compactTitleBlock:(BabelCompactTitleBlock)compactTitleBlock {
  if (!tab) {
    return NO;
  }

  BOOL isGeneratedTitle = [title hasPrefix:@"data:"] || [title containsString:@"data:text"];
  tab.title = title.length > 0 && !isGeneratedTitle ? title : tab.urlString;
  tab.tabItemView.title = compactTitleBlock ? compactTitleBlock(tab.title) : tab.title;
  return YES;
}

- (BOOL)updateTab:(BabelBrowserTab*)tab
 withFaviconImage:(NSImage*)faviconImage
     faviconStore:(BabelFaviconStore*)faviconStore {
  if (!tab || !faviconImage) {
    return NO;
  }

  tab.faviconImage = faviconImage;
  tab.tabItemView.faviconImage = faviconImage;
  [faviconStore cacheFaviconImage:faviconImage forURLString:tab.urlString];
  return YES;
}

@end
