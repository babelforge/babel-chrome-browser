<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

/**
 * Runs manifest-declared module commands with a bounded execution context.
 */
final class ModuleCommandRunner
{
    /**
     * Executes a module command.
     *
     * @param ModuleManifest          $module  the module manifest
     * @param ModuleCommandDefinition $command the command definition
     *
     * @return array{exitCode: int|null, stdout: string, stderr: string, timedOut: bool} the command result
     */
    public function run(ModuleManifest $module, ModuleCommandDefinition $command): array
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
                'stderr' => 'Unable to start module command.',
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
        foreach (['PATH', 'HOME', 'TMPDIR', 'TMP', 'TEMP', 'SHELL'] as $name) {
            $value = getenv($name);
            if (is_string($value) && '' !== $value) {
                $environment[$name] = $value;
            }
        }

        $environment['BABELCHROME_MODULE_ID'] = $module->id;
        $environment['BABELCHROME_MODULE_NAME'] = $module->name;
        $environment['BABELCHROME_MODULE_VERSION'] = $module->version;
        $environment['BABELCHROME_MODULE_DIR'] = $module->path;

        return $environment;
    }
}
