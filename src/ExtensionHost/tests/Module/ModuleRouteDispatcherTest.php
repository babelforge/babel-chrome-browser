<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Tests\Module;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleDispatchException;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleAutoloadRegistrar;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRegistry;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRequest;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRouteDispatcher;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRuntimeContext;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleWebRuntime;
use BabelForge\BabelChrome\LocalViewer\Module\Runtime\ModuleRuntimeDispatcher;
use BabelForge\BabelChrome\LocalViewer\Module\Runtime\ModuleRuntimeType;
use BabelForge\BabelChrome\LocalViewer\Module\Runtime\PhpClassRuntimeHandler;
use BabelForge\BabelChrome\LocalViewer\Module\Runtime\PhpWebRuntimeHandler;
use BabelForge\BabelChrome\LocalViewer\Module\Runtime\StaticWebRuntimeHandler;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\TestCase;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Verifies dispatching requests to installed PHP modules.
 */
#[CoversClass(ModuleRouteDispatcher::class)]
#[CoversClass(ModuleRequest::class)]
#[CoversClass(ModuleRuntimeContext::class)]
#[CoversClass(ModuleWebRuntime::class)]
#[CoversClass(ModuleRuntimeDispatcher::class)]
#[CoversClass(ModuleRuntimeType::class)]
#[CoversClass(PhpClassRuntimeHandler::class)]
#[CoversClass(PhpWebRuntimeHandler::class)]
#[CoversClass(StaticWebRuntimeHandler::class)]
final class ModuleRouteDispatcherTest extends TestCase
{
    private string $workspaceDirectory;

    /**
     * Creates an isolated module workspace.
     */
    protected function setUp(): void
    {
        parent::setUp();

        $this->workspaceDirectory = sys_get_temp_dir().'/babelchrome-module-dispatcher-test-'.bin2hex(random_bytes(6));
        if (!mkdir($this->workspaceDirectory.'/Modules/vendor.routable-module/src', 0o775, true) && !is_dir($this->workspaceDirectory.'/Modules/vendor.routable-module/src')) {
            self::fail('Unable to create test module directory.');
        }

        if (!mkdir($this->workspaceDirectory.'/Modules/vendor.routable-module/vendor', 0o775, true) && !is_dir($this->workspaceDirectory.'/Modules/vendor.routable-module/vendor')) {
            self::fail('Unable to create test module vendor directory.');
        }

        $this->writeRoutableModule();
        $this->writeWebModule();
        $this->writeExplicitPhpWebModule();
        $this->writeProcessIsolatedWebModule();
        $this->writeStaticWebModule();
        $this->writeEscapingStaticWebModule();
    }

    /**
     * Clears the isolated module workspace.
     */
    protected function tearDown(): void
    {
        parent::tearDown();
    }

    /**
     * Ensures an enabled module route is dispatched to the module entrypoint.
     */
    public function testDispatchesEnabledModuleRoute(): void
    {
        $dispatcher = $this->dispatcher();
        $response = $dispatcher->dispatch(
            'vendor.routable-module',
            'index',
            Request::create('http://127.0.0.1:49152/module/vendor.routable-module/index', 'GET', [
                'token' => 'test-token',
                'sourceUrl' => 'https://example.com/source',
            ]),
        );

        $content = $response->getContent();

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertIsString($content);
        self::assertStringContainsString('vendor.routable-module:index', $content);
        self::assertStringContainsString('https://example.com/source', $content);
        self::assertStringContainsString('http://127.0.0.1:49152/module/vendor.routable-module/assets/styles/app.css?token=test-token', $content);
    }

    /**
     * Ensures an undeclared route is rejected before the entrypoint is called.
     */
    public function testRejectsUndeclaredRoute(): void
    {
        $this->expectException(ModuleDispatchException::class);
        $this->expectExceptionMessage('does not declare route');

        $this->dispatcher()->dispatch(
            'vendor.routable-module',
            'missing',
            Request::create('/module/vendor.routable-module/missing', 'GET'),
        );
    }

