#import "Browser/Tabs/Creation/BrowserTabCreationCoordinator.h"

#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/Tabs/Creation/BrowserTabFactory.h"
#import "Browser/Tabs/Creation/BrowserTabInsertionCoordinator.h"
#import "Browser/Tabs/UI/TabContentViewAttacher.h"

@implementation BabelBrowserTabCreationCoordinator {
  BabelBrowserTabFactory* tabFactory_;
  BabelBrowserTabInsertionCoordinator* insertionCoordinator_;
  BabelTabContentViewAttacher* contentViewAttacher_;
  NSView* pagesPanel_;
  BabelBrowserTabOpeningStrategyProvider tabOpeningStrategyProvider_;
}

- (instancetype)initWithTabFactory:(BabelBrowserTabFactory*)tabFactory
              insertionCoordinator:(BabelBrowserTabInsertionCoordinator*)insertionCoordinator
                contentViewAttacher:(BabelTabContentViewAttacher*)contentViewAttacher
                         pagesPanel:(NSView*)pagesPanel
         tabOpeningStrategyProvider:(BabelBrowserTabOpeningStrategyProvider)tabOpeningStrategyProvider {
  self = [super init];
  if (self) {
    tabFactory_ = tabFactory;
    insertionCoordinator_ = insertionCoordinator;
    contentViewAttacher_ = contentViewAttacher;
    pagesPanel_ = pagesPanel;
    tabOpeningStrategyProvider_ = [tabOpeningStrategyProvider copy];
  }
  return self;
}

- (BabelBrowserTab*)makeTabForURL:(NSString*)urlString
                       identifier:(NSString*)identifier
                            title:(NSString*)title {
  return [tabFactory_ makeTabForURL:urlString
                         identifier:identifier
                              title:title
                         hostBounds:pagesPanel_.bounds];
}

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString inGroup:(BabelBrowserGroup*)group {
  BabelBrowserTab* tab = [self makeTabForURL:urlString identifier:nil title:urlString];
  [group.tabs addObject:tab];
  [contentViewAttacher_ attachTab:tab toPagesPanel:pagesPanel_];
  return tab;
}

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString
                            inGroup:(BabelBrowserGroup*)group
                          parentTab:(BabelBrowserTab*)parentTab
             respectingUserStrategy:(BOOL)respectingUserStrategy {
  BabelBrowserTab* tab = [self makeTabForURL:urlString identifier:nil title:urlString];
  tab.parentTabIdentifier = parentTab.identifier;
  [self insertTab:tab
          inGroup:group
        parentTab:parentTab
respectingUserStrategy:respectingUserStrategy];
  [contentViewAttacher_ attachTab:tab toPagesPanel:pagesPanel_];
  return tab;
}

- (void)insertTab:(BabelBrowserTab*)tab
          inGroup:(BabelBrowserGroup*)group
        parentTab:(BabelBrowserTab*)parentTab
respectingUserStrategy:(BOOL)respectingUserStrategy {
  NSString* strategy = tabOpeningStrategyProvider_ ? tabOpeningStrategyProvider_() : @"";
  [insertionCoordinator_ insertTab:tab
                           inGroup:group
                         parentTab:parentTab
                          strategy:strategy
           respectingUserStrategy:respectingUserStrategy];
}

@end
