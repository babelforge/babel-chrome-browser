#import "Browser/CEF/Client/BrowserClient.h"

#import "Browser/Modules/Registry/NativeModuleRegistry.h"
#import "Browser/Window/Controller/BrowserWindowController.h"

#include <array>
#include <sstream>
#include <string>
#include <vector>

#include "include/cef_image.h"
#include "include/cef_parser.h"
#include "include/wrapper/cef_helpers.h"

namespace {

const int kOpenInNewTabCommandId = MENU_ID_USER_FIRST + 1;
const int kOpenDeveloperToolsCommandId = MENU_ID_USER_FIRST + 2;
const int kOpenViewerSourceCommandId = MENU_ID_USER_FIRST + 3;
const int kRevealViewerSourceCommandId = MENU_ID_USER_FIRST + 4;
const int kCopyLinkCommandId = MENU_ID_USER_FIRST + 5;
const int kFaviconDownloadMaximumSize = 32;
const int kReloadVirtualKeyCode = 0x52;
const char kBabelChromeFileTypesHeaderName[] = "X-BabelChrome-File-Types";
NSString* const kBabelChromeLocalFileReloadQueryItemName = @"__babelchrome_reload";

/**
 * Removes BabelChrome's local file reload token from the URL exposed to the UI.
 *
 * @param urlString The URL string reported by CEF.
 * @return The visible URL string without internal reload metadata.
 */
NSString* URLStringByRemovingLocalFileReloadToken(NSString* urlString) {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString];
  if (!components || ![components.scheme.lowercaseString isEqualToString:@"file"]) {
    return urlString;
  }

  NSArray<NSURLQueryItem*>* existingQueryItems = components.queryItems;
  if (existingQueryItems.count == 0) {
    return urlString;
  }

  BOOL removedReloadToken = NO;
  NSMutableArray<NSURLQueryItem*>* queryItems = [NSMutableArray array];
  for (NSURLQueryItem* queryItem in existingQueryItems) {
    if ([queryItem.name isEqualToString:kBabelChromeLocalFileReloadQueryItemName]) {
      removedReloadToken = YES;
      continue;
    }
    [queryItems addObject:queryItem];
  }

  if (!removedReloadToken) {
    return urlString;
  }

  components.queryItems = queryItems.count > 0 ? queryItems : nil;
  return components.URL.absoluteString ?: urlString;
}

/**
 * Builds a comparable origin string from a URL.
 *
 * @param urlString The URL to parse.
 * @return The origin string, or an empty string when parsing fails.
 */
std::string OriginFromURLString(const std::string& urlString) {
  if (urlString.empty()) {
    return "";
  }

  CefURLParts parts;
  if (!CefParseURL(urlString, parts)) {
    return "";
  }

  std::string scheme = CefString(&parts.scheme).ToString();
  std::string host = CefString(&parts.host).ToString();
  std::string port = CefString(&parts.port).ToString();
  if (scheme.empty() || host.empty()) {
    return "";
  }

  return scheme + "://" + host + (port.empty() ? "" : ":" + port);
}

/**
 * Converts a CEF image to a native AppKit image.
 *
 * @param image The CEF image to convert.
 * @return The native image, or nil when conversion fails.
 */
NSImage* NativeImageFromCefImage(CefRefPtr<CefImage> image) {
  if (!image || image->IsEmpty()) {
    return nil;
  }

  int pixelWidth = 0;
  int pixelHeight = 0;
  CefRefPtr<CefBinaryValue> pngValue = image->GetAsPNG(1.0, true, pixelWidth, pixelHeight);
  if (!pngValue || pngValue->GetSize() == 0) {
    return nil;
  }

  size_t pngSize = pngValue->GetSize();
  std::vector<unsigned char> pngData(pngSize);
  pngValue->GetData(pngData.data(), pngSize, 0);

  NSData* data = [NSData dataWithBytes:pngData.data() length:pngSize];
  NSImage* nativeImage = [[NSImage alloc] initWithData:data];
  nativeImage.size = NSMakeSize(16.0, 16.0);
  return nativeImage;
}

