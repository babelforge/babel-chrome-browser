<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Tests\Service;

use BabelForge\BabelChrome\LocalViewer\DocumentSource;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleManifest;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRuntimeContext;
use BabelForge\BabelChrome\LocalViewer\Service\SourceRegistry;
use BabelForge\BabelChromeOpenApiViewerModule\ModuleAssetResolver;
use BabelForge\BabelChromeOpenApiViewerModule\OpenApiDocumentRenderer;
use BabelForge\BabelChromeOpenApiViewerModule\OpenApiRenderException;
use BabelForge\BabelChromeOpenApiViewerModule\OpenApiView;
use BabelForge\BabelChromeViewerKit\ViewerSource;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\TestCase;
use Symfony\Component\HttpFoundation\Request;

/**
 * Verifies OpenAPI source parsing and viewer metadata.
 */
#[CoversClass(OpenApiDocumentRenderer::class)]
final class OpenApiDocumentRendererTest extends TestCase
{
    private string $workspaceDirectory;

    /**
     * Registers the OpenAPI viewer module autoloader.
     */
    public static function setUpBeforeClass(): void
    {
        class_exists(DocumentSource::class);
        class_exists(ModuleManifest::class);
        class_exists(ModuleRuntimeContext::class);
        class_exists(SourceRegistry::class);

        if (!class_exists(ViewerSource::class)) {
            require_once dirname(__DIR__, 5).'/modules/openapi-viewer-module/vendor/autoload.php';
        }

        spl_autoload_register(static function (string $class): void {
            $prefix = 'BabelForge\\BabelChromeOpenApiViewerModule\\';
            if (!str_starts_with($class, $prefix)) {
                return;
            }

            $relativeClass = substr($class, strlen($prefix));
            $path = dirname(__DIR__, 5).'/modules/openapi-viewer-module/src/'.str_replace('\\', '/', $relativeClass).'.php';
            if (is_file($path)) {
                require $path;
            }
        });
    }

    /**
     * Creates an isolated OpenAPI workspace.
     */
    protected function setUp(): void
    {
        parent::setUp();

        $root = sys_get_temp_dir().'/babelchrome-openapi-renderer-test-'.bin2hex(random_bytes(6));
        $state = $root.'/state';
        if (!mkdir($root, 0o775, true) && !is_dir($root)) {
            self::fail('Unable to create test workspace.');
        }

        if (!mkdir($state, 0o775, true) && !is_dir($state)) {
            self::fail('Unable to create test state directory.');
        }

        $this->workspaceDirectory = $root;
        putenv('BABELCHROME_VIEWER_STATE_DIR='.$state);
    }

    /**
     * Clears the isolated viewer state.
     */
    protected function tearDown(): void
    {
        putenv('BABELCHROME_VIEWER_STATE_DIR');

        parent::tearDown();
    }

    /**
     * Ensures YAML OpenAPI documents are converted to JSON for Swagger UI.
     */
    public function testYamlOpenApiDocumentIsEncodedAsJsonSpecification(): void
    {
        $view = $this->renderOpenApi(
            <<<'YAML'
                openapi: 3.1.0
                info:
                  title: Pet Store
                  version: 1.0.0
                paths:
                  /pets:
                    get:
                      summary: List pets
                YAML,
        );

        $specification = $this->decodedSpecification($view);

        self::assertSame('3.1.0', $specification['openapi']);
        self::assertSame('Pet Store', $this->mapValue($specification, 'info')['title']);
        self::assertArrayHasKey('/pets', $this->mapValue($specification, 'paths'));
    }

    /**
     * Ensures JSON OpenAPI documents are passed through as Swagger UI specifications.
     */
    public function testJsonOpenApiDocumentIsEncodedAsJsonSpecification(): void
    {
        $view = $this->renderOpenApi('{"openapi":"3.0.3","info":{"title":"JSON API","version":"1.0.0"},"paths":{}}');
        $specification = $this->decodedSpecification($view);

        self::assertSame('3.0.3', $specification['openapi']);
        self::assertSame('JSON API', $this->mapValue($specification, 'info')['title']);
        self::assertSame([], $specification['paths']);
    }

    /**
     * Ensures invalid OpenAPI documents report a root rendering error.
     */
    public function testInvalidOpenApiDocumentThrowsRenderException(): void
    {
        $this->expectException(OpenApiRenderException::class);
        $this->expectExceptionMessage('The OpenAPI document must define openapi/swagger, info, and paths.');

        $this->renderOpenApi(':::');
    }

    /**
     * Ensures local auto-refresh metadata is exposed for file-backed OpenAPI sources.
     */
    public function testLocalOpenApiExposesAutoRefreshMetadata(): void
    {
        $view = $this->renderOpenApi(
            <<<'YAML'
                openapi: 3.1.0
                info:
                  title: Refresh
                  version: 1.0.0
                paths: {}
                YAML,
        );

        self::assertTrue($view->autoRefreshEnabled);
        self::assertNotSame('', $view->sourceId);
        self::assertIsInt($view->lastModified);
    }

