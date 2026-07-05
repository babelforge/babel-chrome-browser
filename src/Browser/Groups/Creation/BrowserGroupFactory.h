#ifndef BABEL_CHROME_BROWSER_GROUP_FACTORY_H_
#define BABEL_CHROME_BROWSER_GROUP_FACTORY_H_

#import <Foundation/Foundation.h>

@class BabelBrowserGroup;

/**
 * Builds native browser group models and their group-list item views.
 */
@interface BabelBrowserGroupFactory : NSObject

/**
 * Creates a browser group factory.
 *
 * @param actionTarget The target that receives group item actions.
 * @return The initialized factory.
 */
- (instancetype)initWithActionTarget:(id)actionTarget;

/**
 * Creates a group model with its native item view wired to the action target.
 *
 * @param name The group display name.
 * @param identifier The group identifier.
 * @return The created group.
 */
- (BabelBrowserGroup*)makeGroupWithName:(NSString*)name identifier:(NSString*)identifier;

@end

#endif
