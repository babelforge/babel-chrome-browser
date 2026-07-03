#import "Browser/BrowserTabFactory.h"

#import "Browser/BrowserModels.h"
#import "Browser/BrowserTheme.h"
#import "Browser/BrowserViews.h"
#import "Browser/FaviconStore.h"

@implementation BabelBrowserTabFactory {
  __weak id actionTarget_;
  BabelFaviconStore* faviconStore_;
  NSString* (^compactTitleBlock_)(NSString* title);
  BOOL (^localDropAcceptanceBlock_)(BabelPageContainerView* container);
  void (^localDropHandlerBlock_)(BabelPageContainerView* container);
}

- (instancetype)initWithFaviconStore:(BabelFaviconStore*)faviconStore
                         actionTarget:(id)actionTarget
                    compactTitleBlock:(NSString* (^)(NSString* title))compactTitleBlock
             localDropAcceptanceBlock:(BOOL (^)(BabelPageContainerView* container))localDropAcceptanceBlock
                 localDropHandlerBlock:(void (^)(BabelPageContainerView* container))localDropHandlerBlock {
  self = [super init];
  if (self) {
    faviconStore_ = faviconStore;
    actionTarget_ = actionTarget;
    compactTitleBlock_ = [compactTitleBlock copy];
    localDropAcceptanceBlock_ = [localDropAcceptanceBlock copy];
    localDropHandlerBlock_ = [localDropHandlerBlock copy];
  }
  return self;
}

- (BabelBrowserTab*)makeTabForURL:(NSString*)urlString
                       identifier:(NSString*)identifier
                            title:(NSString*)title
                       hostBounds:(NSRect)hostBounds {
  BabelBrowserTab* tab = [[BabelBrowserTab alloc] init];
  tab.identifier = identifier ?: NSUUID.UUID.UUIDString;
  tab.urlString = urlString;
  tab.requestedURLString = urlString;
  tab.title = title ?: urlString;
  tab.hostView = [[BabelPageContainerView alloc] initWithFrame:hostBounds];
  tab.hostView.canAcceptLocalDrop = localDropAcceptanceBlock_;
  tab.hostView.localDropHandler = localDropHandlerBlock_;
  tab.hostView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  tab.hostView.hidden = YES;

  [self configureDeveloperToolsViewsForTab:tab];
  [self configureTabItemForTab:tab];
  return tab;
}

- (void)configureDeveloperToolsViewsForTab:(BabelBrowserTab*)tab {
  tab.developerToolsPanelView = [[NSView alloc] initWithFrame:NSZeroRect];
  tab.developerToolsPanelView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  tab.developerToolsPanelView.hidden = YES;
  tab.developerToolsPanelView.wantsLayer = YES;
  tab.developerToolsPanelView.layer.backgroundColor =
      [BabelTheme.sharedTheme cgColorForToken:@"developerTools.panel.background"
                                         view:tab.developerToolsPanelView];

  tab.developerToolsToolbarView = [[NSView alloc] initWithFrame:NSZeroRect];
  tab.developerToolsToolbarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  tab.developerToolsToolbarView.wantsLayer = YES;
  tab.developerToolsToolbarView.layer.backgroundColor =
      [BabelTheme.sharedTheme cgColorForToken:@"developerTools.toolbar.background"
                                         view:tab.developerToolsToolbarView];
  [tab.developerToolsPanelView addSubview:tab.developerToolsToolbarView];

  tab.developerToolsResizeHandleView =
      [[BabelDeveloperToolsResizeHandleView alloc] initWithFrame:NSZeroRect];
  tab.developerToolsResizeHandleView.resizeTarget = actionTarget_;
  tab.developerToolsResizeHandleView.resizeAction = @selector(resizeDeveloperToolsFromHandle:);
  tab.developerToolsResizeHandleView.wantsLayer = YES;
  tab.developerToolsResizeHandleView.layer.backgroundColor =
      [BabelTheme.sharedTheme cgColorForToken:@"developerTools.handle.background"
                                         view:tab.developerToolsResizeHandleView];
  [tab.developerToolsPanelView addSubview:tab.developerToolsResizeHandleView];

  tab.developerToolsHostView = [[BabelBrowserHostView alloc] initWithFrame:NSZeroRect];
  tab.developerToolsHostView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  tab.developerToolsHostView.wantsLayer = YES;
  tab.developerToolsHostView.layer.backgroundColor =
      [BabelTheme.sharedTheme cgColorForToken:@"developerTools.panel.background"
                                         view:tab.developerToolsHostView];
  [tab.developerToolsPanelView addSubview:tab.developerToolsHostView];
  [self addDeveloperToolsControlsToTab:tab];
  tab.developerToolsVisible = NO;
}

