<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module\Runtime;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleDispatchException;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleManifest;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Executes process-web modules through their own local HTTP process.
 */
final readonly class ProcessWebRuntimeHandler implements ModuleRuntimeHandlerInterface
{
    /**
     * @param ModuleProcessWebRuntime $processWebRuntime starts and proxies process-web modules
     */
    public function __construct(
        private ModuleProcessWebRuntime $processWebRuntime,
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
        return ModuleRuntimeType::isProcessWeb($module->runtimeType);
    }

    /**
     * Dispatches one process-web module route.
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
        return $this->processWebRuntime->dispatch($module, $route, $request);
    }
}
