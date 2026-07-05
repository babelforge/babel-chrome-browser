#ifndef BABEL_CHROME_BROWSER_DEVELOPER_TOOLS_DOCKING_POLICY_H_
#define BABEL_CHROME_BROWSER_DEVELOPER_TOOLS_DOCKING_POLICY_H_

#import <Foundation/Foundation.h>

/**
 * Resolves Developer Tools docking modes from UI state.
 */
@interface BabelDeveloperToolsDockingPolicy : NSObject

/**
 * Initializes the policy.
 *
 * @param bottomMode The bottom docking mode value.
 * @param topMode The top docking mode value.
 * @param leftMode The left docking mode value.
 * @param rightMode The right docking mode value.
 * @param leftTag The left docking control tag.
 * @param rightTag The right docking control tag.
 * @param bottomTag The bottom docking control tag.
 * @param topTag The top docking control tag.
 *
 * @return The initialized policy.
 */
- (instancetype)initWithBottomMode:(NSString*)bottomMode
                           topMode:(NSString*)topMode
                          leftMode:(NSString*)leftMode
                         rightMode:(NSString*)rightMode
                           leftTag:(NSInteger)leftTag
                          rightTag:(NSInteger)rightTag
                         bottomTag:(NSInteger)bottomTag
                            topTag:(NSInteger)topTag;

/**
 * Resolves a dock mode from a control tag.
 *
 * @param tag The control tag.
 *
 * @return The dock mode, or nil when the tag is unknown.
 */
- (NSString*)dockModeForTag:(NSInteger)tag;

/**
 * Returns whether a dock mode uses the vertical axis for resizing.
 *
 * @param dockMode The dock mode to inspect.
 *
 * @return YES when the dock mode is top or bottom.
 */
- (BOOL)isHorizontalDockMode:(NSString*)dockMode;

/**
 * Returns the allowed dock modes.
 *
 * @return The allowed dock mode set.
 */
- (NSSet<NSString*>*)allowedDockModes;

@end

#endif
