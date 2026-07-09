<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Tests\Module;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleShippingException;
use BabelForge\BabelChrome\LocalViewer\Module\ModulePackageShipper;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\TestCase;

/**
 * Verifies PHP module production package creation.
 */
#[CoversClass(ModulePackageShipper::class)]
final class ModulePackageShipperTest extends TestCase
{
    private string $workspaceDirectory;

    /**
     * Creates an isolated shipper workspace.
     */
    protected function setUp(): void
    {
        parent::setUp();

        $this->workspaceDirectory = sys_get_temp_dir().'/babelchrome-module-shipper-test-'.bin2hex(random_bytes(6));
        if (!mkdir($this->workspaceDirectory, 0o775, true) && !is_dir($this->workspaceDirectory)) {
            self::fail('Unable to create test workspace directory.');
        }
    }

    /**
     * Ensures a module package contains production files and excludes development files.
     */
    public function testShipCreatesProductionZip(): void
    {
        $moduleDirectory = $this->moduleDirectory('vendor.shipped-module', '1.2.3');
        $targetPath = $this->workspaceDirectory.'/dist/module.zip';

        $result = new ModulePackageShipper()->ship($moduleDirectory, $targetPath);

        self::assertSame($targetPath, $result);
        self::assertFileExists($targetPath);
        self::assertZipContains($targetPath, 'manifest.json');
        self::assertZipContains($targetPath, 'composer.json');
        self::assertZipContains($targetPath, 'src/ShippedModule.php');
        self::assertZipContains($targetPath, 'vendor/autoload.php');
        self::assertZipContains($targetPath, 'public/styles/demo.css');
        self::assertZipNotContains($targetPath, 'assets/app/module.ts');
        self::assertZipNotContains($targetPath, 'bin/console');
        self::assertZipNotContains($targetPath, 'config/bundles.php');
        self::assertZipNotContains($targetPath, 'importmap.php');
        self::assertZipNotContains($targetPath, 'phpstan.neon');
        self::assertZipNotContains($targetPath, 'phpunit.xml.dist');
        self::assertZipNotContains($targetPath, '.php-cs-fixer.dist.php');
        self::assertZipNotContains($targetPath, '.phpunit.result.cache');
        self::assertZipNotContains($targetPath, 'tests/ModuleTest.php');
        self::assertZipNotContains($targetPath, 'var/cache/item');
        self::assertZipNotContains($targetPath, 'ai/CODEX.md');
        self::assertZipNotContains($targetPath, 'node_modules/package/index.js');
        self::assertZipNotContains($targetPath, 'nested.zip');
    }

    /**
     * Ensures the default zip path uses module id and version.
     */
    public function testShipUsesDefaultTargetPath(): void
    {
        $moduleDirectory = $this->moduleDirectory('vendor.default-target', '4.5.6');
        $resolvedModuleDirectory = realpath($moduleDirectory);
        self::assertIsString($resolvedModuleDirectory);

        $targetPath = new ModulePackageShipper()->ship($moduleDirectory);

        self::assertSame(dirname($resolvedModuleDirectory).'/vendor.default-target-4.5.6.zip', $targetPath);
        self::assertFileExists($targetPath);
    }

    /**
     * Ensures explicit php-web modules are validated as web modules.
     */
    public function testShipSupportsExplicitPhpWebRuntime(): void
    {
        $moduleDirectory = $this->moduleDirectory('vendor.php-web-shipped-module', '1.0.0', [
            'type' => 'php-web',
            'entrypoint' => 'public/index.php',
        ]);
        file_put_contents($moduleDirectory.'/public/index.php', '<?php return "";');
        $targetPath = $this->workspaceDirectory.'/dist/php-web-module.zip';

        $result = new ModulePackageShipper()->ship($moduleDirectory, $targetPath);

        self::assertSame($targetPath, $result);
        self::assertFileExists($targetPath);
        self::assertZipContains($targetPath, 'public/index.php');
    }

