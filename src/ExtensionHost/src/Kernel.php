<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer;

use Symfony\Bundle\FrameworkBundle\Kernel\MicroKernelTrait;
use Symfony\Component\HttpKernel\Kernel as BaseKernel;

/**
 * Symfony kernel for the BabelChrome local viewer service.
 */
final class Kernel extends BaseKernel
{
    use MicroKernelTrait;

    /**
     * Returns the cache directory outside the application bundle.
     *
     * @return string the cache directory path
     */
    public function getCacheDir(): string
    {
        return $this->stateDirectory().'/cache/'.$this->environment.'/'.$this->cacheKey();
    }

    /**
     * Returns the log directory outside the application bundle.
     *
     * @return string the log directory path
     */
    public function getLogDir(): string
    {
        return $this->stateDirectory().'/log';
    }

    /**
     * Returns the writable state directory for the embedded service.
     *
     * @return string the writable state directory path
     */
    private function stateDirectory(): string
    {
        $stateDirectory = $this->environmentString('BABELCHROME_VIEWER_STATE_DIR', '');
        if ('' !== $stateDirectory) {
            return $stateDirectory;
        }

        return sys_get_temp_dir().'/babel-chrome-local-viewer';
    }

    /**
     * Returns the cache key for the embedded runtime.
     *
     * @return string the safe cache key
     */
    private function cacheKey(): string
    {
        $cacheKey = $this->environmentString('BABELCHROME_VIEWER_CACHE_KEY', 'default');
        $safeCacheKey = preg_replace('/[^A-Za-z0-9_.-]/', '_', $cacheKey);
        if (!is_string($safeCacheKey) || '' === $safeCacheKey) {
            return 'default';
        }

        return $safeCacheKey;
    }

    /**
     * Reads a string environment value.
     *
     * @param string $name    the environment variable name
     * @param string $default the default value
     *
     * @return string the resolved environment value
     */
    private function environmentString(string $name, string $default): string
    {
        $serverValue = $_SERVER[$name] ?? null;
        if (is_string($serverValue)) {
            return $serverValue;
        }

        $envValue = $_ENV[$name] ?? null;
        if (is_string($envValue)) {
            return $envValue;
        }

        $processValue = getenv($name);
        if (is_string($processValue)) {
            return $processValue;
        }

        return $default;
    }
}
