<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

/**
 * Builds the hook index exposed by enabled modules.
 */
final readonly class ModuleHookRegistry
{
    /**
     * @param ModuleRegistry $moduleRegistry exposes installed modules
     */
    public function __construct(
        private ModuleRegistry $moduleRegistry,
    ) {
    }

    /**
     * Returns all hooks grouped by hook name.
     *
     * @return array<string, list<array<string, mixed>>> the hook index
     */
    public function all(): array
    {
        $hooks = [];
        foreach ($this->moduleRegistry->enabled() as $module) {
            foreach ($module->hooks as $hook) {
                $hooks[$hook] ??= [];
                $hooks[$hook][] = $this->moduleHookPayload($module, $hook);
            }
        }

        ksort($hooks);

        return $hooks;
    }

    /**
     * Returns modules exposing one hook.
     *
     * @param string $hook the hook name
     *
     * @return list<array<string, mixed>> the module payloads
     */
    public function forHook(string $hook): array
    {
        if ('' === $hook) {
            return [];
        }

        $modules = [];
        foreach ($this->moduleRegistry->enabled() as $module) {
            if (in_array($hook, $module->hooks, true)) {
                $modules[] = $this->moduleHookPayload($module, $hook);
            }
        }

        return $modules;
    }

    /**
     * Returns menu items exposed for one hook and optional contexts.
     *
     * @param string       $hook     the hook name
     * @param list<string> $contexts the requested contexts
     *
     * @return list<array<string, mixed>> the menu item payloads
     */
    public function menuItems(string $hook, array $contexts = []): array
    {
        if ('' === $hook) {
            return [];
        }

        $items = [];
        foreach ($this->moduleRegistry->enabled() as $module) {
            if (!in_array($hook, $module->hooks, true)) {
                continue;
            }

            foreach ($module->menuItems as $menuItem) {
                if ($hook !== $menuItem->hook || !$this->menuItemMatchesContexts($menuItem, $contexts)) {
                    continue;
                }

                $items[] = [
                    'moduleId' => $module->id,
                    'moduleName' => $module->name,
                    'moduleType' => $module->type,
                    'item' => $menuItem->toArray(),
                ];
            }
        }

        return $items;
    }

    /**
     * Returns the minimal module payload needed by hook consumers.
     *
     * @param ModuleManifest $module the module manifest
     * @param string         $hook   the hook name
     *
     * @return array<string, mixed> the module hook payload
     */
    private function moduleHookPayload(ModuleManifest $module, string $hook): array
    {
        return [
            'id' => $module->id,
            'name' => $module->name,
            'type' => $module->type,
            'routes' => array_map(
                static fn (ModuleRoute $route): array => $route->toArray(),
                $module->routes,
            ),
            'permissions' => $module->permissions,
            'menuItems' => $this->menuItemsForHook($module, $hook),
            'badge' => $module->badge?->toArray(),
            'settingsRoute' => $module->settingsRoute,
            'defaultGroup' => $module->defaultGroup,
        ];
    }

    /**
     * Returns module menu items attached to one hook.
     *
     * @param ModuleManifest $module the module manifest
     * @param string         $hook   the hook name
     *
     * @return list<array<string, mixed>> the menu item payloads
     */
    private function menuItemsForHook(ModuleManifest $module, string $hook): array
    {
        $menuItems = [];
        foreach ($module->menuItems as $menuItem) {
            if ($hook === $menuItem->hook) {
                $menuItems[] = $menuItem->toArray();
            }
        }

        return $menuItems;
    }

    /**
     * Returns whether a menu item matches requested contexts.
     *
     * @param ModuleMenuItem $menuItem the menu item
     * @param list<string>   $contexts the requested contexts
     *
     * @return bool true when the item is relevant
     */
    private function menuItemMatchesContexts(ModuleMenuItem $menuItem, array $contexts): bool
    {
        if ([] === $contexts || [] === $menuItem->contexts) {
            return true;
        }

        return [] !== array_intersect($contexts, $menuItem->contexts);
    }
}
