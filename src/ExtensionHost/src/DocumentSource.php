<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer;

/**
 * Represents a document loaded from a local file or remote URL.
 */
final readonly class DocumentSource
{
    /**
     * @param string   $title        the document title
     * @param string   $content      the raw document content
     * @param string   $baseUri      the base URI used to resolve relative links
     * @param bool     $local        whether the source comes from a local file
     * @param string   $type         the source type
     * @param string   $value        the source value
     * @param string   $mimeType     the source MIME type
     * @param int|null $lastModified the source last modification timestamp
     */
    public function __construct(
        public string $title,
        public string $content,
        public string $baseUri,
        public bool $local,
        public string $type,
        public string $value,
        public string $mimeType,
        public ?int $lastModified = null,
    ) {
    }
}