    /**
     * Ensures the bundled Swagger UI stylesheet is injected into OpenAPI pages.
     */
    public function testSwaggerUiStylesheetIsInjected(): void
    {
        $view = $this->renderOpenApi(
            <<<'YAML'
                openapi: 3.1.0
                info:
                  title: Styled
                  version: 1.0.0
                paths: {}
                YAML,
        );

        self::assertStringContainsString('.swagger-ui', $view->stylesheetContent);
    }

    /**
     * Ensures internal OpenAPI references are resolved before Swagger UI receives the specification.
     */
    public function testInternalReferencesAreResolved(): void
    {
        $view = $this->renderOpenApi(
            <<<'YAML'
                openapi: 3.1.0
                info:
                  title: Internal References
                  version: 1.0.0
                paths:
                  /users:
                    get:
                      responses:
                        '200':
                          description: OK
                          content:
                            application/json:
                              schema:
                                $ref: '#/components/schemas/User'
                components:
                  schemas:
                    User:
                      type: object
                      properties:
                        name:
                          type: string
                YAML,
        );

        $schema = $this->responseSchema($this->decodedSpecification($view), '/users', '200');

        self::assertSame('object', $schema['type']);
        self::assertArrayNotHasKey('$ref', $schema);
    }

    /**
     * Ensures relative file references are resolved before Swagger UI receives the specification.
     */
    public function testRelativeFileReferencesAreResolved(): void
    {
        if (!mkdir($this->workspaceDirectory.'/schemas', 0o775, true) && !is_dir($this->workspaceDirectory.'/schemas')) {
            self::fail('Unable to create schemas directory.');
        }

        file_put_contents(
            $this->workspaceDirectory.'/schemas/user.yaml',
            <<<'YAML'
                User:
                  type: object
                  properties:
                    id:
                      type: integer
                YAML,
        );

        $view = $this->renderOpenApi(
            <<<'YAML'
                openapi: 3.1.0
                info:
                  title: External References
                  version: 1.0.0
                paths:
                  /users:
                    get:
                      responses:
                        '200':
                          description: OK
                          content:
                            application/json:
                              schema:
                                $ref: './schemas/user.yaml#/User'
                YAML,
        );

        $schema = $this->responseSchema($this->decodedSpecification($view), '/users', '200');

        self::assertSame('object', $schema['type']);
        self::assertArrayHasKey('id', $this->mapValue($schema, 'properties'));
    }

    /**
     * Ensures missing relative file references stay visible in the rendered specification.
     */
    public function testMissingRelativeFileReferenceProducesVisibleError(): void
    {
        $view = $this->renderOpenApi(
            <<<'YAML'
                openapi: 3.1.0
                info:
                  title: Missing References
                  version: 1.0.0
                paths:
                  /users:
                    get:
                      responses:
                        '200':
                          description: OK
                          content:
                            application/json:
                              schema:
                                $ref: './schemas/missing.yaml#/User'
                YAML,
        );

        $schema = $this->responseSchema($this->decodedSpecification($view), '/users', '200');

        self::assertSame('Referenced OpenAPI document could not be loaded.', $schema['x-babelchrome-ref-error']);
    }

    /**
     * Ensures local referenced files contribute to the OpenAPI auto-refresh timestamp.
     */
    public function testReferencedFilesContributeToLastModifiedTimestamp(): void
    {
        if (!mkdir($this->workspaceDirectory.'/schemas', 0o775, true) && !is_dir($this->workspaceDirectory.'/schemas')) {
            self::fail('Unable to create schemas directory.');
        }

        $schemaPath = $this->workspaceDirectory.'/schemas/user.yaml';
        file_put_contents(
            $schemaPath,
            <<<'YAML'
                User:
                  type: object
                YAML,
        );

        $sourceContent = <<<'YAML'
            openapi: 3.1.0
            info:
              title: Refresh References
              version: 1.0.0
            paths:
              /users:
                get:
                  responses:
                    '200':
                      description: OK
                      content:
                        application/json:
                          schema:
                            $ref: './schemas/user.yaml#/User'
            YAML;

        $sourcePath = $this->workspaceDirectory.'/openapi.yaml';
        file_put_contents($sourcePath, $sourceContent);
        $sourceTimestamp = time() - 60;
        $schemaTimestamp = time();
        touch($sourcePath, $sourceTimestamp);
        touch($schemaPath, $schemaTimestamp);

        $source = new ViewerSource(
            'OpenAPI',
            $sourceContent,
            'file://'.$this->workspaceDirectory.'/',
            true,
            'file',
            $sourcePath,
            'application/yaml',
            $sourceTimestamp,
        );

        self::assertSame($schemaTimestamp, $this->renderer()->sourceLastModified($source));
    }

