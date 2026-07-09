<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module\Runtime;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleDispatchException;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleManifest;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleProcessRuntimeCommand;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleProcessRuntimeDefinition;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRuntimeContext;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Runs process-runtime modules through stdin/stdout JSON contracts.
 */
final class ModuleProcessRuntime
{
    /**
     * @var array<string, ModuleProcessRuntimeInstance>
     */
    private static array $instances = [];

    /**
     * Dispatches one process-runtime module route.
     *
     * @param ModuleManifest $module  the module manifest
     * @param string         $route   the requested module route
     * @param Request        $request the current HTTP request
     *
     * @return Response the command response
     *
     * @throws ModuleDispatchException when the runtime cannot execute the request
     */
    public function dispatch(ModuleManifest $module, string $route, Request $request): Response
    {
        $definition = $module->processRuntime;
        if (!$definition instanceof ModuleProcessRuntimeDefinition) {
            throw new ModuleDispatchException(sprintf('Module "%s" has no process-runtime definition.', $module->id));
        }

        if (ModuleProcessRuntimeDefinition::MODE_LONG_RUNNING === $definition->mode) {
            return $this->dispatchLongRunning($module, $route, $request, $definition);
        }

        return $this->dispatchOnDemand($module, $route, $request, $definition);
    }

    /**
     * Stops one running module process.
     *
     * @param string $moduleId the module identifier
     */
    public function stopModule(string $moduleId): void
    {
        $instance = self::$instances[$moduleId] ?? null;
        if (null === $instance) {
            return;
        }

        $instance->stop();
        unset(self::$instances[$moduleId]);
    }

    /**
     * Stops every running module process.
     */
    public function stopAll(): void
    {
        foreach (array_keys(self::$instances) as $moduleId) {
            $this->stopModule($moduleId);
        }
    }

    /**
     * Returns the current process-runtime status for one module.
     *
     * @param ModuleManifest $module the module manifest
     *
     * @return array<string, mixed> the runtime status
     */
    public function status(ModuleManifest $module): array
    {
        $definition = $module->processRuntime;
        if (!$definition instanceof ModuleProcessRuntimeDefinition) {
            return [
                'kind' => 'process-runtime',
                'state' => 'unavailable',
                'running' => false,
                'restartable' => false,
                'messages' => ['Module does not declare a process-runtime definition.'],
            ];
        }

        $instance = self::$instances[$module->id] ?? null;
        $running = null !== $instance && $instance->isRunning();
        $command = null === $instance ? array_merge([$definition->command->command], $definition->command->args) : $instance->command;
        $cwd = null === $instance ? $definition->cwd : $instance->cwd;

        return [
            'kind' => 'process-runtime',
            'mode' => $definition->mode,
            'state' => null === $instance ? 'idle' : ($running ? 'running' : 'exited'),
            'running' => $running,
            'restartable' => false,
            'command' => $command,
            'cwd' => $cwd,
            'logs' => $instance?->logs() ?? '',
        ];
    }

    /**
     * Dispatches an on-demand process request.
     *
     * @param ModuleManifest                 $module     the module manifest
     * @param string                         $route      the requested route
     * @param Request                        $request    the current HTTP request
     * @param ModuleProcessRuntimeDefinition $definition the process runtime definition
     *
     * @return Response the process response
     *
     * @throws ModuleDispatchException when the process fails
     */
    private function dispatchOnDemand(ModuleManifest $module, string $route, Request $request, ModuleProcessRuntimeDefinition $definition): Response
    {
        $command = $definition->commandForRoute($route);
        $execution = $this->runCommand($module, $route, $request, $definition, $command);

        if ($execution['timedOut']) {
            throw new ModuleDispatchException(sprintf('Module "%s" process-runtime route "%s" timed out.%s', $module->id, $route, $this->logsSuffix($execution)));
        }

        if (0 !== $execution['exitCode']) {
            throw new ModuleDispatchException(sprintf('Module "%s" process-runtime route "%s" failed with exit code %d.%s', $module->id, $route, $execution['exitCode'], $this->logsSuffix($execution)));
        }

        return $this->responseFromStdout($execution['stdout']);
    }

