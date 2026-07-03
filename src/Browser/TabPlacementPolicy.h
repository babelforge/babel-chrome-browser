#ifndef BABEL_CHROME_BROWSER_TAB_PLACEMENT_POLICY_H_
#define BABEL_CHROME_BROWSER_TAB_PLACEMENT_POLICY_H_

#import <Foundation/Foundation.h>

/**
 * Calculates where new tabs should be inserted.
 */
@interface BabelTabPlacementPolicy : NSObject

/**
 * Returns whether a new tab should be appended.
 *
 * @param parentTabIdentifier The parent tab identifier.
 * @param tabIdentifiers The current tab identifiers.
 * @param strategy The active tab opening strategy.
 * @param respectingUserStrategy YES when the user strategy should be applied.
 * @return YES when the new tab should be appended.
 */
- (BOOL)shouldAppendTabWithParentIdentifier:(NSString*)parentTabIdentifier
                             tabIdentifiers:(NSArray<NSString*>*)tabIdentifiers
                                   strategy:(NSString*)strategy
                     respectingUserStrategy:(BOOL)respectingUserStrategy;

/**
 * Calculates the insertion index for a new child tab.
 *
 * @param parentTabIdentifier The parent tab identifier.
 * @param tabIdentifiers The current tab identifiers.
 * @param parentIdentifiersByTabIdentifier Parent tab identifiers keyed by tab identifier.
 * @param strategy The active tab opening strategy.
 * @return The insertion index.
 */
- (NSUInteger)insertionIndexForNewChildOfParentIdentifier:(NSString*)parentTabIdentifier
                                           tabIdentifiers:(NSArray<NSString*>*)tabIdentifiers
                         parentIdentifiersByTabIdentifier:(NSDictionary<NSString*, NSString*>*)parentIdentifiersByTabIdentifier
                                                 strategy:(NSString*)strategy;

@end

#endif