/**
 * Receives favicon image downloads and forwards the native image to the window controller.
 */
class BabelFaviconDownloadCallback final : public CefDownloadImageCallback {
 public:
  /**
   * Creates a favicon download callback.
   *
   * @param controller The native controller receiving the image.
   * @param browser The browser owning the favicon.
   */
  BabelFaviconDownloadCallback(BabelBrowserWindowController* controller,
                               CefRefPtr<CefBrowser> browser)
      : controller_(controller), browser_(browser) {}

  /**
   * Receives the downloaded favicon image.
   *
   * @param image_url The downloaded image URL.
   * @param http_status_code The HTTP status code.
   * @param image The downloaded CEF image.
   */
  void OnDownloadImageFinished(const CefString& image_url,
                               int http_status_code,
                               CefRefPtr<CefImage> image) override {
    CEF_REQUIRE_UI_THREAD();
    if (http_status_code >= 400) {
      return;
    }

    NSImage* nativeImage = NativeImageFromCefImage(image);
    if (!nativeImage) {
      return;
    }

    BabelBrowserWindowController* controller = controller_;
    CefRefPtr<CefBrowser> browser = browser_;
    dispatch_async(dispatch_get_main_queue(), ^{
      [controller updateBrowser:browser faviconImage:nativeImage];
    });
  }

 private:
  BabelBrowserWindowController* controller_;
  CefRefPtr<CefBrowser> browser_;

  IMPLEMENT_REFCOUNTING(BabelFaviconDownloadCallback);
};

/**
 * Builds a base64 data URL.
 *
 * @param data The raw document data.
 * @param mime_type The MIME type to expose.
 * @return A data URL string.
 */
std::string MakeDataURI(const std::string& data, const std::string& mime_type) {
  return "data:" + mime_type + ";base64," +
         CefURIEncode(CefBase64Encode(data.data(), data.size()), false).ToString();
}

/**
 * Returns the URL targeted by a page context menu action.
 *
 * @param params The CEF context menu parameters.
 * @param frame The frame used as a fallback URL source.
 * @return The link URL when present, otherwise the page or frame URL.
 */
std::string ContextMenuTargetURL(CefRefPtr<CefContextMenuParams> params,
                                 CefRefPtr<CefFrame> frame) {
  std::string linkURL = params->GetLinkUrl().ToString();
  if (!linkURL.empty()) {
    return linkURL;
  }

  std::string pageURL = params->GetPageUrl().ToString();
  if (!pageURL.empty()) {
    return pageURL;
  }

  if (frame) {
    return frame->GetURL().ToString();
  }

  return "";
}

/**
 * Returns the direct link URL targeted by a page context menu action.
 *
 * @param params The CEF context menu parameters.
 * @return The link URL when the menu targets a link.
 */
std::string ContextMenuLinkURL(CefRefPtr<CefContextMenuParams> params) {
  if (!params) {
    return "";
  }

  return params->GetLinkUrl().ToString();
}

/**
 * Reports whether a BabelChrome internal action URL should suppress the context menu.
 *
 * @param urlString The target link URL.
 * @return True when the link is an action button rather than navigable content.
 */
