<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module\Runtime;

use BabelForge\BabelChrome\LocalViewer\Module\BabelChromeModuleInterface;
use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleDispatchException;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleAutoloadRegistrar;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleManifest;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRequest;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRuntimeContext;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Executes PHP class modules implementing the ExtensionHost PHP interface.
 */
final readonly class PhpClassRuntimeHandler implements ModuleRuntimeHandlerInterface
{
    /**
     * @param ModuleAutoloadRegistrar $moduleAutoloadRegistrar registers module-local PHP autoloaders
     */
    public function __construct(
        private ModuleAutoloadRegistrar $moduleAutoloadRegistrar,
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
        return ModuleRuntimeType::isPhpClass($module->runtimeType);
    }

    /**
     * Dispatches one PHP class module route.
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
        if ('' === $module->entrypoint) {
            throw new ModuleDispatchException(sprintf('Module "%s" has no PHP class entrypoint.', $module->id));
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
}
