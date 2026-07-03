#ifndef BABEL_CHROME_BROWSER_CLOSED_TAB_RESTORATION_PLANNER_H_
#define BABEL_CHROME_BROWSER_CLOSED_TAB_RESTORATION_PLANNER_H_

#import <Foundation/Foundation.h>

#import "Browser/NewTabURLResolver.h"

@class BabelClosedTab;

/**
 * Represents the values needed to restore one closed tab.
 */
@interface BabelClosedTabRestorationPlan : NSObject

@property(nonatomic, strong) NSString* groupIdentifier;
@property(nonatomic, strong) NSString* groupName;
@property(nonatomic, strong) NSString* requestedURLString;
@property(nonatomic, strong) NSString* navigationURLString;
@property(nonatomic, strong) NSString* title;

@end

/**
 * Builds restoration plans for recently closed tabs.
 */
@interface BabelClosedTabRestorationPlanner : NSObject

/**
 * Initializes the planner.
 *
 * @param defaultGroupName The fallback group name.
 * @param stableNavigationURLResolver The block resolving stable runtime navigation URLs.
 *
 * @return The initialized planner.
 */
- (instancetype)initWithDefaultGroupName:(NSString*)defaultGroupName
             stableNavigationURLResolver:(BabelStableNavigationURLResolverBlock)stableNavigationURLResolver;

/**
 * Builds a restoration plan for a closed tab.
 *
 * @param closedTab The closed tab snapshot.
 *
 * @return The restoration plan, or nil when no tab can be restored.
 */
- (BabelClosedTabRestorationPlan*)restorationPlanForClosedTab:(BabelClosedTab*)closedTab;

@end

#endif
