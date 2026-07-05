#import "Browser/DragDrop/Bridge/LocalDropBridgeScriptBuilder.h"

@implementation BabelLocalDropBridgeScriptBuilder

- (NSString*)scriptWithPayloadJSON:(NSString*)payloadJSON {
  NSString* payloadAssignment = payloadJSON.length > 0
      ? [NSString stringWithFormat:@"window.__babelChromeLocalDropPayload=%@;", payloadJSON]
      : @"";
  return [NSString stringWithFormat:
      @"(function(){"
       "%@"
       "if(!window.__babelChromeLocalDropBridgeInstalled){"
       "window.__babelChromeLocalDropBridgeInstalled=true;"
       "var hasLocalFiles=function(event){"
       "if(window.__babelChromeLocalDropPayload){return true;}"
       "var transfer=event.dataTransfer;"
       "if(!transfer){return false;}"
       "if(transfer.types&&Array.prototype.indexOf.call(transfer.types,'Files')>=0){return true;}"
       "return transfer.files&&transfer.files.length>0;"
       "};"
       "window.addEventListener('dragover',function(event){"
       "if(!hasLocalFiles(event)){return;}"
       "event.preventDefault();"
       "event.stopPropagation();"
       "},true);"
       "window.addEventListener('drop',function(event){"
       "if(!hasLocalFiles(event)){return;}"
       "event.preventDefault();"
       "event.stopPropagation();"
       "var detail=window.__babelChromeLocalDropPayload;"
       "if(!detail){return;}"
       "window.dispatchEvent(new CustomEvent('babelchrome:local-drop',{detail:detail}));"
       "window.__babelChromeLocalDropPayload=null;"
       "},true);"
       "}"
       "})();",
      payloadAssignment];
}

@end
