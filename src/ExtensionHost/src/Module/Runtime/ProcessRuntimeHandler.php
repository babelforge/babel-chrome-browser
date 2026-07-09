<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module\Runtime;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleDispatchException;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleManifest;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Executes process-runtime modules through command stdin/stdout contracts.
 */
final readonly class ProcessRuntimeHandler implements ModuleRuntimeHandlerInterface
{
    /**
     * @param ModuleProcessRuntime $processRuntime runs non-web process modules
     */
    public function __construct(
        private ModuleProcessRuntime $processRuntime,
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
        return ModuleRuntimeType::isProcessRuntime($module->runtimeType);
    }

    /**
     * Dispatches one process-runtime module route.
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
        return $this->processRuntime->dispatch($module, $route, $request);
    }
}
