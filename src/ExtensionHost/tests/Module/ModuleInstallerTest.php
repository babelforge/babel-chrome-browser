<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Tests\Module;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleInstallationException;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleInstaller;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRegistry;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\TestCase;

/**
 * Verifies user module installation.
 */
#[CoversClass(ModuleInstaller::class)]
final class ModuleInstallerTest extends TestCase
{
    private string $workspaceDirectory;

    /**
     * Creates an isolated installer workspace.
     */
    protected function setUp(): void
    {
        parent::setUp();

        $this->workspaceDirectory = sys_get_temp_dir().'/babelchrome-module-installer-test-'.bin2hex(random_bytes(6));
        if (!mkdir($this->workspaceDirectory, 0o775, true) && !is_dir($this->workspaceDirectory)) {
            self::fail('Unable to create test workspace directory.');
        }
    }

    /**
     * Ensures a valid zip module can be installed.
     */
    public function testInstallZipInstallsUserModule(): void
    {
        $zipPath = $this->moduleZip('vendor.installable-module', 'Installable Module');
        $registry = $this->registry();
        $installer = new ModuleInstaller($registry);

        $module = $installer->installZip($zipPath);

        self::assertSame('vendor.installable-module', $module->id);
        self::assertTrue($module->enabled);
        self::assertFileExists($this->workspaceDirectory.'/Modules/vendor.installable-module/vendor/autoload.php');
        self::assertNotNull($registry->find('vendor.installable-module'));
    }

    /**
     * Ensures installed modules can be disabled and enabled.
     */
    public function testSetEnabledUpdatesUserModuleManifest(): void
    {
        $zipPath = $this->moduleZip('vendor.toggle-module', 'Toggle Module');
        $registry = $this->registry();
        $installer = new ModuleInstaller($registry);
        $installer->installZip($zipPath);

        $disabledModule = $installer->setEnabled('vendor.toggle-module', false);
        $enabledModule = $installer->setEnabled('vendor.toggle-module', true);

        self::assertFalse($disabledModule->enabled);
        self::assertTrue($enabledModule->enabled);
    }

    /**
     * Ensures installing a zip for an existing user module updates it in place.
     */
    public function testInstallZipUpdatesExistingUserModule(): void
    {
        $registry = $this->registry();
        $installer = new ModuleInstaller($registry);
        $installer->installZip($this->moduleZip('vendor.updatable-module', 'Old Module', '1.0.0'));
        $installer->setEnabled('vendor.updatable-module', false);

        $module = $installer->installZip($this->moduleZip('vendor.updatable-module', 'New Module', '2.0.0'));

        self::assertSame('vendor.updatable-module', $module->id);
        self::assertSame('New Module', $module->name);
        self::assertSame('2.0.0', $module->version);
        self::assertFalse($module->enabled);
        self::assertNotNull($registry->find('vendor.updatable-module'));
    }

    /**
     * Ensures a static web module zip can be installed without Composer files.
     */
    public function testInstallZipInstallsStaticWebModule(): void
    {
        $zipPath = $this->staticWebModuleZip('vendor.static-web-module', 'Static Web Module');
        $registry = $this->registry();
        $installer = new ModuleInstaller($registry);

        $module = $installer->installZip($zipPath);

        self::assertSame('vendor.static-web-module', $module->id);
        self::assertSame('static-web', $module->runtimeType);
        self::assertSame('', $module->phpRequirement);
        self::assertFileExists($this->workspaceDirectory.'/Modules/vendor.static-web-module/public/index.html');
        self::assertNotNull($registry->find('vendor.static-web-module'));
    }

    /**
     * Ensures installed modules can be removed.
     */
    public function testRemoveDeletesUserModule(): void
    {
        $zipPath = $this->moduleZip('vendor.removable-module', 'Removable Module');
        $registry = $this->registry();
        $installer = new ModuleInstaller($registry);
        $installer->installZip($zipPath);

        $installer->remove('vendor.removable-module');

        self::assertDirectoryDoesNotExist($this->workspaceDirectory.'/Modules/vendor.removable-module');
        self::assertNull($registry->find('vendor.removable-module'));
    }

