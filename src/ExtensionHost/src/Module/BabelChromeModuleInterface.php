<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

use Symfony\Component\HttpFoundation\Response;

/**
 * Defines the runtime contract implemented by routable PHP modules.
 */
interface BabelChromeModuleInterface
{
    /**
     * Handles one routed module request.
     *
     * @param ModuleRequest $request the module request context
     *
     * @return Response the module response
     */
    public function handle(ModuleRequest $request): Response;
}