bool ShouldSuppressContextMenuForBabelChromeActionURL(const std::string& urlString) {
  if (urlString.rfind("babelchrome://", 0) != 0) {
    return false;
  }

  const std::array<std::string, 20> actionMarkers = {{
      "babelchrome://history?reopen=",
      "babelchrome://settings?tabOpeningStrategy=",
      "babelchrome://settings?addressSuggestions=",
      "babelchrome://settings?markdownTheme=",
      "babelchrome://settings?appearanceTheme=",
      "babelchrome://extensions?search=",
      "babelchrome://extensions?addUnpacked=",
      "babelchrome://extensions?remove=",
      "babelchrome://extensions?disableProfile=",
      "babelchrome://extensions?enableProfile=",
      "babelchrome://extensions?removeProfile=",
      "babelchrome://extensions?restart=",
      "babelchrome://modules?installZip=",
      "babelchrome://modules?configureUpdateURL=",
      "babelchrome://modules?configureUpdateLocal=",
      "babelchrome://modules?installSelectedUpdates=",
      "babelchrome://modules?installUpdates=",
      "babelchrome://modules?installUpdate=",
      "babelchrome://modules?enable=",
      "babelchrome://modules?disable="
  }};

  for (const std::string& marker : actionMarkers) {
    if (urlString.rfind(marker, 0) == 0) {
      return true;
    }
  }

  return urlString.rfind("babelchrome://modules?remove=", 0) == 0 ||
         urlString.rfind("babelchrome://modules?open=", 0) == 0;
}

/**
 * Returns the source URL for the page owning a context menu.
 *
 * @param params The CEF context menu parameters.
 * @param frame The frame used as a fallback URL source.
 * @return The page URL to inspect as source.
 */
std::string ContextMenuPageURL(CefRefPtr<CefContextMenuParams> params,
                               CefRefPtr<CefFrame> frame) {
  std::string pageURL = params->GetPageUrl().ToString();
  if (!pageURL.empty()) {
    return pageURL;
  }

  if (frame) {
    return frame->GetURL().ToString();
  }

  return "";
}

/**
 * Reports whether a popup disposition should become a native tab.
 *
 * @param disposition The CEF target disposition.
 * @return True when BabelChrome should open a new tab.
 */
bool IsTabDisposition(cef_window_open_disposition_t disposition) {
  return disposition == CEF_WOD_NEW_FOREGROUND_TAB ||
         disposition == CEF_WOD_NEW_BACKGROUND_TAB;
}

/**
 * Reports whether a popup disposition should become a native tab.
 *
 * @param disposition The CEF target disposition.
 * @return True when BabelChrome should open a new tab.
 */
bool ShouldOpenPopupDispositionInNewTab(CefLifeSpanHandler::WindowOpenDisposition disposition) {
  return IsTabDisposition(disposition) ||
         disposition == CEF_WOD_NEW_WINDOW ||
         disposition == CEF_WOD_NEW_POPUP;
}

/**
 * Reports whether BabelChrome capability headers should be exposed to a request URL.
 *
 * @param urlString The outgoing request URL.
 * @param requestInitiator The request initiator origin.
 * @return True when the request can receive BabelChrome headers.
 */
bool ShouldExposeBabelChromeHeadersToURL(const std::string& urlString,
                                         const std::string& requestInitiator) {
  if (urlString.empty()) {
    return false;
  }

  CefURLParts parts;
  if (!CefParseURL(urlString, parts)) {
    return false;
  }

  std::string scheme = CefString(&parts.scheme).ToString();
  if (scheme != "http" && scheme != "https") {
    return false;
  }

  if (requestInitiator.empty()) {
    return true;
  }

  std::string requestOrigin = OriginFromURLString(urlString);
  std::string initiatorOrigin = OriginFromURLString(requestInitiator);
  if (requestOrigin.empty() || initiatorOrigin.empty()) {
    return true;
  }

  return requestOrigin == initiatorOrigin;
}

/**
 * Reports whether a key event is a BabelChrome reload shortcut.
 *
 * @param event The CEF key event.
 * @return True when the key event is Command+R or Shift+Command+R.
 */
bool IsReloadShortcutKeyEvent(const CefKeyEvent& event) {
  if (event.type != KEYEVENT_RAWKEYDOWN && event.type != KEYEVENT_KEYDOWN) {
    return false;
  }

  bool isReloadKey = event.windows_key_code == kReloadVirtualKeyCode ||
                     event.unmodified_character == u'r' ||
                     event.unmodified_character == u'R';
  if (!isReloadKey) {
    return false;
  }

  if (0 == (event.modifiers & EVENTFLAG_COMMAND_DOWN)) {
    return false;
  }

  return 0 == (event.modifiers & (EVENTFLAG_CONTROL_DOWN | EVENTFLAG_ALT_DOWN));
}

