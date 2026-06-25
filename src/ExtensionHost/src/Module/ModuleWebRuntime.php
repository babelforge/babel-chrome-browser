<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleDispatchException;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Runs framework-agnostic module front controllers.
 */
final class ModuleWebRuntime
{
    private const RESPONSE_MARKER = '__BABELCHROME_MODULE_RESPONSE__';

    /**
     * Dispatches one request to a module web front controller.
     *
     * @param ModuleManifest $module  the module manifest
     * @param string         $route   the requested module route
     * @param Request        $request the host request
     *
     * @return Response the module response
     *
     * @throws ModuleDispatchException when the module cannot be executed
     */
    public function dispatch(ModuleManifest $module, string $route, Request $request): Response
    {
        $entrypoint = $this->resolvedEntrypoint($module);
        $context = ModuleRuntimeContext::fromRequest($request);

        if (!$module->usesProcessIsolation()) {
            return $this->dispatchInProcess($module, $route, $request, $context, $entrypoint);
        }

        $processResult = $this->runIsolatedProcess($module, $route, $request, $context, $entrypoint);

        return new Response(
            $processResult['content'],
            $processResult['statusCode'],
            $processResult['headers'],
        );
    }

    /**
     * Resolves the module front controller path.
     *
     * @param ModuleManifest $module the module manifest
     *
     * @return string the resolved entrypoint path
     *
     * @throws ModuleDispatchException when the entrypoint is invalid
     */
    private function resolvedEntrypoint(ModuleManifest $module): string
    {
        if ('' === $module->entrypoint) {
            throw new ModuleDispatchException(sprintf('Module "%s" has no web entrypoint.', $module->id));
        }

        $entrypoint = realpath($module->path.'/'.ltrim($module->entrypoint, '/'));
        $modulePath = realpath($module->path);
        if (false === $entrypoint || false === $modulePath || !str_starts_with($entrypoint, $modulePath.'/') || !is_file($entrypoint)) {
            throw new ModuleDispatchException(sprintf('Module "%s" web entrypoint "%s" was not found.', $module->id, $module->entrypoint));
        }

        return $entrypoint;
    }

    /**
     * Returns BabelChrome variables exposed to web modules.
     *
     * @param ModuleManifest       $module  the module manifest
     * @param string               $route   the requested module route
     * @param Request              $request the host request
     * @param ModuleRuntimeContext $context the runtime context
     *
     * @return array<string, string> the server variables
     */
    private function babelChromeServerVariables(ModuleManifest $module, string $route, Request $request, ModuleRuntimeContext $context): array
    {
        $routePath = '/module/'.rawurlencode($module->id).'/'.$route;
        $assetBaseUrl = $context->baseUrl.'/module/'.rawurlencode($module->id).'/assets';
        $assetTokenQuery = '' === $context->token ? '' : '?'.http_build_query(['token' => $context->token], '', '&', PHP_QUERY_RFC3986);
        $sourceId = $request->attributes->get('sourceId', '');
        $babelChromeFileTypes = $request->attributes->get('babelChromeFileTypes', '');

        return [
            'BABELCHROME_MODULE_ID' => $module->id,
            'BABELCHROME_MODULE_NAME' => $module->name,
            'BABELCHROME_MODULE_VERSION' => $module->version,
            'BABELCHROME_MODULE_DIR' => $module->path,
            'BABELCHROME_MODULE_ROUTE' => $route,
            'BABELCHROME_MODULE_ASSET_BASE_URL' => $assetBaseUrl,
            'BABELCHROME_MODULE_ASSET_TOKEN_QUERY' => $assetTokenQuery,
            'BABELCHROME_LOCAL_SERVICE_BASE_URL' => $context->baseUrl,
            'BABELCHROME_LOCAL_SERVICE_TOKEN' => $context->token,
            'BABELCHROME_SOURCE_URL' => $context->sourceUrl,
            'BABELCHROME_SOURCE_ID' => is_string($sourceId) ? $sourceId : '',
            'BABELCHROME_FILE_TYPES' => is_string($babelChromeFileTypes) ? $babelChromeFileTypes : '',
            'BABELCHROME_ROUTE_PREFIX' => $routePath,
            'SCRIPT_FILENAME' => $module->path.'/'.ltrim($module->entrypoint, '/'),
            'SCRIPT_NAME' => $routePath,
            'REQUEST_URI' => $request->getRequestUri(),
            'REQUEST_METHOD' => $request->getMethod(),
        ];
    }

