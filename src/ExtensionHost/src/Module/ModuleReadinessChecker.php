<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

/**
 * Evaluates optional module readiness declarations.
 */
final readonly class ModuleReadinessChecker
{
    /**
     * @param ModuleCommandRunner $moduleCommandRunner runs bounded module commands
     */
    public function __construct(
        private ModuleCommandRunner $moduleCommandRunner,
    ) {
    }

    /**
     * Returns the readiness status for one module.
     *
     * @param ModuleManifest $module the module manifest
     *
     * @return array<string, mixed> the readiness status
     */
    public function status(ModuleManifest $module): array
    {
        if (null === $module->readiness) {
            return [
                'state' => 'unknown',
                'ready' => null,
                'messages' => [],
                'canSetup' => null !== $module->setup,
            ];
        }

        if ('command' !== $module->readiness->type) {
            return [
                'state' => 'unsupported',
                'ready' => false,
                'messages' => [sprintf('Unsupported readiness type "%s".', $module->readiness->type)],
                'canSetup' => null !== $module->setup,
            ];
        }

        return $this->commandStatus($module);
    }

    /**
     * Runs a readiness command and returns its status.
     *
     * @param ModuleManifest $module the module manifest
     *
     * @return array<string, mixed> the readiness status
     */
    private function commandStatus(ModuleManifest $module): array
    {
        $command = $module->readiness;
        if (null === $command) {
            return [
                'state' => 'unknown',
                'ready' => null,
                'messages' => [],
                'canSetup' => null !== $module->setup,
            ];
        }

        $result = $this->moduleCommandRunner->run($module, $command);
        if ($result['timedOut']) {
            return [
                'state' => 'timeout',
                'ready' => false,
                'messages' => [sprintf('Readiness command timed out after %d ms.', $command->timeoutMs)],
                'canSetup' => null !== $module->setup,
                'exitCode' => $result['exitCode'],
                'stderr' => $result['stderr'],
            ];
        }

        $decoded = json_decode($result['stdout'], true);
        if (!is_array($decoded)) {
            return [
                'state' => 0 === $result['exitCode'] ? 'invalid-output' : 'failed',
                'ready' => false,
                'messages' => ['Readiness command did not return a JSON object.'],
                'canSetup' => null !== $module->setup,
                'exitCode' => $result['exitCode'],
                'stderr' => $result['stderr'],
            ];
        }

        $ready = $decoded['ready'] ?? false;
        $status = $decoded['status'] ?? (true === $ready ? 'ready' : 'not-ready');
        $messages = $decoded['messages'] ?? [];
        $canSetup = $decoded['canSetup'] ?? (null !== $module->setup);

        return [
            'state' => is_string($status) && '' !== $status ? $status : 'unknown',
            'ready' => true === $ready,
            'messages' => $this->stringList($messages),
            'canSetup' => is_bool($canSetup) ? $canSetup : null !== $module->setup,
            'exitCode' => $result['exitCode'],
            'stderr' => $result['stderr'],
        ];
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
