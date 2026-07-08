<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module\Runtime;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleDispatchException;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleManifest;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Dispatches module requests to the matching runtime handler.
 */
final readonly class ModuleRuntimeDispatcher
{
    /**
     * @var list<ModuleRuntimeHandlerInterface>
     */
    private array $handlers;

    /**
     * @param PhpWebRuntimeHandler   $phpWebRuntimeHandler   handles PHP web modules
     * @param PhpClassRuntimeHandler $phpClassRuntimeHandler handles PHP class modules
     */
    public function __construct(
        PhpWebRuntimeHandler $phpWebRuntimeHandler,
        PhpClassRuntimeHandler $phpClassRuntimeHandler,
    ) {
        $this->handlers = [
            $phpWebRuntimeHandler,
            $phpClassRuntimeHandler,
        ];
    }

    /**
     * Dispatches one module route to a runtime handler.
     *
     * @param ModuleManifest $module  the module manifest
     * @param string         $route   the requested module route
     * @param Request        $request the current HTTP request
     *
     * @return Response the module response
     *
     * @throws ModuleDispatchException when no runtime handler supports the module
     */
    public function dispatch(ModuleManifest $module, string $route, Request $request): Response
    {
        foreach ($this->handlers as $handler) {
            if ($handler->supports($module)) {
                return $handler->dispatch($module, $route, $request);
            }
        }

        throw new ModuleDispatchException(sprintf('Module "%s" uses unsupported runtime "%s".', $module->id, $module->runtimeType));
    }
}
