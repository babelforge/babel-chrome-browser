<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Service;

/**
 * Provides macOS "Open With" application discovery and dispatch.
 */
final readonly class OpenWithService
{
    /**
     * Returns applications that can reasonably open one extension.
     *
     * @param string $extension the file extension without a leading dot
     *
     * @return array{default: string|null, apps: list<array{applicationId: string, name: string, path: string}>} the application list
     *
     * @throws \RuntimeException when the state directory cannot be created
     */
    public function applicationsForExtension(string $extension): array
    {
        $extension = $this->normalizedExtension($extension);
        $apps = $this->matchingApplications($extension);
        $default = $this->storedDefaultApplicationId($extension);
        if (null !== $default && !$this->containsApplicationId($apps, $default)) {
            $default = null;
        }

        return [
            'default' => $default,
            'apps' => $apps,
        ];
    }

    /**
     * Stores the shared default application for one extension.
     *
     * @param string $extension     the file extension without a leading dot
     * @param string $applicationId the application bundle identifier
     *
     * @return bool true when the preference can be stored
     *
     * @throws \RuntimeException when the preferences cannot be written
     */
    public function setDefaultApplication(string $extension, string $applicationId): bool
    {
        $extension = $this->normalizedExtension($extension);
        $applicationId = trim($applicationId);
        if ('' === $extension || '' === $applicationId) {
            return false;
        }

        $preferences = $this->readPreferences();
        $preferences[$extension] = $applicationId;
        $this->writePreferences($preferences);

        return true;
    }

    /**
     * Opens one file with either a selected application or the macOS default application.
     *
     * @param string      $filePath      the local file path
     * @param string|null $applicationId the selected application bundle identifier
     *
     * @return array{ok: bool, error?: string} the open result
     */
    public function openFile(string $filePath, ?string $applicationId): array
    {
        if (!is_file($filePath)) {
            return [
                'ok' => false,
                'error' => sprintf('File "%s" does not exist.', $filePath),
            ];
        }

        $applicationId = null === $applicationId ? '' : trim($applicationId);
        $command = '' === $applicationId
            ? sprintf('/usr/bin/open %s', escapeshellarg($filePath))
            : sprintf('/usr/bin/open -b %s %s', escapeshellarg($applicationId), escapeshellarg($filePath));
        $command = sprintf('(%s) >/dev/null 2>&1 &', $command);

        $output = [];
        $statusCode = 0;
        exec($command, $output, $statusCode);
        if (0 !== $statusCode) {
            return [
                'ok' => false,
                'error' => implode("\n", $output),
            ];
        }

        return ['ok' => true];
    }

    /**
     * Returns matching application bundles by reading installed app manifests.
     *
     * @param string $extension the normalized extension
     *
     * @return list<array{applicationId: string, name: string, path: string}> the matching applications
     */
    private function matchingApplications(string $extension): array
    {
        $apps = [];
        foreach ($this->applicationBundlePaths() as $path) {
            $metadata = $this->applicationMetadata($path);
            if (null === $metadata || !$this->supportsExtension($metadata['documentTypes'], $extension)) {
                continue;
            }

            $apps[$metadata['applicationId']] = [
                'applicationId' => $metadata['applicationId'],
                'name' => $metadata['name'],
                'path' => $path,
            ];
        }

        uasort($apps, static fn (array $left, array $right): int => strcasecmp($left['name'], $right['name']));

        return array_values($apps);
    }

    /**
     * Returns discovered application bundle paths.
     *
     * @return list<string> the application bundle paths
     */
    private function applicationBundlePaths(): array
    {
        $patterns = [
            '/Applications/*.app',
            '/Applications/Utilities/*.app',
            '/System/Applications/*.app',
            '/System/Applications/Utilities/*.app',
            rtrim((string) getenv('HOME'), '/').'/Applications/*.app',
        ];
        $paths = [];
        foreach ($patterns as $pattern) {
            $matchedPaths = glob($pattern, GLOB_ONLYDIR);
            if (!is_array($matchedPaths)) {
                continue;
            }

            foreach ($matchedPaths as $path) {
                if (str_ends_with($path, '.app')) {
                    $paths[$path] = $path;
                }
            }
        }

        return array_values($paths);
    }

    /**
     * Reads metadata from one application bundle.
     *
     * @param string $applicationPath the application bundle path
     *
     * @return array{applicationId: string, name: string, documentTypes: list<array<string, mixed>>}|null the metadata
     */
    private function applicationMetadata(string $applicationPath): ?array
    {
        $infoPlistPath = $applicationPath.'/Contents/Info.plist';
        if (!is_file($infoPlistPath)) {
            return null;
        }

        $command = sprintf('/usr/bin/plutil -convert json -o - %s 2>/dev/null', escapeshellarg($infoPlistPath));
        $json = shell_exec($command);
        if (!is_string($json) || '' === trim($json)) {
            return null;
        }

        $plist = json_decode($json, true);
        if (!is_array($plist)) {
            return null;
        }

        $applicationId = $plist['CFBundleIdentifier'] ?? null;
        if (!is_string($applicationId) || '' === $applicationId) {
            return null;
        }

        $name = $plist['CFBundleDisplayName'] ?? $plist['CFBundleName'] ?? basename($applicationPath, '.app');
        if (!is_string($name) || '' === $name) {
            $name = basename($applicationPath, '.app');
        }

        $documentTypes = $plist['CFBundleDocumentTypes'] ?? [];
        if (!is_array($documentTypes)) {
            $documentTypes = [];
        }
        $normalizedDocumentTypes = [];
        foreach ($documentTypes as $documentType) {
            if (!is_array($documentType)) {
                continue;
            }

            $normalizedDocumentType = [];
            foreach ($documentType as $key => $value) {
                if (is_string($key)) {
                    $normalizedDocumentType[$key] = $value;
                }
            }

            $normalizedDocumentTypes[] = $normalizedDocumentType;
        }

        return [
            'applicationId' => $applicationId,
            'name' => $name,
            'documentTypes' => $normalizedDocumentTypes,
        ];
    }

    /**
     * Returns whether application document types support one extension.
     *
     * @param list<array<string, mixed>> $documentTypes the app document types
     * @param string                     $extension     the normalized extension
     *
     * @return bool true when the extension is supported
     */
    private function supportsExtension(array $documentTypes, string $extension): bool
    {
        if ('' === $extension) {
            return false;
        }

        foreach ($documentTypes as $documentType) {
            $extensions = $documentType['CFBundleTypeExtensions'] ?? [];
            if (is_array($extensions)) {
                foreach ($extensions as $candidate) {
                    if (is_string($candidate) && ('*' === $candidate || $extension === strtolower(ltrim($candidate, '.')))) {
                        return true;
                    }
                }
            }

            $contentTypes = $documentType['LSItemContentTypes'] ?? [];
            if (is_array($contentTypes) && $this->genericContentTypesSupportExtension($contentTypes, $extension)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Returns whether generic UTIs are suitable for one extension.
     *
     * @param array<mixed> $contentTypes the declared content types
     * @param string       $extension    the normalized extension
     *
     * @return bool true when generic content types apply
     */
    private function genericContentTypesSupportExtension(array $contentTypes, string $extension): bool
    {
        $textExtensions = ['css', 'csv', 'htm', 'html', 'js', 'json', 'markdown', 'md', 'mdown', 'mermaid', 'mkd', 'mmd', 'php', 'txt', 'xml', 'yaml', 'yml'];
        foreach ($contentTypes as $contentType) {
            if (!is_string($contentType)) {
                continue;
            }

            if (in_array($contentType, ['public.data', 'public.item', 'public.content'], true)) {
                return true;
            }

            if (in_array($extension, $textExtensions, true) && in_array($contentType, ['public.text', 'public.plain-text', 'public.source-code'], true)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Returns the stored default application id for one extension.
     *
     * @param string $extension the normalized extension
     *
     * @return string|null the stored application id
     *
     * @throws \RuntimeException when the state directory cannot be created
     */
    private function storedDefaultApplicationId(string $extension): ?string
    {
        $preferences = $this->readPreferences();
        $applicationId = $preferences[$extension] ?? null;

        return is_string($applicationId) && '' !== $applicationId ? $applicationId : null;
    }

    /**
     * Returns whether an application id exists in an app list.
     *
     * @param list<array{applicationId: string, name: string, path: string}> $apps          the applications
     * @param string                                                         $applicationId the application id
     *
     * @return bool true when found
     */
    private function containsApplicationId(array $apps, string $applicationId): bool
    {
        foreach ($apps as $app) {
            if ($applicationId === $app['applicationId']) {
                return true;
            }
        }

        return false;
    }

    /**
     * Normalizes a file extension.
     *
     * @param string $extension the raw extension
     *
     * @return string the normalized extension
     */
    private function normalizedExtension(string $extension): string
    {
        return strtolower(ltrim(trim($extension), '.'));
    }

    /**
     * Reads open-with preferences.
     *
     * @return array<string, string> the preferences
     *
     * @throws \RuntimeException when the state directory cannot be created
     */
    private function readPreferences(): array
    {
        $path = $this->preferencesPath();
        if (!is_file($path)) {
            return [];
        }

        $content = file_get_contents($path);
        if (false === $content || '' === $content) {
            return [];
        }

        $data = json_decode($content, true);
        if (!is_array($data)) {
            return [];
        }

        $preferences = [];
        foreach ($data as $extension => $applicationId) {
            if (is_string($extension) && is_string($applicationId) && '' !== $extension && '' !== $applicationId) {
                $preferences[$extension] = $applicationId;
            }
        }

        return $preferences;
    }

    /**
     * Writes open-with preferences.
     *
     * @param array<string, string> $preferences the preferences
     *
     * @throws \RuntimeException when the state directory cannot be created
     * @throws \RuntimeException when the preferences cannot be written
     */
    private function writePreferences(array $preferences): void
    {
        $json = json_encode($preferences, JSON_PRETTY_PRINT);
        if (false === $json || false === file_put_contents($this->preferencesPath(), $json, LOCK_EX)) {
            throw new \RuntimeException('Unable to write Open With preferences.');
        }
    }

    /**
     * Returns the open-with preferences path.
     *
     * @return string the preferences path
     *
     * @throws \RuntimeException when the state directory cannot be created
     */
    private function preferencesPath(): string
    {
        return $this->stateDirectory().'/open-with-preferences.json';
    }

    /**
     * Returns the writable state directory.
     *
     * @return string the writable state directory
     *
     * @throws \RuntimeException when the state directory cannot be created
     */
    private function stateDirectory(): string
    {
        $stateDirectory = $this->environmentString('BABELCHROME_VIEWER_STATE_DIR', '');
        if ('' === $stateDirectory) {
            $stateDirectory = sys_get_temp_dir().'/babel-chrome-local-viewer';
        }

        if (!is_dir($stateDirectory) && !mkdir($stateDirectory, 0o775, true) && !is_dir($stateDirectory)) {
            throw new \RuntimeException(sprintf('Unable to create state directory "%s".', $stateDirectory));
        }

        return $stateDirectory;
    }

    /**
     * Reads a string environment value.
     *
     * @param string $name    the environment variable name
     * @param string $default the default value
     *
     * @return string the resolved value
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