    /**
     * Ensures a web runtime module is dispatched through its front controller.
     */
    public function testDispatchesWebRuntimeModuleRoute(): void
    {
        $dispatcher = $this->dispatcher();
        $response = $dispatcher->dispatch(
            'vendor.web-module',
            'index',
            Request::create('http://127.0.0.1:49152/module/vendor.web-module/index', 'GET', [
                'token' => 'test-token',
                'sourceUrl' => 'https://example.com/web-source',
            ]),
        );

        $content = $response->getContent();

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertIsString($content);
        self::assertStringContainsString('vendor.web-module:index', $content);
        self::assertStringContainsString('https://example.com/web-source', $content);
        self::assertStringContainsString('http://127.0.0.1:49152/module/vendor.web-module/assets', $content);
        self::assertStringContainsString('?token=test-token', $content);
        self::assertStringNotContainsString('/assets/?token=', $content);
    }

    /**
     * Ensures an explicit php-web runtime module is dispatched through its front controller.
     */
    public function testDispatchesExplicitPhpWebRuntimeModuleRoute(): void
    {
        $dispatcher = $this->dispatcher();
        $response = $dispatcher->dispatch(
            'vendor.php-web-module',
            'index',
            Request::create('http://127.0.0.1:49152/module/vendor.php-web-module/index', 'GET', [
                'token' => 'test-token',
                'sourceUrl' => 'https://example.com/php-web-source',
            ]),
        );

        $content = $response->getContent();

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertIsString($content);
        self::assertStringContainsString('vendor.php-web-module:index', $content);
        self::assertStringContainsString('https://example.com/php-web-source', $content);
    }

    /**
     * Ensures a process-isolated web runtime module is dispatched through a dedicated PHP process.
     */
    public function testDispatchesProcessIsolatedWebRuntimeModuleRoute(): void
    {
        $dispatcher = $this->dispatcher();
        $response = $dispatcher->dispatch(
            'vendor.isolated-web-module',
            'index',
            Request::create('http://127.0.0.1:49152/module/vendor.isolated-web-module/index', 'GET', [
                'token' => 'test-token',
                'sourceUrl' => 'https://example.com/isolated-source',
            ]),
        );

        $content = $response->getContent();

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertIsString($content);
        self::assertStringContainsString('vendor.isolated-web-module:index', $content);
        self::assertStringContainsString('https://example.com/isolated-source', $content);
    }

    /**
     * Ensures a static web module renders its declared index document.
     */
    public function testDispatchesStaticWebRuntimeModuleRoute(): void
    {
        $dispatcher = $this->dispatcher();
        $response = $dispatcher->dispatch(
            'vendor.static-web-module',
            'index',
            Request::create('http://127.0.0.1:49152/module/vendor.static-web-module/index', 'GET', [
                'token' => 'test-token',
                'sourceUrl' => 'https://example.com/static-source',
            ]),
        );

        $content = $response->getContent();

        self::assertSame(Response::HTTP_OK, $response->getStatusCode());
        self::assertStringContainsString('text/html', (string) $response->headers->get('Content-Type'));
        self::assertIsString($content);
        self::assertStringContainsString('vendor.static-web-module:index', $content);
        self::assertStringContainsString('https://example.com/static-source', $content);
        self::assertStringContainsString('http://127.0.0.1:49152/module/vendor.static-web-module/assets/styles/app.css?token=test-token', $content);
    }

    /**
     * Ensures a static web module cannot serve an index outside its document root.
     */
    public function testStaticWebRuntimeRejectsIndexTraversal(): void
    {
        $this->expectException(ModuleDispatchException::class);
        $this->expectExceptionMessage('static index escapes the document root');

        $this->dispatcher()->dispatch(
            'vendor.escaping-static-web-module',
            'index',
            Request::create('http://127.0.0.1:49152/module/vendor.escaping-static-web-module/index', 'GET', [
                'token' => 'test-token',
            ]),
        );
    }

    /**
     * Creates the dispatcher under test.
     *
     * @return ModuleRouteDispatcher the dispatcher
     */
    private function dispatcher(): ModuleRouteDispatcher
    {
        $moduleRegistry = new ModuleRegistry($this->workspaceDirectory.'/Catalog', $this->workspaceDirectory.'/Modules');
        $moduleAutoloadRegistrar = new ModuleAutoloadRegistrar($moduleRegistry);

        return new ModuleRouteDispatcher(
            $moduleRegistry,
            new ModuleRuntimeDispatcher(
                new PhpWebRuntimeHandler(new ModuleWebRuntime()),
                new StaticWebRuntimeHandler(),
                new PhpClassRuntimeHandler($moduleAutoloadRegistrar),
            ),
        );
    }

