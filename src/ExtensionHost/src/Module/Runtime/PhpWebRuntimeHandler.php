<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module\Runtime;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleDispatchException;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleManifest;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleWebRuntime;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Executes PHP web front-controller modules.
 */
final readonly class PhpWebRuntimeHandler implements ModuleRuntimeHandlerInterface
{
    /**
     * @param ModuleWebRuntime $moduleWebRuntime runs PHP web front controllers
     */
    public function __construct(
        private ModuleWebRuntime $moduleWebRuntime,
    ) {
    }

    /**
     * Returns whether this handler can execute a module.
     *
     * @param ModuleManifest $module the module manifest
     *
     * @return bool true when this handler supports the module runtime
     */
    public function supports(ModuleManifest $module): bool
    {
        return ModuleRuntimeType::isPhpWeb($module->runtimeType);
    }

    /**
     * Dispatches one PHP web module route.
     *
     * @param ModuleManifest $module  the module manifest
     * @param string         $route   the requested module route
     * @param Request        $request the current HTTP request
     *
     * @return Response the module response
     *
     * @throws ModuleDispatchException when the module cannot be executed
     */
    public function dispatch(ModuleManifest $module, string $route, Request $request): Response
    {
        return $this->moduleWebRuntime->dispatch($module, $route, $request);
    }
}
