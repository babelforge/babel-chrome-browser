<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Tests\Controller;

use BabelForge\BabelChrome\LocalViewer\Controller\ViewerController;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleAutoloadRegistrar;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleCommandRunner;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleHookRegistry;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleInstaller;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleReadinessChecker;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRegistry;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRouteDispatcher;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleSetupRunner;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleUrlResolver;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleWebRuntime;
use BabelForge\BabelChrome\LocalViewer\Module\Runtime\ModuleProcessWebRuntime;
use BabelForge\BabelChrome\LocalViewer\Module\Runtime\ModuleRuntimeDispatcher;
use BabelForge\BabelChrome\LocalViewer\Module\Runtime\PhpClassRuntimeHandler;
use BabelForge\BabelChrome\LocalViewer\Module\Runtime\PhpWebRuntimeHandler;
use BabelForge\BabelChrome\LocalViewer\Module\Runtime\ProcessWebRuntimeHandler;
use BabelForge\BabelChrome\LocalViewer\Module\Runtime\StaticWebRuntimeHandler;
use BabelForge\BabelChrome\LocalViewer\Service\OpenWithService;
use BabelForge\BabelChrome\LocalViewer\Service\SourceLoader;
use BabelForge\BabelChrome\LocalViewer\Service\SourceRegistry;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\TestCase;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Twig\Environment;
use Twig\Loader\FilesystemLoader;

/**
 * Verifies local viewer controller user-facing Markdown errors.
 */
#[CoversClass(ViewerController::class)]
final class ViewerControllerTest extends TestCase
{
    private string $stateDirectory;

    /**
     * Creates an isolated controller state directory.
     */
    protected function setUp(): void
    {
        parent::setUp();

        $this->stateDirectory = sys_get_temp_dir().'/babelchrome-viewer-controller-test-'.bin2hex(random_bytes(6));
        if (!mkdir($this->stateDirectory, 0o775, true) && !is_dir($this->stateDirectory)) {
            self::fail('Unable to create test state directory.');
        }

        $this->linkViewerModule('markdown-viewer-module');
        $this->linkViewerModule('openapi-viewer-module');

        putenv('BABELCHROME_VIEWER_STATE_DIR='.$this->stateDirectory);
        putenv('BABELCHROME_VIEWER_TOKEN=test-token');
    }

    /**
     * Clears the isolated controller state.
     */
    protected function tearDown(): void
    {
        putenv('BABELCHROME_VIEWER_STATE_DIR');
        putenv('BABELCHROME_VIEWER_TOKEN');

        parent::tearDown();
    }

    /**
     * Ensures missing Markdown sources return a rendered error page.
     */
    public function testMissingMarkdownSourceReturnsRenderedErrorPage(): void
    {
        $response = $this->controller()->markdown(Request::create('/markdown', 'GET', [
            'token' => 'test-token',
            'file' => $this->stateDirectory.'/missing.md',
        ]));

        $content = $this->responseContent($response);

        self::assertSame(Response::HTTP_NOT_FOUND, $response->getStatusCode());
        self::assertStringContainsString('Unable to Load Markdown', $content);
        self::assertStringContainsString('Markdown source not found', $content);
        self::assertStringContainsString($this->stateDirectory.'/missing.md', $content);
    }

    /**
     * Ensures invalid OpenAPI sources return a rendered error page.
     */
    public function testInvalidOpenApiSourceReturnsRenderedErrorPage(): void
    {
        $sourcePath = $this->stateDirectory.'/openapi.yaml';
        file_put_contents($sourcePath, ':::');

        $response = $this->controller()->openApi(Request::create('/openapi', 'GET', [
            'token' => 'test-token',
            'file' => $sourcePath,
        ]));

        $content = $this->responseContent($response);

        self::assertSame(Response::HTTP_UNPROCESSABLE_ENTITY, $response->getStatusCode());
        self::assertStringContainsString('Unable to Render OpenAPI', $content);
        self::assertStringContainsString('OpenAPI document is invalid', $content);
        self::assertStringContainsString('openapi/swagger', $content);
    }