/**
 * Returns the file type header value advertised by installed native module manifests.
 *
 * @return A comma-separated file type list, or an empty string when unavailable.
 */
std::string FileTypesHeaderValueFromNativeModules() {
  @autoreleasepool {
    NSError* error = nil;
    BabelNativeModuleRegistry* registry = [[BabelNativeModuleRegistry alloc] init];
    NSString* headerValue = [registry fileTypeHeaderValueWithError:&error];
    if (headerValue.length == 0) {
      return "";
    }

    return std::string(headerValue.UTF8String);
  }
}

/**
 * Opens a URL string in a native BabelChrome tab on the main queue.
 *
 * @param controller The native controller receiving the request.
 * @param urlString The URL string to open.
 * @param openerBrowser The browser that requested the new tab.
 */
void OpenURLStringInNewTab(BabelBrowserWindowController* controller,
                           const std::string& urlString,
                           CefRefPtr<CefBrowser> openerBrowser) {
  if (urlString.empty()) {
    return;
  }

  NSString* nativeURLString = [NSString stringWithUTF8String:urlString.c_str()];
  dispatch_async(dispatch_get_main_queue(), ^{
    [controller openURLStringInNewTab:nativeURLString openerBrowser:openerBrowser];
  });
}

}  // namespace

BabelBrowserClient::BabelBrowserClient(BabelBrowserWindowController* controller)
    : controller_(controller),
      fileTypesHeaderValue_(FileTypesHeaderValueFromNativeModules()) {}

BabelBrowserClient::~BabelBrowserClient() = default;

void BabelBrowserClient::RefreshFileTypesHeaderValue() {
  std::string refreshedHeaderValue = FileTypesHeaderValueFromNativeModules();
  std::lock_guard<std::mutex> lock(fileTypesHeaderValueMutex_);
  fileTypesHeaderValue_ = refreshedHeaderValue;
}

std::string BabelBrowserClient::FileTypesHeaderValue() {
  {
    std::lock_guard<std::mutex> lock(fileTypesHeaderValueMutex_);
    if (!fileTypesHeaderValue_.empty()) {
      return fileTypesHeaderValue_;
    }
  }

  std::string refreshedHeaderValue = FileTypesHeaderValueFromNativeModules();
  std::lock_guard<std::mutex> lock(fileTypesHeaderValueMutex_);
  if (fileTypesHeaderValue_.empty()) {
    fileTypesHeaderValue_ = refreshedHeaderValue;
  }

  return fileTypesHeaderValue_;
}

CefRefPtr<CefContextMenuHandler> BabelBrowserClient::GetContextMenuHandler() {
  return this;
}

CefRefPtr<CefDragHandler> BabelBrowserClient::GetDragHandler() {
  return this;
}

CefRefPtr<CefDisplayHandler> BabelBrowserClient::GetDisplayHandler() {
  return this;
}

CefRefPtr<CefKeyboardHandler> BabelBrowserClient::GetKeyboardHandler() {
  return this;
}

CefRefPtr<CefLifeSpanHandler> BabelBrowserClient::GetLifeSpanHandler() {
  return this;
}

CefRefPtr<CefLoadHandler> BabelBrowserClient::GetLoadHandler() {
  return this;
}

CefRefPtr<CefRequestHandler> BabelBrowserClient::GetRequestHandler() {
  return this;
}

CefRefPtr<CefResourceRequestHandler> BabelBrowserClient::GetResourceRequestHandler(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    CefRefPtr<CefRequest> request,
    bool is_navigation,
    bool is_download,
    const CefString& request_initiator,
    bool& disable_default_handling) {
  CEF_REQUIRE_IO_THREAD();
  if (!request) {
    return nullptr;
  }

  if (FileTypesHeaderValue().empty()) {
    return nullptr;
  }

  if (!ShouldExposeBabelChromeHeadersToURL(request->GetURL().ToString(),
                                          request_initiator.ToString())) {
    return nullptr;
  }

  return this;
}

