<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

/**
 * Describes one process-runtime command declaration.
 */
final readonly class ModuleProcessRuntimeCommand
{
    /**
     * @param string       $command   the executable command path or name
     * @param list<string> $args      the command arguments
     * @param int          $timeoutMs the command timeout in milliseconds
     */
    public function __construct(
        public string $command,
        public array $args,
        public int $timeoutMs,
    ) {
    }

    /**
     * Creates a command from a manifest value.
     *
     * @param mixed $value            the decoded manifest value
     * @param int   $defaultTimeoutMs the default timeout in milliseconds
     *
     * @return self|null the command when valid
     */
    public static function fromManifestValue(mixed $value, int $defaultTimeoutMs): ?self
    {
        if (!is_array($value)) {
            return null;
        }

        $command = $value['command'] ?? null;
        if (!is_string($command) || '' === trim($command)) {
            return null;
        }

        $timeoutMs = $value['timeoutMs'] ?? $defaultTimeoutMs;

        return new self(
            trim($command),
            self::stringList($value['args'] ?? []),
            is_int($timeoutMs) && $timeoutMs > 0 ? $timeoutMs : $defaultTimeoutMs,
        );
    }

    /**
     * Exports this command as a manifest array.
     *
     * @return array{command: string, args: list<string>, timeoutMs: int} the exported command
     */
    public function toArray(): array
    {
        return [
            'command' => $this->command,
            'args' => $this->args,
            'timeoutMs' => $this->timeoutMs,
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
}
