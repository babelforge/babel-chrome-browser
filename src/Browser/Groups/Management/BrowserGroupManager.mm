#import "Browser/Groups/Management/BrowserGroupManager.h"

#import "Browser/Groups/Model/BrowserGroupCollection.h"
#import "Browser/Groups/Creation/BrowserGroupFactory.h"
#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/UI/Views/BrowserViews.h"

@implementation BabelBrowserGroupManager {
  NSMutableArray<BabelBrowserGroup*>* groups_;
  NSView* groupsListView_;
  BabelBrowserGroupCollection* groupCollection_;
  BabelBrowserGroupFactory* groupFactory_;
  NSString* defaultGroupIdentifier_;
  NSString* defaultGroupName_;
  BabelBrowserGroupLayoutHandler layoutHandler_;
}

- (instancetype)initWithGroups:(NSMutableArray<BabelBrowserGroup*>*)groups
                groupsListView:(NSView*)groupsListView
               groupCollection:(BabelBrowserGroupCollection*)groupCollection
                  groupFactory:(BabelBrowserGroupFactory*)groupFactory
        defaultGroupIdentifier:(NSString*)defaultGroupIdentifier
              defaultGroupName:(NSString*)defaultGroupName
                 layoutHandler:(BabelBrowserGroupLayoutHandler)layoutHandler {
  self = [super init];
  if (self) {
    groups_ = groups;
    groupsListView_ = groupsListView;
    groupCollection_ = groupCollection;
    groupFactory_ = groupFactory;
    defaultGroupIdentifier_ = [defaultGroupIdentifier copy];
    defaultGroupName_ = [defaultGroupName copy];
    layoutHandler_ = [layoutHandler copy];
  }
  return self;
}

- (BabelBrowserGroup*)createGroupWithName:(NSString*)name identifier:(NSString*)identifier {
  BabelBrowserGroup* existingGroup = [self groupWithIdentifier:identifier];
  if (existingGroup) {
    return existingGroup;
  }

  BabelBrowserGroup* group = [groupFactory_ makeGroupWithName:name identifier:identifier];
  [groups_ addObject:group];
  [groupsListView_ addSubview:group.groupItemView];
  if (layoutHandler_) {
    layoutHandler_();
  }
  return group;
}

- (BabelBrowserGroup*)groupWithIdentifier:(NSString*)identifier {
  return [groupCollection_ groupWithIdentifier:identifier groups:groups_];
}

- (BabelBrowserGroup*)groupWithName:(NSString*)name {
  return [groupCollection_ groupWithName:name groups:groups_];
}

- (BabelBrowserGroup*)ensureGroupNamed:(NSString*)name {
  NSString* normalizedName = name.length > 0 ? name : defaultGroupName_;
  BabelBrowserGroup* existingGroup = [self groupWithName:normalizedName];
  if (existingGroup) {
    return existingGroup;
  }

  NSString* identifier = [normalizedName isEqualToString:defaultGroupName_]
      ? defaultGroupIdentifier_
      : NSUUID.UUID.UUIDString;
  return [self createGroupWithName:normalizedName identifier:identifier];
}

- (NSString*)nextManualGroupName {
  return [groupCollection_ nextManualGroupNameForGroups:groups_];
}

@end
