#ifndef BABEL_CHROME_BROWSER_TAB_DRAG_HOVER_SCHEDULER_H_
#define BABEL_CHROME_BROWSER_TAB_DRAG_HOVER_SCHEDULER_H_

#import <Foundation/Foundation.h>

@class BabelBrowserGroup;

typedef BOOL (^BabelTabDragHoverValidationBlock)(BabelBrowserGroup* group);
typedef void (^BabelTabDragHoverSelectionBlock)(BabelBrowserGroup* group);

/**
 * Schedules delayed group selection while a tab is dragged over the sidebar.
 */
@interface BabelTabDragHoverScheduler : NSObject

/**
 * Cancels the pending hover selection.
 */
- (void)cancelPendingSelection;

/**
 * Checks whether the provided group is already pending hover selection.
 *
 * @param group The group to compare.
 * @return YES when the group is already pending.
 */
- (BOOL)isPendingGroup:(BabelBrowserGroup*)group;

/**
 * Schedules a delayed selection for a group.
 *
 * @param group The group to select after the delay.
 * @param delayNanoseconds The scheduling delay.
 * @param validationBlock The validation block called immediately before selection.
 * @param selectionBlock The selection block.
 */
- (void)scheduleSelectionForGroup:(BabelBrowserGroup*)group
                 delayNanoseconds:(int64_t)delayNanoseconds
                  validationBlock:(BabelTabDragHoverValidationBlock)validationBlock
                   selectionBlock:(BabelTabDragHoverSelectionBlock)selectionBlock;

@end

#endif
