<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

/**
 * Resolves module metadata from stable BabelChrome URLs.
 */
final readonly class ModuleUrlResolver
{
    /**
     * @param ModuleRegistry $moduleRegistry exposes registered modules
     */
    public function __construct(
        private ModuleRegistry $moduleRegistry,
    ) {
    }

    /**
     * Resolves a module for a stable URL.
     *
     * @param string $url the URL to resolve
     *
     * @return ModuleManifest|null the matching module when found
     */
    public function moduleForUrl(string $url): ?ModuleManifest
    {
        $route = $this->routeForStableUrl($url);

        return $route['module'] ?? null;
    }

    /**
     * Resolves a viewer module route for a local or remote source URL.
     *
     * @param string $url the source URL to resolve
     *
     * @return array{module: ModuleManifest, route: ModuleRoute}|null the matching route
     */
    public function viewerRouteForSourceUrl(string $url): ?array
    {
        $parts = parse_url($url);
        if (!is_array($parts)) {
            return null;
        }

        $scheme = strtolower((string) ($parts['scheme'] ?? ''));
        if ('file' !== $scheme && 'http' !== $scheme && 'https' !== $scheme) {
            return null;
        }

        $path = (string) ($parts['path'] ?? '');
        $extension = strtolower(pathinfo($path, PATHINFO_EXTENSION));
        if ('' === $extension) {
            return null;
        }

        $filename = strtolower(basename($path));
        $enabledModules = $this->moduleRegistry->enabled();
        foreach ($enabledModules as $module) {
            if ([] === $module->fileNameContains) {
                continue;
            }

            $candidateRoute = $this->candidateViewerRoute($module, $extension, $filename);
            if (null !== $candidateRoute) {
                return $candidateRoute;
            }
        }

        foreach ($enabledModules as $module) {
            if ([] !== $module->fileNameContains) {
                continue;
            }

            $candidateRoute = $this->candidateViewerRoute($module, $extension, $filename);
            if (null !== $candidateRoute) {
                return $candidateRoute;
            }
        }

        return null;
    }

    /**
     * Resolves a candidate viewer route for one module and source filename.
     *
     * @param ModuleManifest $module    the candidate module
     * @param string         $extension the source file extension
     * @param string         $filename  the lowercase source filename
     *
     * @return array{module: ModuleManifest, route: ModuleRoute}|null the matching route
     */
    private function candidateViewerRoute(ModuleManifest $module, string $extension, string $filename): ?array
    {
        if ('viewer' !== $module->type || !in_array($extension, $module->fileTypes, true)) {
            return null;
        }

        if (!$this->filenameMatchesModule($filename, $module)) {
            return null;
        }

        $route = $this->firstBabelChromeRoute($module);
        if (null === $route) {
            return null;
        }

        return [
            'module' => $module,
            'route' => $route,
        ];
    }

    /**
     * Resolves a module route for a stable BabelChrome URL.
     *
     * @param string $url the stable BabelChrome URL
     *
     * @return array{module: ModuleManifest, route: ModuleRoute}|null the matching route
     */
    public function routeForStableUrl(string $url): ?array
    {
        $parts = parse_url($url);
        if (!is_array($parts)) {
            return null;
        }

        $scheme = $parts['scheme'] ?? '';
        $host = $parts['host'] ?? '';
        if (!is_string($scheme) || !is_string($host) || '' === $scheme || '' === $host) {
            return null;
        }

        foreach ($this->moduleRegistry->enabled() as $module) {
            foreach ($module->routes as $route) {
                if ($route->scheme === $scheme && $route->host === $host) {
                    return [
                        'module' => $module,
                        'route' => $route,
                    ];
                }
            }
        }

        return null;
    }

    /**
     * Returns whether the filename matches module filename constraints.
     *
     * @param string         $filename the lowercase filename
     * @param ModuleManifest $module   the module manifest
     *
     * @return bool true when the filename matches
     */
    private function filenameMatchesModule(string $filename, ModuleManifest $module): bool
    {
        if ([] === $module->fileNameContains) {
            return true;
        }

        foreach ($module->fileNameContains as $fragment) {
            if (str_contains($filename, strtolower($fragment))) {
                return true;
            }
        }

        return false;
    }

    /**
     * Returns the first BabelChrome route declared by a module.
     *
     * @param ModuleManifest $module the module manifest
     *
     * @return ModuleRoute|null the route when found
     */
    private function firstBabelChromeRoute(ModuleManifest $module): ?ModuleRoute
    {
        foreach ($module->routes as $route) {
            if ('babelchrome' === $route->scheme && '' !== $route->host && '' !== $route->handler) {
                return $route;
            }
        }

        return null;
    }
}
