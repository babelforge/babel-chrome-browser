<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module\Runtime;

/**
 * Defines normalized BabelChrome module runtime type names.
 */
final class ModuleRuntimeType
{
    public const PHP_WEB = 'php-web';

    public const PHP_CLASS = 'php-class';

    public const STATIC_WEB = 'static-web';

    private const LEGACY_WEB = 'web';

    private const LEGACY_CLASS = 'class';

    /**
     * Normalizes a manifest runtime type.
     *
     * @param string $runtimeType the manifest runtime type
     *
     * @return string the normalized runtime type
     */
    public static function normalize(string $runtimeType): string
    {
        return match ($runtimeType) {
            '', self::LEGACY_CLASS => self::PHP_CLASS,
            self::LEGACY_WEB => self::PHP_WEB,
            default => $runtimeType,
        };
    }

    /**
     * Returns whether a runtime type is the PHP web runtime.
     *
     * @param string $runtimeType the runtime type
     *
     * @return bool true when the runtime type is PHP web
     */
    public static function isPhpWeb(string $runtimeType): bool
    {
        return self::PHP_WEB === self::normalize($runtimeType);
    }

    /**
     * Returns whether a runtime type is the PHP class runtime.
     *
     * @param string $runtimeType the runtime type
     *
     * @return bool true when the runtime type is PHP class
     */
    public static function isPhpClass(string $runtimeType): bool
    {
        return self::PHP_CLASS === self::normalize($runtimeType);
    }

    /**
     * Returns whether a runtime type is the static web runtime.
     *
     * @param string $runtimeType the runtime type
     *
     * @return bool true when the runtime type is static web
     */
    public static function isStaticWeb(string $runtimeType): bool
    {
        return self::STATIC_WEB === self::normalize($runtimeType);
    }

    /**
     * Returns whether a runtime type executes PHP module code.
     *
     * @param string $runtimeType the runtime type
     *
     * @return bool true when the runtime needs a PHP requirement
     */
    public static function requiresPhp(string $runtimeType): bool
    {
        return self::isPhpWeb($runtimeType) || self::isPhpClass($runtimeType);
    }
}