    /**
     * Ensures valid JSON sources are dispatched to the JSON viewer module.
     */
    public function testModuleRouteCanDispatchToJsonViewerModule(): void
    {
        $this->writeJsonViewerModule();
        $sourcePath = $this->stateDirectory.'/document.json';
        file_put_contents($sourcePath, '{"name":"BabelChrome"}');

        $response = $this->controller()->moduleRoute(Request::create('/module/babelforge.json-viewer/json', 'GET', [
            'token' => 'test-token',
            'file' => $sourcePath,
        ]), 'babelforge.json-viewer', 'json');

        $content = $this->responseContent($response);

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertStringContainsString('JSON viewer module route reached.', $content);
    }

    /**
     * Ensures the internal module endpoint returns registered modules.
     */
    public function testInternalModulesReturnsRegisteredModules(): void
    {
        $response = $this->controller()->internalModules(Request::create('/internal/modules', 'GET', [
            'token' => 'test-token',
        ]));

        $content = $this->responseContent($response);
        $decoded = json_decode($content, true);

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertSame('per-module', $decoded['vendorIsolation'] ?? null);
        self::assertArrayHasKey('modules', $decoded);

        $modules = $decoded['modules'];
        self::assertIsArray($modules);
        self::assertContains('babelforge.markdown-viewer', array_column($modules, 'id'));
        self::assertContains('babelforge.openapi-viewer', array_column($modules, 'id'));

        $firstModule = $modules[0] ?? null;
        self::assertIsArray($firstModule);
        self::assertIsArray($firstModule['readinessStatus'] ?? null);
    }

    /**
     * Ensures the internal file type endpoint returns enabled module handler extensions.
     */
    public function testInternalFileTypesReturnsHeaderValue(): void
    {
        $response = $this->controller()->internalFileTypes(Request::create('/internal/file-types', 'GET', [
            'token' => 'test-token',
        ]));

        $decoded = json_decode($this->responseContent($response), true);

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertSame(['md', 'markdown', 'mmd', 'mermaid', 'yaml', 'yml', 'json'], $decoded['fileTypes'] ?? null);
        self::assertSame('md,markdown,mmd,mermaid,yaml,yml,json', $decoded['headerValue'] ?? null);
    }

    /**
     * Ensures internal module setup runs the declared setup command.
     */
    public function testInternalModulesSetupRunsDeclaredSetup(): void
    {
        $this->writeSetupModule();

        $response = $this->controller()->internalModulesSetup(Request::create('/internal/modules/setup', 'GET', [
            'token' => 'test-token',
            'moduleId' => 'vendor.setup-module',
        ]));

        $decoded = json_decode($this->responseContent($response), true);

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertTrue($decoded['ok'] ?? false);
        self::assertSame('vendor.setup-module', $decoded['moduleId'] ?? null);

        $setup = $decoded['setup'] ?? null;
        $readinessStatus = $decoded['readinessStatus'] ?? null;
        self::assertIsArray($setup);
        self::assertIsArray($readinessStatus);
        self::assertSame('completed', $setup['state'] ?? null);
        self::assertTrue($setup['ok'] ?? false);

        $stdout = $setup['stdout'] ?? null;
        self::assertIsString($stdout);
        self::assertStringContainsString('setup-output', $stdout);
        self::assertSame('ready', $readinessStatus['state'] ?? null);
    }