    /**
     * Dispatches one module web request in the current PHP process.
     *
     * @param ModuleManifest       $module     the module manifest
     * @param string               $route      the requested module route
     * @param Request              $request    the host request
     * @param ModuleRuntimeContext $context    the runtime context
     * @param string               $entrypoint the resolved front controller path
     *
     * @return Response the module response
     *
     * @throws ModuleDispatchException when the module cannot be executed
     */
    private function dispatchInProcess(ModuleManifest $module, string $route, Request $request, ModuleRuntimeContext $context, string $entrypoint): Response
    {
        $state = $this->captureState();
        $currentDirectory = getcwd();
        if (false === $currentDirectory) {
            $currentDirectory = null;
        }

        try {
            $this->prepareState($module, $route, $request, $context);
            chdir($module->path);
            ob_start();
            $result = require $entrypoint;
            $content = ob_get_clean();
            if (!is_string($content)) {
                $content = '';
            }

            if (null !== $currentDirectory) {
                chdir($currentDirectory);
            }
        } catch (\Throwable $exception) {
            if (ob_get_level() > $state['outputLevel']) {
                ob_end_clean();
            }

            if (null !== $currentDirectory) {
                chdir($currentDirectory);
            }

            $this->restoreState($state);

            throw new ModuleDispatchException(sprintf('Module "%s" web runtime failed: %s', $module->id, $exception->getMessage()), 0, $exception);
        }

        $this->restoreState($state);

        if ($result instanceof Response) {
            if ('' !== $content) {
                $result->setContent($content.$result->getContent());
            }

            return $result;
        }

        if (is_string($result) && '' !== $result) {
            $content .= $result;
        }

        return new Response($content, Response::HTTP_OK, ['Content-Type' => 'text/html; charset=utf-8']);
    }

    /**
     * Captures global PHP request state before module execution.
     *
     * @return array{get: array<array-key, mixed>, post: array<array-key, mixed>, cookie: array<array-key, mixed>, files: array<array-key, mixed>, server: array<array-key, mixed>, env: array<array-key, mixed>, outputLevel: int} the captured state
     */
    private function captureState(): array
    {
        return [
            'get' => $_GET,
            'post' => $_POST,
            'cookie' => $_COOKIE,
            'files' => $_FILES,
            'server' => $_SERVER,
            'env' => $_ENV,
            'outputLevel' => ob_get_level(),
        ];
    }

    /**
     * Prepares globals for one module web request.
     *
     * @param ModuleManifest       $module  the module manifest
     * @param string               $route   the requested module route
     * @param Request              $request the host request
     * @param ModuleRuntimeContext $context the runtime context
     */
    private function prepareState(ModuleManifest $module, string $route, Request $request, ModuleRuntimeContext $context): void
    {
        $_GET = $request->query->all();
        $_POST = $request->request->all();
        $_COOKIE = $request->cookies->all();
        $_FILES = [];
        $_SERVER = array_merge($_SERVER, $request->server->all(), $this->babelChromeServerVariables($module, $route, $request, $context));
        $_ENV = array_merge($_ENV, $this->babelChromeServerVariables($module, $route, $request, $context));

        foreach ($this->babelChromeServerVariables($module, $route, $request, $context) as $name => $value) {
            putenv($name.'='.$value);
        }
    }

