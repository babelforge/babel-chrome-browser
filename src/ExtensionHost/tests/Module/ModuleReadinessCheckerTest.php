<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Tests\Module;

use BabelForge\BabelChrome\LocalViewer\Module\ModuleCommandDefinition;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleManifest;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleReadinessChecker;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\TestCase;

/**
 * Verifies optional module readiness checks.
 */
#[CoversClass(ModuleCommandDefinition::class)]
#[CoversClass(ModuleManifest::class)]
#[CoversClass(ModuleReadinessChecker::class)]
final class ModuleReadinessCheckerTest extends TestCase
{
    private string $moduleDirectory;

    /**
     * Creates an isolated module directory.
     */
    protected function setUp(): void
    {
        parent::setUp();

        $this->moduleDirectory = sys_get_temp_dir().'/babelchrome-readiness-test-'.bin2hex(random_bytes(6));
        if (!mkdir($this->moduleDirectory, 0o775, true) && !is_dir($this->moduleDirectory)) {
            self::fail('Unable to create readiness test module directory.');
        }
    }

    /**
     * Ensures modules without readiness are reported as unknown.
     */
    public function testModuleWithoutReadinessIsUnknown(): void
    {
        $module = $this->module();

        $status = new ModuleReadinessChecker()->status($module);

        self::assertSame('unknown', $status['state'] ?? null);
        self::assertNull($status['ready'] ?? null);
        self::assertFalse($status['canSetup'] ?? true);
    }

    /**
     * Ensures command readiness JSON is parsed.
     */
    public function testCommandReadinessIsParsed(): void
    {
        $module = $this->module([
            'readiness' => [
                'type' => 'command',
                'command' => escapeshellarg(PHP_BINARY).' -r '.escapeshellarg('echo json_encode(["ready" => true, "status" => "ready", "messages" => ["Ready"], "canSetup" => false]);'),
                'timeoutMs' => 5000,
            ],
        ]);

        $status = new ModuleReadinessChecker()->status($module);

        self::assertSame('ready', $status['state'] ?? null);
        self::assertTrue($status['ready'] ?? false);
        self::assertSame(['Ready'], $status['messages'] ?? null);
        self::assertFalse($status['canSetup'] ?? true);
    }

    /**
     * Ensures invalid command output fails readiness.
     */
    public function testInvalidCommandOutputFailsReadiness(): void
    {
        $module = $this->module([
            'readiness' => [
                'type' => 'command',
                'command' => escapeshellarg(PHP_BINARY).' -r '.escapeshellarg('echo "not-json";'),
                'timeoutMs' => 5000,
            ],
            'setup' => [
                'type' => 'command',
                'command' => './setup',
            ],
        ]);

        $status = new ModuleReadinessChecker()->status($module);

        self::assertSame('invalid-output', $status['state'] ?? null);
        self::assertFalse($status['ready'] ?? true);
        self::assertTrue($status['canSetup'] ?? false);
    }

    /**
     * Creates a module manifest.
     *
     * @param array<string, mixed> $extraData extra manifest data
     *
     * @return ModuleManifest the module manifest
     */
    private function module(array $extraData = []): ModuleManifest
    {
        return ModuleManifest::fromArray(array_merge([
            'id' => 'vendor.readiness-module',
            'name' => 'Readiness Module',
            'version' => '1.0.0',
            'requirements' => [
                'php' => '>=8.4',
            ],
        ], $extraData), $this->moduleDirectory);
    }
}
