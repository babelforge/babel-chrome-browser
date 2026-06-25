<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Service;

/**
 * Stores and reads source references shared with the native BabelChrome host.
 */
final readonly class SourceRegistry
{
    /**
     * Registers a source and returns its identifier.
     *
     * @param string $type  the source type
     * @param string $value the source value
     *
     * @return string the generated source identifier
     *
     * @throws \Random\RandomException when the source identifier cannot be generated
     * @throws \RuntimeException       when the registry cannot be written
     */
    public function register(string $type, string $value): string
    {
        $identifier = bin2hex(random_bytes(16));
        $registry = $this->readRegistry();
        $registry[$identifier] = [
            'type' => $type,
            'value' => $value,
            'createdAt' => time(),
        ];
        $this->writeRegistry($registry);

        return $identifier;
    }

    /**
     * Finds a registered source.
     *
     * @param string $identifier the source identifier
     *
     * @return array{type: string, value: string}|null the source data
     *
     * @throws \RuntimeException when the state directory cannot be created
     */
    public function find(string $identifier): ?array
    {
        $registry = $this->readRegistry();
        $entry = $registry[$identifier] ?? null;
        if (!is_array($entry)) {
            return null;
        }

        $type = (string) ($entry['type'] ?? '');
        $value = (string) ($entry['value'] ?? '');
        if ('' === $type || '' === $value) {
            return null;
        }

        return [
            'type' => $type,
            'value' => $value,
        ];
    }

    /**
     * Returns the source registry path.
     *
     * @return string the registry path
     *
     * @throws \RuntimeException when the state directory cannot be created
     */
    private function registryPath(): string
    {
        return $this->stateDirectory().'/sources.json';
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
     * Reads the registry.
     *
     * @return array<string, array{type?: string, value?: string, createdAt?: int}> the registry data
     *
     * @throws \RuntimeException when the state directory cannot be created
     */
    private function readRegistry(): array
    {
        $path = $this->registryPath();
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

        $registry = [];
        foreach ($data as $identifier => $entry) {
            if (!is_string($identifier) || !is_array($entry)) {
                continue;
            }

            $type = $entry['type'] ?? null;
            $value = $entry['value'] ?? null;
            $createdAt = $entry['createdAt'] ?? null;
            $normalizedEntry = [];
            if (is_string($type)) {
                $normalizedEntry['type'] = $type;
            }

            if (is_string($value)) {
                $normalizedEntry['value'] = $value;
            }

            if (is_int($createdAt)) {
                $normalizedEntry['createdAt'] = $createdAt;
            }

            $registry[$identifier] = $normalizedEntry;
        }

        return $registry;
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

    /**
     * Writes the registry.
     *
     * @param array<string, array{type?: string, value?: string, createdAt?: int}> $registry the registry data
     *
     * @throws \RuntimeException when the state directory cannot be created
     * @throws \RuntimeException when the registry cannot be written
     */
    private function writeRegistry(array $registry): void
    {
        $path = $this->registryPath();
        $json = json_encode($registry, JSON_PRETTY_PRINT);
        if (false === $json || false === file_put_contents($path, $json, LOCK_EX)) {
            throw new \RuntimeException(sprintf('Unable to write source registry "%s".', $path));
        }
    }
}
