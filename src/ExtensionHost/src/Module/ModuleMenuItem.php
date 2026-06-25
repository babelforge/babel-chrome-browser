<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module;

/**
 * Describes one menu item contributed by a BabelChrome PHP module.
 */
final readonly class ModuleMenuItem
{
    /**
     * @param string       $id       the stable menu item identifier
     * @param string       $label    the menu item label
     * @param string       $hook     the hook where the item is contributed
     * @param string       $route    the module route or stable BabelChrome URL
     * @param list<string> $contexts the contexts where the item is relevant
     * @param string|null  $shortcut the optional display shortcut
     */
    public function __construct(
        public string $id,
        public string $label,
        public string $hook,
        public string $route,
        public array $contexts,
        public ?string $shortcut,
    ) {
    }

    /**
     * Creates a menu item from decoded manifest data.
     *
     * @param array<string, mixed> $data the decoded menu item data
     *
     * @return self|null the menu item when data is valid
     */
    public static function fromArray(array $data): ?self
    {
        $id = self::stringValue($data, 'id');
        $label = self::stringValue($data, 'label');
        $hook = self::stringValue($data, 'hook');
        $route = self::stringValue($data, 'route');
        if ('' === $id || '' === $label || '' === $hook || '' === $route) {
            return null;
        }

        return new self(
            $id,
            $label,
            $hook,
            $route,
            self::stringList($data, 'contexts'),
            self::nullableStringValue($data, 'shortcut'),
        );
    }

    /**
     * Exports this menu item as an array.
     *
     * @return array{id: string, label: string, hook: string, route: string, contexts: list<string>, shortcut: string|null} the exported menu item
     */
    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'label' => $this->label,
            'hook' => $this->hook,
            'route' => $this->route,
            'contexts' => $this->contexts,
            'shortcut' => $this->shortcut,
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

    /**
     * Reads a nullable string value from an array.
     *
     * @param array<string, mixed> $data the source data
     * @param string               $key  the key to read
     *
     * @return string|null the string value
     */
    private static function nullableStringValue(array $data, string $key): ?string
    {
        $value = $data[$key] ?? null;

        return is_string($value) && '' !== $value ? $value : null;
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
}
