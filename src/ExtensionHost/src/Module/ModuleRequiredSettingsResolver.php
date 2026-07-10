<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleDispatchException;

/**
 * Resolves required module runtime settings for the transitional ExtensionHost.
 */
final class ModuleRequiredSettingsResolver
{
    /**
     * Resolves all required settings declared by one module.
     *
     * @param ModuleManifest $module the module manifest
     *
     * @return array<string, string> the resolved settings indexed by setting key
     *
     * @throws ModuleDispatchException when a required setting cannot be resolved
     */
    public function resolve(ModuleManifest $module): array
    {
        $resolved = [];
        foreach ($module->requiredSettings as $key => $definition) {
            $type = self::stringValue($definition, 'type', '');
            if ('executable' !== $type) {
                throw new ModuleDispatchException(sprintf('Module "%s" required setting "%s" uses unsupported type "%s".', $module->id, $key, $type));
            }

            $resolved[$key] = $this->resolveExecutable($module, $key, $definition);
        }

        return $resolved;
    }

    /**
     * Builds environment variables exposing resolved settings to the child process.
     *
     * @param array<string, string> $settings the resolved settings
     *
     * @return array<string, string> the process environment variables
     */
    public function environmentVariables(array $settings): array
    {
        $variables = [];
        foreach ($settings as $key => $value) {
            $variables[self::environmentName($key)] = $value;
        }

        return $variables;
    }

    /**
     * Builds placeholder replacements for resolved settings.
     *
     * @param array<string, string> $settings the resolved settings
     *
     * @return array<string, string> the placeholder replacements
     */
    public function interpolationMap(array $settings): array
    {
        $map = [];
        foreach ($settings as $key => $value) {
            $map[sprintf('{{ settings.%s }}', $key)] = $value;
        }

        return $map;
    }

    /**
     * Resolves one executable setting.
     *
     * @param ModuleManifest       $module     the module manifest
     * @param string               $key        the setting key
     * @param array<string, mixed> $definition the setting definition
     *
     * @return string the executable path
     *
     * @throws ModuleDispatchException when no valid executable can be found
     */
    private function resolveExecutable(ModuleManifest $module, string $key, array $definition): string
    {
        $environmentValue = getenv(self::environmentName($key));
        if (is_string($environmentValue) && $this->isValidExecutable($environmentValue, $definition)) {
            return $environmentValue;
        }

        foreach ($this->candidatePaths($definition) as $candidate) {
            if ($this->isValidExecutable($candidate, $definition)) {
                return $candidate;
            }
        }

        throw new ModuleDispatchException(sprintf('Module "%s" required setting "%s" could not be resolved.', $module->id, $key));
    }

    /**
     * Returns whether one candidate is an executable satisfying the definition.
     *
     * @param string               $candidate  the executable candidate
     * @param array<string, mixed> $definition the setting definition
     *
     * @return bool true when the candidate can be used
     */
    private function isValidExecutable(string $candidate, array $definition): bool
    {
        $path = trim($candidate);
        if ('' === $path || !is_file($path) || !is_executable($path)) {
            return false;
        }

        $minimumVersion = self::stringValue($definition, 'minVersion', '');
        if ('' === $minimumVersion) {
            return true;
        }

        $detectedVersion = $this->detectedVersion($path, self::stringList($definition['versionArgs'] ?? []));

        return null !== $detectedVersion && version_compare($detectedVersion, $minimumVersion, '>=');
    }

    /**
     * Detects an executable version from its version command output.
     *
     * @param string       $path        the executable path
     * @param list<string> $versionArgs the version command arguments
     *
     * @return string|null the detected version
     */
    private function detectedVersion(string $path, array $versionArgs): ?string
    {
        $args = [] === $versionArgs ? ['--version'] : $versionArgs;
        $command = array_merge([$path], $args);
        $descriptors = [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ];
        $pipes = [];
        $process = proc_open($command, $descriptors, $pipes, null, null, [
            'bypass_shell' => true,
        ]);

        if (!is_resource($process)) {
            return null;
        }

        if (is_resource($pipes[0] ?? null)) {
            fclose($pipes[0]);
        }

        $stdout = is_resource($pipes[1] ?? null) ? (string) stream_get_contents($pipes[1]) : '';
        $stderr = is_resource($pipes[2] ?? null) ? (string) stream_get_contents($pipes[2]) : '';

        if (is_resource($pipes[1] ?? null)) {
            fclose($pipes[1]);
        }

        if (is_resource($pipes[2] ?? null)) {
            fclose($pipes[2]);
        }

        proc_close($process);

        return $this->firstVersion($stdout."\n".$stderr);
    }

    /**
     * Extracts the first semantic-looking version from text.
     *
     * @param string $output the command output
     *
     * @return string|null the extracted version
     */
    private function firstVersion(string $output): ?string
    {
        if (1 !== preg_match('/([0-9]+(?:\.[0-9]+){0,3})/', $output, $matches)) {
            return null;
        }

        return $matches[1];
    }

    /**
     * Builds executable candidate paths from the manifest definition.
     *
     * @param array<string, mixed> $definition the setting definition
     *
     * @return list<string> the executable candidate paths
     */
    private function candidatePaths(array $definition): array
    {
        $paths = self::stringList($definition['autoDetectPaths'] ?? []);
        $binary = self::stringValue($definition, 'binary', '');
        if ('' !== $binary) {
            $paths = array_merge($paths, $this->defaultExecutablePaths($binary));
        }

        return array_values(array_unique($paths));
    }

    /**
     * Builds common executable paths for one binary name.
     *
     * @param string $binary the binary name
     *
     * @return list<string> the default executable paths
     */
    private function defaultExecutablePaths(string $binary): array
    {
        $name = basename($binary);
        if (str_starts_with($binary, '/')) {
            return [$binary];
        }

        $paths = [
            '/opt/homebrew/bin/'.$name,
            '/usr/local/bin/'.$name,
            '/opt/local/bin/'.$name,
            '/usr/bin/'.$name,
            '/bin/'.$name,
        ];

        if ('php' === $name) {
            array_unshift(
                $paths,
                '/opt/homebrew/opt/php@8.4/bin/php',
                '/opt/homebrew/opt/php/bin/php',
                '/usr/local/opt/php@8.4/bin/php',
                '/usr/local/opt/php/bin/php',
            );
        }

        return $paths;
    }

    /**
     * Reads a string value from a definition.
     *
     * @param array<string, mixed> $definition the setting definition
     * @param string               $key        the key to read
     * @param string               $default    the default value
     *
     * @return string the string value
     */
    private static function stringValue(array $definition, string $key, string $default): string
    {
        $value = $definition[$key] ?? $default;

        return is_string($value) ? trim($value) : $default;
    }

    /**
     * Reads a string list from a manifest value.
     *
     * @param mixed $value the manifest value
     *
     * @return list<string> the string list
     */
    private static function stringList(mixed $value): array
    {
        if (!is_array($value)) {
            return [];
        }

        $items = [];
        foreach ($value as $item) {
            if (is_string($item) && '' !== trim($item)) {
                $items[] = trim($item);
            }
        }

        return $items;
    }

    /**
     * Builds the environment variable name for one setting key.
     *
     * @param string $key the setting key
     *
     * @return string the environment variable name
     */
    private static function environmentName(string $key): string
    {
        $normalized = preg_replace('/[^A-Za-z0-9]+/', '_', $key);
        if (!is_string($normalized)) {
            $normalized = $key;
        }

        $normalized = trim($normalized, '_');

        return 'BABELCHROME_SETTING_'.strtoupper($normalized);
    }
}
