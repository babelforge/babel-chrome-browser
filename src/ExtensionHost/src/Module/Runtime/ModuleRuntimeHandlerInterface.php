<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module\Runtime;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleDispatchException;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleManifest;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Defines an internal ExtensionHost runtime handler.
 */
interface ModuleRuntimeHandlerInterface
{
    /**
     * Returns whether this handler can execute a module.
     *
     * @param ModuleManifest $module the module manifest
     *
     * @return bool true when this handler supports the module runtime
     */
    public function supports(ModuleManifest $module): bool;

    /**
     * Dispatches one module route.
     *
     * @param ModuleManifest $module  the module manifest
     * @param string         $route   the requested module route
     * @param Request        $request the current HTTP request
     *
     * @return Response the module response
     *
     * @throws ModuleDispatchException when the module cannot be executed
     */
    public function dispatch(ModuleManifest $module, string $route, Request $request): Response;
}
