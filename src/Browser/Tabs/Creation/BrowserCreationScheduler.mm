#import "Browser/Tabs/Creation/BrowserCreationScheduler.h"

@implementation BabelBrowserCreationScheduler {
  NSUInteger keyboardGeneration_;
  NSUInteger adjacentPreloadGeneration_;
}

- (void)cancelKeyboardBrowserCreation {
  keyboardGeneration_++;
}

- (void)scheduleKeyboardBrowserCreationForTab:(BabelBrowserTab*)tab
                             delayNanoseconds:(int64_t)delayNanoseconds
                          selectedTabProvider:(BabelSelectedTabProvider)selectedTabProvider
                          terminationProvider:(BabelBrowserSchedulerTerminationProvider)terminationProvider
                                createHandler:(BabelBrowserTabAction)createHandler
                               preloadHandler:(BabelBrowserSchedulerAction)preloadHandler {
  if (!tab || !selectedTabProvider || !terminationProvider || !createHandler) {
    return;
  }

  NSUInteger generation = ++keyboardGeneration_;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayNanoseconds), dispatch_get_main_queue(), ^{
    if (generation != keyboardGeneration_ ||
        selectedTabProvider() != tab ||
        terminationProvider()) {
      return;
    }

    createHandler(tab);
    if (preloadHandler) {
      preloadHandler();
    }
  });
}

- (void)scheduleAdjacentPreloadForTabs:(NSArray<BabelBrowserTab*>*)tabs
                             anchorTab:(BabelBrowserTab*)anchorTab
               initialDelayNanoseconds:(int64_t)initialDelayNanoseconds
                  stepDelayNanoseconds:(int64_t)stepDelayNanoseconds
                    selectedTabProvider:(BabelSelectedTabProvider)selectedTabProvider
                    terminationProvider:(BabelBrowserSchedulerTerminationProvider)terminationProvider
                          createHandler:(BabelBrowserTabAction)createHandler {
  NSUInteger generation = ++adjacentPreloadGeneration_;
  [self scheduleAdjacentPreloadForTabs:tabs
                             anchorTab:anchorTab
                            generation:generation
                                 index:0
               initialDelayNanoseconds:initialDelayNanoseconds
                  stepDelayNanoseconds:stepDelayNanoseconds
                    selectedTabProvider:selectedTabProvider
                    terminationProvider:terminationProvider
                          createHandler:createHandler];
}

- (void)scheduleAdjacentPreloadForTabs:(NSArray<BabelBrowserTab*>*)tabs
                             anchorTab:(BabelBrowserTab*)anchorTab
                            generation:(NSUInteger)generation
                                 index:(NSUInteger)index
               initialDelayNanoseconds:(int64_t)initialDelayNanoseconds
                  stepDelayNanoseconds:(int64_t)stepDelayNanoseconds
                    selectedTabProvider:(BabelSelectedTabProvider)selectedTabProvider
                    terminationProvider:(BabelBrowserSchedulerTerminationProvider)terminationProvider
                          createHandler:(BabelBrowserTabAction)createHandler {
  if (index >= tabs.count || !anchorTab || !selectedTabProvider || !terminationProvider || !createHandler) {
    return;
  }

  int64_t delay = index == 0 ? initialDelayNanoseconds : stepDelayNanoseconds;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), dispatch_get_main_queue(), ^{
    if (generation != adjacentPreloadGeneration_ ||
        selectedTabProvider() != anchorTab ||
        terminationProvider()) {
      return;
    }

    createHandler(tabs[index]);
    [self scheduleAdjacentPreloadForTabs:tabs
                               anchorTab:anchorTab
                              generation:generation
                                   index:index + 1
                 initialDelayNanoseconds:initialDelayNanoseconds
                    stepDelayNanoseconds:stepDelayNanoseconds
                      selectedTabProvider:selectedTabProvider
                      terminationProvider:terminationProvider
                            createHandler:createHandler];
  });
}

@end
