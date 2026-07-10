<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

/**
 * Registers enabled module Composer autoloaders without sharing module vendors.
 */
final class ModuleAutoloadRegistrar
{
    /**
     * @var array<string, true>
     */
    private static array $registeredAutoloaders = [];

    /**
     * @param ModuleRegistry $moduleRegistry exposes registered modules
     */
    public function __construct(
        private readonly ModuleRegistry $moduleRegistry,
    ) {
    }

    /**
     * Registers enabled module autoloaders.
     *
     * @return list<string> the registered autoloader paths
     */
    public function registerEnabledModuleAutoloaders(): array
    {
        $registered = [];
        foreach ($this->moduleRegistry->enabled() as $module) {
            if (!$module->usesPhpClassRuntime()) {
                continue;
            }

            $autoloadPath = $module->path.'/vendor/autoload.php';
            $autoloadKey = $module->id.'@'.$module->version;
            if (!is_file($autoloadPath) || isset(self::$registeredAutoloaders[$autoloadKey])) {
                continue;
            }

            require $autoloadPath;
            self::$registeredAutoloaders[$autoloadKey] = true;
            $registered[] = $autoloadPath;
        }

        return $registered;
    }
}
