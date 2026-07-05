#ifndef BABEL_CHROME_BROWSER_CLOSED_TAB_REOPEN_COORDINATOR_H_
#define BABEL_CHROME_BROWSER_CLOSED_TAB_REOPEN_COORDINATOR_H_

#import <Foundation/Foundation.h>

@class BabelClosedTabRestorationPlan;
@class BabelClosedTabRestorationPlanner;
@class BabelRecentlyClosedTabStore;

@interface BabelClosedTabReopenCoordinator : NSObject

- (instancetype)initWithRecentlyClosedTabStore:(BabelRecentlyClosedTabStore*)recentlyClosedTabStore
                  closedTabRestorationPlanner:(BabelClosedTabRestorationPlanner*)closedTabRestorationPlanner;

- (BabelClosedTabRestorationPlan*)restorationPlanForClosedTabAtIndex:(NSUInteger)closedTabIndex;

@end

#endif  // BABEL_CHROME_BROWSER_CLOSED_TAB_REOPEN_COORDINATOR_H_
