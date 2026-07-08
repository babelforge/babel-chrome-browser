<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

/**
 * Evaluates optional module readiness declarations.
 */
final class ModuleReadinessChecker
{
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

        $result = $this->runCommand($module, $command);
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
     * Executes a module command.
     *
     * @param ModuleManifest          $module  the module manifest
     * @param ModuleCommandDefinition $command the command definition
     *
     * @return array{exitCode: int|null, stdout: string, stderr: string, timedOut: bool} the command result
     */
    private function runCommand(ModuleManifest $module, ModuleCommandDefinition $command): array
    {
        $process = proc_open(
            $command->command,
            [
                0 => ['pipe', 'r'],
                1 => ['pipe', 'w'],
                2 => ['pipe', 'w'],
            ],
            $pipes,
            $module->path,
            $this->environment($module),
        );

        if (!is_resource($process)) {
            return [
                'exitCode' => null,
                'stdout' => '',
                'stderr' => 'Unable to start readiness command.',
                'timedOut' => false,
            ];
        }

        fclose($pipes[0]);
        stream_set_blocking($pipes[1], false);
        stream_set_blocking($pipes[2], false);

        $stdout = '';
        $stderr = '';
        $deadline = microtime(true) + ($command->timeoutMs / 1000);
        $timedOut = false;

        while (true) {
            $stdout .= (string) stream_get_contents($pipes[1]);
            $stderr .= (string) stream_get_contents($pipes[2]);
            $status = proc_get_status($process);

            if (!$status['running']) {
                break;
            }

            if (microtime(true) >= $deadline) {
                $timedOut = true;
                proc_terminate($process);
                break;
            }

            usleep(20_000);
        }

        $stdout .= (string) stream_get_contents($pipes[1]);
        $stderr .= (string) stream_get_contents($pipes[2]);
        fclose($pipes[1]);
        fclose($pipes[2]);

        $exitCode = proc_close($process);

        return [
            'exitCode' => $exitCode,
            'stdout' => $stdout,
            'stderr' => $stderr,
            'timedOut' => $timedOut,
        ];
    }

    /**
     * Returns the command environment.
     *
     * @param ModuleManifest $module the module manifest
     *
     * @return array<string, string> the process environment
     */
    private function environment(ModuleManifest $module): array
    {
        $environment = [];
        foreach ($_ENV as $key => $value) {
            if (is_string($key) && is_string($value)) {
                $environment[$key] = $value;
            }
        }

        $environment['BABELCHROME_MODULE_ID'] = $module->id;
        $environment['BABELCHROME_MODULE_NAME'] = $module->name;
        $environment['BABELCHROME_MODULE_VERSION'] = $module->version;
        $environment['BABELCHROME_MODULE_DIR'] = $module->path;

        return $environment;
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
