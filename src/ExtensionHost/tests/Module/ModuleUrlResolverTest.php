<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Tests\Module;

use BabelForge\BabelChrome\LocalViewer\Module\ModuleRegistry;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleUrlResolver;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\TestCase;

/**
 * Verifies stable URL and viewer module resolution.
 */
#[CoversClass(ModuleUrlResolver::class)]
final class ModuleUrlResolverTest extends TestCase
{
    private string $workspaceDirectory;

    /**
     * Creates an isolated module registry workspace.
     */
    protected function setUp(): void
    {
        parent::setUp();

        $this->workspaceDirectory = sys_get_temp_dir().'/babelchrome-module-url-resolver-test-'.bin2hex(random_bytes(6));
        if (!mkdir($this->workspaceDirectory.'/Modules', 0o775, true) && !is_dir($this->workspaceDirectory.'/Modules')) {
            self::fail('Unable to create test workspace directory.');
        }
    }

    /**
     * Removes the isolated module registry workspace.
     */
    protected function tearDown(): void
    {
        $this->removeDirectory($this->workspaceDirectory);

        parent::tearDown();
    }

    /**
     * Ensures constrained viewer modules are selected before generic ones.
     */
    public function testConstrainedViewerModuleWinsOverGenericViewerModule(): void
    {
        $this->writeViewerModule('vendor.generic-json-viewer', 'json', []);
        $this->writeViewerModule('vendor.openapi-viewer', 'openapi', ['openapi', 'swagger']);

        $resolver = new ModuleUrlResolver(new ModuleRegistry(null, $this->workspaceDirectory.'/Modules'));

        $openApiRoute = $resolver->viewerRouteForSourceUrl('file:///tmp/openapi.json');
        $genericRoute = $resolver->viewerRouteForSourceUrl('file:///tmp/data.json');

        self::assertSame('vendor.openapi-viewer', $openApiRoute['module']->id ?? null);
        self::assertSame('vendor.generic-json-viewer', $genericRoute['module']->id ?? null);
    }

    /**
     * Writes a minimal viewer module manifest.
     *
     * @param string       $moduleId         the module identifier
     * @param string       $host             the BabelChrome route host
     * @param list<string> $fileNameContains filename fragments required by the module
     */
    private function writeViewerModule(string $moduleId, string $host, array $fileNameContains): void
    {
        $moduleDirectory = $this->workspaceDirectory.'/Modules/'.$moduleId;
        if (!mkdir($moduleDirectory, 0o775, true) && !is_dir($moduleDirectory)) {
            self::fail(sprintf('Unable to create test module directory "%s".', $moduleId));
        }

        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => $moduleId,
            'name' => $moduleId,
            'version' => '1.0.0',
            'requirements' => [
                'php' => '>=8.4',
            ],
            'type' => 'viewer',
            'enabled' => true,
            'routes' => [
                [
                    'scheme' => 'babelchrome',
                    'host' => $host,
                    'handler' => $host,
                ],
            ],
            'fileTypes' => ['json'],
            'fileNameContains' => $fileNameContains,
        ], JSON_THROW_ON_ERROR));
    }

    /**
     * Removes a directory tree created by the test.
     *
     * @param string $directory the directory to remove
     */
    private function removeDirectory(string $directory): void
    {
        if (!is_dir($directory)) {
            return;
        }

        $items = scandir($directory);
        if (false === $items) {
            return;
        }

        foreach ($items as $item) {
            if ('.' === $item || '..' === $item) {
                continue;
            }

            $path = $directory.'/'.$item;
            if (is_dir($path) && !is_link($path)) {
                $this->removeDirectory($path);
                continue;
            }

            unlink($path);
        }

        rmdir($directory);
    }
}
