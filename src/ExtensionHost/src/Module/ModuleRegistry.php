<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleManifestException;

/**
 * Discovers and exposes BabelChrome PHP modules.
 */
final class ModuleRegistry
{
    /**
     * @var array<string, ModuleManifest>|null
     */
    private ?array $modules = null;

    /**
     * @param string|null $unusedModuleCatalogDirectory unused legacy argument
     * @param string|null $userModulesDirectory         the user module installation directory
     */
    public function __construct(
        ?string $unusedModuleCatalogDirectory = null,
        private readonly ?string $userModulesDirectory = null,
    ) {
        unset($unusedModuleCatalogDirectory);
    }

    /**
     * Returns all discovered modules.
     *
     * @return list<ModuleManifest> the discovered modules
     */
    public function all(): array
    {
        $modules = $this->modules();
        ksort($modules);

        return array_values($modules);
    }

    /**
     * Returns enabled modules only.
     *
     * @return list<ModuleManifest> the enabled modules
     */
    public function enabled(): array
    {
        return array_values(array_filter(
            $this->all(),
            static fn (ModuleManifest $module): bool => $module->enabled,
        ));
    }

    /**
     * Returns a module by id.
     *
     * @param string $id the module id
     *
     * @return ModuleManifest|null the module when found
     */
    public function find(string $id): ?ModuleManifest
    {
        return $this->modules()[$id] ?? null;
    }

    /**
     * Clears the module discovery cache.
     */
    public function reload(): void
    {
        $this->modules = null;
    }

    /**
     * Returns the user module installation directory.
     *
     * @return string the user module directory
     */
    public function userModulesDirectory(): string
    {
        if (null !== $this->userModulesDirectory) {
            return $this->userModulesDirectory;
        }

        $home = $this->environmentString('HOME', sys_get_temp_dir());

        return $home.'/Library/Application Support/BabelForge/BabelChrome/Modules';
    }

    /**
     * Loads all module manifests once.
     *
     * @return array<string, ModuleManifest> modules indexed by id
     */
    private function modules(): array
    {
        if (null !== $this->modules) {
            return $this->modules;
        }

        $modules = [];
        foreach ($this->userManifestFiles($this->userModulesDirectory()) as $manifestFile) {
            $module = $this->loadManifest($manifestFile, dirname($manifestFile));
            $modules[$module->id] = $module;
        }

        $this->modules = $modules;

        return $this->modules;
    }

    /**
     * Returns user module manifest files.
     *
     * @param string $directory the user module root directory
     *
     * @return list<string> the manifest files
     */
    private function userManifestFiles(string $directory): array
    {
        if (!is_dir($directory)) {
            return [];
        }

        $files = glob(rtrim($directory, '/').'/*/manifest.json');
        if (false === $files) {
            return [];
        }

        sort($files);

        return $files;
    }

    /**
     * Loads one module manifest file.
     *
     * @param string $manifestFile the manifest file path
     * @param string $modulePath   the module root path
     *
     * @return ModuleManifest the loaded manifest
     *
     * @throws ModuleManifestException when the manifest cannot be read
     */
    private function loadManifest(string $manifestFile, string $modulePath): ModuleManifest
    {
        $content = file_get_contents($manifestFile);
        if (false === $content) {
            throw new ModuleManifestException(sprintf('Unable to read module manifest "%s".', $manifestFile));
        }

        $decoded = json_decode($content, true);
        if (!is_array($decoded)) {
            throw new ModuleManifestException(sprintf('Unable to decode module manifest "%s".', $manifestFile));
        }

        /** @var array<string, mixed> $data */
        $data = $decoded;
        $data['path'] = $modulePath;

        return ModuleManifest::fromArray($data, $modulePath);
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