    /**
     * Starts or reuses a long-running process and returns diagnostics.
     *
     * @param ModuleManifest                 $module     the module manifest
     * @param string                         $route      the requested route
     * @param Request                        $request    the current HTTP request
     * @param ModuleProcessRuntimeDefinition $definition the process runtime definition
     *
     * @return Response the runtime state response
     *
     * @throws ModuleDispatchException when the process cannot be started
     */
    private function dispatchLongRunning(ModuleManifest $module, string $route, Request $request, ModuleProcessRuntimeDefinition $definition): Response
    {
        $instance = $this->runningInstance($module, $route, $request, $definition);
        $body = [
            'ok' => true,
            'moduleId' => $module->id,
            'route' => $route,
            'mode' => $definition->mode,
            'running' => $instance->isRunning(),
        ];

        return new Response(json_encode($body, JSON_THROW_ON_ERROR), Response::HTTP_OK, [
            'Content-Type' => 'application/json; charset=utf-8',
        ]);
    }

    /**
     * Returns a long-running instance, starting or restarting it when needed.
     *
     * @param ModuleManifest                 $module     the module manifest
     * @param string                         $route      the requested route
     * @param Request                        $request    the current HTTP request
     * @param ModuleProcessRuntimeDefinition $definition the process runtime definition
     *
     * @return ModuleProcessRuntimeInstance the running process instance
     *
     * @throws ModuleDispatchException when the process cannot be started
     */
    private function runningInstance(ModuleManifest $module, string $route, Request $request, ModuleProcessRuntimeDefinition $definition): ModuleProcessRuntimeInstance
    {
        $instance = self::$instances[$module->id] ?? null;
        if (null !== $instance && $instance->isRunning()) {
            return $instance;
        }

        if (null !== $instance) {
            $instance->stop();
            unset(self::$instances[$module->id]);
        }

        $instance = $this->startLongRunning($module, $route, $request, $definition);
        self::$instances[$module->id] = $instance;

        return $instance;
    }

    /**
     * Starts a long-running module process.
     *
     * @param ModuleManifest                 $module     the module manifest
     * @param string                         $route      the requested route
     * @param Request                        $request    the current HTTP request
     * @param ModuleProcessRuntimeDefinition $definition the process runtime definition
     *
     * @return ModuleProcessRuntimeInstance the started process instance
     *
     * @throws ModuleDispatchException when the process cannot be started
     */
    private function startLongRunning(ModuleManifest $module, string $route, Request $request, ModuleProcessRuntimeDefinition $definition): ModuleProcessRuntimeInstance
    {
        $command = $definition->commandForRoute($route);
        $cwd = $this->resolvedWorkingDirectory($module, $definition);
        $payload = $this->payload($module, $route, $request);
        $resolvedCommand = $this->resolvedCommand($command, $module, $route, $request);
        $env = $this->resolvedEnvironment($definition, $module, $route, $request);
        $process = proc_open($resolvedCommand, [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ], $pipes, $cwd, $env, [
            'bypass_shell' => true,
        ]);

        if (!is_resource($process)) {
            throw new ModuleDispatchException(sprintf('Module "%s" long-running process could not be started.', $module->id));
        }

        if (is_resource($pipes[0] ?? null)) {
            fwrite($pipes[0], json_encode($payload, JSON_THROW_ON_ERROR));
            fclose($pipes[0]);
            unset($pipes[0]);
        }

        return new ModuleProcessRuntimeInstance(
            $module->id,
            $resolvedCommand,
            $cwd,
            $env,
            $definition->stopSignal,
            $definition->stopTimeoutMs,
            $process,
            $pipes,
        );
    }