    /**
     * Ensures static web modules can be shipped without Composer files.
     */
    public function testShipSupportsStaticWebRuntimeWithoutComposer(): void
    {
        $moduleDirectory = $this->workspaceDirectory.'/vendor.static-web-module';
        self::assertTrue(mkdir($moduleDirectory.'/public/styles', 0o775, true));
        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'vendor.static-web-module',
            'name' => 'Static Web Module',
            'version' => '1.0.0',
            'runtime' => [
                'type' => 'static-web',
                'documentRoot' => 'public',
                'index' => 'index.html',
            ],
        ], JSON_THROW_ON_ERROR));
        file_put_contents($moduleDirectory.'/public/index.html', '<!doctype html><title>Static</title>');
        file_put_contents($moduleDirectory.'/public/styles/app.css', '.static {}');
        $targetPath = $this->workspaceDirectory.'/dist/static-web-module.zip';

        $result = new ModulePackageShipper()->ship($moduleDirectory, $targetPath);

        self::assertSame($targetPath, $result);
        self::assertFileExists($targetPath);
        self::assertZipContains($targetPath, 'manifest.json');
        self::assertZipContains($targetPath, 'public/index.html');
        self::assertZipContains($targetPath, 'public/styles/app.css');
        self::assertZipNotContains($targetPath, 'composer.json');
        self::assertZipNotContains($targetPath, 'vendor/autoload.php');
    }

    /**
     * Ensures process web modules can ship their own non-PHP runtime files.
     */
    public function testShipSupportsProcessWebRuntimeWithoutComposer(): void
    {
        $moduleDirectory = $this->workspaceDirectory.'/vendor.process-web-module';
        self::assertTrue(mkdir($moduleDirectory.'/server/bin', 0o775, true));
        self::assertTrue(mkdir($moduleDirectory.'/node_modules/example', 0o775, true));
        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'vendor.process-web-module',
            'name' => 'Process Web Module',
            'version' => '1.0.0',
            'runtime' => [
                'type' => 'process-web',
                'command' => 'node',
                'args' => [
                    'server/index.js',
                    '--port={{ port }}',
                ],
                'readyUrl' => 'http://127.0.0.1:{{ port }}/health',
            ],
        ], JSON_THROW_ON_ERROR));
        file_put_contents($moduleDirectory.'/server/index.js', 'console.log("process-web");');
        file_put_contents($moduleDirectory.'/server/bin/start', '#!/usr/bin/env node');
        file_put_contents($moduleDirectory.'/node_modules/example/index.js', 'export default true;');
        $targetPath = $this->workspaceDirectory.'/dist/process-web-module.zip';

        $result = new ModulePackageShipper()->ship($moduleDirectory, $targetPath);

        self::assertSame($targetPath, $result);
        self::assertFileExists($targetPath);
        self::assertZipContains($targetPath, 'manifest.json');
        self::assertZipContains($targetPath, 'server/index.js');
        self::assertZipContains($targetPath, 'server/bin/start');
        self::assertZipContains($targetPath, 'node_modules/example/index.js');
        self::assertZipNotContains($targetPath, 'composer.json');
    }

    /**
     * Ensures process runtime modules can ship their own non-PHP runtime files.
     */
    public function testShipSupportsProcessRuntimeWithoutComposer(): void
    {
        $moduleDirectory = $this->workspaceDirectory.'/vendor.process-runtime-module';
        self::assertTrue(mkdir($moduleDirectory.'/worker/bin', 0o775, true));
        self::assertTrue(mkdir($moduleDirectory.'/node_modules/example', 0o775, true));
        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'vendor.process-runtime-module',
            'name' => 'Process Runtime Module',
            'version' => '1.0.0',
            'runtime' => [
                'type' => 'process-runtime',
                'mode' => 'on-demand',
                'command' => 'node',
                'args' => [
                    'worker/index.js',
                    '{{ route }}',
                ],
            ],
            'routes' => [
                [
                    'scheme' => 'babelchrome',
                    'host' => 'process-runtime',
                    'handler' => 'index',
                ],
            ],
        ], JSON_THROW_ON_ERROR));
        file_put_contents($moduleDirectory.'/worker/index.js', 'console.log("process-runtime");');
        file_put_contents($moduleDirectory.'/worker/bin/run', '#!/usr/bin/env node');
        file_put_contents($moduleDirectory.'/node_modules/example/index.js', 'export default true;');
        $targetPath = $this->workspaceDirectory.'/dist/process-runtime-module.zip';

        $result = new ModulePackageShipper()->ship($moduleDirectory, $targetPath);

        self::assertSame($targetPath, $result);
        self::assertFileExists($targetPath);
        self::assertZipContains($targetPath, 'manifest.json');
        self::assertZipContains($targetPath, 'worker/index.js');
        self::assertZipContains($targetPath, 'worker/bin/run');
        self::assertZipContains($targetPath, 'node_modules/example/index.js');
        self::assertZipNotContains($targetPath, 'composer.json');
    }

    /**
     * Ensures a module without vendor cannot be shipped.
     */
    public function testShipRejectsMissingVendor(): void
    {
        $moduleDirectory = $this->moduleDirectory('vendor.missing-vendor', '1.0.0');
        $this->removeDirectory($moduleDirectory.'/vendor');

        $this->expectException(ModuleShippingException::class);
        $this->expectExceptionMessage('Missing module vendor directory');

        new ModulePackageShipper()->ship($moduleDirectory);
    }

    /**
     * Creates a sample module directory.
     *
     * @param string                                       $moduleId the module id
     * @param string                                       $version  the module version
     * @param array{type: string, entrypoint: string}|null $runtime  the optional runtime declaration
     *
     * @return string the module directory
     */
    private function moduleDirectory(string $moduleId, string $version, ?array $runtime = null): string
    {
        $moduleDirectory = $this->workspaceDirectory.'/'.$moduleId;
        foreach ([
            'src',
            'assets/app',
            'bin',
            'config',
            'vendor',
            'public/styles',
            'tests',
            'var/cache',
            'ai',
            'node_modules/package',
        ] as $directory) {
            if (!mkdir($moduleDirectory.'/'.$directory, 0o775, true) && !is_dir($moduleDirectory.'/'.$directory)) {
                self::fail(sprintf('Unable to create "%s".', $directory));
            }
        }

        $manifest = [
            'id' => $moduleId,
            'name' => 'Shipped Module',
            'version' => $version,
            'requirements' => [
                'php' => '>=8.4',
            ],
        ];
        if (null !== $runtime) {
            $manifest['runtime'] = $runtime;
        }

        file_put_contents($moduleDirectory.'/manifest.json', json_encode($manifest, JSON_THROW_ON_ERROR));
        file_put_contents($moduleDirectory.'/composer.json', '{}');
        file_put_contents($moduleDirectory.'/src/ShippedModule.php', '<?php');
        file_put_contents($moduleDirectory.'/assets/app/module.ts', 'export default true;');
        file_put_contents($moduleDirectory.'/bin/console', '#!/usr/bin/env php');
        file_put_contents($moduleDirectory.'/config/bundles.php', '<?php return [];');
        file_put_contents($moduleDirectory.'/importmap.php', '<?php return [];');
        file_put_contents($moduleDirectory.'/phpstan.neon', 'parameters:');
        file_put_contents($moduleDirectory.'/phpunit.xml.dist', '<phpunit/>');
        file_put_contents($moduleDirectory.'/.php-cs-fixer.dist.php', '<?php');
        file_put_contents($moduleDirectory.'/.phpunit.result.cache', '{}');
        file_put_contents($moduleDirectory.'/vendor/autoload.php', '<?php return true;');
        file_put_contents($moduleDirectory.'/public/styles/demo.css', '.demo {}');
        file_put_contents($moduleDirectory.'/tests/ModuleTest.php', '<?php');
        file_put_contents($moduleDirectory.'/var/cache/item', 'cache');
        file_put_contents($moduleDirectory.'/ai/CODEX.md', '# State');
        file_put_contents($moduleDirectory.'/node_modules/package/index.js', 'export default true;');
        file_put_contents($moduleDirectory.'/nested.zip', 'zip');

        return $moduleDirectory;
    }

    /**
     * Asserts that a zip archive contains a path.
     *
     * @param string $zipPath the zip path
     * @param string $path    the expected entry path
     */
    private static function assertZipContains(string $zipPath, string $path): void
    {
        $zip = new \ZipArchive();
        self::assertTrue($zip->open($zipPath));
        self::assertNotFalse($zip->locateName($path), sprintf('Failed asserting that zip contains "%s".', $path));
        $zip->close();
    }

    /**
     * Asserts that a zip archive does not contain a path.
     *
     * @param string $zipPath the zip path
     * @param string $path    the unexpected entry path
     */
    private static function assertZipNotContains(string $zipPath, string $path): void
    {
        $zip = new \ZipArchive();
        self::assertTrue($zip->open($zipPath));
        self::assertFalse($zip->locateName($path), sprintf('Failed asserting that zip does not contain "%s".', $path));
        $zip->close();
    }

    /**
     * Removes a directory recursively.
     *
     * @param string $directory the directory to remove
     */
    private function removeDirectory(string $directory): void
    {
        if (!is_dir($directory)) {
            return;
        }

        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($directory, \FilesystemIterator::SKIP_DOTS),
            \RecursiveIteratorIterator::CHILD_FIRST,
        );

        foreach ($iterator as $fileInfo) {
            if (!$fileInfo instanceof \SplFileInfo) {
                continue;
            }

            if ($fileInfo->isDir()) {
                rmdir($fileInfo->getPathname());
            } else {
                unlink($fileInfo->getPathname());
            }
        }

        rmdir($directory);
    }
}
