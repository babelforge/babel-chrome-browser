#ifndef BABEL_CHROME_BROWSER_TAB_CREATION_COORDINATOR_H_
#define BABEL_CHROME_BROWSER_TAB_CREATION_COORDINATOR_H_

#import <Cocoa/Cocoa.h>

@class BabelBrowserGroup;
@class BabelBrowserTab;
@class BabelBrowserTabFactory;
@class BabelBrowserTabInsertionCoordinator;
@class BabelTabContentViewAttacher;

typedef NSString* (^BabelBrowserTabOpeningStrategyProvider)(void);

/**
 * Creates tabs and attaches their native page views.
 */
@interface BabelBrowserTabCreationCoordinator : NSObject

/**
 * Creates a tab creation coordinator.
 *
 * @param tabFactory The factory used to create native tabs.
 * @param insertionCoordinator The coordinator used to insert parented tabs.
 * @param contentViewAttacher The service used to attach content views.
 * @param pagesPanel The pages panel receiving content views.
 * @param tabOpeningStrategyProvider The provider for the current tab opening strategy.
 * @return The initialized coordinator.
 */
- (instancetype)initWithTabFactory:(BabelBrowserTabFactory*)tabFactory
              insertionCoordinator:(BabelBrowserTabInsertionCoordinator*)insertionCoordinator
                contentViewAttacher:(BabelTabContentViewAttacher*)contentViewAttacher
                         pagesPanel:(NSView*)pagesPanel
         tabOpeningStrategyProvider:(BabelBrowserTabOpeningStrategyProvider)tabOpeningStrategyProvider;

/**
 * Makes a detached tab model.
 *
 * @param urlString The URL string.
 * @param identifier The optional tab identifier.
 * @param title The tab title.
 * @return The created tab.
 */
- (BabelBrowserTab*)makeTabForURL:(NSString*)urlString
                       identifier:(NSString*)identifier
                            title:(NSString*)title;

/**
 * Creates a tab at the end of a group and attaches its views.
 *
 * @param urlString The URL string.
 * @param group The target group.
 * @return The created tab.
 */
- (BabelBrowserTab*)createTabForURL:(NSString*)urlString inGroup:(BabelBrowserGroup*)group;

/**
 * Creates a parented tab and attaches its views.
 *
 * @param urlString The URL string.
 * @param group The target group.
 * @param parentTab The parent tab.
 * @param respectingUserStrategy YES to apply the user-selected strategy.
 * @return The created tab.
 */
- (BabelBrowserTab*)createTabForURL:(NSString*)urlString
                            inGroup:(BabelBrowserGroup*)group
                          parentTab:(BabelBrowserTab*)parentTab
             respectingUserStrategy:(BOOL)respectingUserStrategy;

/**
 * Inserts an existing tab into a group.
 *
 * @param tab The tab to insert.
 * @param group The target group.
 * @param parentTab The parent tab.
 * @param respectingUserStrategy YES to apply the user-selected strategy.
 */
- (void)insertTab:(BabelBrowserTab*)tab
          inGroup:(BabelBrowserGroup*)group
        parentTab:(BabelBrowserTab*)parentTab
respectingUserStrategy:(BOOL)respectingUserStrategy;

@end

#endif
