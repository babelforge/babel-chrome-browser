#ifndef BABEL_CHROME_BROWSER_TAB_INSERTION_COORDINATOR_H_
#define BABEL_CHROME_BROWSER_TAB_INSERTION_COORDINATOR_H_

#import <Foundation/Foundation.h>

@class BabelBrowserGroup;
@class BabelBrowserTab;
@class BabelBrowserTabCollection;
@class BabelTabPlacementPolicy;

/**
 * Inserts tabs into browser groups according to the active placement strategy.
 */
@interface BabelBrowserTabInsertionCoordinator : NSObject

/**
 * Initializes the tab insertion coordinator.
 *
 * @param placementPolicy The placement policy used to calculate insertion indexes.
 * @param tabCollection The tab collection helper used to inspect existing tabs.
 * @return The initialized coordinator.
 */
- (instancetype)initWithPlacementPolicy:(BabelTabPlacementPolicy*)placementPolicy
                          tabCollection:(BabelBrowserTabCollection*)tabCollection;

/**
 * Inserts a tab into a group.
 *
 * @param tab The tab to insert.
 * @param group The destination group.
 * @param parentTab The parent tab, when the new tab was opened by another tab.
 * @param strategy The active tab opening strategy.
 * @param respectingUserStrategy YES when the configured user strategy should be applied.
 */
- (void)insertTab:(BabelBrowserTab*)tab
          inGroup:(BabelBrowserGroup*)group
        parentTab:(BabelBrowserTab*)parentTab
         strategy:(NSString*)strategy
respectingUserStrategy:(BOOL)respectingUserStrategy;

@end

#endif
