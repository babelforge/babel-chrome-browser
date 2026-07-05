#ifndef BABEL_CHROME_BROWSER_CLIENT_H_
#define BABEL_CHROME_BROWSER_CLIENT_H_

#include "include/cef_client.h"
#include "include/cef_keyboard_handler.h"
#include "include/cef_resource_request_handler.h"

#include <mutex>
#include <string>
#include <vector>

@class BabelBrowserWindowController;

/**
 * Bridges CEF browser callbacks back to the native BabelChrome window.
 */
class BabelBrowserClient final : public CefClient,
                                 public CefContextMenuHandler,
                                 public CefDragHandler,
                                 public CefDisplayHandler,
                                 public CefKeyboardHandler,
                                 public CefLifeSpanHandler,
                                 public CefLoadHandler,
                                 public CefRequestHandler,
                                 public CefResourceRequestHandler {
 public:
  /**
   * Creates a browser client bound to the native window controller.
   *
   * @param controller The native controller receiving browser callbacks.
   */
  explicit BabelBrowserClient(BabelBrowserWindowController* controller);

  /**
   * Destroys the browser client.
   */
  ~BabelBrowserClient() override;

  /**
   * Refreshes the advertised file type header value from the extension host.
   *
   * This must be called after module install, removal, enable, or disable
   * operations because viewer capabilities can change while BabelChrome is
   * running.
   */
  void RefreshFileTypesHeaderValue();

  /**
   * Returns the context menu callback handler.
   *
   * @return The context menu handler.
   */
  CefRefPtr<CefContextMenuHandler> GetContextMenuHandler() override;

  /**
   * Returns the drag callback handler.
   *
   * @return The drag handler.
   */
  CefRefPtr<CefDragHandler> GetDragHandler() override;

  /**
   * Returns the display callback handler.
   *
   * @return The display handler.
   */
  CefRefPtr<CefDisplayHandler> GetDisplayHandler() override;

  /**
   * Returns the keyboard shortcut callback handler.
   *
   * @return The keyboard handler.
   */
  CefRefPtr<CefKeyboardHandler> GetKeyboardHandler() override;

  /**
   * Returns the lifespan callback handler.
   *
   * @return The lifespan handler.
   */
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override;

  /**
   * Returns the load callback handler.
   *
   * @return The load handler.
   */
  CefRefPtr<CefLoadHandler> GetLoadHandler() override;

  /**
   * Returns the request callback handler.
   *
   * @return The request handler.
   */
  CefRefPtr<CefRequestHandler> GetRequestHandler() override;

  /**
   * Returns the resource request handler for eligible network requests.
   *
   * @param browser The browser that owns the request.
   * @param frame The frame that owns the request.
   * @param request The outgoing request.
   * @param is_navigation Whether this request is a navigation.
   * @param is_download Whether this request is a download.
   * @param request_initiator The initiating origin.
   * @param disable_default_handling Receives whether CEF should disable default handling.
   * @return The resource request handler, or null when no handling is needed.
   */
  CefRefPtr<CefResourceRequestHandler> GetResourceRequestHandler(
      CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame,
      CefRefPtr<CefRequest> request,
      bool is_navigation,
      bool is_download,
      const CefString& request_initiator,
      bool& disable_default_handling) override;

  /**
   * Adds BabelChrome capability headers before HTTP resources are loaded.
   *
   * @param browser The browser that owns the request.
   * @param frame The frame that owns the request.
   * @param request The outgoing request.
   * @param callback The optional asynchronous continuation callback.
   * @return The CEF resource load decision.
   */
  ReturnValue OnBeforeResourceLoad(CefRefPtr<CefBrowser> browser,
                                   CefRefPtr<CefFrame> frame,
                                   CefRefPtr<CefRequest> request,
                                   CefRefPtr<CefCallback> callback) override;

  /**
   * Handles browser-level keyboard shortcuts before page JavaScript receives them.
   *
   * @param browser The browser that received the key event.
   * @param event The CEF key event.
   * @param os_event The native operating system event handle.
   * @param is_keyboard_shortcut Receives whether the key is a keyboard shortcut.
   * @return True when BabelChrome handled the event.
   */
  bool OnPreKeyEvent(CefRefPtr<CefBrowser> browser,
                     const CefKeyEvent& event,
                     CefEventHandle os_event,
                     bool* is_keyboard_shortcut) override;

  /**
   * Receives page title changes.
   *
   * @param browser The browser whose title changed.
   * @param title The new page title.
   */
  void OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString& title) override;

  /**
   * Receives address changes for the main browser frame.
   *
   * @param browser The browser whose address changed.
   * @param frame The frame whose address changed.
   * @param url The new URL.
   */
  void OnAddressChange(CefRefPtr<CefBrowser> browser,
                       CefRefPtr<CefFrame> frame,
                       const CefString& url) override;

  /**
   * Receives status text updates such as hovered link URLs.
   *
   * @param browser The browser whose status changed.
   * @param value The new status text.
   */
  void OnStatusMessage(CefRefPtr<CefBrowser> browser, const CefString& value) override;

  /**
   * Receives page favicon URL changes.
   *
   * @param browser The browser whose favicon changed.
   * @param icon_urls The favicon URLs advertised by the page.
   */
  void OnFaviconURLChange(CefRefPtr<CefBrowser> browser,
                          const std::vector<CefString>& icon_urls) override;

  /**
   * Adds BabelChrome-specific page context menu entries.
   *
   * @param browser The browser that owns the menu.
   * @param frame The frame under the menu.
   * @param params Context menu metadata.
   * @param model The menu model to extend.
   */
  void OnBeforeContextMenu(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame,
                           CefRefPtr<CefContextMenuParams> params,
                           CefRefPtr<CefMenuModel> model) override;

  /**
   * Handles BabelChrome-specific page context menu commands.
   *
   * @param browser The browser that owns the command.
   * @param frame The frame under the menu.
   * @param params Context menu metadata.
   * @param commandId The selected command identifier.
   * @param eventFlags CEF event flags for the command.
   * @return True when BabelChrome handled the command.
   */
  bool OnContextMenuCommand(CefRefPtr<CefBrowser> browser,
                            CefRefPtr<CefFrame> frame,
                            CefRefPtr<CefContextMenuParams> params,
                            int commandId,
                            EventFlags eventFlags) override;

  /**
   * Redirects popup or modified-click navigations into native tabs.
   *
   * @param browser The opener browser.
   * @param frame The opener frame.
   * @param popupId The CEF popup identifier.
   * @param targetUrl The popup target URL.
   * @param targetFrameName The popup target frame name.
   * @param targetDisposition The user-requested target disposition.
   * @param userGesture Whether the popup came from a user gesture.
   * @param popupFeatures CEF popup feature hints.
   * @param windowInfo The popup window info.
   * @param client The popup client.
   * @param settings The popup browser settings.
   * @param extraInfo Extra popup information.
   * @param noJavascriptAccess Whether JavaScript access is disabled.
   * @return True when BabelChrome cancels the popup and opens a native tab.
   */
  bool OnBeforePopup(CefRefPtr<CefBrowser> browser,
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
                     bool* noJavascriptAccess) override;

  /**
   * Redirects modified link clicks into native tabs.
   *
   * @param browser The browser receiving the navigation.
   * @param frame The frame receiving the navigation.
   * @param targetUrl The navigation target URL.
   * @param targetDisposition The user-requested target disposition.
   * @param userGesture Whether the navigation came from a user gesture.
   * @return True when BabelChrome cancels the navigation and opens a native tab.
   */
  bool OnOpenURLFromTab(CefRefPtr<CefBrowser> browser,
                        CefRefPtr<CefFrame> frame,
                        const CefString& targetUrl,
                        CefRequestHandler::WindowOpenDisposition targetDisposition,
                        bool userGesture) override;

  /**
   * Handles navigation before it is committed.
   *
   * @param browser The browser receiving the navigation.
   * @param frame The frame receiving the navigation.
   * @param request The navigation request.
   * @param userGesture Whether the navigation came from a user gesture.
   * @param isRedirect Whether the navigation is a redirect.
   * @return True when BabelChrome cancels the navigation.
   */
  bool OnBeforeBrowse(CefRefPtr<CefBrowser> browser,
                      CefRefPtr<CefFrame> frame,
                      CefRefPtr<CefRequest> request,
                      bool userGesture,
                      bool isRedirect) override;

  /**
   * Receives successful frame load notifications.
   *
   * @param browser The browser that loaded.
   * @param frame The loaded frame.
   * @param httpStatusCode The HTTP status code.
   */
  void OnLoadEnd(CefRefPtr<CefBrowser> browser,
                 CefRefPtr<CefFrame> frame,
                 int httpStatusCode) override;

  /**
   * Observes local file drags entering a browser.
   *
   * @param browser The browser receiving the drag.
   * @param dragData The drag payload.
   * @param mask The drag operation mask.
   * @return False to keep default page drag handling.
   */
  bool OnDragEnter(CefRefPtr<CefBrowser> browser,
                   CefRefPtr<CefDragData> dragData,
                   DragOperationsMask mask) override;

  /**
   * Receives newly created browser instances.
   *
   * @param browser The created browser.
   */
  void OnAfterCreated(CefRefPtr<CefBrowser> browser) override;

  /**
   * Handles browser close requests.
   *
   * @param browser The browser being closed.
   * @return True to stop tab browser closes from propagating to the native window.
   */
  bool DoClose(CefRefPtr<CefBrowser> browser) override;

  /**
   * Receives final browser close notifications.
   *
   * @param browser The closed browser.
   */
  void OnBeforeClose(CefRefPtr<CefBrowser> browser) override;

  /**
   * Receives browser load failures.
   *
   * @param browser The browser that failed loading.
   * @param frame The frame that failed loading.
   * @param errorCode The CEF error code.
   * @param errorText The CEF error text.
   * @param failedUrl The failed URL.
   */
  void OnLoadError(CefRefPtr<CefBrowser> browser,
                   CefRefPtr<CefFrame> frame,
                   ErrorCode errorCode,
                   const CefString& errorText,
                   const CefString& failedUrl) override;

 private:
  /**
   * Returns the advertised file type header value.
   *
   * The value is loaded lazily because extension modules can become available
   * after the CEF client has been created.
   */
  std::string FileTypesHeaderValue();

  BabelBrowserWindowController* controller_;
  std::string fileTypesHeaderValue_;
  std::mutex fileTypesHeaderValueMutex_;

  IMPLEMENT_REFCOUNTING(BabelBrowserClient);
};

#endif
