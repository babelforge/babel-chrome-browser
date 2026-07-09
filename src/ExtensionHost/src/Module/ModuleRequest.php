<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

use Symfony\Component\HttpFoundation\Request;

/**
 * Carries the request context passed to a routed module.
 */
final readonly class ModuleRequest
{
    /**
     * @param ModuleManifest       $module  the routed module manifest
     * @param string               $route   the requested module route
     * @param Request              $request the underlying HTTP request
     * @param ModuleRuntimeContext $context the BabelChrome runtime context
     */
    public function __construct(
        public ModuleManifest $module,
        public string $route,
        public Request $request,
        public ModuleRuntimeContext $context,
    ) {
    }
}
