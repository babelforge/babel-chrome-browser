#import <Cocoa/Cocoa.h>

@class BabelBadgeLabel;
@class BabelDeveloperToolsResizeHandleView;

@interface BabelMainWindowViewSet : NSObject

@property(nonatomic, strong) NSView* rootView;
@property(nonatomic, strong) NSView* splitView;
@property(nonatomic, strong) NSView* sidebarView;
@property(nonatomic, strong) BabelDeveloperToolsResizeHandleView* sidebarResizeHandleView;
@property(nonatomic, strong) NSTextField* sidebarTitle;
@property(nonatomic, strong) NSButton* sidebarCollapseButton;
@property(nonatomic, strong) NSButton* groupAddButton;
@property(nonatomic, strong) NSView* groupsListView;
@property(nonatomic, strong) NSView* rightView;
@property(nonatomic, strong) NSView* tabsBarPanel;
@property(nonatomic, strong) NSView* tabsItemsPanel;
@property(nonatomic, strong) NSButton* tabAddButton;
@property(nonatomic, strong) NSView* addressBarPanel;
@property(nonatomic, strong) NSTextField* addressLabel;
@property(nonatomic, strong) NSView* addressTextFieldContainer;
@property(nonatomic, strong) NSTextField* urlTextField;
@property(nonatomic, strong) BabelBadgeLabel* viewerBadgeLabel;
@property(nonatomic, strong) NSButton* reloadButton;
@property(nonatomic, strong) NSView* omniboxSuggestionsPanel;
@property(nonatomic, strong) NSView* pagesPanel;
@property(nonatomic, strong) NSView* linkStatusBarView;
@property(nonatomic, strong) NSTextField* linkStatusBarLabel;

@end

@interface BabelMainWindowViewFactory : NSObject

- (BabelMainWindowViewSet*)viewSetWithWindowBounds:(NSRect)windowBounds
                                            target:(id)target
                                  initialSidebarWidth:(CGFloat)initialSidebarWidth
                                      tabBarHeight:(CGFloat)tabBarHeight
                                     toolbarHeight:(CGFloat)toolbarHeight
                              sidebarHeaderButtonSize:(CGFloat)sidebarHeaderButtonSize
                           sidebarHeaderLeadingInset:(CGFloat)sidebarHeaderLeadingInset
                               sidebarHeaderButtonGap:(CGFloat)sidebarHeaderButtonGap
                           linkStatusBarHeight:(CGFloat)linkStatusBarHeight;

@end