    /**
     * Ensures the internal open-with list endpoint returns a valid payload.
     */
    public function testInternalOpenWithListRequiresToken(): void
    {
        $response = $this->controller()->internalOpenWithList(Request::create('/internal/open-with/list/md', 'GET'), 'md');

        $decoded = json_decode($this->responseContent($response), true);

        self::assertSame(Response::HTTP_FORBIDDEN, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertSame('Forbidden', $decoded['error'] ?? null);
    }

    /**
     * Ensures open-with rejects non-local sources.
     */
    public function testInternalOpenWithOpenRejectsRemoteSource(): void
    {
        $registry = new SourceRegistry();
        $sourceId = $registry->register('url', 'https://example.com/schema.json');
        $request = Request::create('/internal/open-with/open?token=test-token', 'POST', [], [], [], [], json_encode(['sourceId' => $sourceId], JSON_THROW_ON_ERROR));

        $response = $this->controller()->internalOpenWithOpen($request);
        $decoded = json_decode($this->responseContent($response), true);

        self::assertSame(Response::HTTP_BAD_REQUEST, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertFalse($decoded['ok'] ?? true);
        self::assertSame('Missing local file.', $decoded['error'] ?? null);
    }

    /**
     * Ensures the internal message relay endpoint requires a valid token.
     */
    public function testInternalMessageRelayRequiresToken(): void
    {
        $request = Request::create('/internal/message-relay', 'POST', [], [], [], [], json_encode([
            'supports' => 'file-viewer',
            'message' => ['event' => 'viewer-changed'],
        ], JSON_THROW_ON_ERROR));

        $response = $this->controller()->internalMessageRelay($request);
        $decoded = json_decode($this->responseContent($response), true);

        self::assertSame(Response::HTTP_FORBIDDEN, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertSame('Forbidden', $decoded['error'] ?? null);
    }

    /**
     * Ensures the internal message relay endpoint rejects malformed envelopes.
     */
    public function testInternalMessageRelayRejectsMalformedEnvelope(): void
    {
        $request = Request::create('/internal/message-relay?token=test-token', 'POST', [], [], [], [], json_encode([
            'supports' => '',
            'message' => 'viewer-changed',
        ], JSON_THROW_ON_ERROR));

        $response = $this->controller()->internalMessageRelay($request);
        $decoded = json_decode($this->responseContent($response), true);

        self::assertSame(Response::HTTP_BAD_REQUEST, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertFalse($decoded['ok'] ?? true);
        self::assertSame('Invalid relay envelope.', $decoded['error'] ?? null);
    }

    /**
     * Ensures the internal message relay endpoint accepts opaque module messages.
     */
    public function testInternalMessageRelayAcceptsOpaqueMessage(): void
    {
        $request = Request::create('/internal/message-relay?token=test-token', 'POST', [], [], [], [], json_encode([
            'supports' => 'file-viewer',
            'message' => [
                'event' => 'viewer-changed',
                'extension' => 'md',
                'applicationId' => 'com.microsoft.VSCode',
            ],
        ], JSON_THROW_ON_ERROR));

        $response = $this->controller()->internalMessageRelay($request);
        $decoded = json_decode($this->responseContent($response), true);

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertTrue($decoded['ok'] ?? false);
        self::assertIsArray($decoded['relay'] ?? null);
        self::assertIsArray($decoded['relay']['message'] ?? null);
        self::assertSame('file-viewer', $decoded['relay']['supports'] ?? null);
        self::assertSame('viewer-changed', $decoded['relay']['message']['event'] ?? null);
        self::assertSame('md', $decoded['relay']['message']['extension'] ?? null);
        self::assertSame('com.microsoft.VSCode', $decoded['relay']['message']['applicationId'] ?? null);
    }

    /**
     * Ensures the internal module hook endpoint groups enabled modules by hook.
     */
    public function testInternalModuleHooksReturnsEnabledModuleHooks(): void
    {
        $response = $this->controller()->internalModuleHooks(Request::create('/internal/module-hooks', 'GET', [
            'token' => 'test-token',
        ]));

        $decoded = json_decode($this->responseContent($response), true);

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertIsArray($decoded['hooks'] ?? null);
        self::assertIsArray($decoded['hooks']['address.badge.resolve'] ?? null);
        self::assertContains('babelforge.markdown-viewer', array_column($decoded['hooks']['address.badge.resolve'], 'id'));
        self::assertContains('babelforge.openapi-viewer', array_column($decoded['hooks']['address.badge.resolve'], 'id'));
        self::assertIsArray($decoded['hooks']['context-menu.build'] ?? null);
        $contextMenuModules = $decoded['hooks']['context-menu.build'];
        self::assertIsArray($contextMenuModules[0] ?? null);
        self::assertIsArray($contextMenuModules[0]['menuItems'] ?? null);
    }

    /**
     * Ensures the internal module hook endpoint can filter one hook.
     */
    public function testInternalModuleHooksCanFilterOneHook(): void
    {
        $response = $this->controller()->internalModuleHooks(Request::create('/internal/module-hooks', 'GET', [
            'token' => 'test-token',
            'hook' => 'settings.section.register',
        ]));

        $decoded = json_decode($this->responseContent($response), true);

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertSame('settings.section.register', $decoded['hook'] ?? null);
        self::assertIsArray($decoded['modules'] ?? null);
        self::assertContains('babelforge.markdown-viewer', array_column($decoded['modules'], 'id'));
        self::assertNotContains('babelforge.openapi-viewer', array_column($decoded['modules'], 'id'));
    }

    /**
     * Ensures the internal module hook endpoint includes menu contributions for one hook.
     */
    public function testInternalModuleHooksIncludesMenuContributions(): void
    {
        $response = $this->controller()->internalModuleHooks(Request::create('/internal/module-hooks', 'GET', [
            'token' => 'test-token',
            'hook' => 'context-menu.build',
        ]));

        $decoded = json_decode($this->responseContent($response), true);

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertIsArray($decoded['modules'] ?? null);

        $markdownModules = array_values(array_filter(
            $decoded['modules'],
            static fn (mixed $module): bool => is_array($module) && 'babelforge.markdown-viewer' === ($module['id'] ?? null),
        ));

        self::assertNotEmpty($markdownModules);
        self::assertIsArray($markdownModules[0]['menuItems'] ?? null);
        self::assertContains('markdown.open-source-file', array_column($markdownModules[0]['menuItems'], 'id'));
    }

    /**
     * Ensures the internal module menu endpoint returns matching menu items.
     */
    public function testInternalModuleMenuItemsReturnsMatchingItems(): void
    {
        $response = $this->controller()->internalModuleMenuItems(Request::create('/internal/module-menu-items', 'GET', [
            'token' => 'test-token',
            'hook' => 'context-menu.build',
            'context' => 'markdown.local-file',
        ]));

        $decoded = json_decode($this->responseContent($response), true);

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertSame('context-menu.build', $decoded['hook'] ?? null);
        self::assertSame(['markdown.local-file'], $decoded['contexts'] ?? null);
        self::assertIsArray($decoded['items'] ?? null);

        $itemIds = [];
        foreach ($decoded['items'] as $item) {
            if (is_array($item) && is_array($item['item'] ?? null) && is_string($item['item']['id'] ?? null)) {
                $itemIds[] = $item['item']['id'];
            }
        }

        self::assertContains('markdown.open-source-file', $itemIds);
        self::assertContains('markdown.reveal-in-finder', $itemIds);
        self::assertNotContains('openapi.open-source-file', $itemIds);
    }

    /**
     * Ensures the internal module menu endpoint accepts multiple contexts.
     */
    public function testInternalModuleMenuItemsAcceptsMultipleContexts(): void
    {
        $response = $this->controller()->internalModuleMenuItems(Request::create('/internal/module-menu-items', 'GET', [
            'token' => 'test-token',
            'hook' => 'context-menu.build',
            'context' => 'markdown.local-file,openapi.local-file',
        ]));

        $decoded = json_decode($this->responseContent($response), true);

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertSame(['markdown.local-file', 'openapi.local-file'], $decoded['contexts'] ?? null);
        self::assertIsArray($decoded['items'] ?? null);

        $itemIds = [];
        foreach ($decoded['items'] as $item) {
            if (is_array($item) && is_array($item['item'] ?? null) && is_string($item['item']['id'] ?? null)) {
                $itemIds[] = $item['item']['id'];
            }
        }

        self::assertContains('markdown.open-source-file', $itemIds);
        self::assertContains('openapi.open-source-file', $itemIds);
    }

    /**
     * Ensures the internal module menu endpoint requires a hook.
     */
    public function testInternalModuleMenuItemsRequiresHook(): void
    {
        $response = $this->controller()->internalModuleMenuItems(Request::create('/internal/module-menu-items', 'GET', [
            'token' => 'test-token',
        ]));

        $decoded = json_decode($this->responseContent($response), true);

        self::assertSame(Response::HTTP_BAD_REQUEST, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertFalse($decoded['ok'] ?? true);
        self::assertSame('Missing hook.', $decoded['error'] ?? null);
    }

    /**
     * Ensures the modules page renders registered user modules.
     */
    public function testModulesPageRendersRegisteredModules(): void
    {
        $response = $this->controller()->modules(Request::create('/modules', 'GET', [
            'token' => 'test-token',
        ]));

        $content = $this->responseContent($response);

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertStringContainsString('PHP Modules', $content);
        self::assertStringContainsString('Markdown Viewer', $content);
        self::assertStringContainsString('OpenAPI Viewer', $content);
        self::assertStringContainsString('own Composer vendor directory', $content);
    }

    /**
     * Ensures the internal address badge endpoint resolves module badges.
     */
    public function testInternalAddressBadgeReturnsModuleBadge(): void
    {
        $response = $this->controller()->internalAddressBadge(Request::create('/internal/address-badge', 'GET', [
            'token' => 'test-token',
            'url' => 'babelchrome://openapi/file/%2Ftmp%2Fopenapi.yaml',
        ]));

        $content = $this->responseContent($response);
        $decoded = json_decode($content, true);

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertTrue($decoded['handled'] ?? false);
        self::assertSame('babelforge.openapi-viewer', $decoded['moduleId'] ?? null);
        self::assertIsArray($decoded['badge'] ?? null);
        self::assertSame('API', $decoded['badge']['text'] ?? null);
    }

    /**
     * Ensures generic viewer URLs return the resolved viewer module badge.
     */
    public function testInternalAddressBadgeResolvesGenericViewerModuleBadge(): void
    {
        $this->writeJsonViewerModule();

        $response = $this->controller()->internalAddressBadge(Request::create('/internal/address-badge', 'GET', [
            'token' => 'test-token',
            'url' => 'babelchrome://viewer/file/%2Ftmp%2Fdocument.json',
        ]));

        $content = $this->responseContent($response);
        $decoded = json_decode($content, true);

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertTrue($decoded['handled'] ?? false);
        self::assertSame('babelforge.json-viewer', $decoded['moduleId'] ?? null);
        self::assertIsArray($decoded['badge'] ?? null);
        self::assertSame('JSON', $decoded['badge']['text'] ?? null);
        self::assertSame('#8250df', $decoded['badge']['backgroundColor'] ?? null);
    }

    /**
     * Ensures the internal viewer route endpoint resolves source URLs through module manifests.
     */
    public function testInternalViewerRouteResolvesSourceUrlsThroughModuleManifest(): void
    {
        $response = $this->controller()->internalViewerRoute(Request::create('/internal/viewer-route', 'GET', [
            'token' => 'test-token',
            'url' => 'file:///tmp/README.md',
        ]));

        $decoded = json_decode($this->responseContent($response), true);

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertTrue($decoded['handled'] ?? false);
        self::assertSame('babelforge.markdown-viewer', $decoded['moduleId'] ?? null);
        self::assertSame('markdown', $decoded['viewerKind'] ?? null);
        self::assertSame('/module/babelforge.markdown-viewer/markdown', $decoded['route'] ?? null);
    }

    /**
     * Ensures newly installed viewer types resolve through the generic module route.
     */
    public function testInternalViewerRouteResolvesJsonThroughGenericModuleRoute(): void
    {
        $this->writeJsonViewerModule();

        $response = $this->controller()->internalViewerRoute(Request::create('/internal/viewer-route', 'GET', [
            'token' => 'test-token',
            'url' => 'file:///tmp/document.json',
        ]));

        $decoded = json_decode($this->responseContent($response), true);

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertIsArray($decoded);
        self::assertTrue($decoded['handled'] ?? false);
        self::assertSame('babelforge.json-viewer', $decoded['moduleId'] ?? null);
        self::assertSame('json', $decoded['viewerKind'] ?? null);
        self::assertSame('/module/babelforge.json-viewer/json', $decoded['route'] ?? null);
    }

    /**
     * Ensures OpenAPI filename constraints are read from the module manifest.
     */
    public function testInternalViewerRouteHonorsModuleFilenameConstraints(): void
    {
        $openApiResponse = $this->controller()->internalViewerRoute(Request::create('/internal/viewer-route', 'GET', [
            'token' => 'test-token',
            'url' => 'file:///tmp/openapi.yaml',
        ]));
        $plainYamlResponse = $this->controller()->internalViewerRoute(Request::create('/internal/viewer-route', 'GET', [
            'token' => 'test-token',
            'url' => 'file:///tmp/config.yaml',
        ]));

        $openApiDecoded = json_decode($this->responseContent($openApiResponse), true);
        $plainYamlDecoded = json_decode($this->responseContent($plainYamlResponse), true);

        self::assertIsArray($openApiDecoded);
        self::assertIsArray($plainYamlDecoded);
        self::assertTrue($openApiDecoded['handled'] ?? false);
        self::assertSame('babelforge.openapi-viewer', $openApiDecoded['moduleId'] ?? null);
        self::assertFalse($plainYamlDecoded['handled'] ?? true);
    }

    /**
     * Ensures public module assets are served from the module public directory.
     */
    public function testModuleAssetReturnsPublicAsset(): void
    {
        $this->writeAssetModule();

        $response = $this->controller()->moduleAsset(Request::create('/module/vendor.asset-module/assets/styles/app.css', 'GET', [
            'token' => 'test-token',
        ]), 'vendor.asset-module', 'styles/app.css');

        $content = $this->responseContent($response);

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertStringContainsString('text/css', (string) $response->headers->get('Content-Type'));
        self::assertStringContainsString('.asset-module', $content);
    }

    /**
     * Ensures module assets cannot escape the module public directory.
     */
    public function testModuleAssetRejectsTraversal(): void
    {
        $this->writeAssetModule();

        $response = $this->controller()->moduleAsset(Request::create('/module/vendor.asset-module/assets/../manifest.json', 'GET', [
            'token' => 'test-token',
        ]), 'vendor.asset-module', '../manifest.json');

        self::assertSame(Response::HTTP_NOT_FOUND, $response->getStatusCode());
    }

    /**
     * Ensures missing image assets return an SVG placeholder.
     */
    public function testMissingAssetReturnsSvgPlaceholder(): void
    {
        $response = $this->controller()->asset(Request::create('/asset/missing', 'GET', [
            'token' => 'test-token',
        ]), 'missing-image');

        $content = $this->responseContent($response);

        self::assertSame(Response::HTTP_NOT_FOUND, $response->getStatusCode());
        self::assertSame('image/svg+xml; charset=utf-8', $response->headers->get('Content-Type'));
        self::assertStringContainsString('Missing image', $content);
        self::assertStringContainsString('missing-image', $content);
    }

    /**
     * Creates the controller under test.
     *
     * @return ViewerController the controller
     */
    private function controller(): ViewerController
    {
        $registry = new SourceRegistry();

        return new ViewerController(
            new SourceLoader($registry),
            $registry,
            $moduleRegistry = new ModuleRegistry(null, $this->stateDirectory.'/Modules'),
            new ModuleHookRegistry($moduleRegistry),
            new ModuleInstaller($moduleRegistry),
            $moduleAutoloadRegistrar = new ModuleAutoloadRegistrar($moduleRegistry),
            new ModuleReadinessChecker($moduleCommandRunner = new ModuleCommandRunner()),
            new ModuleSetupRunner($moduleCommandRunner),
            new ModuleRouteDispatcher(
                $moduleRegistry,
                new ModuleRuntimeDispatcher(
                    new ProcessWebRuntimeHandler(new ModuleProcessWebRuntime()),
                    new PhpWebRuntimeHandler(new ModuleWebRuntime()),
                    new StaticWebRuntimeHandler(),
                    new PhpClassRuntimeHandler($moduleAutoloadRegistrar),
                ),
            ),
            new ModuleUrlResolver($moduleRegistry),
            new ModuleProcessWebRuntime(),
            new OpenWithService(),
            new Environment(new FilesystemLoader(dirname(__DIR__, 2).'/templates')),
        );
    }

    /**
     * Links an installable viewer module into the isolated module directory.
     *
     * @param string $moduleDirectoryName the source module directory name
     */
    private function linkViewerModule(string $moduleDirectoryName): void
    {
        $sourceDirectory = dirname(__DIR__, 5).'/modules/'.$moduleDirectoryName;
        $manifestPath = $sourceDirectory.'/manifest.json';
        $manifest = json_decode((string) file_get_contents($manifestPath), true);
        if (!is_array($manifest) || !isset($manifest['id']) || !is_string($manifest['id'])) {
            self::fail(sprintf('Unable to read module manifest "%s".', $manifestPath));
        }

        $modulesDirectory = $this->stateDirectory.'/Modules';
        if (!is_dir($modulesDirectory) && !mkdir($modulesDirectory, 0o775, true) && !is_dir($modulesDirectory)) {
            self::fail('Unable to create test modules directory.');
        }

        if (!symlink($sourceDirectory, $modulesDirectory.'/'.$manifest['id'])) {
            self::fail(sprintf('Unable to link test module "%s".', $moduleDirectoryName));
        }
    }

    /**
     * Writes a module containing a public CSS asset.
     */
    private function writeAssetModule(): void
    {
        $moduleDirectory = $this->stateDirectory.'/Modules/vendor.asset-module';
        if (!mkdir($moduleDirectory.'/public/styles', 0o775, true) && !is_dir($moduleDirectory.'/public/styles')) {
            self::fail('Unable to create asset module directory.');
        }

        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'vendor.asset-module',
            'name' => 'Asset Module',
            'version' => '1.0.0',
            'requirements' => [
                'php' => '>=8.4',
            ],
            'enabled' => true,
            'entrypoint' => 'Vendor\\AssetModule\\Module',
            'routes' => [],
        ], JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT));
        file_put_contents($moduleDirectory.'/public/styles/app.css', '.asset-module { color: #0969da; }');
    }

    /**
     * Writes a minimal JSON viewer module used to verify the legacy route dispatch.
     */
    private function writeJsonViewerModule(): void
    {
        $moduleDirectory = $this->stateDirectory.'/Modules/babelforge.json-viewer';
        if (!mkdir($moduleDirectory.'/public', 0o775, true) && !is_dir($moduleDirectory.'/public')) {
            self::fail('Unable to create JSON viewer module directory.');
        }

        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'babelforge.json-viewer',
            'name' => 'JSON Viewer',
            'version' => '1.0.0',
            'type' => 'viewer',
            'requirements' => [
                'php' => '>=8.4',
            ],
            'enabled' => true,
            'runtime' => [
                'type' => 'web',
                'entrypoint' => 'public/index.php',
            ],
            'entrypoint' => 'public/index.php',
            'routes' => [
                [
                    'scheme' => 'babelchrome',
                    'host' => 'json',
                    'handler' => 'json',
                ],
            ],
            'fileTypes' => [
                'json',
            ],
            'badge' => [
                'text' => 'JSON',
                'textColor' => '#ffffff',
                'backgroundColor' => '#8250df',
            ],
        ], JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT));
        file_put_contents($moduleDirectory.'/public/index.php', <<<'PHP'
            <?php

            declare(strict_types=1);

            use Symfony\Component\HttpFoundation\Response;

            return new Response('JSON viewer module route reached.');
            PHP);
    }

    /**
     * Writes a setup-enabled module.
     */
    private function writeSetupModule(): void
    {
        $moduleDirectory = $this->stateDirectory.'/Modules/vendor.setup-module';
        if (!mkdir($moduleDirectory, 0o775, true) && !is_dir($moduleDirectory)) {
            self::fail('Unable to create setup module directory.');
        }

        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'vendor.setup-module',
            'name' => 'Setup Module',
            'version' => '1.0.0',
            'requirements' => [
                'php' => '>=8.4',
            ],
            'enabled' => true,
            'readiness' => [
                'type' => 'command',
                'command' => escapeshellarg(PHP_BINARY).' -r '.escapeshellarg('echo json_encode(["ready" => true, "status" => "ready"]);'),
            ],
            'setup' => [
                'type' => 'command',
                'command' => escapeshellarg(PHP_BINARY).' -r '.escapeshellarg('echo "setup-output";'),
            ],
        ], JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
    }

    /**
     * Returns a response body as a string.
     *
     * @param Response $response the response
     *
     * @return string the response body
     */
    private function responseContent(Response $response): string
    {
        $content = $response->getContent();
        if (false === $content) {
            self::fail('The response body is not available.');
        }

        return $content;
    }
}
