<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

/**
 * Describes a module-owned local HTTP process runtime.
 */
final readonly class ModuleProcessWebDefinition
{
    /**
     * @param string                $command       the executable command path or name
     * @param list<string>          $args          the command arguments
     * @param string                $cwd           the working directory relative to the module root, or absolute
     * @param array<string, string> $env           the environment variables added to the process
     * @param string                $readyUrl      the readiness URL template
     * @param int                   $timeoutMs     the process readiness timeout in milliseconds
     * @param string                $stopSignal    the stop signal name
     * @param int                   $stopTimeoutMs the graceful stop timeout in milliseconds
     */
    public function __construct(
        public string $command,
        public array $args,
        public string $cwd,
        public array $env,
        public string $readyUrl,
        public int $timeoutMs,
        public string $stopSignal,
        public int $stopTimeoutMs,
    ) {
    }

    /**
     * Creates a process web definition from a manifest runtime declaration.
     *
     * @param mixed $runtime the decoded runtime declaration
     *
     * @return self|null the process web definition when valid
     */
    public static function fromManifestRuntime(mixed $runtime): ?self
    {
        if (!is_array($runtime)) {
            return null;
        }

        $command = $runtime['command'] ?? null;
        if (!is_string($command) || '' === trim($command)) {
            return null;
        }

        $cwd = $runtime['cwd'] ?? '.';
        $readyUrl = $runtime['readyUrl'] ?? 'http://127.0.0.1:{{ port }}';
        $timeoutMs = $runtime['timeoutMs'] ?? 10000;
        $stop = $runtime['stop'] ?? [];
        $stopSignal = is_array($stop) && is_string($stop['signal'] ?? null) ? $stop['signal'] : 'TERM';
        $stopTimeoutMs = is_array($stop) && is_int($stop['timeoutMs'] ?? null) ? $stop['timeoutMs'] : 3000;

        return new self(
            trim($command),
            self::stringList($runtime['args'] ?? []),
            is_string($cwd) && '' !== trim($cwd) ? trim($cwd) : '.',
            self::stringMap($runtime['env'] ?? []),
            is_string($readyUrl) && '' !== trim($readyUrl) ? trim($readyUrl) : 'http://127.0.0.1:{{ port }}',
            is_int($timeoutMs) && $timeoutMs > 0 ? $timeoutMs : 10000,
            '' !== trim($stopSignal) ? trim($stopSignal) : 'TERM',
            $stopTimeoutMs > 0 ? $stopTimeoutMs : 3000,
        );
    }

    /**
     * Exports this definition as a manifest array.
     *
     * @return array<string, mixed> the exported definition
     */
    public function toArray(): array
    {
        return [
            'command' => $this->command,
            'args' => $this->args,
            'cwd' => $this->cwd,
            'env' => $this->env,
            'readyUrl' => $this->readyUrl,
            'timeoutMs' => $this->timeoutMs,
            'stop' => [
                'signal' => $this->stopSignal,
                'timeoutMs' => $this->stopTimeoutMs,
            ],
        ];
    }

    /**
     * Reads a list of strings from a manifest value.
     *
     * @param mixed $value the decoded manifest value
     *
     * @return list<string> the normalized string list
     */
    private static function stringList(mixed $value): array
    {
        if (!is_array($value)) {
            return [];
        }

        $items = [];
        foreach ($value as $item) {
            if (is_string($item)) {
                $items[] = $item;
            }
        }

        return $items;
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
}
