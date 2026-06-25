<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleManifestException;

/**
 * Describes an installed BabelChrome PHP module.
 */
final readonly class ModuleManifest
{
    /**
     * @param string               $id                       the stable module identifier
     * @param string               $name                     the display name
     * @param string               $version                  the semantic module version
     * @param string               $description              the human-readable description
     * @param string               $type                     the module type
     * @param bool                 $enabled                  whether this module is enabled
     * @param string               $entrypoint               the PHP entrypoint class or web front controller
     * @param string               $runtimeType              the module runtime type
     * @param bool                 $processIsolation         whether the web runtime uses a dedicated PHP process
     * @param string               $phpRequirement           the required PHP version constraint
     * @param string               $path                     the module root path
     * @param list<ModuleRoute>    $routes                   the module routes
     * @param list<string>         $fileTypes                the file extensions handled by the viewer router
     * @param list<string>         $fileNameContains         lowercase filename fragments required by the module
     * @param list<string>         $fileTypeHandlerFileTypes the file extensions advertised to web pages
     * @param list<string>         $hooks                    the hooks implemented by the module
     * @param list<string>         $permissions              the requested permissions
     * @param list<ModuleMenuItem> $menuItems                the menu items contributed by the module
     * @param ModuleBadge|null     $badge                    the optional address badge
     * @param string|null          $settingsRoute            the optional settings route
     * @param string               $currentPhpVersion        the PHP version used to validate this manifest
     */
    public function __construct(
        public string $id,
        public string $name,
        public string $version,
        public string $description,
        public string $type,
        public bool $enabled,
        public string $entrypoint,
        public string $runtimeType,
        public bool $processIsolation,
        public string $phpRequirement,
        public string $path,
        public array $routes,
        public array $fileTypes,
        public array $fileNameContains,
        public array $fileTypeHandlerFileTypes,
        public array $hooks,
        public array $permissions,
        public array $menuItems,
        public ?ModuleBadge $badge,
        public ?string $settingsRoute,
        public string $currentPhpVersion = PHP_VERSION,
    ) {
        if ('' === $this->id) {
            throw new ModuleManifestException('Module id cannot be empty.');
        }

        if (1 !== preg_match('/^[a-z0-9][a-z0-9.-]*[a-z0-9]$/', $this->id)) {
            throw new ModuleManifestException(sprintf('Module id "%s" is invalid.', $this->id));
        }

        if ('' === $this->name) {
            throw new ModuleManifestException(sprintf('Module "%s" name cannot be empty.', $this->id));
        }

        if ('' === $this->version) {
            throw new ModuleManifestException(sprintf('Module "%s" version cannot be empty.', $this->id));
        }

        if ('' === $this->phpRequirement) {
            throw new ModuleManifestException(sprintf('Module "%s" must declare requirements.php.', $this->id));
        }

        if (!self::phpVersionSatisfies($this->currentPhpVersion, $this->phpRequirement)) {
            throw new ModuleManifestException(sprintf('Module "%s" requires PHP "%s"; current PHP is "%s".', $this->id, $this->phpRequirement, $this->currentPhpVersion));
        }
    }

    /**
     * Creates a manifest from a decoded manifest array.
     *
     * @param array<string, mixed> $data the decoded manifest data
     * @param string               $path the module root path
     *
     * @return self the manifest
     */
    public static function fromArray(array $data, string $path): self
    {
        return new self(
            self::requiredString($data, 'id'),
            self::requiredString($data, 'name'),
            self::requiredString($data, 'version'),
            self::optionalString($data, 'description', ''),
            self::optionalString($data, 'type', 'module'),
            self::optionalBool($data, 'enabled', true),
            self::entrypoint($data),
            self::runtimeType($data),
            self::processIsolation($data),
            self::phpRequirement($data),
            $path,
            self::routes($data),
            self::stringList($data, 'fileTypes'),
            self::stringList($data, 'fileNameContains'),
            self::fileTypeHandlerFileTypes($data),
            self::stringList($data, 'hooks'),
            self::stringList($data, 'permissions'),
            self::menuItems($data),
            self::badge($data),
            self::settingsRoute($data),
        );
    }

    /**
     * Exports this manifest as a serializable array.
     *
     * @return array<string, mixed> the exported manifest
     */
    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'version' => $this->version,
            'description' => $this->description,
            'type' => $this->type,
            'enabled' => $this->enabled,
            'entrypoint' => $this->entrypoint,
            'runtimeType' => $this->runtimeType,
            'runtime' => self::runtimeExport($this->runtimeType, $this->entrypoint, $this->processIsolation),
            'requirements' => [
                'php' => $this->phpRequirement,
            ],
            'currentPhpVersion' => $this->currentPhpVersion,
            'path' => $this->path,
            'routes' => array_map(
                static fn (ModuleRoute $route): array => $route->toArray(),
                $this->routes,
            ),
            'fileTypes' => $this->fileTypes,
            'fileNameContains' => $this->fileNameContains,
            'fileTypeHandler' => [
                'fileTypes' => $this->fileTypeHandlerFileTypes,
            ],
            'hooks' => $this->hooks,
            'permissions' => $this->permissions,
            'menuItems' => array_map(
                static fn (ModuleMenuItem $menuItem): array => $menuItem->toArray(),
                $this->menuItems,
            ),
            'badge' => $this->badge?->toArray(),
            'settingsRoute' => $this->settingsRoute,
            'hasIsolatedVendor' => $this->hasIsolatedVendor(),
        ];
    }

    /**
     * Returns whether this module ships its own Composer vendor.
     *
     * @return bool true when the module has its own vendor autoloader
     */
    public function hasIsolatedVendor(): bool
    {
        return is_file($this->path.'/vendor/autoload.php');
    }

    /**
     * Returns whether this module is served by a web front controller.
     *
     * @return bool true when the module uses the generic web runtime
     */
    public function usesWebRuntime(): bool
    {
        return 'web' === $this->runtimeType;
    }

    /**
     * Returns whether this module web runtime should use a dedicated PHP process.
     *
     * @return bool true when the web runtime must be process-isolated
     */
    public function usesProcessIsolation(): bool
    {
        return $this->usesWebRuntime() && $this->processIsolation;
    }

    /**
     * Reads a required string from an array.
     *
     * @param array<string, mixed> $data the source data
     * @param string               $key  the key to read
     *
     * @return string the string value
     */
    private static function requiredString(array $data, string $key): string
    {
        $value = $data[$key] ?? null;
        if (!is_string($value) || '' === $value) {
            throw new ModuleManifestException(sprintf('Manifest field "%s" is required.', $key));
        }

        return $value;
    }

    /**
     * Reads an optional string from an array.
     *
     * @param array<string, mixed> $data    the source data
     * @param string               $key     the key to read
     * @param string               $default the default value
     *
     * @return string the string value
     */
    private static function optionalString(array $data, string $key, string $default): string
    {
        $value = $data[$key] ?? $default;

        return is_string($value) ? $value : $default;
    }

    /**
     * Reads the module entrypoint from an array.
     *
     * @param array<string, mixed> $data the source data
     *
     * @return string the entrypoint
     */
    private static function entrypoint(array $data): string
    {
        $entrypoint = self::optionalString($data, 'entrypoint', '');
        if ('' !== $entrypoint) {
            return $entrypoint;
        }

        $runtime = $data['runtime'] ?? null;
        if (!is_array($runtime)) {
            return '';
        }

        $runtimeEntrypoint = $runtime['entrypoint'] ?? null;

        return is_string($runtimeEntrypoint) ? $runtimeEntrypoint : '';
    }

    /**
     * Reads the module runtime type from an array.
     *
     * @param array<string, mixed> $data the source data
     *
     * @return string the runtime type
     */
    private static function runtimeType(array $data): string
    {
        $runtime = $data['runtime'] ?? null;
        if (is_array($runtime)) {
            $type = $runtime['type'] ?? null;

            return is_string($type) && '' !== $type ? $type : 'class';
        }

        return is_string($runtime) && '' !== $runtime ? $runtime : 'class';
    }

    /**
     * Reads the module process isolation setting from an array.
     *
     * @param array<string, mixed> $data the source data
     *
     * @return bool true when the web runtime should be process-isolated
     */
    private static function processIsolation(array $data): bool
    {
        $runtime = $data['runtime'] ?? null;
        if (!is_array($runtime)) {
            return false;
        }

        return true === ($runtime['processIsolation'] ?? false);
    }

    /**
     * Reads the required PHP version constraint.
     *
     * @param array<string, mixed> $data the source data
     *
     * @return string the required PHP version constraint
     */
    private static function phpRequirement(array $data): string
    {
        $requirements = $data['requirements'] ?? null;
        if (!is_array($requirements)) {
            throw new ModuleManifestException('Manifest field "requirements.php" is required.');
        }

        $phpRequirement = $requirements['php'] ?? null;
        if (!is_string($phpRequirement) || '' === trim($phpRequirement)) {
            throw new ModuleManifestException('Manifest field "requirements.php" is required.');
        }

        return trim($phpRequirement);
    }

    /**
     * Returns whether a PHP version satisfies a simple module constraint.
     *
     * @param string $phpVersion the current PHP version
     * @param string $constraint the PHP version constraint
     *
     * @return bool true when the constraint is satisfied
     */
    private static function phpVersionSatisfies(string $phpVersion, string $constraint): bool
    {
        $parts = preg_split('/[\s,]+/', trim($constraint));
        if (false === $parts || [] === $parts) {
            throw new ModuleManifestException(sprintf('PHP requirement "%s" is invalid.', $constraint));
        }

        foreach ($parts as $part) {
            if ('' === $part) {
                continue;
            }

            if (!self::phpVersionSatisfiesPart($phpVersion, $part)) {
                return false;
            }
        }

        return true;
    }

    /**
     * Returns whether a PHP version satisfies one simple constraint part.
     *
     * @param string $phpVersion the current PHP version
     * @param string $constraint the constraint part
     *
     * @return bool true when the constraint is satisfied
     */
    private static function phpVersionSatisfiesPart(string $phpVersion, string $constraint): bool
    {
        if (1 !== preg_match('/^(>=|<=|>|<|=|==)?\s*([0-9]+(?:\.[0-9]+){0,2})$/', $constraint, $matches)) {
            throw new ModuleManifestException(sprintf('PHP requirement "%s" is invalid.', $constraint));
        }

        $operator = '' !== $matches[1] ? $matches[1] : '==';
        if ('=' === $operator) {
            $operator = '==';
        }

        return version_compare($phpVersion, $matches[2], $operator);
    }

    /**
     * Exports the module runtime declaration.
     *
     * @param string $runtimeType      the runtime type
     * @param string $entrypoint       the entrypoint
     * @param bool   $processIsolation whether the runtime uses process isolation
     *
     * @return array{type: string, entrypoint: string, processIsolation?: true} the runtime declaration
     */
    private static function runtimeExport(string $runtimeType, string $entrypoint, bool $processIsolation): array
    {
        $runtime = [
            'type' => $runtimeType,
            'entrypoint' => $entrypoint,
        ];

        if ($processIsolation) {
            $runtime['processIsolation'] = true;
        }

        return $runtime;
    }

    /**
     * Reads an optional boolean from an array.
     *
     * @param array<string, mixed> $data    the source data
     * @param string               $key     the key to read
     * @param bool                 $default the default value
     *
     * @return bool the boolean value
     */
    private static function optionalBool(array $data, string $key, bool $default): bool
    {
        $value = $data[$key] ?? $default;

        return is_bool($value) ? $value : $default;
    }

    /**
     * Reads a string list from an array.
     *
     * @param array<string, mixed> $data the source data
     * @param string               $key  the key to read
     *
     * @return list<string> the string list
     */
    private static function stringList(array $data, string $key): array
    {
        $value = $data[$key] ?? [];
        if (!is_array($value)) {
            return [];
        }

        $strings = [];
        foreach ($value as $item) {
            if (is_string($item) && '' !== $item) {
                $strings[] = $item;
            }
        }

        return $strings;
    }

    /**
     * Reads file type handler declarations from a manifest.
     *
     * @param array<string, mixed> $data the source data
     *
     * @return list<string> the normalized advertised file extensions
     */
    private static function fileTypeHandlerFileTypes(array $data): array
    {
        $handler = $data['file-type-handler'] ?? $data['fileTypeHandler'] ?? null;
        if (!is_array($handler)) {
            return self::normalizedFileTypes(self::stringList($data, 'fileTypes'));
        }

        $value = $handler['fileTypes'] ?? $handler['file-types'] ?? [];
        if (!is_array($value)) {
            return [];
        }

        return self::normalizedFileTypes($value);
    }

    /**
     * Normalizes file extension declarations.
     *
     * @param array<mixed> $value the raw extension declarations
     *
     * @return list<string> the normalized file extensions
     */
    private static function normalizedFileTypes(array $value): array
    {
        $fileTypes = [];
        foreach ($value as $item) {
            if (!is_string($item)) {
                continue;
            }

            $fileType = strtolower(ltrim(trim($item), '.'));
            if ('' !== $fileType && !in_array($fileType, $fileTypes, true)) {
                $fileTypes[] = $fileType;
            }
        }

        return $fileTypes;
    }

    /**
     * Reads route declarations from an array.
     *
     * @param array<string, mixed> $data the source data
     *
     * @return list<ModuleRoute> the routes
     */
    private static function routes(array $data): array
    {
        $value = $data['routes'] ?? [];
        if (!is_array($value)) {
            return [];
        }

        $routes = [];
        foreach ($value as $item) {
            if (is_array($item)) {
                /** @var array<string, mixed> $routeData */
                $routeData = $item;
                $routes[] = ModuleRoute::fromArray($routeData);
            }
        }

        return $routes;
    }

    /**
     * Reads the optional settings route from an array.
     *
     * @param array<string, mixed> $data the source data
     *
     * @return string|null the settings route
     */
    private static function settingsRoute(array $data): ?string
    {
        $settings = $data['settings'] ?? null;
        if (!is_array($settings)) {
            return null;
        }

        $route = $settings['route'] ?? null;

        return is_string($route) && '' !== $route ? $route : null;
    }

    /**
     * Reads menu item declarations from an array.
     *
     * @param array<string, mixed> $data the source data
     *
     * @return list<ModuleMenuItem> the menu items
     */
    private static function menuItems(array $data): array
    {
        $value = $data['menuItems'] ?? [];
        if (!is_array($value)) {
            return [];
        }

        $menuItems = [];
        foreach ($value as $item) {
            if (is_array($item)) {
                /** @var array<string, mixed> $menuItemData */
                $menuItemData = $item;
                $menuItem = ModuleMenuItem::fromArray($menuItemData);
                if (null !== $menuItem) {
                    $menuItems[] = $menuItem;
                }
            }
        }

        return $menuItems;
    }

    /**
     * Reads the optional badge from an array.
     *
     * @param array<string, mixed> $data the source data
     *
     * @return ModuleBadge|null the optional badge
     */
    private static function badge(array $data): ?ModuleBadge
    {
        $badge = $data['badge'] ?? null;
        if (!is_array($badge)) {
            return null;
        }

        /** @var array<string, mixed> $badgeData */
        $badgeData = $badge;

        return ModuleBadge::fromArray($badgeData);
    }
}
