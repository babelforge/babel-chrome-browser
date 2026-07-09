<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

/**
 * Describes a module-owned non-web process runtime.
 */
final readonly class ModuleProcessRuntimeDefinition
{
    public const MODE_ON_DEMAND = 'on-demand';

    public const MODE_LONG_RUNNING = 'long-running';

    /**
     * @param string                                     $mode          the runtime mode
     * @param ModuleProcessRuntimeCommand                $command       the default command
     * @param array<string, ModuleProcessRuntimeCommand> $commands      route-specific commands indexed by route handler
     * @param string                                     $cwd           the working directory relative to the module root, or absolute
     * @param array<string, string>                      $env           the environment variables added to the process
     * @param string                                     $stopSignal    the stop signal name
     * @param int                                        $stopTimeoutMs the graceful stop timeout in milliseconds
     */
    public function __construct(
        public string $mode,
        public ModuleProcessRuntimeCommand $command,
        public array $commands,
        public string $cwd,
        public array $env,
        public string $stopSignal,
        public int $stopTimeoutMs,
    ) {
    }

    /**
     * Creates a process runtime definition from a manifest runtime declaration.
     *
     * @param mixed $runtime the decoded runtime declaration
     *
     * @return self|null the process runtime definition when valid
     */
    public static function fromManifestRuntime(mixed $runtime): ?self
    {
        if (!is_array($runtime)) {
            return null;
        }

        $defaultTimeoutMs = self::positiveInt($runtime['timeoutMs'] ?? null, 10000);
        $command = ModuleProcessRuntimeCommand::fromManifestValue($runtime, $defaultTimeoutMs);
        if (null === $command) {
            return null;
        }

        $mode = $runtime['mode'] ?? self::MODE_ON_DEMAND;
        $cwd = $runtime['cwd'] ?? '.';
        $stop = $runtime['stop'] ?? [];
        $stopSignal = is_array($stop) && is_string($stop['signal'] ?? null) ? $stop['signal'] : 'TERM';
        $stopTimeoutMs = is_array($stop) ? self::positiveInt($stop['timeoutMs'] ?? null, 3000) : 3000;

        return new self(
            self::normalizedMode(is_string($mode) ? $mode : self::MODE_ON_DEMAND),
            $command,
            self::commands($runtime['commands'] ?? [], $command->timeoutMs),
            is_string($cwd) && '' !== trim($cwd) ? trim($cwd) : '.',
            self::stringMap($runtime['env'] ?? []),
            '' !== trim($stopSignal) ? trim($stopSignal) : 'TERM',
            $stopTimeoutMs,
        );
    }

    /**
     * Returns the command for a route.
     *
     * @param string $route the requested route
     *
     * @return ModuleProcessRuntimeCommand the matching command
     */
    public function commandForRoute(string $route): ModuleProcessRuntimeCommand
    {
        return $this->commands[$route] ?? $this->command;
    }

    /**
     * Exports this definition as a manifest array.
     *
     * @return array<string, mixed> the exported definition
     */
    public function toArray(): array
    {
        return [
            'mode' => $this->mode,
            'command' => $this->command->command,
            'args' => $this->command->args,
            'timeoutMs' => $this->command->timeoutMs,
            'cwd' => $this->cwd,
            'env' => $this->env,
            'commands' => array_map(
                static fn (ModuleProcessRuntimeCommand $command): array => $command->toArray(),
                $this->commands,
            ),
            'stop' => [
                'signal' => $this->stopSignal,
                'timeoutMs' => $this->stopTimeoutMs,
            ],
        ];
    }

    /**
     * Normalizes a process runtime mode.
     *
     * @param string $mode the manifest mode
     *
     * @return string the normalized mode
     */
    private static function normalizedMode(string $mode): string
    {
        return self::MODE_LONG_RUNNING === $mode ? self::MODE_LONG_RUNNING : self::MODE_ON_DEMAND;
    }

    /**
     * Reads route-specific command declarations.
     *
     * @param mixed $value            the decoded commands value
     * @param int   $defaultTimeoutMs the default timeout in milliseconds
     *
     * @return array<string, ModuleProcessRuntimeCommand> the commands indexed by route
     */
    private static function commands(mixed $value, int $defaultTimeoutMs): array
    {
        if (!is_array($value)) {
            return [];
        }

        $commands = [];
        foreach ($value as $route => $commandValue) {
            if (!is_string($route) || '' === trim($route)) {
                continue;
            }

            $command = ModuleProcessRuntimeCommand::fromManifestValue($commandValue, $defaultTimeoutMs);
            if (null !== $command) {
                $commands[trim($route)] = $command;
            }
        }

        return $commands;
    }

    /**
     * Reads a string map from a manifest value.
     *
     * @param mixed $value the decoded manifest value
     *
     * @return array<string, string> the normalized string map
     */
    private static function stringMap(mixed $value): array
    {
        if (!is_array($value)) {
            return [];
        }

        $items = [];
        foreach ($value as $key => $item) {
            if (is_string($key) && is_string($item)) {
                $items[$key] = $item;
            }
        }

        return $items;
    }

    /**
     * Returns a positive integer value.
     *
     * @param mixed $value   the decoded manifest value
     * @param int   $default the default value
     *
     * @return int the positive integer
     */
    private static function positiveInt(mixed $value, int $default): int
    {
        return is_int($value) && $value > 0 ? $value : $default;
    }
}
