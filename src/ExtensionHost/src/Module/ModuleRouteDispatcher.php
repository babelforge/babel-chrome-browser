<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleDispatchException;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Dispatches local HTTP requests to installed PHP modules.
 */
final readonly class ModuleRouteDispatcher
{
    /**
     * @param ModuleRegistry          $moduleRegistry          exposes registered modules
     * @param ModuleAutoloadRegistrar $moduleAutoloadRegistrar registers module-local vendors
     * @param ModuleWebRuntime        $moduleWebRuntime        runs generic web modules
     */
    public function __construct(
        private ModuleRegistry $moduleRegistry,
        private ModuleAutoloadRegistrar $moduleAutoloadRegistrar,
        private ModuleWebRuntime $moduleWebRuntime,
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

        if ($module->usesWebRuntime()) {
            return $this->moduleWebRuntime->dispatch($module, $route, $request);
        }

        if ('' === $module->entrypoint) {
            throw new ModuleDispatchException(sprintf('Module "%s" has no PHP entrypoint.', $moduleId));
        }

        $this->moduleAutoloadRegistrar->registerEnabledModuleAutoloaders();

        if (!class_exists($module->entrypoint)) {
            throw new ModuleDispatchException(sprintf('Module entrypoint "%s" was not found. Check the module vendor autoloader.', $module->entrypoint));
        }

        $handler = new $module->entrypoint();
        if (!$handler instanceof BabelChromeModuleInterface) {
            throw new ModuleDispatchException(sprintf('Module entrypoint "%s" must implement %s.', $module->entrypoint, BabelChromeModuleInterface::class));
        }

        return $handler->handle(new ModuleRequest(
            $module,
            $route,
            $request,
            ModuleRuntimeContext::fromRequest($request),
        ));
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
