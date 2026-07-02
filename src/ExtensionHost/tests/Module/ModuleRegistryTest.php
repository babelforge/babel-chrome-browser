<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Tests\Module;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleManifestException;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleAutoloadRegistrar;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleManifest;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleMenuItem;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRegistry;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\TestCase;

/**
 * Verifies BabelChrome PHP module discovery.
 */
#[CoversClass(ModuleManifest::class)]
#[CoversClass(ModuleMenuItem::class)]
#[CoversClass(ModuleAutoloadRegistrar::class)]
#[CoversClass(ModuleRegistry::class)]
final class ModuleRegistryTest extends TestCase
{
    private string $workspaceDirectory;

    /**
     * Creates an isolated registry workspace.
     */
    protected function setUp(): void
    {
        parent::setUp();

        $this->workspaceDirectory = sys_get_temp_dir().'/babelchrome-module-registry-test-'.bin2hex(random_bytes(6));
        if (!mkdir($this->workspaceDirectory, 0o775, true) && !is_dir($this->workspaceDirectory)) {
            self::fail('Unable to create test workspace directory.');
        }
    }

    /**
     * Ensures source modules are not synchronized into the runtime automatically.
     */
    public function testSourceModulesAreNotSynchronizedAsRuntimeModules(): void
    {
        $registry = new ModuleRegistry(dirname(__DIR__, 5).'/modules', $this->workspaceDirectory.'/Modules');

        self::assertSame([], $registry->all());
        self::assertNull($registry->find('babelforge.markdown-viewer'));
        self::assertDirectoryDoesNotExist($this->workspaceDirectory.'/Modules/babelforge.markdown-viewer');
    }

