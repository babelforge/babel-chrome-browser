<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

/**
 * Runs explicitly user-confirmed module setup commands.
 */
final readonly class ModuleSetupRunner
{
    /**
     * @param ModuleCommandRunner $moduleCommandRunner runs bounded module commands
     */
    public function __construct(
        private ModuleCommandRunner $moduleCommandRunner,
    ) {
    }

    /**
     * Runs the setup command declared by one module.
     *
     * @param ModuleManifest $module the module manifest
     *
     * @return array<string, mixed> the setup result
     */
    public function run(ModuleManifest $module): array
    {
        if (null === $module->setup) {
            return [
                'ok' => false,
                'state' => 'missing-setup',
                'messages' => ['Module does not declare a setup command.'],
                'stdout' => '',
                'stderr' => '',
                'exitCode' => null,
                'timedOut' => false,
            ];
        }

        if ('command' !== $module->setup->type) {
            return [
                'ok' => false,
                'state' => 'unsupported',
                'messages' => [sprintf('Unsupported setup type "%s".', $module->setup->type)],
                'stdout' => '',
                'stderr' => '',
                'exitCode' => null,
                'timedOut' => false,
            ];
        }

        $result = $this->moduleCommandRunner->run($module, $module->setup);
        if ($result['timedOut']) {
            return [
                'ok' => false,
                'state' => 'timeout',
                'messages' => [sprintf('Setup command timed out after %d ms.', $module->setup->timeoutMs)],
                'stdout' => $result['stdout'],
                'stderr' => $result['stderr'],
                'exitCode' => $result['exitCode'],
                'timedOut' => true,
            ];
        }

        $decoded = $this->decodedJsonObject($result['stdout']);
        if (null !== $decoded) {
            return $this->jsonResult($decoded, $result);
        }

        $ok = 0 === $result['exitCode'];

        return [
            'ok' => $ok,
            'state' => $ok ? 'completed' : 'failed',
            'messages' => [$ok ? 'Setup command completed.' : 'Setup command failed.'],
            'stdout' => $result['stdout'],
            'stderr' => $result['stderr'],
            'exitCode' => $result['exitCode'],
            'timedOut' => false,
        ];
    }

    /**
     * Builds a setup result from JSON command output.
     *
     * @param array<string, mixed>                                                      $decoded the decoded setup output
     * @param array{exitCode: int|null, stdout: string, stderr: string, timedOut: bool} $result  the raw command result
     *
     * @return array<string, mixed> the setup result
     */
    private function jsonResult(array $decoded, array $result): array
    {
        $ok = $decoded['ok'] ?? (0 === $result['exitCode']);
        $state = $decoded['status'] ?? (true === $ok ? 'completed' : 'failed');
        $messages = $decoded['messages'] ?? [];

        return [
            'ok' => true === $ok,
            'state' => is_string($state) && '' !== $state ? $state : 'unknown',
            'messages' => $this->stringList($messages),
            'stdout' => $result['stdout'],
            'stderr' => $result['stderr'],
            'exitCode' => $result['exitCode'],
            'timedOut' => false,
        ];
    }

    /**
     * Decodes a JSON object with string keys.
     *
     * @param string $value the JSON value
     *
     * @return array<string, mixed>|null the decoded object
     */
    private function decodedJsonObject(string $value): ?array
    {
        $decoded = json_decode($value, true);
        if (!is_array($decoded)) {
            return null;
        }

        $object = [];
        foreach ($decoded as $key => $item) {
            if (is_string($key)) {
                $object[$key] = $item;
            }
        }

        return $object;
    }

    /**
     * Normalizes a list of strings.
     *
     * @param mixed $value the decoded list value
     *
     * @return list<string> the string list
     */
    private function stringList(mixed $value): array
    {
        if (!is_array($value)) {
            return [];
        }

        $strings = [];
        foreach ($value as $item) {
            if (is_string($item) && '' !== trim($item)) {
                $strings[] = trim($item);
            }
        }

        return $strings;
    }
}
