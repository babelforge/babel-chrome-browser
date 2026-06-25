<?php

declare(strict_types=1);

use BabelForge\BabelChrome\LocalViewer\DocumentSource;
use BabelForge\BabelChrome\LocalViewer\Module\BabelChromeModuleInterface;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleManifest;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRequest;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRuntimeContext;
use BabelForge\BabelChrome\LocalViewer\Service\SourceLoader;
use BabelForge\BabelChrome\LocalViewer\Service\SourceRegistry;

require dirname(__DIR__).'/vendor/autoload.php';

/**
 * Keeps host API classes loaded before module-local dev autoloaders are registered.
 */
function babelchrome_load_host_api_classes(): void
{
    class_exists(DocumentSource::class);
    interface_exists(BabelChromeModuleInterface::class);
    class_exists(ModuleManifest::class);
    class_exists(ModuleRequest::class);
    class_exists(ModuleRuntimeContext::class);
    class_exists(SourceLoader::class);
    class_exists(SourceRegistry::class);
}

babelchrome_load_host_api_classes();