- (void)configureTabItemForTab:(BabelBrowserTab*)tab {
  NSString* visibleTitle = compactTitleBlock_ ? compactTitleBlock_(tab.title) : tab.title;
  tab.tabItemView = [[BabelTabItemView alloc] initWithIdentifier:tab.identifier
                                                           title:visibleTitle];
  tab.tabItemView.faviconImage = [faviconStore_ faviconImageForURLString:tab.urlString];
  tab.tabItemView.target = actionTarget_;
  tab.tabItemView.action = @selector(selectTabFromItem:);
  tab.tabItemView.closeTarget = actionTarget_;
  tab.tabItemView.closeAction = @selector(closeTabFromItem:);
  tab.tabItemView.dragTarget = actionTarget_;
  tab.tabItemView.dragAction = @selector(dragTabFromItem:);
  tab.tabItemView.dragEndTarget = actionTarget_;
  tab.tabItemView.dragEndAction = @selector(finishDraggingTabFromItem:);
}

- (void)addDeveloperToolsControlsToTab:(BabelBrowserTab*)tab {
  NSArray<NSButton*>* buttons = @[
    [self developerToolsButtonWithImageName:@"devtools-close"
                              fallbackTitle:@"x"
                                    toolTip:@"Close Developer Tools"
                                        tag:0
                                     action:@selector(closeDeveloperToolsFromButton:)],
    [self developerToolsButtonWithImageName:@"devtools-dock-left"
                              fallbackTitle:@"L"
                                    toolTip:@"Dock Developer Tools Left"
                                        tag:1
                                     action:@selector(changeDeveloperToolsDockFromButton:)],
    [self developerToolsButtonWithImageName:@"devtools-dock-right"
                              fallbackTitle:@"R"
                                    toolTip:@"Dock Developer Tools Right"
                                        tag:2
                                     action:@selector(changeDeveloperToolsDockFromButton:)],
    [self developerToolsButtonWithImageName:@"devtools-dock-bottom"
                              fallbackTitle:@"B"
                                    toolTip:@"Dock Developer Tools Bottom"
                                        tag:3
                                     action:@selector(changeDeveloperToolsDockFromButton:)],
    [self developerToolsButtonWithImageName:@"devtools-dock-top"
                              fallbackTitle:@"T"
                                    toolTip:@"Dock Developer Tools Top"
                                        tag:4
                                     action:@selector(changeDeveloperToolsDockFromButton:)]
  ];

  CGFloat x = 8.0;
  for (NSButton* button in buttons) {
    button.frame = NSMakeRect(x, 4.0, 26.0, 22.0);
    [tab.developerToolsToolbarView addSubview:button];
    x += 30.0;
  }
}

- (NSButton*)developerToolsButtonWithImageName:(NSString*)imageName
                                 fallbackTitle:(NSString*)fallbackTitle
                                       toolTip:(NSString*)toolTip
                                           tag:(NSInteger)tag
                                        action:(SEL)action {
  NSButton* button = BabelButton(fallbackTitle, actionTarget_, action);
  button.bezelStyle = NSBezelStyleTexturedRounded;
  button.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
  button.toolTip = toolTip;
  button.tag = tag;
  ConfigureIconButton(button, imageName, fallbackTitle);
  return button;
}

@end