CefResourceRequestHandler::ReturnValue BabelBrowserClient::OnBeforeResourceLoad(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    CefRefPtr<CefRequest> request,
    CefRefPtr<CefCallback> callback) {
  CEF_REQUIRE_IO_THREAD();
  const std::string fileTypesHeaderValue = FileTypesHeaderValue();
  if (request && !fileTypesHeaderValue.empty()) {
    CefRequest::HeaderMap headers;
    request->GetHeaderMap(headers);
    headers.erase(CefString(kBabelChromeFileTypesHeaderName));
    headers.insert(std::make_pair(CefString(kBabelChromeFileTypesHeaderName), CefString(fileTypesHeaderValue)));
    request->SetHeaderMap(headers);
  }

  return RV_CONTINUE;
}

bool BabelBrowserClient::OnPreKeyEvent(CefRefPtr<CefBrowser> browser,
                                       const CefKeyEvent& event,
                                       CefEventHandle os_event,
                                       bool* is_keyboard_shortcut) {
  CEF_REQUIRE_UI_THREAD();
  if (!IsReloadShortcutKeyEvent(event)) {
    return false;
  }

  if (is_keyboard_shortcut) {
    *is_keyboard_shortcut = true;
  }

  const bool ignoringCache = 0 != (event.modifiers & EVENTFLAG_SHIFT_DOWN);
  dispatch_async(dispatch_get_main_queue(), ^{
    [controller_ reloadBrowser:browser ignoringCache:ignoringCache];
  });
  return true;
}

void BabelBrowserClient::OnTitleChange(CefRefPtr<CefBrowser> browser,
                                       const CefString& title) {
  CEF_REQUIRE_UI_THREAD();
  std::string titleString(title);
  NSString* nativeTitle = [NSString stringWithUTF8String:titleString.c_str()];
  dispatch_async(dispatch_get_main_queue(), ^{
    [controller_ updateBrowser:browser title:nativeTitle];
  });
}

void BabelBrowserClient::OnAddressChange(CefRefPtr<CefBrowser> browser,
                                         CefRefPtr<CefFrame> frame,
                                         const CefString& url) {
  CEF_REQUIRE_UI_THREAD();
  if (!frame->IsMain()) {
    return;
  }

  std::string urlString(url);
  NSString* nativeURLString = URLStringByRemovingLocalFileReloadToken([NSString stringWithUTF8String:urlString.c_str()]);
  dispatch_async(dispatch_get_main_queue(), ^{
    [controller_ updateBrowser:browser urlString:nativeURLString];
  });
}

void BabelBrowserClient::OnStatusMessage(CefRefPtr<CefBrowser> browser,
                                         const CefString& value) {
  CEF_REQUIRE_UI_THREAD();
  std::string statusString(value);
  NSString* nativeStatusString = [NSString stringWithUTF8String:statusString.c_str()];
  dispatch_async(dispatch_get_main_queue(), ^{
    [controller_ updateBrowser:browser statusText:nativeStatusString];
  });
}

void BabelBrowserClient::OnFaviconURLChange(CefRefPtr<CefBrowser> browser,
                                            const std::vector<CefString>& icon_urls) {
  CEF_REQUIRE_UI_THREAD();
  if (!browser || icon_urls.empty()) {
    return;
  }

  for (const CefString& iconURL : icon_urls) {
    std::string iconURLString = iconURL.ToString();
    if (iconURLString.empty()) {
      continue;
    }

    browser->GetHost()->DownloadImage(iconURL,
                                       true,
                                       kFaviconDownloadMaximumSize,
                                       false,
                                       new BabelFaviconDownloadCallback(controller_, browser));
    return;
  }
}

