<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleInstallationException;

/**
 * Installs and manages user modules.
 */
final readonly class ModuleInstaller
{
    /**
     * @param ModuleRegistry $moduleRegistry exposes module paths
     */
    public function __construct(
        private ModuleRegistry $moduleRegistry,
    ) {
    }

    /**
     * Installs a module from a zip archive.
     *
     * @param string $zipPath the zip archive path
     *
     * @return ModuleManifest the installed module manifest
     *
     * @throws ModuleInstallationException when the archive cannot be installed
     */
    public function installZip(string $zipPath): ModuleManifest
    {
        $this->requireZipExtension();

        if (!is_file($zipPath) || !is_readable($zipPath)) {
            throw new ModuleInstallationException('Module zip not found or not readable.');
        }

        $zip = new \ZipArchive();
        if (true !== $zip->open($zipPath)) {
            throw new ModuleInstallationException('Unable to open module zip.');
        }

        try {
            $this->validateZipEntries($zip);
            $temporaryDirectory = $this->temporaryDirectory();
            if (!$zip->extractTo($temporaryDirectory)) {
                throw new ModuleInstallationException('Unable to extract module zip.');
            }
        } finally {
            $zip->close();
        }

        $moduleRoot = $this->resolvedExtractedModuleRoot($temporaryDirectory);
        $manifest = $this->manifestFromDirectory($moduleRoot);
        $targetDirectory = $this->moduleTargetDirectory($manifest->id);
        $existingModule = $this->moduleRegistry->find($manifest->id);

        if (null !== $existingModule) {
            $this->replaceExistingModule($moduleRoot, $targetDirectory, $existingModule);
        } else {
            $this->installExtractedModule($moduleRoot, $targetDirectory);
        }

        $this->removeDirectory($temporaryDirectory);
        $this->moduleRegistry->reload();

        return $this->manifestFromDirectory($targetDirectory);
    }

    /**
     * Enables or disables a user module.
     *
     * @param string $moduleId the module id
     * @param bool   $enabled  whether the module should be enabled
     *
     * @return ModuleManifest the updated module manifest
     *
     * @throws ModuleInstallationException when the module cannot be updated
     */
    public function setEnabled(string $moduleId, bool $enabled): ModuleManifest
    {
        $module = $this->userModule($moduleId);
        $manifestPath = $module->path.'/manifest.json';
        $data = $this->manifestData($manifestPath);
        $data['enabled'] = $enabled;
        $this->writeManifestData($manifestPath, $data);
        $this->moduleRegistry->reload();

        return $this->manifestFromDirectory($module->path);
    }

    /**
     * Removes a user module.
     *
     * @param string $moduleId the module id
     *
     * @throws ModuleInstallationException when the module cannot be removed
     */
    public function remove(string $moduleId): void
    {
        $module = $this->userModule($moduleId);
        $this->removeDirectory($module->path);
        $this->moduleRegistry->reload();
    }

    /**
     * Ensures the Zip extension is available.
     *
     * @throws ModuleInstallationException when ZipArchive is unavailable
     */
    private function requireZipExtension(): void
    {
        if (!class_exists(\ZipArchive::class)) {
            throw new ModuleInstallationException('The PHP Zip extension is required to install modules.');
        }
    }

    /**
     * Validates archive entries before extraction.
     *
     * @param \ZipArchive $zip the zip archive
     *
     * @throws ModuleInstallationException when an entry is unsafe
     */
    private function validateZipEntries(\ZipArchive $zip): void
    {
        for ($index = 0; $index < $zip->numFiles; ++$index) {
            $name = $zip->getNameIndex($index);
            if (false === $name || '' === $name) {
                throw new ModuleInstallationException('Module zip contains an invalid entry.');
            }

            if (str_starts_with($name, '/') || str_contains($name, '\\') || str_contains($name, '../') || str_contains($name, '..'.DIRECTORY_SEPARATOR)) {
                throw new ModuleInstallationException(sprintf('Module zip contains an unsafe entry "%s".', $name));
            }

            $operatingSystem = 0;
            $attributes = 0;
            if (!$zip->getExternalAttributesIndex($index, $operatingSystem, $attributes)) {
                throw new ModuleInstallationException(sprintf('Unable to read zip entry attributes for "%s".', $name));
            }

            if (!is_int($attributes)) {
                throw new ModuleInstallationException(sprintf('Invalid zip entry attributes for "%s".', $name));
            }

            $fileType = ($attributes >> 16) & 0o170000;
            if (0o120000 === $fileType) {
                throw new ModuleInstallationException(sprintf('Module zip contains a symlink "%s".', $name));
            }
        }
    }

    /**
     * Creates a temporary extraction directory.
     *
     * @return string the temporary directory
     *
     * @throws ModuleInstallationException when the directory cannot be created
     */
    private function temporaryDirectory(): string
    {
        $directory = sys_get_temp_dir().'/babelchrome-module-install-'.bin2hex(random_bytes(8));
        if (!mkdir($directory, 0o775, true) && !is_dir($directory)) {
            throw new ModuleInstallationException('Unable to create a temporary module installation directory.');
        }

        return $directory;
    }

    /**
     * Resolves the module root after extraction.
     *
     * @param string $temporaryDirectory the temporary extraction directory
     *
     * @return string the extracted module root
     *
     * @throws ModuleInstallationException when manifest.json cannot be found
     */
    private function resolvedExtractedModuleRoot(string $temporaryDirectory): string
    {
        if (is_file($temporaryDirectory.'/manifest.json')) {
            return $temporaryDirectory;
        }

        $children = glob($temporaryDirectory.'/*');
        if (false === $children || 1 !== count($children) || !is_dir($children[0])) {
            throw new ModuleInstallationException('Module zip must contain manifest.json at its root or inside one top-level directory.');
        }

        if (!is_file($children[0].'/manifest.json')) {
            throw new ModuleInstallationException('Module zip does not contain manifest.json.');
        }

        return $children[0];
    }

    /**
     * Reads a manifest from a module directory.
     *
     * @param string $directory the module directory
     *
     * @return ModuleManifest the module manifest
     */
    private function manifestFromDirectory(string $directory): ModuleManifest
    {
        return ModuleManifest::fromArray($this->manifestData($directory.'/manifest.json'), $directory);
    }

    /**
     * Reads manifest data.
     *
     * @param string $manifestPath the manifest path
     *
     * @return array<string, mixed> the decoded manifest data
     *
     * @throws ModuleInstallationException when the manifest cannot be read
     */
    private function manifestData(string $manifestPath): array
    {
        $content = file_get_contents($manifestPath);
        if (false === $content) {
            throw new ModuleInstallationException('Unable to read module manifest.');
        }

        $decoded = json_decode($content, true);
        if (!is_array($decoded)) {
            throw new ModuleInstallationException('Unable to decode module manifest.');
        }

        /** @var array<string, mixed> $data */
        $data = $decoded;

        return $data;
    }

    /**
     * Writes manifest data.
     *
     * @param string               $manifestPath the manifest path
     * @param array<string, mixed> $data         the manifest data
     *
     * @throws ModuleInstallationException when the manifest cannot be written
     */
    private function writeManifestData(string $manifestPath, array $data): void
    {
        $encoded = json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        if (!is_string($encoded) || false === file_put_contents($manifestPath, $encoded."\n")) {
            throw new ModuleInstallationException('Unable to write module manifest.');
        }
    }

    /**
     * Installs a freshly extracted module directory.
     *
     * @param string $moduleRoot      the extracted module root
     * @param string $targetDirectory the target installation directory
     *
     * @throws ModuleInstallationException when the module cannot be moved
     */
    private function installExtractedModule(string $moduleRoot, string $targetDirectory): void
    {
        $parentDirectory = dirname($targetDirectory);
        if (!is_dir($parentDirectory) && !mkdir($parentDirectory, 0o775, true) && !is_dir($parentDirectory)) {
            throw new ModuleInstallationException('Unable to create modules directory.');
        }

        if (!rename($moduleRoot, $targetDirectory)) {
            throw new ModuleInstallationException('Unable to move module to the installation directory.');
        }
    }

    /**
     * Replaces an existing user module while preserving its enabled state.
     *
     * @param string         $moduleRoot      the extracted replacement module root
     * @param string         $targetDirectory the target installation directory
     * @param ModuleManifest $existingModule  the existing user module
     *
     * @throws ModuleInstallationException when the module cannot be replaced
     */
    private function replaceExistingModule(
        string $moduleRoot,
        string $targetDirectory,
        ModuleManifest $existingModule,
    ): void {
        $manifestPath = $moduleRoot.'/manifest.json';
        $data = $this->manifestData($manifestPath);
        $data['enabled'] = $existingModule->enabled;
        $this->writeManifestData($manifestPath, $data);

        $backupDirectory = $targetDirectory.'.backup-'.bin2hex(random_bytes(6));
        if (!rename($targetDirectory, $backupDirectory)) {
            throw new ModuleInstallationException(sprintf('Unable to prepare replacement for module "%s".', $existingModule->id));
        }

        if (!rename($moduleRoot, $targetDirectory)) {
            if (is_dir($backupDirectory)) {
                rename($backupDirectory, $targetDirectory);
            }

            throw new ModuleInstallationException(sprintf('Unable to replace module "%s".', $existingModule->id));
        }

        $this->removeDirectory($backupDirectory);
    }

    /**
     * Returns the target directory for a module id.
     *
     * @param string $moduleId the module id
     *
     * @return string the target directory
     */
    private function moduleTargetDirectory(string $moduleId): string
    {
        return rtrim($this->moduleRegistry->userModulesDirectory(), '/').'/'.$moduleId;
    }

    /**
     * Returns a user module by id.
     *
     * @param string $moduleId the module id
     *
     * @return ModuleManifest the user module
     *
     * @throws ModuleInstallationException when the module is missing or cannot be modified
     */
    private function userModule(string $moduleId): ModuleManifest
    {
        $module = $this->moduleRegistry->find($moduleId);
        if (null === $module) {
            throw new ModuleInstallationException(sprintf('Module "%s" is not installed.', $moduleId));
        }

        return $module;
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
                continue;
            }

            unlink($fileInfo->getPathname());
        }

        rmdir($directory);
    }
}
