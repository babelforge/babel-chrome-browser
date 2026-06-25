<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

use Symfony\Component\HttpFoundation\Request;

/**
 * Exposes BabelChrome runtime helpers to a PHP module.
 */
final readonly class ModuleRuntimeContext
{
    /**
     * @param string $baseUrl   the local service base URL
     * @param string $token     the per-process LocalServiceHost token
     * @param string $sourceUrl the source URL forwarded by the native shell
     */
    public function __construct(
        public string $baseUrl,
        public string $token,
        public string $sourceUrl,
    ) {
    }

    /**
     * Creates a runtime context from an HTTP request.
     *
     * @param Request $request the current HTTP request
     *
     * @return self the runtime context
     */
    public static function fromRequest(Request $request): self
    {
        $tokenValue = $request->query->get('token', '');
        $sourceUrlValue = $request->query->get('sourceUrl', '');

        return new self(
            rtrim($request->getSchemeAndHttpHost(), '/'),
            is_string($tokenValue) ? $tokenValue : '',
            is_string($sourceUrlValue) ? $sourceUrlValue : '',
        );
    }

    /**
     * Returns a tokenized public asset URL for a module.
     *
     * @param ModuleManifest $module the module manifest
     * @param string         $path   the public asset path
     *
     * @return string the tokenized asset URL
     */
    public function moduleAssetUrl(ModuleManifest $module, string $path): string
    {
        return $this->tokenizedUrl(sprintf(
            '/module/%s/assets/%s',
            rawurlencode($module->id),
            ltrim($path, '/'),
        ));
    }

    /**
     * Returns a tokenized URL to one module route.
     *
     * @param ModuleManifest        $module     the module manifest
     * @param string                $route      the route handler name
     * @param array<string, string> $queryItems extra query items
     *
     * @return string the tokenized module route URL
     */
    public function moduleRouteUrl(ModuleManifest $module, string $route, array $queryItems = []): string
    {
        return $this->tokenizedUrl(sprintf(
            '/module/%s/%s',
            rawurlencode($module->id),
            ltrim($route, '/'),
        ), $queryItems);
    }

    /**
     * Returns an absolute tokenized local service URL.
     *
     * @param string                $path       the local service path
     * @param array<string, string> $queryItems extra query items
     *
     * @return string the tokenized URL
     */
    public function tokenizedUrl(string $path, array $queryItems = []): string
    {
        $queryItems['token'] = $this->token;
        $queryString = http_build_query($queryItems, '', '&', PHP_QUERY_RFC3986);

        return $this->baseUrl.'/'.ltrim($path, '/').('' === $queryString ? '' : '?'.$queryString);
    }
}