    /**
     * Runs the module front controller in a dedicated PHP process.
     *
     * @param ModuleManifest       $module     the module manifest
     * @param string               $route      the requested module route
     * @param Request              $request    the host request
     * @param ModuleRuntimeContext $context    the runtime context
     * @param string               $entrypoint the resolved front controller path
     *
     * @return array{statusCode: int, headers: array<string, string|list<string>>, content: string} the isolated response
     *
     * @throws ModuleDispatchException when the isolated process cannot be executed
     */
    private function runIsolatedProcess(ModuleManifest $module, string $route, Request $request, ModuleRuntimeContext $context, string $entrypoint): array
    {
        $runner = dirname(__DIR__, 2).'/bin/module-web-runtime-runner.php';
        if (!is_file($runner)) {
            throw new ModuleDispatchException(sprintf('Module "%s" web runtime runner was not found.', $module->id));
        }

        $payload = [
            'modulePath' => $module->path,
            'entrypoint' => $entrypoint,
            'get' => $request->query->all(),
            'post' => $request->request->all(),
            'cookie' => $request->cookies->all(),
            'files' => [],
            'server' => array_merge($request->server->all(), $this->babelChromeServerVariables($module, $route, $request, $context)),
            'env' => $this->babelChromeServerVariables($module, $route, $request, $context),
            'responseMarker' => self::RESPONSE_MARKER,
        ];

        $process = proc_open(
            [PHP_BINARY, $runner],
            [
                0 => ['pipe', 'r'],
                1 => ['pipe', 'w'],
                2 => ['pipe', 'w'],
            ],
            $pipes,
            $module->path,
        );

        if (!is_resource($process)) {
            throw new ModuleDispatchException(sprintf('Module "%s" web runtime process could not be started.', $module->id));
        }

        fwrite($pipes[0], json_encode($payload, JSON_THROW_ON_ERROR));
        fclose($pipes[0]);

        $stdout = stream_get_contents($pipes[1]);
        fclose($pipes[1]);

        $stderr = stream_get_contents($pipes[2]);
        fclose($pipes[2]);

        $exitCode = proc_close($process);
        if (!is_string($stdout)) {
            $stdout = '';
        }

        if (!is_string($stderr)) {
            $stderr = '';
        }

        $markerPosition = strrpos($stdout, self::RESPONSE_MARKER);
        if (0 !== $exitCode || false === $markerPosition) {
            throw new ModuleDispatchException(sprintf('Module "%s" web runtime failed with exit code %d. %s%s', $module->id, $exitCode, '' !== $stderr ? 'Error: '.$stderr : '', '' !== $stdout ? ' Output: '.$stdout : ''));
        }

        $encodedResponse = substr($stdout, $markerPosition + strlen(self::RESPONSE_MARKER));
        $decodedResponse = json_decode($encodedResponse, true, 512, JSON_THROW_ON_ERROR);
        if (!is_array($decodedResponse)) {
            throw new ModuleDispatchException(sprintf('Module "%s" web runtime returned an invalid response.', $module->id));
        }

        $statusCode = $decodedResponse['statusCode'] ?? Response::HTTP_OK;
        $headers = $decodedResponse['headers'] ?? [];
        $content = $decodedResponse['content'] ?? '';

        return [
            'statusCode' => is_int($statusCode) ? $statusCode : Response::HTTP_OK,
            'headers' => is_array($headers) ? $this->normalizedHeaders($headers) : [],
            'content' => is_string($content) ? $content : '',
        ];
    }

    /**
     * Normalizes decoded process headers for HttpFoundation.
     *
     * @param array<mixed> $headers the decoded headers
     *
     * @return array<string, string|list<string>> the normalized headers
     */
    private function normalizedHeaders(array $headers): array
    {
        $normalizedHeaders = [];

        foreach ($headers as $name => $value) {
            if (!is_string($name)) {
                continue;
            }

            if (is_string($value)) {
                $normalizedHeaders[$name] = $value;

                continue;
            }

            if (!is_array($value)) {
                continue;
            }

            $values = [];
            foreach ($value as $headerValue) {
                if (is_string($headerValue)) {
                    $values[] = $headerValue;
                }
            }

            if ([] !== $values) {
                $normalizedHeaders[$name] = $values;
            }
        }

        return $normalizedHeaders;
    }

    /**
     * Restores global PHP request state.
     *
     * @param array{get: array<array-key, mixed>, post: array<array-key, mixed>, cookie: array<array-key, mixed>, files: array<array-key, mixed>, server: array<array-key, mixed>, env: array<array-key, mixed>, outputLevel: int} $state the captured state
     */
    private function restoreState(array $state): void
    {
        $_GET = $state['get'];
        $_POST = $state['post'];
        $_COOKIE = $state['cookie'];
        $_FILES = $state['files'];
        $_SERVER = $state['server'];
        $_ENV = $state['env'];
    }
}