    /**
     * Renders OpenAPI from the isolated local document directory.
     *
     * @param string $content the OpenAPI source content
     *
     * @return OpenApiView the rendered view
     */
    private function renderOpenApi(string $content): OpenApiView
    {
        $sourcePath = $this->workspaceDirectory.'/openapi.yaml';
        file_put_contents($sourcePath, $content);

        $source = new ViewerSource(
            'OpenAPI',
            $content,
            'file://'.$this->workspaceDirectory.'/',
            true,
            'file',
            $sourcePath,
            'application/yaml',
            $this->lastModified($sourcePath),
        );
        $sourceId = new SourceRegistry()->register('file', $source->value);
        $request = Request::create('/openapi', 'GET', ['token' => 'test-token']);
        $request->attributes->set('sourceId', $sourceId);

        return $this->renderer()->render($source, $request);
    }

    /**
     * Decodes the rendered OpenAPI specification.
     *
     * @param OpenApiView $view the rendered view
     *
     * @return array<string, mixed> the decoded specification
     */
    private function decodedSpecification(OpenApiView $view): array
    {
        $specification = json_decode($view->specJson, true);
        if (!is_array($specification)) {
            self::fail('The OpenAPI specification JSON could not be decoded.');
        }

        return $this->stringKeyedMap($specification);
    }

    /**
     * Returns a nested string-keyed map from a decoded specification.
     *
     * @param array<int|string, mixed> $specification the decoded specification
     * @param string                   $key           the map key
     *
     * @return array<string, mixed> the nested map
     */
    private function mapValue(array $specification, string $key): array
    {
        $value = $specification[$key] ?? (ctype_digit($key) ? ($specification[(int) $key] ?? null) : null);
        if (!is_array($value)) {
            self::fail('The expected OpenAPI map value is missing.');
        }

        return $this->stringKeyedMap($value);
    }

    /**
     * Returns a response schema from a decoded OpenAPI document.
     *
     * @param array<string, mixed> $specification the decoded specification
     * @param string               $path          the OpenAPI path
     * @param string               $statusCode    the response status code
     *
     * @return array<string, mixed> the response schema
     */
    private function responseSchema(array $specification, string $path, string $statusCode): array
    {
        $paths = $this->mapValue($specification, 'paths');
        $pathItem = $this->mapValue($paths, $path);
        $operation = $this->mapValue($pathItem, 'get');
        $responses = $this->mapValue($operation, 'responses');
        $response = $this->mapValue($responses, $statusCode);
        $content = $this->mapValue($response, 'content');
        $jsonContent = $this->mapValue($content, 'application/json');

        return $this->mapValue($jsonContent, 'schema');
    }

    /**
     * Converts a decoded array to a string-keyed map.
     *
     * @param array<mixed, mixed> $value the decoded array
     *
     * @return array<string, mixed> the string-keyed map
     */
    private function stringKeyedMap(array $value): array
    {
        $map = [];
        foreach ($value as $key => $item) {
            $map[(string) $key] = $item;
        }

        return $map;
    }

    /**
     * Creates the renderer under test.
     *
     * @return OpenApiDocumentRenderer the renderer
     */
    private function renderer(): OpenApiDocumentRenderer
    {
        return new OpenApiDocumentRenderer(
            new ModuleAssetResolver($this->moduleManifest(), new ModuleRuntimeContext('http://127.0.0.1:12345', 'test-token', '')),
        );
    }

    /**
     * Returns the real OpenAPI viewer module manifest.
     *
     * @return ModuleManifest the module manifest
     */
    private function moduleManifest(): ModuleManifest
    {
        $modulePath = dirname(__DIR__, 5).'/modules/openapi-viewer-module';

        return ModuleManifest::fromArray($this->manifestData($modulePath), $modulePath);
    }

    /**
     * Decodes a module manifest with string keys.
     *
     * @param string $modulePath the module root path
     *
     * @return array<string, mixed> the decoded manifest data
     */
    private function manifestData(string $modulePath): array
    {
        $decoded = json_decode((string) file_get_contents($modulePath.'/manifest.json'), true, 512, JSON_THROW_ON_ERROR);
        self::assertIsArray($decoded);

        $data = [];
        foreach ($decoded as $key => $value) {
            if (is_string($key)) {
                $data[$key] = $value;
            }
        }

        return $data;
    }

    /**
     * Returns the last modification timestamp for a test file.
     *
     * @param string $path the file path
     *
     * @return int|null the last modification timestamp
     */
    private function lastModified(string $path): ?int
    {
        $lastModified = filemtime($path);

        return false === $lastModified ? null : $lastModified;
    }
}
