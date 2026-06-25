<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

/**
 * Describes one route exposed by a BabelChrome PHP module.
 */
final readonly class ModuleRoute
{
    /**
     * @param string $scheme  the route scheme
     * @param string $host    the route host
     * @param string $handler the route handler identifier
     */
    public function __construct(
        public string $scheme,
        public string $host,
        public string $handler,
    ) {
    }

    /**
     * Creates a route from a decoded manifest array.
     *
     * @param array<string, mixed> $data the decoded route data
     *
     * @return self the route
     */
    public static function fromArray(array $data): self
    {
        return new self(
            self::stringValue($data, 'scheme'),
            self::stringValue($data, 'host'),
            self::stringValue($data, 'handler'),
        );
    }

    /**
     * Exports this route as an array.
     *
     * @return array{scheme: string, host: string, handler: string} the exported route
     */
    public function toArray(): array
    {
        return [
            'scheme' => $this->scheme,
            'host' => $this->host,
            'handler' => $this->handler,
        ];
    }

    /**
     * Reads a string value from an array.
     *
     * @param array<string, mixed> $data the source data
     * @param string               $key  the key to read
     *
     * @return string the string value
     */
    private static function stringValue(array $data, string $key): string
    {
        $value = $data[$key] ?? '';

        return is_string($value) ? $value : '';
    }
}
