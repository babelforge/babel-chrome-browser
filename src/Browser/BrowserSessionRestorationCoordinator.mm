#import "Browser/BrowserSessionRestorationCoordinator.h"

#import "Browser/BrowserModels.h"
#import "Browser/GroupSessionStore.h"
#import "Browser/TabContentViewAttacher.h"

@implementation BabelBrowserSessionRestorationCoordinator {
  BabelGroupSessionStore* groupSessionStore_;
  BabelTabContentViewAttacher* tabContentViewAttacher_;
  __weak NSView* pagesPanel_;
  NSString* defaultGroupIdentifier_;
  NSString* defaultGroupName_;
  BabelSessionGroupLookupProvider groupLookupProvider_;
  BabelSessionGroupCreateHandler groupCreateHandler_;
  BabelSessionTabLookupProvider tabLookupProvider_;
  BabelSessionTabCreateHandler tabCreateHandler_;
  BabelSessionStableURLResolver stableURLResolver_;
  BabelSessionStableURLPredicate stableURLPredicate_;
  BabelSessionGroupSelectionHandler selectGroupHandler_;
  BabelSessionStateSaveHandler saveStateHandler_;
}

- (instancetype)initWithGroupSessionStore:(BabelGroupSessionStore*)groupSessionStore
                  tabContentViewAttacher:(BabelTabContentViewAttacher*)tabContentViewAttacher
                              pagesPanel:(NSView*)pagesPanel
                  defaultGroupIdentifier:(NSString*)defaultGroupIdentifier
                         defaultGroupName:(NSString*)defaultGroupName
                     groupLookupProvider:(BabelSessionGroupLookupProvider)groupLookupProvider
                       groupCreateHandler:(BabelSessionGroupCreateHandler)groupCreateHandler
                        tabLookupProvider:(BabelSessionTabLookupProvider)tabLookupProvider
                         tabCreateHandler:(BabelSessionTabCreateHandler)tabCreateHandler
                        stableURLResolver:(BabelSessionStableURLResolver)stableURLResolver
                       stableURLPredicate:(BabelSessionStableURLPredicate)stableURLPredicate
                       selectGroupHandler:(BabelSessionGroupSelectionHandler)selectGroupHandler
                         saveStateHandler:(BabelSessionStateSaveHandler)saveStateHandler {
  self = [super init];
  if (self) {
    groupSessionStore_ = groupSessionStore;
    tabContentViewAttacher_ = tabContentViewAttacher;
    pagesPanel_ = pagesPanel;
    defaultGroupIdentifier_ = [defaultGroupIdentifier copy];
    defaultGroupName_ = [defaultGroupName copy];
    groupLookupProvider_ = [groupLookupProvider copy];
    groupCreateHandler_ = [groupCreateHandler copy];
    tabLookupProvider_ = [tabLookupProvider copy];
    tabCreateHandler_ = [tabCreateHandler copy];
    stableURLResolver_ = [stableURLResolver copy];
    stableURLPredicate_ = [stableURLPredicate copy];
    selectGroupHandler_ = [selectGroupHandler copy];
    saveStateHandler_ = [saveStateHandler copy];
  }
  return self;
}

- (void)restoreSelectedGroupFromState:(NSDictionary*)state {
  BabelBrowserGroup* defaultGroup = groupLookupProvider_ ? groupLookupProvider_(defaultGroupIdentifier_) : nil;
  if (!defaultGroup && groupCreateHandler_) {
    defaultGroup = groupCreateHandler_(defaultGroupName_, defaultGroupIdentifier_);
  }

  NSString* selectedGroupIdentifier =
      [groupSessionStore_ selectedGroupIdentifierFromState:state
                                        fallbackIdentifier:defaultGroupIdentifier_];
  BabelBrowserGroup* groupToSelect =
      (groupLookupProvider_ ? groupLookupProvider_(selectedGroupIdentifier) : nil) ?: defaultGroup;
  if (selectGroupHandler_) {
    selectGroupHandler_(groupToSelect);
  }
  if (saveStateHandler_) {
    saveStateHandler_();
  }
}

- (void)restoreGroupsFromState:(NSDictionary*)state {
  for (BabelRestoredGroupState* groupState in [groupSessionStore_ restoredGroupStatesFromState:state]) {
    BabelBrowserGroup* group = groupCreateHandler_ ? groupCreateHandler_(groupState.name, groupState.identifier) : nil;
    group.selectedTabIdentifier = groupState.selectedTabIdentifier;

    for (BabelRestoredTabState* tabState in groupState.tabs) {
      NSString* urlString = tabState.urlString;
      NSString* requestedURLString = tabState.requestedURLString;
      NSString* restoredNavigationURLString =
          stableURLResolver_ ? stableURLResolver_(requestedURLString) : @"";
      if (restoredNavigationURLString.length > 0) {
        urlString = restoredNavigationURLString;
      } else if (stableURLPredicate_ && stableURLPredicate_(requestedURLString)) {
        urlString = requestedURLString;
      }
      if ((tabLookupProvider_ && tabLookupProvider_(requestedURLString, group)) ||
          (tabLookupProvider_ && tabLookupProvider_(urlString, group))) {
        continue;
      }

      BabelBrowserTab* tab =
          tabCreateHandler_ ? tabCreateHandler_(urlString, tabState.identifier, tabState.title) : nil;
      tab.requestedURLString = requestedURLString;
      tab.parentTabIdentifier = tabState.parentTabIdentifier;
      [group.tabs addObject:tab];
      [tabContentViewAttacher_ attachTab:tab toPagesPanel:pagesPanel_];
    }
  }
}

@end
