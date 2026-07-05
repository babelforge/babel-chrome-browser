#import "Browser/BrowserThemeApplier.h"

#import "Browser/BrowserModels.h"
#import "Browser/BrowserTheme.h"
#import "Browser/BrowserViews.h"

@implementation BabelBrowserThemeApplier

- (void)applyThemeToRootView:(NSView*)rootView
                 sidebarView:(NSView*)sidebarView
                   rightView:(NSView*)rightView
                tabsBarPanel:(NSView*)tabsBarPanel
             addressBarPanel:(NSView*)addressBarPanel
                addressLabel:(NSTextField*)addressLabel
   addressTextFieldContainer:(NSView*)addressTextFieldContainer
                urlTextField:(NSTextField*)urlTextField
     omniboxSuggestionsPanel:(NSView*)omniboxSuggestionsPanel
           linkStatusBarView:(NSView*)linkStatusBarView
          linkStatusBarLabel:(NSTextField*)linkStatusBarLabel
                      groups:(NSArray<BabelBrowserGroup*>*)groups {
  BabelTheme* theme = BabelTheme.sharedTheme;
  rootView.appearance = [theme forcedAppearance];
  sidebarView.layer.backgroundColor = [theme cgColorForToken:@"sidebar.background" view:sidebarView];
  rightView.layer.backgroundColor = [theme cgColorForToken:@"address.panel.background" view:rightView];
  tabsBarPanel.layer.backgroundColor = [theme cgColorForToken:@"tabsBar.background" view:tabsBarPanel];
  addressBarPanel.layer.backgroundColor = [theme cgColorForToken:@"address.panel.background" view:addressBarPanel];
  addressLabel.textColor = [theme colorForToken:@"address.title" view:addressLabel];
  addressTextFieldContainer.layer.backgroundColor =
      [theme cgColorForToken:@"address.container.background" view:addressTextFieldContainer];
  addressTextFieldContainer.layer.borderColor =
      [theme cgColorForToken:@"address.border" view:addressTextFieldContainer];
  urlTextField.textColor = [theme colorForToken:@"address.text" view:urlTextField];
  omniboxSuggestionsPanel.layer.backgroundColor =
      [theme cgColorForToken:@"omnibox.panel.background" view:omniboxSuggestionsPanel];
  omniboxSuggestionsPanel.layer.borderColor =
      [theme cgColorForToken:@"omnibox.border" view:omniboxSuggestionsPanel];
  linkStatusBarView.layer.backgroundColor =
      [theme cgColorForToken:@"linkStatus.background" view:linkStatusBarView];
  linkStatusBarView.layer.borderColor =
      [theme cgColorForToken:@"linkStatus.border" view:linkStatusBarView];
  linkStatusBarLabel.textColor = [theme colorForToken:@"linkStatus.text" view:linkStatusBarLabel];

  for (BabelBrowserGroup* group in groups) {
    [group.groupItemView setNeedsDisplay:YES];
    for (BabelBrowserTab* tab in group.tabs) {
      tab.developerToolsPanelView.layer.backgroundColor =
          [theme cgColorForToken:@"developerTools.panel.background" view:tab.developerToolsPanelView];
      tab.developerToolsToolbarView.layer.backgroundColor =
          [theme cgColorForToken:@"developerTools.toolbar.background" view:tab.developerToolsToolbarView];
      tab.developerToolsResizeHandleView.layer.backgroundColor =
          [theme cgColorForToken:@"developerTools.handle.background" view:tab.developerToolsResizeHandleView];
      tab.developerToolsHostView.layer.backgroundColor =
          [theme cgColorForToken:@"developerTools.panel.background" view:tab.developerToolsHostView];
      [tab.developerToolsResizeHandleView setNeedsDisplay:YES];
      [tab.tabItemView setNeedsDisplay:YES];
    }
  }

  for (NSView* suggestionRow in omniboxSuggestionsPanel.subviews) {
    if ([suggestionRow respondsToSelector:@selector(setSuggestionHighlighted:)]) {
      [suggestionRow setNeedsDisplay:YES];
    }
  }
}

@end
