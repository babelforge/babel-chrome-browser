#ifndef BABEL_CHROME_BROWSER_THEME_APPLIER_H_
#define BABEL_CHROME_BROWSER_THEME_APPLIER_H_

#import <Cocoa/Cocoa.h>

@class BabelBrowserGroup;

/**
 * Applies the active BabelChrome theme to existing browser window views.
 */
@interface BabelBrowserThemeApplier : NSObject

/**
 * Applies the active theme to the main browser chrome.
 *
 * @param rootView The themed root view.
 * @param sidebarView The sidebar view.
 * @param rightView The right content view.
 * @param tabsBarPanel The tab bar panel.
 * @param addressBarPanel The address bar panel.
 * @param addressLabel The address title label.
 * @param addressTextFieldContainer The address field container.
 * @param urlTextField The URL text field.
 * @param omniboxSuggestionsPanel The suggestions panel.
 * @param linkStatusBarView The link-hover status bar view.
 * @param linkStatusBarLabel The link-hover status label.
 * @param groups The current browser groups.
 */
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
                      groups:(NSArray<BabelBrowserGroup*>*)groups;

@end

#endif
