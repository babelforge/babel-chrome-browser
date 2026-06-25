<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

/**
 * Describes the address bar badge contributed by a module.
 */
final readonly class ModuleBadge
{
    /**
     * @param string $text            the badge text
     * @param string $textColor       the badge text color
     * @param string $backgroundColor the badge background color
     */
    public function __construct(
        public string $text,
        public string $textColor,
        public string $backgroundColor,
    ) {
    }

    /**
     * Creates a badge from decoded manifest data.
     *
     * @param array<string, mixed> $data the decoded badge data
     *
     * @return self|null the badge when data is valid
     */
    public static function fromArray(array $data): ?self
    {
        $text = self::stringValue($data, 'text');
        if ('' === $text) {
            return null;
        }

        return new self(
            $text,
            self::stringValue($data, 'textColor', '#ffffff'),
            self::stringValue($data, 'backgroundColor', '#57606a'),
        );
    }

    /**
     * Exports this badge as an array.
     *
     * @return array{text: string, textColor: string, backgroundColor: string} the badge data
     */
    public function toArray(): array
    {
        return [
            'text' => $this->text,
            'textColor' => $this->textColor,
            'backgroundColor' => $this->backgroundColor,
        ];
    }

    /**
     * Reads a string value from an array.
     *
     * @param array<string, mixed> $data    the source data
     * @param string               $key     the key to read
     * @param string               $default the default value
     *
     * @return string the string value
     */
    private static function stringValue(array $data, string $key, string $default = ''): string
    {
        $value = $data[$key] ?? $default;

        return is_string($value) ? $value : $default;
    }
}
