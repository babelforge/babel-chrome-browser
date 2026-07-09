#import "Browser/InternalPages/Modules/ModulePageRenderer.h"

@implementation BabelModulePageRenderer {
  NSString* gearIconHTML_;
  NSString* trashIconHTML_;
}

- (instancetype)initWithGearIconHTML:(NSString*)gearIconHTML trashIconHTML:(NSString*)trashIconHTML {
  self = [super init];
  if (self) {
    gearIconHTML_ = gearIconHTML ?: @"";
    trashIconHTML_ = trashIconHTML ?: @"";
  }
  return self;
}

- (NSString*)modulesPageBodyWithModules:(NSArray*)modules
                                  error:(NSError*)error
                        updateURLString:(NSString*)updateURLString
                   updateLocalDirectory:(NSString*)updateLocalDirectory {
  NSString* updateURLLabel = updateURLString.length > 0 ? updateURLString : @"Not configured";
  NSString* updateLocalLabel = updateLocalDirectory.length > 0 ? updateLocalDirectory : @"Not configured";
  NSMutableString* moduleListHTML = [NSMutableString string];
  if (error) {
    [moduleListHTML appendFormat:@"<p class='empty'>%@</p>",
                                 [self htmlEscapedString:error.localizedDescription]];
  } else if (modules.count == 0) {
    [moduleListHTML appendString:@"<p class='empty'>No PHP module is registered.</p>"];
  } else {
    [moduleListHTML appendString:@"<ul class='stripedList moduleList'>"];
    for (NSDictionary* module in modules) {
      if (![module isKindOfClass:NSDictionary.class]) {
        continue;
      }

      NSString* moduleIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
      NSString* moduleName = [module[@"name"] isKindOfClass:NSString.class] ? module[@"name"] : moduleIdentifier;
      NSString* moduleVersion = [module[@"version"] isKindOfClass:NSString.class] ? module[@"version"] : @"";
      NSString* moduleDescription =
          [module[@"description"] isKindOfClass:NSString.class] ? module[@"description"] : @"";
      BOOL enabled = [module[@"enabled"] boolValue];
      BOOL hasIsolatedVendor = [module[@"hasIsolatedVendor"] boolValue];
      NSString* settingsRoute =
          [module[@"settingsRoute"] isKindOfClass:NSString.class] ? module[@"settingsRoute"] : @"";
      BOOL hasSettingsPage = settingsRoute.length > 0 && ![settingsRoute isEqualToString:@"babelchrome://modules"];
      NSString* enabledLabel = enabled ? @"Enabled" : @"Disabled";
      NSString* vendorLabel = hasIsolatedVendor ? @"Bundled vendor" : @"No bundled vendor";
      NSString* versionLabel = [NSString stringWithFormat:@"Installed %@", moduleVersion];
      NSString* detailsActionHTML = @"";
      NSString* settingsActionHTML = @"";
      NSString* toggleActionHTML = @"";
      NSString* removeActionHTML = @"";
      if (moduleIdentifier.length > 0) {
        detailsActionHTML = [NSString stringWithFormat:
            @"<a class='smallButton' data-can-open-menu='true' href='babelchrome://modules?module=%@'>Details</a>",
            [self queryEscapedString:moduleIdentifier]];
      }
      if (hasSettingsPage) {
        settingsActionHTML = [NSString stringWithFormat:@"<a class='smallButton' data-can-open-menu='true' href='%@'>Settings</a>",
                                                        [self htmlEscapedString:settingsRoute]];
      }
      if (moduleIdentifier.length > 0) {
        NSString* toggleAction = enabled ? @"disable" : @"enable";
        NSString* toggleLabel = enabled ? @"Disable" : @"Enable";
        toggleActionHTML = [NSString stringWithFormat:
            @"<a class='smallButton' href='babelchrome://modules?%@=%@'>%@</a>",
            toggleAction,
            [self queryEscapedString:moduleIdentifier],
            toggleLabel];
        removeActionHTML = [NSString stringWithFormat:
            @"<a class='smallButton dangerButton iconTextButton' href='babelchrome://modules?remove=%@' title='Remove'>%@<span>Remove</span></a>",
            [self queryEscapedString:moduleIdentifier],
            trashIconHTML_];
      }

      [moduleListHTML appendFormat:
          @"<li class='moduleItem'>"
           "<div class='moduleText'><span>%@</span><small>%@ - %@ - %@ - %@</small><em>%@</em>"
           "<p class='note'>%@</p></div>"
           "<div class='moduleButtons'>"
           "<div class='moduleButtonCell'>%@</div><div class='moduleButtonCell'>%@</div>"
           "<div class='moduleButtonCell'>%@</div><div class='moduleButtonCell'>%@</div>"
           "</div>"
           "</li>",
          [self htmlEscapedString:moduleName],
          [self htmlEscapedString:moduleIdentifier],
          [self htmlEscapedString:versionLabel],
          @"User-installed",
          [self htmlEscapedString:enabledLabel],
          [self htmlEscapedString:vendorLabel],
          [self htmlEscapedString:moduleDescription],
          detailsActionHTML,
          settingsActionHTML,
          toggleActionHTML,
          removeActionHTML];
    }
    [moduleListHTML appendString:@"</ul>"];
  }

  return [NSString stringWithFormat:
      @"<h1>PHP Modules</h1>"
       "<section>"
       "<h2>Installed Modules</h2>"
       "<div class='buttonRow'>"
       "<a class='primaryButton' href='babelchrome://modules?installZip=1'>Install or Update Module Zip</a>"
       "<a class='primaryButton' data-can-open-menu='true' href='babelchrome://modules?checkUpdates=1'>Check Updates</a>"
       "<details class='gearMenu'>"
       "<summary title='Update source settings' aria-label='Update source settings'>%@</summary>"
       "<div class='gearMenuPanel'>"
       "<a class='smallButton' href='babelchrome://modules?configureUpdateURL=1'>Set Update URL</a>"
       "<a class='smallButton' href='babelchrome://modules?configureUpdateLocal=1'>Set Local Update Folder</a>"
       "</div>"
       "</details>"
       "</div>"
       "<dl>"
       "<dt>Update URL</dt><dd>%@</dd>"
       "<dt>Local update folder</dt><dd>%@</dd>"
       "</dl>"
       "%@"
       "</section>"
       "<div class='bottomButtonRow'><a class='smallButton' data-can-open-menu='true' href='babelchrome://settings'>Back to Settings</a></div>",
      gearIconHTML_,
      [self htmlEscapedString:updateURLLabel],
      [self htmlEscapedString:updateLocalLabel],
      moduleListHTML];
}

