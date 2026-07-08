<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

/**
 * Describes a module-provided command declaration.
 */
final readonly class ModuleCommandDefinition
{
    /**
     * @param string $type                 the command declaration type
     * @param string $command              the command line to execute
     * @param int    $timeoutMs            the command timeout in milliseconds
     * @param bool   $requiresConfirmation whether the command requires explicit user confirmation
     */
    public function __construct(
        public string $type,
        public string $command,
        public int $timeoutMs,
        public bool $requiresConfirmation = false,
    ) {
    }

    /**
     * Creates a command definition from decoded manifest data.
     *
     * @param mixed $value                       the decoded manifest value
     * @param int   $defaultTimeoutMs            the default timeout in milliseconds
     * @param bool  $defaultRequiresConfirmation whether confirmation is required by default
     *
     * @return self|null the command definition when valid
     */
    public static function fromManifestValue(mixed $value, int $defaultTimeoutMs, bool $defaultRequiresConfirmation): ?self
    {
        if (!is_array($value)) {
            return null;
        }

        $type = $value['type'] ?? 'command';
        $command = $value['command'] ?? null;
        $timeoutMs = $value['timeoutMs'] ?? $defaultTimeoutMs;
        $requiresConfirmation = $value['requiresConfirmation'] ?? $defaultRequiresConfirmation;

        if (!is_string($type) || '' === trim($type) || !is_string($command) || '' === trim($command)) {
            return null;
        }

        return new self(
            trim($type),
            trim($command),
            is_int($timeoutMs) && $timeoutMs > 0 ? $timeoutMs : $defaultTimeoutMs,
            is_bool($requiresConfirmation) ? $requiresConfirmation : $defaultRequiresConfirmation,
        );
    }

    /**
     * Exports this definition as an array.
     *
     * @return array{type: string, command: string, timeoutMs: int, requiresConfirmation: bool} the exported definition
     */
    public function toArray(): array
    {
        return [
            'type' => $this->type,
            'command' => $this->command,
            'timeoutMs' => $this->timeoutMs,
            'requiresConfirmation' => $this->requiresConfirmation,
        ];
    }
}
