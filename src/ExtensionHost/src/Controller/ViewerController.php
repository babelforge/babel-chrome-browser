<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Controller;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleDispatchException;
use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleInstallationException;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleAutoloadRegistrar;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleHookRegistry;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleInstaller;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleManifest;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRegistry;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRouteDispatcher;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleUrlResolver;
use BabelForge\BabelChrome\LocalViewer\Service\OpenWithService;
use BabelForge\BabelChrome\LocalViewer\Service\SourceLoader;
use BabelForge\BabelChrome\LocalViewer\Service\SourceRegistry;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Twig\Environment;

/**
 * Handles local viewer HTTP endpoints.
 */
final readonly class ViewerController
{
    /**
     * @param SourceLoader            $sourceLoader            loads local and remote documents
     * @param ModuleRegistry          $moduleRegistry          exposes registered PHP modules
     * @param ModuleHookRegistry      $moduleHookRegistry      exposes module hooks
     * @param ModuleInstaller         $moduleInstaller         installs and manages user modules
     * @param ModuleAutoloadRegistrar $moduleAutoloadRegistrar registers module-local vendors
     * @param ModuleRouteDispatcher   $moduleRouteDispatcher   dispatches routable modules
     * @param ModuleUrlResolver       $moduleUrlResolver       resolves module metadata from URLs
     * @param OpenWithService         $openWithService         opens local files with macOS applications
     * @param Environment             $twig                    renders viewer templates
     */
    public function __construct(
        private SourceLoader $sourceLoader,
        private SourceRegistry $sourceRegistry,
        private ModuleRegistry $moduleRegistry,
        private ModuleHookRegistry $moduleHookRegistry,
        private ModuleInstaller $moduleInstaller,
        private ModuleAutoloadRegistrar $moduleAutoloadRegistrar,
        private ModuleRouteDispatcher $moduleRouteDispatcher,
        private ModuleUrlResolver $moduleUrlResolver,
        private OpenWithService $openWithService,
        private Environment $twig,
    ) {
    }

    /**
     * Installs a user PHP module from a zip archive.
     *
     * @param Request $request the current request
     *
     * @return JsonResponse the install response
     */
    #[Route('/internal/modules/install', name: 'internal_modules_install', methods: ['GET'])]
    public function internalModulesInstall(Request $request): JsonResponse
    {
        if (!$this->hasValidToken($request)) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $zipPath = $this->queryString($request, 'zip');
        if ('' === $zipPath) {
            return new JsonResponse(['ok' => false, 'error' => 'Missing zip path.'], Response::HTTP_BAD_REQUEST);
        }

        try {
            $module = $this->moduleInstaller->installZip($zipPath);

            return new JsonResponse([
                'ok' => true,
                'module' => $module->toArray(),
            ]);
        } catch (ModuleInstallationException $exception) {
            return new JsonResponse([
                'ok' => false,
                'error' => $exception->getMessage(),
            ], Response::HTTP_UNPROCESSABLE_ENTITY);
        }
    }

    /**
     * Enables a user PHP module.
     *
     * @param Request $request the current request
     *
     * @return JsonResponse the enable response
     */
    #[Route('/internal/modules/enable', name: 'internal_modules_enable', methods: ['GET'])]
    public function internalModulesEnable(Request $request): JsonResponse
    {
        return $this->setModuleEnabled($request, true);
    }

    /**
     * Disables a user PHP module.
     *
     * @param Request $request the current request
     *
     * @return JsonResponse the disable response
     */
    #[Route('/internal/modules/disable', name: 'internal_modules_disable', methods: ['GET'])]
    public function internalModulesDisable(Request $request): JsonResponse
    {
        return $this->setModuleEnabled($request, false);
    }

    /**
     * Removes a user PHP module.
     *
     * @param Request $request the current request
     *
     * @return JsonResponse the remove response
     */
    #[Route('/internal/modules/remove', name: 'internal_modules_remove', methods: ['GET'])]
    public function internalModulesRemove(Request $request): JsonResponse
    {
        if (!$this->hasValidToken($request)) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $moduleId = $this->queryString($request, 'moduleId');
        if ('' === $moduleId) {
            return new JsonResponse(['ok' => false, 'error' => 'Missing module id.'], Response::HTTP_BAD_REQUEST);
        }

        try {
            $this->moduleInstaller->remove($moduleId);

            return new JsonResponse(['ok' => true]);
        } catch (ModuleInstallationException $exception) {
            return new JsonResponse([
                'ok' => false,
                'error' => $exception->getMessage(),
            ], Response::HTTP_UNPROCESSABLE_ENTITY);
        }
    }

    /**
     * Returns the address badge contributed by a module.
     *
     * @param Request $request the current request
     *
     * @return JsonResponse the badge response
     */
    #[Route('/internal/address-badge', name: 'internal_address_badge', methods: ['GET'])]
    public function internalAddressBadge(Request $request): JsonResponse
    {
        if (!$this->hasValidToken($request)) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $urlValue = $request->query->get('url', '');
        $url = is_string($urlValue) ? $urlValue : '';
        $module = $this->moduleForAddressBadgeUrl($url);
        if (null === $module || null === $module->badge) {
            return new JsonResponse(['handled' => false]);
        }

        return new JsonResponse([
            'handled' => true,
            'moduleId' => $module->id,
            'badge' => $module->badge->toArray(),
        ]);
    }

    /**
     * Resolves the module that should provide an address badge for a URL.
     *
     * @param string $url the user-facing URL
     *
     * @return ModuleManifest|null the matching module when found
     */
    private function moduleForAddressBadgeUrl(string $url): ?ModuleManifest
    {
        $module = $this->moduleUrlResolver->moduleForUrl($url);
        if (null !== $module) {
            return $module;
        }

        $sourceUrl = $this->sourceUrlFromStableViewerUrl($url);
        if (null === $sourceUrl) {
            return null;
        }

        $resolvedRoute = $this->moduleUrlResolver->viewerRouteForSourceUrl($sourceUrl);

        return $resolvedRoute['module'] ?? null;
    }

    /**
     * Extracts the source URL from a stable BabelChrome viewer URL.
     *
     * @param string $url the stable viewer URL
     *
     * @return string|null the source URL when the URL targets a viewer source
     */
    private function sourceUrlFromStableViewerUrl(string $url): ?string
    {
        $parts = parse_url($url);
        if (!is_array($parts) || 'babelchrome' !== ($parts['scheme'] ?? '') || 'viewer' !== ($parts['host'] ?? '')) {
            return null;
        }

        $path = (string) ($parts['path'] ?? '');
        if (str_starts_with($path, '/file/')) {
            return 'file://'.rawurldecode(substr($path, strlen('/file/')));
        }

        if (str_starts_with($path, '/url/')) {
            return rawurldecode(substr($path, strlen('/url/')));
        }

        return null;
    }

    /**
     * Returns the viewer module route that can handle a local or remote source URL.
     *
     * @param Request $request the current request
     *
     * @return JsonResponse the viewer route response
     */
    #[Route('/internal/viewer-route', name: 'internal_viewer_route', methods: ['GET'])]
    public function internalViewerRoute(Request $request): JsonResponse
    {
        if (!$this->hasValidToken($request)) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $urlValue = $request->query->get('url', '');
        $url = is_string($urlValue) ? $urlValue : '';
        $resolvedRoute = $this->moduleUrlResolver->viewerRouteForSourceUrl($url);
        if (null === $resolvedRoute) {
            return new JsonResponse(['handled' => false]);
        }

        $module = $resolvedRoute['module'];
        $route = $resolvedRoute['route'];

        return new JsonResponse([
            'handled' => true,
            'moduleId' => $module->id,
            'viewerKind' => $route->host,
            'route' => sprintf('/module/%s/%s', rawurlencode($module->id), rawurlencode($route->handler)),
            'handler' => $route->handler,
        ]);
    }

    /**
     * Renders the PHP modules management page.
     *
     * @param Request $request the current request
     *
     * @return Response the rendered modules response
     */
    #[Route('/modules', name: 'modules', methods: ['GET'])]
    public function modules(Request $request): Response
    {
        if (!$this->hasValidToken($request)) {
            return new Response('Forbidden', Response::HTTP_FORBIDDEN);
        }

        return new Response(
            $this->twig->render('modules/index.html.twig', [
                'modules' => $this->moduleRows(),
                'userModulesDirectory' => $this->moduleRegistry->userModulesDirectory(),
                'stylesheetContent' => $this->viewerShellStyles(),
            ]),
            Response::HTTP_OK,
            ['Content-Type' => 'text/html; charset=utf-8'],
        );
    }

    /**
     * Dispatches a route to an installed PHP module.
     *
     * @param Request $request  the current request
     * @param string  $moduleId the module identifier
     * @param string  $route    the module route
     *
     * @return Response the module response
     */
    #[Route('/module/{moduleId}/{route}', name: 'module_route', requirements: ['route' => '(?!assets/).+'], methods: ['GET'])]
    public function moduleRoute(Request $request, string $moduleId, string $route): Response
    {
        if (!$this->hasValidToken($request)) {
            return new Response('Forbidden', Response::HTTP_FORBIDDEN);
        }

        try {
            $sourceId = $request->query->get('sourceId', '');
            if (is_string($sourceId) && '' !== $sourceId) {
                $request->attributes->set('sourceId', $sourceId);
            }

            $request->attributes->set('babelChromeFileTypes', implode(',', $this->fileTypeHandlerFileTypes()));

            return $this->moduleRouteDispatcher->dispatch($moduleId, $route, $request);
        } catch (ModuleDispatchException $exception) {
            return $this->errorResponse(
                'Unable to Run Module',
                'PHP module route failed',
                'The requested PHP module route could not be executed.',
                $exception->getMessage(),
                Response::HTTP_UNPROCESSABLE_ENTITY,
            );
        }
    }

    /**
     * Serves a public asset from an installed PHP module.
     *
     * @param Request $request  the current request
     * @param string  $moduleId the module identifier
     * @param string  $path     the public asset path
     *
     * @return Response the asset response
     */
    #[Route('/module/{moduleId}/assets/{path}', name: 'module_asset', requirements: ['path' => '.+'], methods: ['GET'], priority: 10)]
    public function moduleAsset(Request $request, string $moduleId, string $path): Response
    {
        if (!$this->hasValidToken($request)) {
            return new Response('Forbidden', Response::HTTP_FORBIDDEN);
        }

        $module = $this->moduleRegistry->find($moduleId);
        if (null === $module || !$module->enabled) {
            return new Response('Module not found', Response::HTTP_NOT_FOUND);
        }

        $assetPath = $this->resolvedModuleAssetPath($module, $path);
        if (null === $assetPath) {
            return new Response('Module asset not found', Response::HTTP_NOT_FOUND);
        }

        $content = file_get_contents($assetPath);
        if (false === $content) {
            return new Response('Module asset not found', Response::HTTP_NOT_FOUND);
        }

        return new Response($content, Response::HTTP_OK, [
            'Content-Type' => $this->moduleAssetMimeType($assetPath),
        ]);
    }

    /**
     * Returns registered PHP modules for the native shell.
     *
     * @param Request $request the current request
     *
     * @return JsonResponse the modules response
     */
    #[Route('/internal/modules', name: 'internal_modules', methods: ['GET'])]
    public function internalModules(Request $request): JsonResponse
    {
        if (!$this->hasValidToken($request)) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        return new JsonResponse([
            'modules' => $this->moduleRows(),
            'registeredAutoloaders' => $this->moduleAutoloadRegistrar->registerEnabledModuleAutoloaders(),
            'userModulesDirectory' => $this->moduleRegistry->userModulesDirectory(),
            'vendorIsolation' => 'per-module',
        ]);
    }

    /**
     * Returns file extensions advertised by enabled file type handler modules.
     *
     * @param Request $request the current request
     *
     * @return JsonResponse the file type response
     */
    #[Route('/internal/file-types', name: 'internal_file_types', methods: ['GET'])]
    public function internalFileTypes(Request $request): JsonResponse
    {
        if (!$this->hasValidToken($request)) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $fileTypes = $this->fileTypeHandlerFileTypes();

        return new JsonResponse([
            'fileTypes' => $fileTypes,
            'headerValue' => implode(',', $fileTypes),
        ]);
    }

    /**
     * Returns macOS applications that can open one file extension.
     *
     * @param Request $request   the current request
     * @param string  $extension the file extension
     *
     * @return JsonResponse the open-with list response
     */
    #[Route('/internal/open-with/list/{extension}', name: 'internal_open_with_list', methods: ['GET'])]
    public function internalOpenWithList(Request $request, string $extension): JsonResponse
    {
        if (!$this->hasValidToken($request)) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        return new JsonResponse($this->openWithService->applicationsForExtension($extension));
    }

    /**
     * Stores the shared BabelChrome open-with preference for one extension.
     *
     * @param Request $request   the current request
     * @param string  $extension the file extension
     *
     * @return JsonResponse the preference response
     */
    #[Route('/internal/open-with/set/{extension}', name: 'internal_open_with_set', methods: ['POST'])]
    public function internalOpenWithSet(Request $request, string $extension): JsonResponse
    {
        if (!$this->hasValidToken($request)) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $payload = $this->jsonPayload($request);
        $applicationId = $payload['applicationId'] ?? null;
        if (!is_string($applicationId) || '' === trim($applicationId)) {
            return new JsonResponse([
                'ok' => false,
                'error' => 'Missing application id.',
            ], Response::HTTP_BAD_REQUEST);
        }

        if (!$this->openWithService->setDefaultApplication($extension, $applicationId)) {
            return new JsonResponse([
                'ok' => false,
                'error' => 'Open With preference cannot be stored.',
            ], Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        return new JsonResponse(['ok' => true]);
    }

    /**
     * Opens a registered local source or explicit local file with a macOS application.
     *
     * @param Request $request the current request
     *
     * @return JsonResponse the open result
     */
    #[Route('/internal/open-with/open', name: 'internal_open_with_open', methods: ['POST'])]
    public function internalOpenWithOpen(Request $request): JsonResponse
    {
        if (!$this->hasValidToken($request)) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $payload = $this->jsonPayload($request);
        $filePath = $this->openWithFilePath($payload);
        if ('' === $filePath) {
            return new JsonResponse([
                'ok' => false,
                'error' => 'Missing local file.',
            ], Response::HTTP_BAD_REQUEST);
        }

        $applicationId = $payload['applicationId'] ?? null;
        $result = $this->openWithService->openFile($filePath, is_string($applicationId) ? $applicationId : null);
        if (!($result['ok'] ?? false)) {
            return new JsonResponse($result, Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        return new JsonResponse($result);
    }

    /**
     * Validates an opaque message envelope that modules can relay to compatible pages.
     *
     * @param Request $request the current request
     *
     * @return JsonResponse the relay acknowledgement
     */
    #[Route('/internal/message-relay', name: 'internal_message_relay', methods: ['POST'])]
    public function internalMessageRelay(Request $request): JsonResponse
    {
        if (!$this->hasValidToken($request)) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $payload = $this->jsonPayload($request);
        $supports = $payload['supports'] ?? null;
        $message = $payload['message'] ?? null;

        if (!is_string($supports) || '' === trim($supports) || !is_array($message)) {
            return new JsonResponse([
                'ok' => false,
                'error' => 'Invalid relay envelope.',
            ], Response::HTTP_BAD_REQUEST);
        }

        return new JsonResponse([
            'ok' => true,
            'relay' => [
                'supports' => trim($supports),
                'message' => $message,
            ],
        ]);
    }

    /**
     * Returns installed module rows.
     *
     * @return list<array<string, mixed>> the module rows
     */
    private function moduleRows(): array
    {
        $rows = [];
        foreach ($this->moduleRegistry->all() as $module) {
            $rows[] = $module->toArray();
        }

        return $rows;
    }

    /**
     * Returns unique file extensions advertised by enabled modules.
     *
     * @return list<string> the advertised file extensions
     */
    private function fileTypeHandlerFileTypes(): array
    {
        $fileTypes = [];
        foreach ($this->moduleRegistry->enabled() as $module) {
            foreach ($module->fileTypeHandlerFileTypes as $fileType) {
                if (!in_array($fileType, $fileTypes, true)) {
                    $fileTypes[] = $fileType;
                }
            }
        }

        return $fileTypes;
    }

    /**
     * Returns hooks exposed by enabled PHP modules.
     *
     * @param Request $request the current request
     *
     * @return JsonResponse the module hook response
     */
    #[Route('/internal/module-hooks', name: 'internal_module_hooks', methods: ['GET'])]
    public function internalModuleHooks(Request $request): JsonResponse
    {
        if (!$this->hasValidToken($request)) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $hook = $this->queryString($request, 'hook');
        if ('' !== $hook) {
            return new JsonResponse([
                'hook' => $hook,
                'modules' => $this->moduleHookRegistry->forHook($hook),
            ]);
        }

        return new JsonResponse([
            'hooks' => $this->moduleHookRegistry->all(),
        ]);
    }

    /**
     * Dispatches one application lifecycle hook to enabled PHP modules.
     *
     * @param Request $request the current request
     *
     * @return JsonResponse the lifecycle dispatch response
     */
    #[Route('/internal/module-lifecycle', name: 'internal_module_lifecycle', methods: ['GET'])]
    public function internalModuleLifecycle(Request $request): JsonResponse
    {
        if (!$this->hasValidToken($request)) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $hook = $this->queryString($request, 'hook');
        if ('' === $hook) {
            return new JsonResponse([
                'ok' => false,
                'error' => 'Missing hook.',
            ], Response::HTTP_BAD_REQUEST);
        }

        $results = [];
        foreach ($this->moduleHookRegistry->forHook($hook) as $module) {
            $moduleId = is_string($module['id'] ?? null) ? $module['id'] : '';
            if ('' === $moduleId) {
                continue;
            }

            $moduleRequest = $request->duplicate(array_merge($request->query->all(), [
                'hook' => $hook,
            ]));

            try {
                $response = $this->moduleRouteDispatcher->dispatch($moduleId, 'lifecycle', $moduleRequest);
                $result = [
                    'moduleId' => $moduleId,
                    'ok' => $response->isSuccessful(),
                    'statusCode' => $response->getStatusCode(),
                ];
                $content = $response->getContent();
                if (false !== $content && '' !== trim($content)) {
                    $payload = json_decode($content, true);
                    if (is_array($payload)) {
                        $result['payload'] = $payload;
                    }
                }

                $results[] = $result;
            } catch (ModuleDispatchException $exception) {
                $results[] = [
                    'moduleId' => $moduleId,
                    'ok' => false,
                    'error' => $exception->getMessage(),
                ];
            }
        }

        return new JsonResponse([
            'ok' => true,
            'hook' => $hook,
            'results' => $results,
        ]);
    }

    /**
     * Returns module-contributed menu items for one hook and optional contexts.
     *
     * @param Request $request the current request
     *
     * @return JsonResponse the module menu item response
     */
    #[Route('/internal/module-menu-items', name: 'internal_module_menu_items', methods: ['GET'])]
    public function internalModuleMenuItems(Request $request): JsonResponse
    {
        if (!$this->hasValidToken($request)) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $hook = $this->queryString($request, 'hook');
        if ('' === $hook) {
            return new JsonResponse([
                'ok' => false,
                'error' => 'Missing hook.',
            ], Response::HTTP_BAD_REQUEST);
        }

        $contexts = $this->queryStringList($request, 'context');

        return new JsonResponse([
            'hook' => $hook,
            'contexts' => $contexts,
            'items' => $this->moduleHookRegistry->menuItems($hook, $contexts),
        ]);
    }

    /**
     * Returns the health check response used by the native host.
     *
     * @return Response the health response
     */
    #[Route('/health', name: 'health', methods: ['GET'])]
    public function health(): Response
    {
        return new Response('ok', Response::HTTP_OK, ['Content-Type' => 'text/plain; charset=utf-8']);
    }

    /**
     * Dispatches the legacy Markdown URL to the Markdown viewer module.
     *
     * @param Request $request the current request
     *
     * @return Response the rendered document response
     */
    #[Route('/markdown', name: 'markdown', methods: ['GET'])]
    #[Route('/markdown/{sourceId}', name: 'markdown_source', methods: ['GET'])]
    public function markdown(Request $request): Response
    {
        if (!$this->hasValidToken($request)) {
            return new Response('Forbidden', Response::HTTP_FORBIDDEN);
        }

        return $this->dispatchViewerModule('babelforge.markdown-viewer', 'markdown', $request);
    }

    /**
     * Dispatches the legacy OpenAPI URL to the OpenAPI viewer module.
     *
     * @param Request $request the current request
     *
     * @return Response the rendered document response
     */
    #[Route('/openapi', name: 'openapi', methods: ['GET'])]
    #[Route('/openapi/{sourceId}', name: 'openapi_source', methods: ['GET'])]
    public function openApi(Request $request): Response
    {
        if (!$this->hasValidToken($request)) {
            return new Response('Forbidden', Response::HTTP_FORBIDDEN);
        }

        return $this->dispatchViewerModule('babelforge.openapi-viewer', 'openapi', $request);
    }

    /**
     * Dispatches a legacy viewer endpoint to its PHP module.
     *
     * @param string  $moduleId the module identifier
     * @param string  $route    the module route
     * @param Request $request  the current request
     *
     * @return Response the rendered viewer response
     */
    private function dispatchViewerModule(string $moduleId, string $route, Request $request): Response
    {
        try {
            return $this->moduleRouteDispatcher->dispatch($moduleId, $route, $request);
        } catch (ModuleDispatchException $exception) {
            return $this->errorResponse(
                'Unable to Run Viewer',
                'Viewer module failed',
                'The requested viewer module could not be executed.',
                $exception->getMessage(),
                Response::HTTP_UNPROCESSABLE_ENTITY,
            );
        }
    }

    /**
     * Returns source metadata used by local auto-refresh.
     *
     * @param Request $request  the current request
     * @param string  $sourceId the source identifier
     *
     * @return Response the source status response
     */
    #[Route('/source-status/{sourceId}', name: 'source_status', methods: ['GET'])]
    public function sourceStatus(Request $request, string $sourceId): Response
    {
        if (!$this->hasValidToken($request)) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $source = $this->sourceLoader->loadById($sourceId);
        if (null === $source) {
            return new JsonResponse(['error' => 'Source not found'], Response::HTTP_NOT_FOUND);
        }

        return new JsonResponse([
            'local' => $source->local,
            'lastModified' => $source->lastModified,
        ]);
    }

    /**
     * Serves a registered asset.
     *
     * @param Request $request  the current request
     * @param string  $sourceId the source identifier
     *
     * @return Response the asset response
     */
    #[Route('/asset/{sourceId}', name: 'asset_source', methods: ['GET'])]
    public function asset(Request $request, string $sourceId): Response
    {
        if (!$this->hasValidToken($request)) {
            return new Response('Forbidden', Response::HTTP_FORBIDDEN);
        }

        $source = $this->sourceLoader->loadById($sourceId);
        if (null === $source) {
            return new Response(
                $this->missingImageSvg($sourceId),
                Response::HTTP_NOT_FOUND,
                ['Content-Type' => 'image/svg+xml; charset=utf-8'],
            );
        }

        return new Response($source->content, Response::HTTP_OK, [
            'Content-Type' => $source->mimeType,
        ]);
    }

    /**
     * Returns an empty favicon response.
     *
     * @return Response the favicon response
     */
    #[Route('/favicon.ico', name: 'favicon', methods: ['GET'])]
    public function favicon(): Response
    {
        return new Response('', Response::HTTP_NO_CONTENT);
    }

    /**
     * Renders a viewer error page.
     *
     * @param string $title      the page title
     * @param string $heading    the visible heading
     * @param string $message    the visible message
     * @param string $detail     the technical detail
     * @param int    $statusCode the HTTP status code
     *
     * @return Response the rendered error response
     */
    private function errorResponse(
        string $title,
        string $heading,
        string $message,
        string $detail,
        int $statusCode,
    ): Response {
        return new Response(
            $this->twig->render('viewer/error.html.twig', [
                'title' => $title,
                'heading' => $heading,
                'message' => $message,
                'detail' => $detail,
                'stylesheetContent' => $this->viewerShellStyles(),
            ]),
            $statusCode,
            ['Content-Type' => 'text/html; charset=utf-8'],
        );
    }

    /**
     * Returns minimal styles for LocalServiceHost-owned pages.
     *
     * @return string the inline CSS
     */
    private function viewerShellStyles(): string
    {
        return <<<'CSS'
            :root {
              color-scheme: light;
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
              background: #f6f8fa;
              color: #1f2328;
            }
            body {
              margin: 0;
              background: #f6f8fa;
            }
            header {
              box-sizing: border-box;
              border-bottom: 1px solid #d0d7de;
              background: #ffffff;
              font-weight: 700;
              padding: 14px 24px;
            }
            main {
              box-sizing: border-box;
              padding: 28px;
            }
            .viewer-document {
              max-width: 920px;
              margin: 0 auto;
              background: #ffffff;
              border: 1px solid #d0d7de;
              border-radius: 8px;
              padding: 28px;
            }
            .viewer-error pre,
            .modules-path,
            code {
              background: #eef1f4;
              border-radius: 6px;
              padding: 2px 6px;
            }
            .modules-page {
              max-width: 1120px;
              margin: 0 auto;
            }
            .modules-list {
              display: grid;
              gap: 16px;
            }
            .module-card {
              background: #ffffff;
              border: 1px solid #d0d7de;
              border-radius: 8px;
              padding: 18px;
            }
            .module-card-header {
              display: flex;
              align-items: start;
              justify-content: space-between;
              gap: 16px;
            }
            .module-card h2 {
              margin: 0 0 4px;
            }
            .module-card p {
              margin: 6px 0;
            }
            .module-status,
            .module-tags span {
              border-radius: 999px;
              display: inline-flex;
              font-size: 12px;
              font-weight: 700;
              padding: 4px 8px;
            }
            .module-status-enabled {
              background: #dafbe1;
              color: #116329;
            }
            .module-status-disabled {
              background: #ffebe9;
              color: #82071e;
            }
            .module-tags,
            .module-hooks {
              display: flex;
              flex-wrap: wrap;
              gap: 6px;
              margin-top: 10px;
            }
            .module-tags span {
              background: #ddf4ff;
              color: #0969da;
            }
            dl {
              display: grid;
              gap: 8px;
              grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
            }
            dt {
              color: #57606a;
              font-size: 12px;
              font-weight: 700;
              text-transform: uppercase;
            }
            dd {
              margin: 0;
            }
            CSS;
    }

    /**
     * Resolves a module asset path and ensures it stays inside the module public directory.
     *
     * @param ModuleManifest $module the module manifest
     * @param string         $path   the requested asset path
     *
     * @return string|null the resolved asset path when readable
     */
    private function resolvedModuleAssetPath(ModuleManifest $module, string $path): ?string
    {
        $publicDirectory = realpath($module->path.'/public');
        if (false === $publicDirectory) {
            return null;
        }

        $assetPath = realpath($publicDirectory.'/'.ltrim($path, '/'));
        if (false === $assetPath || !is_file($assetPath) || !is_readable($assetPath)) {
            return null;
        }

        $normalizedPublicDirectory = rtrim($publicDirectory, DIRECTORY_SEPARATOR).DIRECTORY_SEPARATOR;
        if (!str_starts_with($assetPath, $normalizedPublicDirectory)) {
            return null;
        }

        return $assetPath;
    }

    /**
     * Returns a stable web MIME type for a module asset.
     *
     * @param string $assetPath the resolved asset path
     *
     * @return string the MIME type
     */
    private function moduleAssetMimeType(string $assetPath): string
    {
        $extension = strtolower(pathinfo($assetPath, PATHINFO_EXTENSION));
        $mimeTypes = [
            'css' => 'text/css; charset=utf-8',
            'gif' => 'image/gif',
            'html' => 'text/html; charset=utf-8',
            'ico' => 'image/x-icon',
            'jpeg' => 'image/jpeg',
            'jpg' => 'image/jpeg',
            'js' => 'text/javascript; charset=utf-8',
            'json' => 'application/json; charset=utf-8',
            'map' => 'application/json; charset=utf-8',
            'png' => 'image/png',
            'svg' => 'image/svg+xml; charset=utf-8',
            'txt' => 'text/plain; charset=utf-8',
            'webp' => 'image/webp',
        ];

        if (isset($mimeTypes[$extension])) {
            return $mimeTypes[$extension];
        }

        $mimeType = mime_content_type($assetPath);

        return false === $mimeType ? 'application/octet-stream' : $mimeType;
    }

    /**
     * Updates the enabled state of a user module.
     *
     * @param Request $request the current request
     * @param bool    $enabled whether the module should be enabled
     *
     * @return JsonResponse the update response
     */
    private function setModuleEnabled(Request $request, bool $enabled): JsonResponse
    {
        if (!$this->hasValidToken($request)) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $moduleId = $this->queryString($request, 'moduleId');
        if ('' === $moduleId) {
            return new JsonResponse(['ok' => false, 'error' => 'Missing module id.'], Response::HTTP_BAD_REQUEST);
        }

        try {
            $module = $this->moduleInstaller->setEnabled($moduleId, $enabled);

            return new JsonResponse([
                'ok' => true,
                'module' => $module->toArray(),
            ]);
        } catch (ModuleInstallationException $exception) {
            return new JsonResponse([
                'ok' => false,
                'error' => $exception->getMessage(),
            ], Response::HTTP_UNPROCESSABLE_ENTITY);
        }
    }

    /**
     * Reads a string query parameter.
     *
     * @param Request $request the current request
     * @param string  $name    the query parameter name
     *
     * @return string the query value
     */
    private function queryString(Request $request, string $name): string
    {
        $value = $request->query->get($name, '');

        return is_string($value) ? $value : '';
    }

    /**
     * Reads a comma-separated string query parameter.
     *
     * @param Request $request the current request
     * @param string  $name    the query parameter name
     *
     * @return list<string> the query values
     */
    private function queryStringList(Request $request, string $name): array
    {
        $value = $this->queryString($request, $name);
        if ('' === $value) {
            return [];
        }

        $items = [];
        foreach (explode(',', $value) as $item) {
            $trimmedItem = trim($item);
            if ('' !== $trimmedItem) {
                $items[] = $trimmedItem;
            }
        }

        return $items;
    }

    /**
     * Reads a JSON object payload from the request body.
     *
     * @param Request $request the current request
     *
     * @return array<string, mixed> the decoded payload
     */
    private function jsonPayload(Request $request): array
    {
        $content = $request->getContent();
        if ('' === $content) {
            return [];
        }

        $payload = json_decode($content, true);

        if (!is_array($payload)) {
            return [];
        }

        $normalizedPayload = [];
        foreach ($payload as $key => $value) {
            if (is_string($key)) {
                $normalizedPayload[$key] = $value;
            }
        }

        return $normalizedPayload;
    }

    /**
     * Resolves the local file path requested by an open-with payload.
     *
     * @param array<string, mixed> $payload the request payload
     *
     * @return string the local file path or an empty string
     */
    private function openWithFilePath(array $payload): string
    {
        $sourceId = $payload['sourceId'] ?? null;
        if (is_string($sourceId) && '' !== $sourceId) {
            $source = $this->sourceRegistry->find($sourceId);
            if (null !== $source && 'file' === $source['type']) {
                return $source['value'];
            }
        }

        $file = $payload['file'] ?? null;
        if (is_string($file) && '' !== $file) {
            return $file;
        }

        return '';
    }

    /**
     * Returns an SVG placeholder for an image that cannot be loaded.
     *
     * @param string $sourceId the source identifier
     *
     * @return string the SVG image
     */
    private function missingImageSvg(string $sourceId): string
    {
        $escapedSourceId = htmlspecialchars($sourceId, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');

        return <<<SVG
            <svg xmlns="http://www.w3.org/2000/svg" width="720" height="160" viewBox="0 0 720 160" role="img" aria-label="Missing image">
              <rect width="720" height="160" rx="10" fill="#fff5f5" stroke="#e7b5b5"/>
              <text x="24" y="58" fill="#8a1f1f" font-family="-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif" font-size="20" font-weight="700">Missing image</text>
              <text x="24" y="94" fill="#8a1f1f" font-family="-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif" font-size="14">The linked image could not be loaded.</text>
              <text x="24" y="124" fill="#8a1f1f" font-family="ui-monospace, SFMono-Regular, Menlo, Consolas, monospace" font-size="12">{$escapedSourceId}</text>
            </svg>
            SVG;
    }

    /**
     * Checks the per-process token.
     *
     * @param Request $request the current request
     *
     * @return bool true when the token is valid
     */
    private function hasValidToken(Request $request): bool
    {
        $expectedToken = $this->environmentString('BABELCHROME_VIEWER_TOKEN', '');
        $tokenValue = $request->query->get('token', '');
        $token = is_string($tokenValue) ? $tokenValue : '';

        return '' !== $expectedToken && hash_equals($expectedToken, $token);
    }

    /**
     * Reads a string environment value.
     *
     * @param string $name    the environment variable name
     * @param string $default the default value
     *
     * @return string the resolved environment value
     */
    private function environmentString(string $name, string $default): string
    {
        $serverValue = $_SERVER[$name] ?? null;
        if (is_string($serverValue)) {
            return $serverValue;
        }

        $envValue = $_ENV[$name] ?? null;
        if (is_string($envValue)) {
            return $envValue;
        }

        $processValue = getenv($name);
        if (is_string($processValue)) {
            return $processValue;
        }

        return $default;
    }
}
