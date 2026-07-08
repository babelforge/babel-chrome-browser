<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleDispatchException;
use BabelForge\BabelChrome\LocalViewer\Module\Runtime\ModuleRuntimeDispatcher;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Dispatches local HTTP requests to installed modules.
 */
final readonly class ModuleRouteDispatcher
{
    /**
     * @param ModuleRegistry          $moduleRegistry          exposes registered modules
     * @param ModuleRuntimeDispatcher $moduleRuntimeDispatcher dispatches requests to runtime handlers
     */
    public function __construct(
        private ModuleRegistry $moduleRegistry,
        private ModuleRuntimeDispatcher $moduleRuntimeDispatcher,
    ) {
    }

    /**
     * Dispatches one module route.
     *
     * @param string  $moduleId the module identifier
     * @param string  $route    the module route
     * @param Request $request  the current HTTP request
     *
     * @return Response the module response
     *
     * @throws ModuleDispatchException when the module cannot handle the request
     */
    public function dispatch(string $moduleId, string $route, Request $request): Response
    {
        $module = $this->moduleRegistry->find($moduleId);
        if (null === $module) {
            throw new ModuleDispatchException(sprintf('Module "%s" is not registered.', $moduleId));
        }

        if (!$module->enabled) {
            throw new ModuleDispatchException(sprintf('Module "%s" is disabled.', $moduleId));
        }

        if (!$this->routeIsDeclared($module, $route)) {
            throw new ModuleDispatchException(sprintf('Module "%s" does not declare route "%s".', $moduleId, $route));
        }

        return $this->moduleRuntimeDispatcher->dispatch($module, $route, $request);
    }

    /**
     * Returns whether a module declares a handler route.
     *
     * @param ModuleManifest $module the module manifest
     * @param string         $route  the route to check
     *
     * @return bool true when the route is declared
     */
    private function routeIsDeclared(ModuleManifest $module, string $route): bool
    {
        foreach ($module->routes as $declaredRoute) {
            if ($declaredRoute->handler === $route) {
                return true;
            }
        }

        return false;
    }
}