    /**
     * Ensures user modules can be discovered with their own vendor.
     */
    public function testUserModuleWithOwnVendorIsDiscovered(): void
    {
        $moduleDirectory = $this->workspaceDirectory.'/Modules/vendor.example-module';
        self::assertTrue(mkdir($moduleDirectory.'/vendor', 0o775, true));
        file_put_contents($moduleDirectory.'/vendor/autoload.php', '<?php return true;');
        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'vendor.example-module',
            'name' => 'Example Module',
            'version' => '1.2.3',
            'requirements' => [
                'php' => '>=8.4',
            ],
            'description' => 'A test module.',
            'entrypoint' => 'Vendor\\Example\\Module',
            'fileTypes' => ['txt'],
            'file-type-handler' => [
                'fileTypes' => ['.TXT', 'log', 'txt'],
            ],
            'hooks' => ['url.resolve'],
            'permissions' => ['serve-assets'],
            'menuItems' => [
                [
                    'id' => 'example.open',
                    'label' => 'Open Example',
                    'hook' => 'url.resolve',
                    'route' => 'babelchrome://example',
                    'contexts' => ['example'],
                    'shortcut' => 'Cmd+E',
                ],
            ],
        ], JSON_THROW_ON_ERROR));

        $registry = new ModuleRegistry($this->workspaceDirectory.'/Catalog', $this->workspaceDirectory.'/Modules');
        $module = $registry->find('vendor.example-module');

        self::assertNotNull($module);
        self::assertTrue($module->enabled);
        self::assertTrue($module->hasIsolatedVendor());
        self::assertCount(1, $module->menuItems);
        self::assertSame('Open Example', $module->menuItems[0]->label);
        self::assertSame(['example'], $module->menuItems[0]->contexts);
        self::assertSame('Cmd+E', $module->menuItems[0]->shortcut);
        self::assertSame('>=8.4', $module->phpRequirement);
        self::assertSame(['txt', 'log'], $module->fileTypeHandlerFileTypes);
        $exportedModule = $module->toArray();
        $requirements = $exportedModule['requirements'] ?? null;
        $fileTypeHandler = $exportedModule['fileTypeHandler'] ?? null;

        self::assertIsArray($requirements);
        self::assertSame('>=8.4', $requirements['php'] ?? null);
        self::assertIsArray($fileTypeHandler);
        self::assertSame(['txt', 'log'], $fileTypeHandler['fileTypes'] ?? null);
    }

    /**
     * Ensures backup directories are ignored during module discovery.
     */
    public function testBackupModuleDirectoriesAreIgnored(): void
    {
        $moduleDirectory = $this->workspaceDirectory.'/Modules/vendor.example-module.backup.20260702120000';
        self::assertTrue(mkdir($moduleDirectory.'/vendor', 0o775, true));
        file_put_contents($moduleDirectory.'/vendor/autoload.php', '<?php return true;');
        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'vendor.example-module',
            'name' => 'Example Module',
            'version' => '1.2.3',
            'requirements' => [
                'php' => '>=8.4',
            ],
            'description' => 'A backup module.',
            'entrypoint' => 'Vendor\\Example\\Module',
        ], JSON_THROW_ON_ERROR));

        $registry = new ModuleRegistry($this->workspaceDirectory.'/Catalog', $this->workspaceDirectory.'/Modules');

        self::assertSame([], $registry->all());
        self::assertNull($registry->find('vendor.example-module'));
    }

    /**
     * Ensures legacy viewer manifests advertise their fileTypes as handler extensions.
     */
    public function testLegacyManifestFileTypesAreAdvertisedAsHandlerExtensions(): void
    {
        $moduleDirectory = $this->workspaceDirectory.'/Modules/vendor.legacy-viewer';
        self::assertTrue(mkdir($moduleDirectory.'/vendor', 0o775, true));
        file_put_contents($moduleDirectory.'/vendor/autoload.php', '<?php return true;');
        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'vendor.legacy-viewer',
            'name' => 'Legacy Viewer',
            'version' => '1.0.0',
            'requirements' => [
                'php' => '>=8.4',
            ],
            'type' => 'viewer',
            'fileTypes' => ['.MD', 'markdown', 'md'],
        ], JSON_THROW_ON_ERROR));

        $registry = new ModuleRegistry($this->workspaceDirectory.'/Catalog', $this->workspaceDirectory.'/Modules');
        $module = $registry->find('vendor.legacy-viewer');

        self::assertNotNull($module);
        self::assertSame(['md', 'markdown'], $module->fileTypeHandlerFileTypes);
    }

    /**
     * Ensures module autoloaders are registered from their own vendor directory.
     */
    public function testModuleAutoloadRegistrarLoadsOwnVendor(): void
    {
        $moduleDirectory = $this->workspaceDirectory.'/Modules/vendor.autoload-module';
        self::assertTrue(mkdir($moduleDirectory.'/vendor', 0o775, true));
        file_put_contents($moduleDirectory.'/vendor/autoload.php', '<?php class BabelChromeModuleAutoloadLoadedForTest {}');
        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'vendor.autoload-module',
            'name' => 'Autoload Module',
            'version' => '1.0.0',
            'requirements' => [
                'php' => '>=8.4',
            ],
        ], JSON_THROW_ON_ERROR));

        $registry = new ModuleRegistry($this->workspaceDirectory.'/Catalog', $this->workspaceDirectory.'/Modules');
        $registrar = new ModuleAutoloadRegistrar($registry);

        $registered = $registrar->registerEnabledModuleAutoloaders();

        self::assertSame([$moduleDirectory.'/vendor/autoload.php'], $registered);
        self::assertTrue(class_exists('BabelChromeModuleAutoloadLoadedForTest', false));
    }

    /**
     * Ensures manifests must declare a PHP version requirement.
     */
    public function testManifestWithoutPhpRequirementIsRejected(): void
    {
        $moduleDirectory = $this->workspaceDirectory.'/Modules/vendor.missing-php-requirement';
        self::assertTrue(mkdir($moduleDirectory, 0o775, true));
        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'vendor.missing-php-requirement',
            'name' => 'Missing PHP Requirement',
            'version' => '1.0.0',
        ], JSON_THROW_ON_ERROR));

        $registry = new ModuleRegistry($this->workspaceDirectory.'/Catalog', $this->workspaceDirectory.'/Modules');

        $this->expectException(ModuleManifestException::class);
        $this->expectExceptionMessage('requirements.php');
        $registry->all();
    }

    /**
     * Ensures manifests are rejected when the current PHP version is too old.
     */
    public function testManifestWithUnsupportedPhpRequirementIsRejected(): void
    {
        $moduleDirectory = $this->workspaceDirectory.'/Modules/vendor.future-php';
        self::assertTrue(mkdir($moduleDirectory, 0o775, true));
        file_put_contents($moduleDirectory.'/manifest.json', json_encode([
            'id' => 'vendor.future-php',
            'name' => 'Future PHP Module',
            'version' => '1.0.0',
            'requirements' => [
                'php' => '>99.0',
            ],
        ], JSON_THROW_ON_ERROR));

        $registry = new ModuleRegistry($this->workspaceDirectory.'/Catalog', $this->workspaceDirectory.'/Modules');

        $this->expectException(ModuleManifestException::class);
        $this->expectExceptionMessage('requires PHP');
        $registry->all();
    }

    /**
     * Ensures invalid manifests are rejected.
     */
    public function testInvalidManifestIsRejected(): void
    {
        $moduleDirectory = $this->workspaceDirectory.'/Modules/invalid';
        self::assertTrue(mkdir($moduleDirectory, 0o775, true));
        file_put_contents($moduleDirectory.'/manifest.json', '{"id": ""}');

        $registry = new ModuleRegistry($this->workspaceDirectory.'/Catalog', $this->workspaceDirectory.'/Modules');

        $this->expectException(ModuleManifestException::class);
        $registry->all();
    }
}