    /**
     * Writes a small routable module to the test workspace.
     */
    private function writeRoutableModule(): void
    {
        $moduleDirectory = $this->workspaceDirectory.'/Modules/vendor.routable-module';
        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'vendor.routable-module',
            'name' => 'Routable Module',
            'version' => '1.0.0',
            'requirements' => [
                'php' => '>=8.4',
            ],
            'enabled' => true,
            'entrypoint' => 'BabelForge\\BabelChromeRoutableTestModule\\RoutableModule',
            'routes' => [
                [
                    'scheme' => 'babelchrome',
                    'host' => 'routable',
                    'handler' => 'index',
                ],
            ],
        ], JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT));

        file_put_contents($moduleDirectory.'/vendor/autoload.php', <<<'PHP'
            <?php

            declare(strict_types=1);

            spl_autoload_register(static function (string $class): void {
                $prefix = 'BabelForge\\BabelChromeRoutableTestModule\\';
                if (!str_starts_with($class, $prefix)) {
                    return;
                }

                $relativeClass = substr($class, strlen($prefix));
                $path = dirname(__DIR__).'/src/'.str_replace('\\', '/', $relativeClass).'.php';
                if (is_file($path)) {
                    require $path;
                }
            });
            PHP);

        file_put_contents($moduleDirectory.'/src/RoutableModule.php', <<<'PHP'
            <?php

            declare(strict_types=1);

            namespace BabelForge\BabelChromeRoutableTestModule;

            use BabelForge\BabelChrome\LocalViewer\Module\BabelChromeModuleInterface;
            use BabelForge\BabelChrome\LocalViewer\Module\ModuleRequest;
            use Symfony\Component\HttpFoundation\Response;

            /**
             * Handles test module requests.
             */
            final class RoutableModule implements BabelChromeModuleInterface
            {
                /**
                 * Handles one test request.
                 *
                 * @param ModuleRequest $request the module request
                 *
                 * @return Response the response
                 */
                public function handle(ModuleRequest $request): Response
                {
                    return new Response(
                        $request->module->id.':'.
                        $request->route.':'.
                        $request->context->sourceUrl.':'.
                        $request->context->moduleAssetUrl($request->module, 'styles/app.css')
                    );
                }
            }
            PHP);
    }

    /**
     * Writes a small web runtime module to the test workspace.
     */
    private function writeWebModule(): void
    {
        $moduleDirectory = $this->workspaceDirectory.'/Modules/vendor.web-module';
        if (!mkdir($moduleDirectory.'/public', 0o775, true) && !is_dir($moduleDirectory.'/public')) {
            self::fail('Unable to create test web module directory.');
        }

        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'vendor.web-module',
            'name' => 'Web Module',
            'version' => '1.0.0',
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
                    'host' => 'web',
                    'handler' => 'index',
                ],
            ],
        ], JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT));

        file_put_contents($moduleDirectory.'/public/index.php', <<<'PHP'
            <?php

            declare(strict_types=1);

            use Symfony\Component\HttpFoundation\Response;

            return new Response(
                $_SERVER['BABELCHROME_MODULE_ID'].':'.
                $_SERVER['BABELCHROME_MODULE_ROUTE'].':'.
                $_SERVER['BABELCHROME_SOURCE_URL'].':'.
                $_SERVER['BABELCHROME_MODULE_ASSET_BASE_URL'].':'.
                $_SERVER['BABELCHROME_MODULE_ASSET_TOKEN_QUERY']
            );
            PHP);
    }

    /**
     * Writes a small explicit php-web runtime module to the test workspace.
     */
    private function writeExplicitPhpWebModule(): void
    {
        $moduleDirectory = $this->workspaceDirectory.'/Modules/vendor.php-web-module';
        if (!mkdir($moduleDirectory.'/public', 0o775, true) && !is_dir($moduleDirectory.'/public')) {
            self::fail('Unable to create test explicit php-web module directory.');
        }

        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'vendor.php-web-module',
            'name' => 'Explicit PHP Web Module',
            'version' => '1.0.0',
            'requirements' => [
                'php' => '>=8.4',
            ],
            'enabled' => true,
            'runtime' => [
                'type' => 'php-web',
                'entrypoint' => 'public/index.php',
            ],
            'routes' => [
                [
                    'scheme' => 'babelchrome',
                    'host' => 'php-web',
                    'handler' => 'index',
                ],
            ],
        ], JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT));

        file_put_contents($moduleDirectory.'/public/index.php', <<<'PHP'
            <?php

            declare(strict_types=1);

            return
                $_SERVER['BABELCHROME_MODULE_ID'].':'.
                $_SERVER['BABELCHROME_MODULE_ROUTE'].':'.
                $_SERVER['BABELCHROME_SOURCE_URL'];
            PHP);
    }

    /**
     * Writes a small process-isolated web runtime module to the test workspace.
     */
    private function writeProcessIsolatedWebModule(): void
    {
        $moduleDirectory = $this->workspaceDirectory.'/Modules/vendor.isolated-web-module';
        if (!mkdir($moduleDirectory.'/public', 0o775, true) && !is_dir($moduleDirectory.'/public')) {
            self::fail('Unable to create test process-isolated web module directory.');
        }

        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'vendor.isolated-web-module',
            'name' => 'Process Isolated Web Module',
            'version' => '1.0.0',
            'requirements' => [
                'php' => '>=8.4',
            ],
            'enabled' => true,
            'runtime' => [
                'type' => 'web',
                'entrypoint' => 'public/index.php',
                'processIsolation' => true,
            ],
            'entrypoint' => 'public/index.php',
            'routes' => [
                [
                    'scheme' => 'babelchrome',
                    'host' => 'isolated-web',
                    'handler' => 'index',
                ],
            ],
        ], JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT));

        file_put_contents($moduleDirectory.'/public/index.php', <<<'PHP'
            <?php

            declare(strict_types=1);

            return
                $_SERVER['BABELCHROME_MODULE_ID'].':'.
                $_SERVER['BABELCHROME_MODULE_ROUTE'].':'.
                $_SERVER['BABELCHROME_SOURCE_URL'];
            PHP);
    }

    /**
     * Writes a small static web runtime module to the test workspace.
     */
    private function writeStaticWebModule(): void
    {
        $moduleDirectory = $this->workspaceDirectory.'/Modules/vendor.static-web-module';
        if (!mkdir($moduleDirectory.'/public/styles', 0o775, true) && !is_dir($moduleDirectory.'/public/styles')) {
            self::fail('Unable to create test static web module directory.');
        }

        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'vendor.static-web-module',
            'name' => 'Static Web Module',
            'version' => '1.0.0',
            'enabled' => true,
            'runtime' => [
                'type' => 'static-web',
                'documentRoot' => 'public',
                'index' => 'index.html',
            ],
            'routes' => [
                [
                    'scheme' => 'babelchrome',
                    'host' => 'static-web',
                    'handler' => 'index',
                ],
            ],
        ], JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT));

        file_put_contents($moduleDirectory.'/public/index.html', <<<'HTML'
            <!doctype html>
            <html>
                <head>
                    <link rel="stylesheet" href="{{ BABELCHROME_MODULE_ASSET_BASE_URL }}/styles/app.css{{ BABELCHROME_MODULE_ASSET_TOKEN_QUERY }}">
                </head>
                <body>{{ BABELCHROME_MODULE_ID }}:{{ BABELCHROME_MODULE_ROUTE }}:{{ BABELCHROME_SOURCE_URL }}</body>
            </html>
            HTML);
        file_put_contents($moduleDirectory.'/public/styles/app.css', '.static-web-module { color: #0969da; }');
    }

    /**
     * Writes a static web runtime module with an unsafe index path.
     */
    private function writeEscapingStaticWebModule(): void
    {
        $moduleDirectory = $this->workspaceDirectory.'/Modules/vendor.escaping-static-web-module';
        if (!mkdir($moduleDirectory.'/public', 0o775, true) && !is_dir($moduleDirectory.'/public')) {
            self::fail('Unable to create test escaping static web module directory.');
        }

        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'vendor.escaping-static-web-module',
            'name' => 'Escaping Static Web Module',
            'version' => '1.0.0',
            'enabled' => true,
            'runtime' => [
                'type' => 'static-web',
                'documentRoot' => 'public',
                'index' => '../manifest.json',
            ],
            'routes' => [
                [
                    'scheme' => 'babelchrome',
                    'host' => 'escaping-static-web',
                    'handler' => 'index',
                ],
            ],
        ], JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT));
        file_put_contents($moduleDirectory.'/public/index.html', '<!doctype html><title>Unused</title>');
    }
}