    /**
     * Runs one on-demand command.
     *
     * @param ModuleManifest                 $module     the module manifest
     * @param string                         $route      the requested route
     * @param Request                        $request    the current HTTP request
     * @param ModuleProcessRuntimeDefinition $definition the process runtime definition
     * @param ModuleProcessRuntimeCommand    $command    the command to execute
     *
     * @return array{exitCode: int, stdout: string, stderr: string, timedOut: bool} the execution result
     *
     * @throws ModuleDispatchException when the process cannot be started
     */
    private function runCommand(
        ModuleManifest $module,
        string $route,
        Request $request,
        ModuleProcessRuntimeDefinition $definition,
        ModuleProcessRuntimeCommand $command,
    ): array {
        $cwd = $this->resolvedWorkingDirectory($module, $definition);
        $process = proc_open($this->resolvedCommand($command, $module, $route, $request), [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ], $pipes, $cwd, $this->resolvedEnvironment($definition, $module, $route, $request), [
            'bypass_shell' => true,
        ]);

        if (!is_resource($process)) {
            throw new ModuleDispatchException(sprintf('Module "%s" process-runtime route "%s" could not be started.', $module->id, $route));
        }

        fwrite($pipes[0], json_encode($this->payload($module, $route, $request), JSON_THROW_ON_ERROR));
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
     * Builds the JSON payload sent to process stdin.
     *
     * @param ModuleManifest $module  the module manifest
     * @param string         $route   the requested route
     * @param Request        $request the current HTTP request
     *
     * @return array<string, mixed> the payload
     */
    private function payload(ModuleManifest $module, string $route, Request $request): array
    {
        $context = ModuleRuntimeContext::fromRequest($request);
        $query = $request->query->all();
        unset($query['token']);

        return [
            'module' => [
                'id' => $module->id,
                'name' => $module->name,
                'version' => $module->version,
                'path' => $module->path,
            ],
            'route' => $route,
            'hook' => $this->hook($request),
            'sourceUrl' => $context->sourceUrl,
            'localServiceBaseUrl' => $context->baseUrl,
            'query' => $query,
            'fileTypes' => $this->fileTypes($request),
        ];
    }

    /**
     * Builds a response from command stdout.
     *
     * @param string $stdout the command stdout
     *
     * @return Response the response
     */
    private function responseFromStdout(string $stdout): Response
    {
        $trimmed = trim($stdout);
        if ('' === $trimmed) {
            return new Response('', Response::HTTP_NO_CONTENT);
        }

        $decoded = json_decode($trimmed, true);
        if (is_array($decoded)) {
            return $this->responseFromJsonOutput($this->stringKeyedArray($decoded));
        }

        return new Response($stdout, Response::HTTP_OK, [
            'Content-Type' => 'text/plain; charset=utf-8',
        ]);
    }

    /**
     * Builds a response from JSON command output.
     *
     * @param array<string, mixed> $output the decoded command output
     *
     * @return Response the response
     */
    private function responseFromJsonOutput(array $output): Response
    {
        $statusCode = $output['statusCode'] ?? Response::HTTP_OK;
        $headers = $this->responseHeaders($output);
        $body = $output['body'] ?? $output;

        if (is_array($body)) {
            $body = json_encode($body, JSON_THROW_ON_ERROR);
            $headers['Content-Type'] ??= 'application/json; charset=utf-8';
        } elseif (!is_string($body)) {
            $body = json_encode($body, JSON_THROW_ON_ERROR);
            $headers['Content-Type'] ??= 'application/json; charset=utf-8';
        }

        return new Response($body, is_int($statusCode) ? $statusCode : Response::HTTP_OK, $headers);
    }

    /**
     * Keeps only string-keyed values from a decoded JSON object.
     *
     * @param array<mixed> $value the decoded JSON array
     *
     * @return array<string, mixed> the string-keyed array
     */
    private function stringKeyedArray(array $value): array
    {
        $output = [];
        foreach ($value as $key => $item) {
            if (is_string($key)) {
                $output[$key] = $item;
            }
        }

        return $output;
    }

    /**
     * Reads response headers from JSON command output.
     *
     * @param array<string, mixed> $output the decoded command output
     *
     * @return array<string, string> the response headers
     */
    private function responseHeaders(array $output): array
    {
        $headers = [];
        $declaredHeaders = $output['headers'] ?? [];
        if (is_array($declaredHeaders)) {
            foreach ($declaredHeaders as $name => $value) {
                if (is_string($name) && is_string($value)) {
                    $headers[$name] = $value;
                }
            }
        }

        $contentType = $output['contentType'] ?? null;
        if (is_string($contentType) && '' !== trim($contentType)) {
            $headers['Content-Type'] = trim($contentType);
        }

        return $headers;
    }

    /**
     * Resolves the command and its interpolated arguments.
     *
     * @param ModuleProcessRuntimeCommand $command the command declaration
     * @param ModuleManifest              $module  the module manifest
     * @param string                      $route   the requested route
     * @param Request                     $request the current HTTP request
     *
     * @return list<string> the resolved command
     */
    private function resolvedCommand(ModuleProcessRuntimeCommand $command, ModuleManifest $module, string $route, Request $request): array
    {
        $resolved = [
            $this->interpolate($command->command, $module, $route, $request),
        ];

        foreach ($command->args as $arg) {
            $resolved[] = $this->interpolate($arg, $module, $route, $request);
        }

        return $resolved;
    }

    /**
     * Resolves the process environment.
     *
     * @param ModuleProcessRuntimeDefinition $definition the process runtime definition
     * @param ModuleManifest                 $module     the module manifest
     * @param string                         $route      the requested route
     * @param Request                        $request    the current HTTP request
     *
     * @return array<string, string> the resolved environment
     */
    private function resolvedEnvironment(ModuleProcessRuntimeDefinition $definition, ModuleManifest $module, string $route, Request $request): array
    {
        $environment = [];
        foreach (['PATH', 'HOME', 'TMPDIR', 'TMP', 'TEMP', 'SHELL'] as $name) {
            $value = getenv($name);
            if (is_string($value) && '' !== $value) {
                $environment[$name] = $value;
            }
        }

        foreach ($definition->env as $key => $value) {
            $environment[$key] = $this->interpolate($value, $module, $route, $request);
        }

        $context = ModuleRuntimeContext::fromRequest($request);
        $environment['BABELCHROME_MODULE_ID'] = $module->id;
        $environment['BABELCHROME_MODULE_NAME'] = $module->name;
        $environment['BABELCHROME_MODULE_VERSION'] = $module->version;
        $environment['BABELCHROME_MODULE_DIR'] = $module->path;
        $environment['BABELCHROME_MODULE_ROUTE'] = $route;
        $environment['BABELCHROME_HOOK'] = $this->hook($request);
        $environment['BABELCHROME_SOURCE_URL'] = $context->sourceUrl;
        $environment['BABELCHROME_FILE_TYPES'] = $this->fileTypes($request);

        return $environment;
    }

    /**
     * Resolves the process working directory.
     *
     * @param ModuleManifest                 $module     the module manifest
     * @param ModuleProcessRuntimeDefinition $definition the process runtime definition
     *
     * @return string the resolved working directory
     *
     * @throws ModuleDispatchException when the working directory is invalid
     */
    private function resolvedWorkingDirectory(ModuleManifest $module, ModuleProcessRuntimeDefinition $definition): string
    {
        $candidate = str_starts_with($definition->cwd, '/') ? $definition->cwd : $module->path.'/'.ltrim($definition->cwd, '/');
        $resolved = realpath($candidate);
        if (false === $resolved || !is_dir($resolved)) {
            throw new ModuleDispatchException(sprintf('Module "%s" process cwd "%s" was not found.', $module->id, $definition->cwd));
        }

        return $resolved;
    }

    /**
     * Interpolates process definition placeholders.
     *
     * @param string         $value   the value to interpolate
     * @param ModuleManifest $module  the module manifest
     * @param string         $route   the requested route
     * @param Request        $request the current HTTP request
     *
     * @return string the interpolated value
     */
    private function interpolate(string $value, ModuleManifest $module, string $route, Request $request): string
    {
        return strtr($value, [
            '{{ moduleId }}' => $module->id,
            '{{ moduleDir }}' => $module->path,
            '{{ route }}' => $route,
            '{{ hook }}' => $this->hook($request),
            '{{ sourceUrl }}' => ModuleRuntimeContext::fromRequest($request)->sourceUrl,
        ]);
    }

    /**
     * Reads the current lifecycle hook name.
     *
     * @param Request $request the current HTTP request
     *
     * @return string the lifecycle hook name
     */
    private function hook(Request $request): string
    {
        $hook = $request->query->get('hook', '');

        return is_string($hook) ? $hook : '';
    }

    /**
     * Reads the advertised BabelChrome file types.
     *
     * @param Request $request the current HTTP request
     *
     * @return string the file types
     */
    private function fileTypes(Request $request): string
    {
        $fileTypes = $request->attributes->get('babelChromeFileTypes', '');

        return is_string($fileTypes) ? $fileTypes : '';
    }

    /**
     * Builds an error suffix from process logs.
     *
     * @param array{stdout: string, stderr: string} $execution the execution result
     *
     * @return string the log suffix
     */
    private function logsSuffix(array $execution): string
    {
        $parts = [];
        if ('' !== trim($execution['stdout'])) {
            $parts[] = 'stdout: '.trim($execution['stdout']);
        }

        if ('' !== trim($execution['stderr'])) {
            $parts[] = 'stderr: '.trim($execution['stderr']);
        }

        return [] === $parts ? '' : "\nProcess log:\n".implode("\n", $parts);
    }
}
