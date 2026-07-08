<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Tests\Module;

use BabelForge\BabelChrome\LocalViewer\Module\ModuleCommandDefinition;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleCommandRunner;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleManifest;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleSetupRunner;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\TestCase;

/**
 * Verifies explicit module setup execution.
 */
#[CoversClass(ModuleCommandDefinition::class)]
#[CoversClass(ModuleCommandRunner::class)]
#[CoversClass(ModuleManifest::class)]
#[CoversClass(ModuleSetupRunner::class)]
final class ModuleSetupRunnerTest extends TestCase
{
    private string $moduleDirectory;

    /**
     * Creates an isolated module directory.
     */
    protected function setUp(): void
    {
        parent::setUp();

        $this->moduleDirectory = sys_get_temp_dir().'/babelchrome-setup-test-'.bin2hex(random_bytes(6));
        if (!mkdir($this->moduleDirectory, 0o775, true) && !is_dir($this->moduleDirectory)) {
            self::fail('Unable to create setup test module directory.');
        }
    }

    /**
     * Ensures modules without setup return a non-executed result.
     */
    public function testModuleWithoutSetupDoesNotRun(): void
    {
        $result = $this->runner()->run($this->module());

        self::assertFalse($result['ok'] ?? true);
        self::assertSame('missing-setup', $result['state'] ?? null);
    }

    /**
     * Ensures setup JSON output is parsed.
     */
    public function testCommandSetupJsonOutputIsParsed(): void
    {
        $module = $this->module([
            'setup' => [
                'type' => 'command',
                'command' => escapeshellarg(PHP_BINARY).' -r '.escapeshellarg('echo json_encode(["ok" => true, "status" => "installed", "messages" => ["Installed"]]);'),
            ],
        ]);

        $result = $this->runner()->run($module);

        self::assertTrue($result['ok'] ?? false);
        self::assertSame('installed', $result['state'] ?? null);
        self::assertSame(['Installed'], $result['messages'] ?? null);
        self::assertSame(0, $result['exitCode'] ?? null);
    }

    /**
     * Ensures failed setup commands keep logs visible.
     */
    public function testFailedSetupKeepsLogsVisible(): void
    {
        $module = $this->module([
            'setup' => [
                'type' => 'command',
                'command' => escapeshellarg(PHP_BINARY).' -r '.escapeshellarg('fwrite(STDERR, "Missing dependency"); exit(3);'),
            ],
        ]);

        $result = $this->runner()->run($module);

        self::assertFalse($result['ok'] ?? true);
        self::assertSame('failed', $result['state'] ?? null);
        self::assertSame(3, $result['exitCode'] ?? null);

        $stderr = $result['stderr'] ?? null;
        self::assertIsString($stderr);
        self::assertStringContainsString('Missing dependency', $stderr);
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
            'id' => 'vendor.setup-module',
            'name' => 'Setup Module',
            'version' => '1.0.0',
            'requirements' => [
                'php' => '>=8.4',
            ],
        ], $extraData), $this->moduleDirectory);
    }

    /**
     * Creates a setup runner.
     *
     * @return ModuleSetupRunner the setup runner
     */
    private function runner(): ModuleSetupRunner
    {
        return new ModuleSetupRunner(new ModuleCommandRunner());
    }
}