void BabelBrowserClient::OnBeforeContextMenu(CefRefPtr<CefBrowser> browser,
                                             CefRefPtr<CefFrame> frame,
                                             CefRefPtr<CefContextMenuParams> params,
                                             CefRefPtr<CefMenuModel> model) {
  CEF_REQUIRE_UI_THREAD();

  if (model->GetCount() > 0) {
    model->AddSeparator();
  }
  std::string linkURL = ContextMenuLinkURL(params);
  if (ShouldSuppressContextMenuForBabelChromeActionURL(linkURL)) {
    model->Clear();
    return;
  }
  if (!ContextMenuTargetURL(params, frame).empty()) {
    model->AddItem(kOpenInNewTabCommandId, "Ouvrir dans un nouvel onglet");
  }
  if (!linkURL.empty()) {
    model->AddItem(kCopyLinkCommandId, "Copier le lien");
  }
  model->AddItem(kOpenDeveloperToolsCommandId, "Developer Tools");
  model->SetEnabled(kOpenDeveloperToolsCommandId,
                    [controller_ canOpenDeveloperToolsForBrowser:browser]);
  if ([controller_ canOpenViewerSourceForBrowser:browser]) {
    model->AddSeparator();
    model->AddItem(kOpenViewerSourceCommandId, "Open Source File");
    model->AddItem(kRevealViewerSourceCommandId, "Reveal in Finder");
  }
}

bool BabelBrowserClient::OnContextMenuCommand(CefRefPtr<CefBrowser> browser,
                                              CefRefPtr<CefFrame> frame,
                                              CefRefPtr<CefContextMenuParams> params,
                                              int commandId,
                                              EventFlags eventFlags) {
  CEF_REQUIRE_UI_THREAD();

  if (commandId == MENU_ID_VIEW_SOURCE) {
    std::string urlString = ContextMenuPageURL(params, frame);
    if (!urlString.empty()) {
      OpenURLStringInNewTab(controller_, "view-source:" + urlString, browser);
    }
    return true;
  }

  if (commandId == kOpenDeveloperToolsCommandId) {
    [controller_ openDeveloperToolsForBrowser:browser
                                             x:params->GetXCoord()
                                             y:params->GetYCoord()];
    return true;
  }

  if (commandId == kOpenInNewTabCommandId) {
    OpenURLStringInNewTab(controller_, ContextMenuTargetURL(params, frame), browser);
    return true;
  }

  if (commandId == kCopyLinkCommandId) {
    std::string linkURL = ContextMenuLinkURL(params);
    if (!linkURL.empty()) {
      NSString* nativeLinkURL = [NSString stringWithUTF8String:linkURL.c_str()];
      [controller_ copyURLStringToPasteboard:nativeLinkURL];
    }
    return true;
  }

  if (commandId == kOpenViewerSourceCommandId) {
    [controller_ openViewerSourceForBrowser:browser];
    return true;
  }

  if (commandId == kRevealViewerSourceCommandId) {
    [controller_ revealViewerSourceForBrowser:browser];
    return true;
  }

  return false;
}

bool BabelBrowserClient::OnBeforePopup(CefRefPtr<CefBrowser> browser,
                                       CefRefPtr<CefFrame> frame,
                                       int popupId,
                                       const CefString& targetUrl,
                                       const CefString& targetFrameName,
                                       CefLifeSpanHandler::WindowOpenDisposition targetDisposition,
                                       bool userGesture,
                                       const CefPopupFeatures& popupFeatures,
                                       CefWindowInfo& windowInfo,
                                       CefRefPtr<CefClient>& client,
                                       CefBrowserSettings& settings,
                                       CefRefPtr<CefDictionaryValue>& extraInfo,
                                       bool* noJavascriptAccess) {
  CEF_REQUIRE_UI_THREAD();

  std::string urlString = targetUrl.ToString();
  if (!userGesture || urlString.empty() || !ShouldOpenPopupDispositionInNewTab(targetDisposition)) {
    return false;
  }

  OpenURLStringInNewTab(controller_, urlString, browser);
  return true;
}