- (NSString*)moduleDetailsPageBodyForIdentifier:(NSString*)moduleIdentifier
                                        modules:(NSArray*)modules
                                          error:(NSError*)error {
  NSDictionary* selectedModule = [self moduleWithIdentifier:moduleIdentifier modules:modules];
  if (error) {
    return [NSString stringWithFormat:@"<h1>Module</h1><p class='empty'>%@</p>",
                                      [self htmlEscapedString:error.localizedDescription]];
  }

  if (!selectedModule) {
    return [NSString stringWithFormat:
        @"<h1>Module</h1><p class='empty'>Module <code>%@</code> is not installed.</p>"
         "<p><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></p>",
        [self htmlEscapedString:moduleIdentifier ?: @""]];
  }

  NSString* moduleName = [selectedModule[@"name"] isKindOfClass:NSString.class] ? selectedModule[@"name"] : moduleIdentifier;
  NSString* moduleVersion = [selectedModule[@"version"] isKindOfClass:NSString.class] ? selectedModule[@"version"] : @"";
  NSString* moduleType = [selectedModule[@"type"] isKindOfClass:NSString.class] ? selectedModule[@"type"] : @"";
  NSString* runtimeType = [selectedModule[@"runtimeType"] isKindOfClass:NSString.class] ? selectedModule[@"runtimeType"] : @"";
  NSString* moduleDescription =
      [selectedModule[@"description"] isKindOfClass:NSString.class] ? selectedModule[@"description"] : @"";
  BOOL enabled = [selectedModule[@"enabled"] boolValue];
  BOOL hasIsolatedVendor = [selectedModule[@"hasIsolatedVendor"] boolValue];
  NSDictionary* requirements =
      [selectedModule[@"requirements"] isKindOfClass:NSDictionary.class] ? selectedModule[@"requirements"] : @{};
  NSString* phpRequirement =
      [requirements[@"php"] isKindOfClass:NSString.class] ? requirements[@"php"] : @"";
  NSArray* routes = [selectedModule[@"routes"] isKindOfClass:NSArray.class] ? selectedModule[@"routes"] : @[];
  NSArray* fileTypes = [selectedModule[@"fileTypes"] isKindOfClass:NSArray.class] ? selectedModule[@"fileTypes"] : @[];
  NSArray* hooks = [selectedModule[@"hooks"] isKindOfClass:NSArray.class] ? selectedModule[@"hooks"] : @[];
  NSDictionary* readinessStatus = [selectedModule[@"readinessStatus"] isKindOfClass:NSDictionary.class]
      ? selectedModule[@"readinessStatus"]
      : @{};
  NSDictionary* setup = [selectedModule[@"setup"] isKindOfClass:NSDictionary.class] ? selectedModule[@"setup"] : nil;
  NSDictionary* runtimeStatus = [selectedModule[@"runtimeStatus"] isKindOfClass:NSDictionary.class]
      ? selectedModule[@"runtimeStatus"]
      : @{};
  NSString* readinessState = [readinessStatus[@"state"] isKindOfClass:NSString.class]
      ? readinessStatus[@"state"]
      : @"unknown";
  NSNumber* ready = [readinessStatus[@"ready"] isKindOfClass:NSNumber.class] ? readinessStatus[@"ready"] : nil;
  NSNumber* canSetup = [readinessStatus[@"canSetup"] isKindOfClass:NSNumber.class] ? readinessStatus[@"canSetup"] : nil;
  BOOL canRunSetup = setup != nil && ![ready boolValue] && (!canSetup || [canSetup boolValue]);
  NSString* setupActionHTML = canRunSetup
      ? [NSString stringWithFormat:@"<a class='smallButton' href='babelchrome://modules?setup=%@'>Run Setup</a>",
                                   [self queryEscapedString:moduleIdentifier ?: @""]]
      : @"";

  NSMutableString* readinessMessagesHTML = [NSMutableString string];
  NSArray* readinessMessages = [readinessStatus[@"messages"] isKindOfClass:NSArray.class]
      ? readinessStatus[@"messages"]
      : @[];
  for (NSString* message in readinessMessages) {
    if ([message isKindOfClass:NSString.class] && message.length > 0) {
      [readinessMessagesHTML appendFormat:@"<li>%@</li>", [self htmlEscapedString:message]];
    }
  }
  NSString* readinessDetailsHTML = readinessMessagesHTML.length > 0
      ? [NSString stringWithFormat:@"<section><h2>Readiness Details</h2><ul>%@</ul></section>", readinessMessagesHTML]
      : @"";
  NSString* runtimeDiagnosticsHTML = [self runtimeDiagnosticsHTML:runtimeStatus
                                                 moduleIdentifier:moduleIdentifier ?: @""];

  NSMutableString* routesHTML = [NSMutableString string];
  for (NSDictionary* route in routes) {
    if (![route isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* routeScheme = [route[@"scheme"] isKindOfClass:NSString.class] ? route[@"scheme"] : @"";
    NSString* routeHost = [route[@"host"] isKindOfClass:NSString.class] ? route[@"host"] : @"";
    NSString* routeHandler = [route[@"handler"] isKindOfClass:NSString.class] ? route[@"handler"] : @"";
    if (routeScheme.length == 0 || routeHost.length == 0 || routeHandler.length == 0) {
      continue;
    }

    BOOL routeCanOpenDirectly = [routeScheme isEqualToString:@"babelchrome"] &&
        ![routeHost isEqualToString:@"server"];
    NSString* actionHTML = enabled && routeCanOpenDirectly
        ? [NSString stringWithFormat:@"<a class='smallButton' href='babelchrome://modules?open=%@&route=%@'>Open route</a>",
                                     [self queryEscapedString:moduleIdentifier ?: @""],
                                     [self queryEscapedString:routeHandler]]
        : @"";
    [routesHTML appendFormat:
        @"<li><code>%@://%@</code><span>&rarr;</span><code>%@</code>%@</li>",
        [self htmlEscapedString:routeScheme],
        [self htmlEscapedString:routeHost],
        [self htmlEscapedString:routeHandler],
        actionHTML];
  }

  NSMutableString* tagsHTML = [NSMutableString string];
  for (NSString* fileType in fileTypes) {
    if ([fileType isKindOfClass:NSString.class] && fileType.length > 0) {
      [tagsHTML appendFormat:@"<code>.%@</code>", [self htmlEscapedString:fileType]];
    }
  }
  for (NSString* hook in hooks) {
    if ([hook isKindOfClass:NSString.class] && hook.length > 0 &&
        ![self isInternalModuleCapability:hook]) {
      [tagsHTML appendFormat:@"<code>%@</code>", [self htmlEscapedString:hook]];
    }
  }

  return [NSString stringWithFormat:
      @"<h1>%@</h1>"
       "<section>"
       "<p class='note'>%@</p>"
       "<dl>"
       "<dt>Identifier</dt><dd><code>%@</code></dd>"
       "<dt>Version</dt><dd>%@</dd>"
       "<dt>Type</dt><dd>%@</dd>"
       "<dt>Runtime</dt><dd><code>%@</code></dd>"
       "<dt>Status</dt><dd>%@</dd>"
       "<dt>Readiness</dt><dd>%@</dd>"
       "<dt>PHP</dt><dd><code>%@</code></dd>"
       "<dt>Vendor</dt><dd>%@</dd>"
       "</dl>"
       "%@"
       "</section>"
       "%@"
       "%@"
       "<section><h2>Routes</h2><ul>%@</ul></section>"
       "<section><h2>Capabilities</h2><div class='routeList'>%@</div></section>"
       "<p><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></p>",
      [self htmlEscapedString:moduleName],
      [self htmlEscapedString:moduleDescription],
      [self htmlEscapedString:moduleIdentifier ?: @""],
      [self htmlEscapedString:moduleVersion],
      [self htmlEscapedString:moduleType],
      [self htmlEscapedString:runtimeType],
      enabled ? @"Enabled" : @"Disabled",
      [self htmlEscapedString:readinessState],
      [self htmlEscapedString:phpRequirement],
      hasIsolatedVendor ? @"Own vendor" : @"No module vendor",
      setupActionHTML,
      readinessDetailsHTML,
      runtimeDiagnosticsHTML,
      routesHTML.length > 0 ? routesHTML : @"<li>No route declared.</li>",
      tagsHTML.length > 0 ? tagsHTML : @"<span class='empty'>No capability declared.</span>"];
}

- (NSString*)runtimeDiagnosticsHTML:(NSDictionary*)runtimeStatus moduleIdentifier:(NSString*)moduleIdentifier {
  if (runtimeStatus.count == 0) {
    return @"";
  }

  NSString* runtimeKind = [runtimeStatus[@"kind"] isKindOfClass:NSString.class] ? runtimeStatus[@"kind"] : @"";
  NSString* state = [runtimeStatus[@"state"] isKindOfClass:NSString.class] ? runtimeStatus[@"state"] : @"unknown";
  NSString* mode = [runtimeStatus[@"mode"] isKindOfClass:NSString.class] ? runtimeStatus[@"mode"] : @"";
  NSString* baseURL = [runtimeStatus[@"baseUrl"] isKindOfClass:NSString.class] ? runtimeStatus[@"baseUrl"] : @"";
  NSString* readyURL = [runtimeStatus[@"readyUrl"] isKindOfClass:NSString.class] ? runtimeStatus[@"readyUrl"] : @"";
  NSString* cwd = [runtimeStatus[@"cwd"] isKindOfClass:NSString.class] ? runtimeStatus[@"cwd"] : @"";
  NSString* logs = [runtimeStatus[@"logs"] isKindOfClass:NSString.class] ? runtimeStatus[@"logs"] : @"";
  NSNumber* port = [runtimeStatus[@"port"] isKindOfClass:NSNumber.class] ? runtimeStatus[@"port"] : nil;
  BOOL restartable = [runtimeStatus[@"restartable"] boolValue] && moduleIdentifier.length > 0;
  NSArray* command = [runtimeStatus[@"command"] isKindOfClass:NSArray.class] ? runtimeStatus[@"command"] : @[];

  NSMutableString* detailsHTML = [NSMutableString string];
  [detailsHTML appendFormat:@"<dt>Kind</dt><dd><code>%@</code></dd>", [self htmlEscapedString:runtimeKind]];
  [detailsHTML appendFormat:@"<dt>State</dt><dd>%@</dd>", [self htmlEscapedString:state]];
  if (mode.length > 0) {
    [detailsHTML appendFormat:@"<dt>Mode</dt><dd><code>%@</code></dd>", [self htmlEscapedString:mode]];
  }
  if (port) {
    [detailsHTML appendFormat:@"<dt>Port</dt><dd>%@</dd>", port];
  }
  if (baseURL.length > 0) {
    [detailsHTML appendFormat:@"<dt>Base URL</dt><dd><code>%@</code></dd>", [self htmlEscapedString:baseURL]];
  }
  if (readyURL.length > 0) {
    [detailsHTML appendFormat:@"<dt>Ready URL</dt><dd><code>%@</code></dd>", [self htmlEscapedString:readyURL]];
  }
  if (command.count > 0) {
    [detailsHTML appendFormat:@"<dt>Command</dt><dd><code>%@</code></dd>",
                              [self htmlEscapedString:[self shellDisplayStringForCommand:command]]];
  }
  if (cwd.length > 0) {
    [detailsHTML appendFormat:@"<dt>CWD</dt><dd><code>%@</code></dd>", [self htmlEscapedString:cwd]];
  }

  NSString* restartActionHTML = restartable
      ? [NSString stringWithFormat:@"<a class='smallButton' href='babelchrome://modules?restartRuntime=%@'>Restart runtime</a>",
                                   [self queryEscapedString:moduleIdentifier]]
      : @"";
  NSString* logsHTML = logs.length > 0
      ? [NSString stringWithFormat:@"<pre>%@</pre>", [self htmlEscapedString:logs]]
      : @"<p class='empty'>No runtime log captured.</p>";

  return [NSString stringWithFormat:
      @"<section><h2>Runtime Diagnostics</h2><dl>%@</dl>%@<h3>Logs</h3>%@</section>",
      detailsHTML,
      restartActionHTML,
      logsHTML];
}

- (NSString*)shellDisplayStringForCommand:(NSArray*)command {
  NSMutableArray<NSString*>* parts = [NSMutableArray array];
  for (id item in command) {
    if (![item isKindOfClass:NSString.class]) {
      continue;
    }

    NSString* value = item;
    if (value.length == 0) {
      continue;
    }

    BOOL needsQuoting = [value rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound;
    NSString* escaped = [value stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
    [parts addObject:needsQuoting ? [NSString stringWithFormat:@"'%@'", escaped] : escaped];
  }

  return [parts componentsJoinedByString:@" "];
}

- (NSString*)moduleUpdatesPageBodyWithUpdateResult:(NSDictionary*)updateResult
                        releaseModulesByIdentifier:(NSDictionary*)releaseModulesByIdentifier
                                  installedModules:(NSArray*)installedModules
                                     snapshotError:(NSError*)snapshotError
                                   updateURLString:(NSString*)updateURLString
                                    localDirectory:(NSString*)localDirectory {
  NSDictionary* manifest = [updateResult[@"manifest"] isKindOfClass:NSDictionary.class]
      ? updateResult[@"manifest"]
      : @{};
  NSString* sourceLabel = [updateResult[@"sourceLabel"] isKindOfClass:NSString.class]
      ? updateResult[@"sourceLabel"]
      : @"No source";
  NSString* errorMessage = [updateResult[@"error"] isKindOfClass:NSString.class] ? updateResult[@"error"] : @"";

  NSMutableString* rowsHTML = [NSMutableString string];
  NSUInteger updateCount = 0;
  if (snapshotError) {
    [rowsHTML appendFormat:@"<p class='empty'>%@</p>",
                           [self htmlEscapedString:snapshotError.localizedDescription]];
  } else if (manifest.count == 0) {
    NSString* message = errorMessage.length > 0
        ? errorMessage
        : @"Configure an update URL or a local update folder containing module zips.";
    [rowsHTML appendFormat:@"<p class='empty'>%@</p>", [self htmlEscapedString:message]];
  } else if (installedModules.count == 0) {
    [rowsHTML appendString:@"<p class='empty'>No installed module was found.</p>"];
  } else {
    NSMutableString* updateRowsHTML = [NSMutableString string];
    for (NSDictionary* module in installedModules) {
      if (![module isKindOfClass:NSDictionary.class]) {
        continue;
      }

      NSString* moduleIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
      NSString* moduleName = [module[@"name"] isKindOfClass:NSString.class] ? module[@"name"] : moduleIdentifier;
      NSString* installedVersion = [module[@"version"] isKindOfClass:NSString.class] ? module[@"version"] : @"";
      NSDictionary* releaseModule = releaseModulesByIdentifier[moduleIdentifier];
      NSString* availableVersion =
          [releaseModule[@"version"] isKindOfClass:NSString.class] ? releaseModule[@"version"] : @"";
      NSString* status = @"Not found in update source";
      NSString* actionHTML = @"";
      if (availableVersion.length > 0) {
        NSComparisonResult comparison = [self compareVersion:availableVersion toVersion:installedVersion];
        if (comparison == NSOrderedDescending) {
          status = @"Update available";
          actionHTML = [NSString stringWithFormat:
              @"<label class='updateCheckbox'><input class='updateItemCheckbox' type='checkbox' name='installUpdates' value='%@'> Update</label>",
              [self queryEscapedString:moduleIdentifier]];
          updateCount++;
        } else if (comparison == NSOrderedSame) {
          status = @"Up to date";
        } else {
          status = @"Installed version is newer";
        }
      }

      NSString* wrappedActionsHTML = actionHTML.length > 0
          ? [NSString stringWithFormat:@"<div class='actions'>%@</div>", actionHTML]
          : @"";
      if (actionHTML.length == 0) {
        continue;
      }

      [updateRowsHTML appendFormat:
          @"<li><span>%@</span><small>%@ - Installed %@ - Available %@</small><em>%@</em>%@</li>",
          [self htmlEscapedString:moduleName],
          [self htmlEscapedString:moduleIdentifier],
          [self htmlEscapedString:installedVersion.length > 0 ? installedVersion : @"Unknown"],
          [self htmlEscapedString:availableVersion.length > 0 ? availableVersion : @"None"],
          [self htmlEscapedString:status],
          wrappedActionsHTML];
    }
    if (updateCount == 0) {
      [rowsHTML appendString:@"<p class='empty'>No update available.</p>"];
    } else {
      [rowsHTML appendFormat:
          @"<form class='updatesForm' action='babelchrome://modules' method='get'>"
           "<input type='hidden' name='installSelectedUpdates' value='1'>"
           "<div class='updatesToolbar'>"
           "<label><input id='selectAllUpdates' type='checkbox'> Select all</label>"
           "<button class='primaryButton' type='submit'>Install Updates</button>"
           "</div>"
           "<ul class='stripedList updateList'>%@</ul>"
           "</form>",
          updateRowsHTML];
    }
  }

  NSString* updateScriptHTML = updateCount > 0
      ? @"<script>"
         "const selectAllUpdates=document.getElementById('selectAllUpdates');"
         "if(selectAllUpdates){selectAllUpdates.addEventListener('change',()=>{"
         "document.querySelectorAll('.updateItemCheckbox').forEach((checkbox)=>{checkbox.checked=selectAllUpdates.checked;});"
         "});}"
         "</script>"
      : @"";
  return [NSString stringWithFormat:
      @"<h1>Module Updates</h1>"
       "<section>"
       "<h2>Source</h2>"
       "<dl>"
       "<dt>Used source</dt><dd>%@</dd>"
       "<dt>URL source</dt><dd>%@</dd>"
       "<dt>Local fallback</dt><dd>%@</dd>"
       "</dl>"
       "</section>"
       "<section>"
       "<h2>Available Updates</h2>"
       "%@"
       "</section>"
       "<div class='bottomButtonRow'><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></div>"
       "%@",
      [self htmlEscapedString:sourceLabel],
      [self htmlEscapedString:updateURLString.length > 0 ? updateURLString : @"Not configured"],
      [self htmlEscapedString:localDirectory.length > 0 ? localDirectory : @"Not configured"],
      rowsHTML,
      updateScriptHTML];
}

- (NSDictionary*)moduleWithIdentifier:(NSString*)moduleIdentifier modules:(NSArray*)modules {
  for (NSDictionary* module in modules) {
    if (![module isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* currentIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
    if ([currentIdentifier isEqualToString:moduleIdentifier ?: @""]) {
      return module;
    }
  }

  return nil;
}

- (BOOL)isInternalModuleCapability:(NSString*)capability {
  static NSSet<NSString*>* internalCapabilities = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    internalCapabilities = [NSSet setWithArray:@[
      @"app.did-start",
      @"app.will-quit",
      @"drop.local-paths",
      @"settings.section.register"
    ]];
  });

  return [internalCapabilities containsObject:capability ?: @""];
}

- (NSComparisonResult)compareVersion:(NSString*)leftVersion toVersion:(NSString*)rightVersion {
  return [leftVersion compare:rightVersion options:NSNumericSearch];
}

- (NSString*)queryEscapedString:(NSString*)value {
  NSCharacterSet* allowedCharacters = NSCharacterSet.URLQueryAllowedCharacterSet;
  return [value stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters] ?: @"";
}

- (NSString*)htmlEscapedString:(NSString*)value {
  NSMutableString* escapedString = [NSMutableString stringWithString:value ?: @""];
  [escapedString replaceOccurrencesOfString:@"&"
                                 withString:@"&amp;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  [escapedString replaceOccurrencesOfString:@"<"
                                 withString:@"&lt;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  [escapedString replaceOccurrencesOfString:@">"
                                 withString:@"&gt;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  [escapedString replaceOccurrencesOfString:@"\""
                                 withString:@"&quot;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  return escapedString;
}

@end
