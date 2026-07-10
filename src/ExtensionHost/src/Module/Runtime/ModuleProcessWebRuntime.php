<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module\Runtime;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleDispatchException;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleManifest;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleProcessWebDefinition;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRequiredSettingsResolver;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRuntimeContext;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Starts process-web modules and proxies route requests to them.
 */
final class ModuleProcessWebRuntime
{
    /**
     * @var array<string, ModuleProcessWebInstance>
     */
    private static array $instances = [];

    /**
     * Dispatches one process-web module route.
     *
     * @param ModuleManifest $module  the module manifest
     * @param string         $route   the requested module route
     * @param Request        $request the current HTTP request
     *
     * @return Response the proxied response
     *
     * @throws ModuleDispatchException when the process cannot be started or proxied
     */
    public function dispatch(ModuleManifest $module, string $route, Request $request): Response
    {
        $instance = $this->runningInstance($module);

        return $this->proxy($instance, $module, $route, $request);
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
     * Returns the current process-web runtime status for one module.
     *
     * @param ModuleManifest $module the module manifest
     *
     * @return array<string, mixed> the runtime status
     */
    public function status(ModuleManifest $module): array
    {
        $definition = $module->processWeb;
        $instance = self::$instances[$module->id] ?? null;
        if (!$definition instanceof ModuleProcessWebDefinition) {
            return [
                'kind' => 'process-web',
                'state' => 'unavailable',
                'running' => false,
                'restartable' => false,
                'messages' => ['Module does not declare a process-web runtime.'],
            ];
        }

        if (null === $instance) {
            return [
                'kind' => 'process-web',
                'state' => 'stopped',
                'running' => false,
                'restartable' => true,
                'command' => array_merge([$definition->command], $definition->args),
                'cwd' => $definition->cwd,
                'readyUrl' => $definition->readyUrl,
                'logs' => '',
            ];
        }

        return $this->instanceStatus($instance);
    }

    /**
     * Restarts one process-web module and returns its new status.
     *
     * @param ModuleManifest $module the module manifest
     *
     * @return array<string, mixed> the runtime status
     *
     * @throws ModuleDispatchException when the process cannot be started
     */
    public function restart(ModuleManifest $module): array
    {
        $this->stopModule($module->id);
        $instance = $this->start($module);
        self::$instances[$module->id] = $instance;

        return $this->instanceStatus($instance);
    }

    /**
     * Returns a running instance, starting or restarting it when needed.
     *
     * @param ModuleManifest $module the module manifest
     *
     * @return ModuleProcessWebInstance the running process instance
     *
     * @throws ModuleDispatchException when the process cannot be started
     */
    private function runningInstance(ModuleManifest $module): ModuleProcessWebInstance
    {
        $instance = self::$instances[$module->id] ?? null;
        if (null !== $instance && $instance->isRunning()) {
            return $instance;
        }

        if (null !== $instance) {
            $instance->stop();
            unset(self::$instances[$module->id]);
        }

        $instance = $this->start($module);
        self::$instances[$module->id] = $instance;

        return $instance;
    }

    /**
     * Builds a status payload for one running or exited process-web instance.
     *
     * @param ModuleProcessWebInstance $instance the process-web instance
     *
     * @return array<string, mixed> the runtime status
     */
    private function instanceStatus(ModuleProcessWebInstance $instance): array
    {
        $running = $instance->isRunning();

        return [
            'kind' => 'process-web',
            'state' => $running ? 'running' : 'exited',
            'running' => $running,
            'restartable' => true,
            'port' => $instance->port,
            'baseUrl' => $instance->baseUrl,
            'command' => $instance->command,
            'cwd' => $instance->cwd,
            'readyUrl' => $instance->readyUrl,
            'logs' => $instance->logs(),
        ];
    }

    /**
     * Starts one module-owned local HTTP process.
     *
     * @param ModuleManifest $module the module manifest
     *
     * @return ModuleProcessWebInstance the started instance
     *
     * @throws ModuleDispatchException when the process cannot be started or does not become ready
     */
    private function start(ModuleManifest $module): ModuleProcessWebInstance
    {
        $definition = $module->processWeb;
        if (!$definition instanceof ModuleProcessWebDefinition) {
            throw new ModuleDispatchException(sprintf('Module "%s" has no process-web runtime definition.', $module->id));
        }

        $port = $this->availablePort();
        $settingsResolver = new ModuleRequiredSettingsResolver();
        $settings = $settingsResolver->resolve($module);
        $cwd = $this->resolvedWorkingDirectory($module, $definition);
        $command = $this->resolvedCommand($definition, $module, $port, $settings, $settingsResolver);
        $env = $this->resolvedEnvironment($definition, $module, $port, $settings, $settingsResolver);
        $readyUrl = $this->interpolate($definition->readyUrl, $module, $port, $settings, $settingsResolver);
        $baseUrl = sprintf('http://127.0.0.1:%d', $port);
        $descriptors = [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ];

        $process = proc_open($command, $descriptors, $pipes, $cwd, $env, [
            'bypass_shell' => true,
        ]);

        if (!is_resource($process)) {
            throw new ModuleDispatchException(sprintf('Module "%s" process could not be started.', $module->id));
        }

        if (is_resource($pipes[0] ?? null)) {
            fclose($pipes[0]);
            unset($pipes[0]);
        }

        $instance = new ModuleProcessWebInstance(
            $module->id,
            $port,
            $baseUrl,
            $command,
            $cwd,
            $env,
            $readyUrl,
            $definition->stopSignal,
            $definition->stopTimeoutMs,
            $process,
            $pipes,
        );

        try {
            $this->waitUntilReady($instance, $definition->timeoutMs);
        } catch (ModuleDispatchException $exception) {
            $logs = $instance->logs();
            $instance->stop();

            throw new ModuleDispatchException(sprintf('%s%s', $exception->getMessage(), '' === $logs ? '' : "\nProcess log:\n".$logs), 0, $exception);
        }

        return $instance;
    }

    /**
     * Proxies one ExtensionHost request to the module process.
     *
     * @param ModuleProcessWebInstance $instance the running process
     * @param ModuleManifest           $module   the module manifest
     * @param string                   $route    the requested module route
     * @param Request                  $request  the current HTTP request
     *
     * @return Response the proxied response
     *
     * @throws ModuleDispatchException when the request cannot be proxied
     */
    private function proxy(ModuleProcessWebInstance $instance, ModuleManifest $module, string $route, Request $request): Response
    {
        $targetUrl = $this->targetUrl($instance, $route, $request);
        $headers = $this->proxyHeaders($module, $route, $request);
        $context = stream_context_create([
            'http' => [
                'method' => 'GET',
                'ignore_errors' => true,
                'timeout' => 30,
                'header' => implode("\r\n", $headers),
            ],
        ]);

        $http_response_header = [];
        $responseContent = @file_get_contents($targetUrl, false, $context);
        $responseHeaders = $http_response_header;
        if (false === $responseContent) {
            $logs = $instance->logs();

            throw new ModuleDispatchException(sprintf('Module "%s" process route "%s" could not be proxied.%s', $module->id, $route, '' === $logs ? '' : "\nProcess log:\n".$logs));
        }

        $statusCode = $this->statusCode($responseHeaders);
        $contentType = $this->headerValue($responseHeaders, 'Content-Type') ?? 'text/html; charset=utf-8';

        return new Response($responseContent, $statusCode, [
            'Content-Type' => $contentType,
        ]);
    }

    /**
     * Waits until a process readiness URL responds.
     *
     * @param ModuleProcessWebInstance $instance  the process instance
     * @param int                      $timeoutMs the timeout in milliseconds
     *
     * @throws ModuleDispatchException when the process exits or does not become ready
     */
    private function waitUntilReady(ModuleProcessWebInstance $instance, int $timeoutMs): void
    {
        $deadline = microtime(true) + ($timeoutMs / 1000);
        while (microtime(true) < $deadline) {
            if (!$instance->isRunning()) {
                throw new ModuleDispatchException(sprintf('Module "%s" process exited before becoming ready.', $instance->moduleId));
            }

            if ($this->urlResponds($instance->readyUrl)) {
                return;
            }

            usleep(100_000);
            $instance->captureLogs();
        }

        throw new ModuleDispatchException(sprintf('Module "%s" process did not become ready at "%s".', $instance->moduleId, $instance->readyUrl));
    }

    /**
     * Returns whether a URL responds with a non-server-error HTTP status.
     *
     * @param string $url the URL to check
     *
     * @return bool true when the URL responds
     */
    private function urlResponds(string $url): bool
    {
        $context = stream_context_create([
            'http' => [
                'method' => 'GET',
                'ignore_errors' => true,
                'timeout' => 0.5,
            ],
        ]);

        $http_response_header = [];
        $content = @file_get_contents($url, false, $context);
        $headers = $http_response_header;
        if (false === $content && [] === $headers) {
            return false;
        }

        $statusCode = $this->statusCode($headers);

        return $statusCode > 0 && $statusCode < 500;
    }

    /**
     * Builds the module process target URL.
     *
     * @param ModuleProcessWebInstance $instance the process instance
     * @param string                   $route    the requested route
     * @param Request                  $request  the current HTTP request
     *
     * @return string the target URL
     */
    private function targetUrl(ModuleProcessWebInstance $instance, string $route, Request $request): string
    {
        $query = $request->query->all();
        unset($query['token']);

        $queryString = http_build_query($query, '', '&', PHP_QUERY_RFC3986);

        return $instance->baseUrl.'/'.ltrim($route, '/').('' === $queryString ? '' : '?'.$queryString);
    }

    /**
     * Builds the proxy request headers sent to the module process.
     *
     * @param ModuleManifest $module  the module manifest
     * @param string         $route   the requested route
     * @param Request        $request the current HTTP request
     *
     * @return list<string> the HTTP header lines
     */
    private function proxyHeaders(ModuleManifest $module, string $route, Request $request): array
    {
        $context = ModuleRuntimeContext::fromRequest($request);
        $headers = [
            'User-Agent: '.$request->headers->get('User-Agent', 'BabelChrome ExtensionHost'),
            'X-BabelChrome-Module-Id: '.$module->id,
            'X-BabelChrome-Module-Route: '.$route,
            'X-BabelChrome-Source-Url: '.$context->sourceUrl,
            'X-BabelChrome-Local-Service-Base-Url: '.$context->baseUrl,
            'X-BabelChrome-Local-Service-Token: '.$context->token,
            'X-BabelChrome-Module-Asset-Base-Url: '.$context->moduleAssetUrl($module, ''),
        ];

        $fileTypes = $request->attributes->get('babelChromeFileTypes', '');
        if (is_string($fileTypes) && '' !== $fileTypes) {
            $headers[] = 'X-BabelChrome-File-Types: '.$fileTypes;
        }

        return $headers;
    }

    /**
     * Resolves the command and its interpolated arguments.
     *
     * @param ModuleProcessWebDefinition     $definition       the process web definition
     * @param ModuleManifest                 $module           the module manifest
     * @param int                            $port             the assigned local port
     * @param array<string, string>          $settings         the resolved required settings
     * @param ModuleRequiredSettingsResolver $settingsResolver the required settings resolver
     *
     * @return list<string> the resolved command
     */
    private function resolvedCommand(
        ModuleProcessWebDefinition $definition,
        ModuleManifest $module,
        int $port,
        array $settings,
        ModuleRequiredSettingsResolver $settingsResolver,
    ): array {
        $command = [
            $this->interpolate($definition->command, $module, $port, $settings, $settingsResolver),
        ];

        foreach ($definition->args as $arg) {
            $command[] = $this->interpolate($arg, $module, $port, $settings, $settingsResolver);
        }

        return $command;
    }

    /**
     * Resolves the process environment.
     *
     * @param ModuleProcessWebDefinition     $definition       the process web definition
     * @param ModuleManifest                 $module           the module manifest
     * @param int                            $port             the assigned local port
     * @param array<string, string>          $settings         the resolved required settings
     * @param ModuleRequiredSettingsResolver $settingsResolver the required settings resolver
     *
     * @return array<string, string> the resolved environment
     */
    private function resolvedEnvironment(
        ModuleProcessWebDefinition $definition,
        ModuleManifest $module,
        int $port,
        array $settings,
        ModuleRequiredSettingsResolver $settingsResolver,
    ): array {
        $environment = getenv();
        if (!is_array($environment)) {
            $environment = [];
        }

        $resolved = [];
        foreach ($environment as $key => $value) {
            $resolved[$key] = $value;
        }

        foreach ($definition->env as $key => $value) {
            $resolved[$key] = $this->interpolate($value, $module, $port, $settings, $settingsResolver);
        }

        foreach ($settingsResolver->environmentVariables($settings) as $key => $value) {
            $resolved[$key] = $value;
        }

        $resolved['BABELCHROME_MODULE_ID'] = $module->id;
        $resolved['BABELCHROME_MODULE_DIR'] = $module->path;
        $resolved['BABELCHROME_PORT'] = (string) $port;
        $resolved['PORT'] = (string) $port;

        return $resolved;
    }

    /**
     * Resolves the process working directory.
     *
     * @param ModuleManifest             $module     the module manifest
     * @param ModuleProcessWebDefinition $definition the process web definition
     *
     * @return string the resolved working directory
     *
     * @throws ModuleDispatchException when the working directory is invalid
     */
    private function resolvedWorkingDirectory(ModuleManifest $module, ModuleProcessWebDefinition $definition): string
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
     * @param string                         $value            the value to interpolate
     * @param ModuleManifest                 $module           the module manifest
     * @param int                            $port             the assigned local port
     * @param array<string, string>          $settings         the resolved required settings
     * @param ModuleRequiredSettingsResolver $settingsResolver the required settings resolver
     *
     * @return string the interpolated value
     */
    private function interpolate(
        string $value,
        ModuleManifest $module,
        int $port,
        array $settings,
        ModuleRequiredSettingsResolver $settingsResolver,
    ): string {
        return strtr($value, [
            '{{ port }}' => (string) $port,
            '{{ moduleId }}' => $module->id,
            '{{ moduleDir }}' => $module->path,
        ] + $settingsResolver->interpolationMap($settings));
    }

    /**
     * Allocates an available local TCP port.
     *
     * @return int the available port
     *
     * @throws ModuleDispatchException when no port can be allocated
     */
    private function availablePort(): int
    {
        $server = @stream_socket_server('tcp://127.0.0.1:0', $errno, $error);
        if (!is_resource($server)) {
            throw new ModuleDispatchException(sprintf('Unable to allocate a local module port: %s (%d).', $error, $errno));
        }

        $name = stream_socket_get_name($server, false);
        fclose($server);

        if (!is_string($name)) {
            throw new ModuleDispatchException('Unable to read allocated local module port.');
        }

        $position = strrpos($name, ':');
        if (false === $position) {
            throw new ModuleDispatchException(sprintf('Unable to parse allocated local module port from "%s".', $name));
        }

        $port = (int) substr($name, $position + 1);
        if ($port <= 0) {
            throw new ModuleDispatchException(sprintf('Allocated local module port "%s" is invalid.', $name));
        }

        return $port;
    }

    /**
     * Extracts an HTTP status code from response headers.
     *
     * @param list<string>|array<int, string> $headers the response headers
     *
     * @return int the HTTP status code
     */
    private function statusCode(array $headers): int
    {
        $statusCode = Response::HTTP_BAD_GATEWAY;
        foreach ($headers as $header) {
            if (1 === preg_match('/^HTTP\/\S+\s+([0-9]{3})\b/', $header, $matches)) {
                $statusCode = (int) $matches[1];
            }
        }

        return $statusCode;
    }

    /**
     * Extracts one HTTP header value from response headers.
     *
     * @param list<string>|array<int, string> $headers the response headers
     * @param string                          $name    the header name
     *
     * @return string|null the header value when present
     */
    private function headerValue(array $headers, string $name): ?string
    {
        $prefix = strtolower($name).':';
        foreach ($headers as $header) {
            if (str_starts_with(strtolower($header), $prefix)) {
                return trim(substr($header, strlen($prefix)));
            }
        }

        return null;
    }
}