    /**
     * Ensures unsafe zip paths are rejected.
     */
    public function testInstallZipRejectsUnsafeEntries(): void
    {
        $zipPath = $this->workspaceDirectory.'/unsafe.zip';
        $zip = new \ZipArchive();
        self::assertTrue($zip->open($zipPath, \ZipArchive::CREATE));
        $zip->addFromString('../manifest.json', '{}');
        $zip->close();

        $this->expectException(ModuleInstallationException::class);
        $this->expectExceptionMessage('unsafe entry');

        new ModuleInstaller($this->registry())->installZip($zipPath);
    }

    /**
     * Creates a registry for tests.
     *
     * @return ModuleRegistry the registry
     */
    private function registry(): ModuleRegistry
    {
        return new ModuleRegistry($this->workspaceDirectory.'/Catalog', $this->workspaceDirectory.'/Modules');
    }

    /**
     * Creates a test module zip.
     *
     * @param string $moduleId the module id
     * @param string $name     the module name
     * @param string $version  the module version
     *
     * @return string the zip path
     */
    private function moduleZip(string $moduleId, string $name, string $version = '1.0.0'): string
    {
        $sourceDirectory = $this->workspaceDirectory.'/source-'.$moduleId.'-'.$version;
        self::assertTrue(mkdir($sourceDirectory.'/vendor', 0o775, true));
        self::assertTrue(mkdir($sourceDirectory.'/src', 0o775, true));
        file_put_contents($sourceDirectory.'/vendor/autoload.php', '<?php return true;');
        file_put_contents($sourceDirectory.'/composer.json', '{}');
        file_put_contents($sourceDirectory.'/manifest.json', json_encode([
            'id' => $moduleId,
            'name' => $name,
            'version' => $version,
            'requirements' => [
                'php' => '>=8.4',
            ],
            'description' => 'A test module.',
            'fileTypes' => ['txt'],
            'hooks' => ['url.resolve'],
            'permissions' => ['serve-assets'],
        ], JSON_THROW_ON_ERROR));

        $zipPath = $this->workspaceDirectory.'/'.$moduleId.'-'.$version.'.zip';
        $zip = new \ZipArchive();
        self::assertTrue($zip->open($zipPath, \ZipArchive::CREATE));
        $zip->addFile($sourceDirectory.'/manifest.json', 'manifest.json');
        $zip->addFile($sourceDirectory.'/composer.json', 'composer.json');
        $zip->addFile($sourceDirectory.'/vendor/autoload.php', 'vendor/autoload.php');
        $zip->close();

        return $zipPath;
    }

    /**
     * Creates a test static web module zip.
     *
     * @param string $moduleId the module id
     * @param string $name     the module name
     *
     * @return string the zip path
     */
    private function staticWebModuleZip(string $moduleId, string $name): string
    {
        $sourceDirectory = $this->workspaceDirectory.'/source-'.$moduleId;
        self::assertTrue(mkdir($sourceDirectory.'/public', 0o775, true));
        file_put_contents($sourceDirectory.'/manifest.json', json_encode([
            'id' => $moduleId,
            'name' => $name,
            'version' => '1.0.0',
            'runtime' => [
                'type' => 'static-web',
                'documentRoot' => 'public',
                'index' => 'index.html',
            ],
        ], JSON_THROW_ON_ERROR));
        file_put_contents($sourceDirectory.'/public/index.html', '<!doctype html><title>Static</title>');

        $zipPath = $this->workspaceDirectory.'/'.$moduleId.'-1.0.0.zip';
        $zip = new \ZipArchive();
        self::assertTrue($zip->open($zipPath, \ZipArchive::CREATE));
        $zip->addFile($sourceDirectory.'/manifest.json', 'manifest.json');
        $zip->addFile($sourceDirectory.'/public/index.html', 'public/index.html');
        $zip->close();

        return $zipPath;
    }
}
