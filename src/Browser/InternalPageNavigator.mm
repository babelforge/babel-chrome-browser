#import "Browser/InternalPageNavigator.h"

#import "Browser/BrowserModels.h"
#import "Browser/BrowserViews.h"
#import "Browser/TabContentViewAttacher.h"

@implementation BabelInternalPageNavigator {
  NSView* pagesPanel_;
  BabelTabContentViewAttacher* tabContentViewAttacher_;
  BabelInternalPageBrowserTabProvider browserTabProvider_;
  BabelInternalPageDefaultGroupProvider defaultGroupProvider_;
  BabelInternalPageExistingTabProvider existingTabProvider_;
  BabelInternalPageTabFactoryBlock tabFactoryBlock_;
  BabelInternalPageHTMLDataURLBuilderBlock dataURLBuilderBlock_;
  BabelInternalPageCompactTitleBlock compactTitleBlock_;
  BabelInternalPageGroupHandler selectGroupHandler_;
  BabelInternalPageTabHandler selectTabHandler_;
  BabelInternalPageVoidHandler showWindowHandler_;
  BabelInternalPageVoidHandler saveStateHandler_;
}

- (instancetype)initWithPagesPanel:(NSView*)pagesPanel
             tabContentViewAttacher:(BabelTabContentViewAttacher*)tabContentViewAttacher
                 browserTabProvider:(BabelInternalPageBrowserTabProvider)browserTabProvider
                defaultGroupProvider:(BabelInternalPageDefaultGroupProvider)defaultGroupProvider
                existingTabProvider:(BabelInternalPageExistingTabProvider)existingTabProvider
                    tabFactoryBlock:(BabelInternalPageTabFactoryBlock)tabFactoryBlock
                 dataURLBuilderBlock:(BabelInternalPageHTMLDataURLBuilderBlock)dataURLBuilderBlock
                   compactTitleBlock:(BabelInternalPageCompactTitleBlock)compactTitleBlock
                   selectGroupHandler:(BabelInternalPageGroupHandler)selectGroupHandler
                     selectTabHandler:(BabelInternalPageTabHandler)selectTabHandler
                    showWindowHandler:(BabelInternalPageVoidHandler)showWindowHandler
                     saveStateHandler:(BabelInternalPageVoidHandler)saveStateHandler {
  self = [super init];
  if (self) {
    pagesPanel_ = pagesPanel;
    tabContentViewAttacher_ = tabContentViewAttacher;
    browserTabProvider_ = [browserTabProvider copy];
    defaultGroupProvider_ = [defaultGroupProvider copy];
    existingTabProvider_ = [existingTabProvider copy];
    tabFactoryBlock_ = [tabFactoryBlock copy];
    dataURLBuilderBlock_ = [dataURLBuilderBlock copy];
    compactTitleBlock_ = [compactTitleBlock copy];
    selectGroupHandler_ = [selectGroupHandler copy];
    selectTabHandler_ = [selectTabHandler copy];
    showWindowHandler_ = [showWindowHandler copy];
    saveStateHandler_ = [saveStateHandler copy];
  }
  return self;
}

- (void)openInternalPageWithURLString:(NSString*)internalURLString
                                title:(NSString*)title
                                 html:(NSString*)html
                              browser:(CefRefPtr<CefBrowser>)browser {
  NSString* dataURLString = dataURLBuilderBlock_ ? dataURLBuilderBlock_(html) : @"";
  if (browser) {
    BabelBrowserTab* targetTab = browserTabProvider_ ? browserTabProvider_(browser) : nil;
    if (targetTab) {
      [self configureTab:targetTab
       internalURLString:internalURLString
                   title:title
           dataURLString:dataURLString];
      browser->GetMainFrame()->LoadURL(std::string(dataURLString.UTF8String));
      [self selectAndPersistTab:targetTab];
      return;
    }
  }

  BabelBrowserGroup* group = defaultGroupProvider_ ? defaultGroupProvider_() : nil;
  if (!group) {
    return;
  }
  if (selectGroupHandler_) {
    selectGroupHandler_(group);
  }

  BabelBrowserTab* existingTab = existingTabProvider_ ? existingTabProvider_(internalURLString, group) : nil;
  if (existingTab) {
    [self configureTab:existingTab
     internalURLString:internalURLString
                 title:title
         dataURLString:dataURLString];
    [self selectAndPersistTab:existingTab];
    if ([existingTab browser]) {
      [existingTab browser]->GetMainFrame()->LoadURL(std::string(dataURLString.UTF8String));
    }
    return;
  }

  BabelBrowserTab* tab = tabFactoryBlock_ ? tabFactoryBlock_(dataURLString, nil, title) : nil;
  if (!tab) {
    return;
  }
  tab.requestedURLString = internalURLString;
  [group.tabs addObject:tab];
  [tabContentViewAttacher_ attachTab:tab toPagesPanel:pagesPanel_];
  [self selectAndPersistTab:tab];
}

- (void)configureTab:(BabelBrowserTab*)tab
 internalURLString:(NSString*)internalURLString
             title:(NSString*)title
     dataURLString:(NSString*)dataURLString {
  tab.urlString = dataURLString;
  tab.requestedURLString = internalURLString;
  tab.title = title;
  tab.tabItemView.title = compactTitleBlock_ ? compactTitleBlock_(title) : title;
}

- (void)selectAndPersistTab:(BabelBrowserTab*)tab {
  if (selectTabHandler_) {
    selectTabHandler_(tab);
  }
  if (showWindowHandler_) {
    showWindowHandler_();
  }
  if (saveStateHandler_) {
    saveStateHandler_();
  }
}

@end