bool BabelBrowserClient::OnOpenURLFromTab(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    const CefString& targetUrl,
    CefRequestHandler::WindowOpenDisposition targetDisposition,
    bool userGesture) {
  CEF_REQUIRE_UI_THREAD();

  std::string urlString = targetUrl.ToString();
  if (!userGesture || urlString.empty() || !IsTabDisposition(targetDisposition)) {
    return false;
  }

  OpenURLStringInNewTab(controller_, urlString, browser);
  return true;
}

bool BabelBrowserClient::OnBeforeBrowse(CefRefPtr<CefBrowser> browser,
                                        CefRefPtr<CefFrame> frame,
                                        CefRefPtr<CefRequest> request,
                                        bool userGesture,
                                        bool isRedirect) {
  CEF_REQUIRE_UI_THREAD();
  if (!frame->IsMain()) {
    return false;
  }

  std::string urlString = request->GetURL().ToString();
  if (urlString.rfind("file://", 0) == 0 && [controller_ shouldSuppressLocalFileNavigationForBrowser:browser]) {
    return true;
  }

  if (urlString.rfind("babelchrome://", 0) != 0) {
    return false;
  }

  NSString* nativeURLString = [NSString stringWithUTF8String:urlString.c_str()];
  dispatch_async(dispatch_get_main_queue(), ^{
    [controller_ handleInternalNavigationURLString:nativeURLString browser:browser];
  });
  return true;
}

void BabelBrowserClient::OnLoadEnd(CefRefPtr<CefBrowser> browser,
                                   CefRefPtr<CefFrame> frame,
                                   int httpStatusCode) {
  CEF_REQUIRE_UI_THREAD();
  if (!frame->IsMain()) {
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    [controller_ browserDidFinishLoading:browser];
  });
}

bool BabelBrowserClient::OnDragEnter(CefRefPtr<CefBrowser> browser,
                                     CefRefPtr<CefDragData> dragData,
                                     DragOperationsMask mask) {
  CEF_REQUIRE_UI_THREAD();
  if (!dragData) {
    return false;
  }

  std::vector<CefString> filePaths;
  if (!dragData->GetFilePaths(filePaths) || filePaths.empty()) {
    return false;
  }

  NSMutableArray<NSString*>* nativePaths = [NSMutableArray arrayWithCapacity:filePaths.size()];
  for (const CefString& filePath : filePaths) {
    std::string path = filePath.ToString();
    if (!path.empty()) {
      [nativePaths addObject:[NSString stringWithUTF8String:path.c_str()]];
    }
  }

  if (nativePaths.count > 0) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [controller_ browser:browser didReceiveLocalDragPaths:nativePaths];
    });
  }

  return false;
}

void BabelBrowserClient::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  dispatch_async(dispatch_get_main_queue(), ^{
    [controller_ attachCreatedBrowser:browser];
  });
}

bool BabelBrowserClient::DoClose(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  return ![controller_ shouldPropagateBrowserClose];
}

void BabelBrowserClient::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  dispatch_async(dispatch_get_main_queue(), ^{
    [controller_ detachClosedBrowser:browser];
  });
}

void BabelBrowserClient::OnLoadError(CefRefPtr<CefBrowser> browser,
                                     CefRefPtr<CefFrame> frame,
                                     ErrorCode errorCode,
                                     const CefString& errorText,
                                     const CefString& failedUrl) {
  CEF_REQUIRE_UI_THREAD();

  if (errorCode == ERR_ABORTED) {
    return;
  }

  std::stringstream html;
  html << "<html><body style=\"font-family:-apple-system;padding:24px\">"
       << "<h2>Unable to load URL</h2>"
       << "<p><strong>URL:</strong> " << std::string(failedUrl) << "</p>"
       << "<p><strong>Error:</strong> " << std::string(errorText)
       << " (" << errorCode << ")</p>"
       << "</body></html>";
  frame->LoadURL(MakeDataURI(html.str(), "text/html"));
}
