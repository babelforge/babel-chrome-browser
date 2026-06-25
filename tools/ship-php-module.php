#!/usr/bin/env php
<?php

declare(strict_types=1);

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleShippingException;
use BabelForge\BabelChrome\LocalViewer\Module\ModulePackageShipper;

require __DIR__.'/../src/ExtensionHost/vendor/autoload.php';

/**
 * Prints command usage.
 */
function babelchrome_shipper_usage(): void
{
    fwrite(STDOUT, <<<'USAGE'
Usage:
  php tools/ship-php-module.php <module-directory> [target.zip]

The module directory must contain:
  manifest.json
  composer.json
  vendor/
  src/

The produced zip excludes dev-only directories such as tests, var, ai, .git, build, coverage, and node_modules.

USAGE);
}

if (2 > $argc || in_array($argv[1], ['--help', '-h'], true)) {
    babelchrome_shipper_usage();

    exit(0);
}

try {
    $targetPath = (new ModulePackageShipper())->ship($argv[1], $argv[2] ?? null);
    fwrite(STDOUT, $targetPath."\n");

    exit(0);
} catch (ModuleShippingException $exception) {
    fwrite(STDERR, $exception->getMessage()."\n");

    exit(65);
}
