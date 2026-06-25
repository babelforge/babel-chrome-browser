<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Service;

use BabelForge\BabelChrome\LocalViewer\DocumentSource;
use Symfony\Component\HttpFoundation\Request;

/**
 * Loads document sources requested by the native BabelChrome shell.
 */
final readonly class SourceLoader
{
    /**
     * @param SourceRegistry $sourceRegistry reads source IDs
     */
    public function __construct(
        private SourceRegistry $sourceRegistry,
    ) {
    }

    /**
     * Loads a local file or remote URL from the request.
     *
     * @param Request $request the current request
     *
     * @return DocumentSource|null the loaded source or null when it cannot be loaded
     */
    public function load(Request $request): ?DocumentSource
    {
        $sourceIdValue = $request->attributes->get('sourceId', '');
        $sourceId = is_string($sourceIdValue) ? $sourceIdValue : '';
        if ('' !== $sourceId) {
            return $this->loadById($sourceId);
        }

        $fileValue = $request->query->get('file', '');
        $file = is_string($fileValue) ? $fileValue : '';
        if ('' !== $file) {
            return $this->loadFile($file);
        }

        $urlValue = $request->query->get('url', '');
        $url = is_string($urlValue) ? $urlValue : '';
        if ('' !== $url) {
            return $this->loadUrl($url);
        }

        return null;
    }

    /**
     * Loads a source by identifier.
     *
     * @param string $sourceId the source identifier
     *
     * @return DocumentSource|null the loaded source or null when it cannot be loaded
     */
    public function loadById(string $sourceId): ?DocumentSource
    {
        $source = $this->sourceRegistry->find($sourceId);
        if (null === $source) {
            return null;
        }

        if ('file' === $source['type']) {
            return $this->loadFile($source['value']);
        }

        if ('url' === $source['type']) {
            return $this->loadUrl($source['value']);
        }

        return null;
    }

    /**
     * Loads a local file.
     *
     * @param string $file the local file path
     *
     * @return DocumentSource|null the loaded source or null when it cannot be loaded
     */
    public function loadFile(string $file): ?DocumentSource
    {
        if (!is_file($file) || !is_readable($file)) {
            return null;
        }

        $content = file_get_contents($file);
        if (false === $content) {
            return null;
        }

        return new DocumentSource(
            basename($file),
            $content,
            'file://'.dirname($file).'/',
            true,
            'file',
            $file,
            $this->localMimeType($file),
            $this->localLastModified($file),
        );
    }

    /**
     * Loads a remote HTTP or HTTPS URL.
     *
     * @param string $url the remote URL
     *
     * @return DocumentSource|null the loaded source or null when it cannot be loaded
     */
    public function loadUrl(string $url): ?DocumentSource
    {
        $parts = parse_url($url);
        $scheme = strtolower((string) ($parts['scheme'] ?? ''));
        if ('http' !== $scheme && 'https' !== $scheme) {
            return null;
        }

        $context = stream_context_create([
            'http' => [
                'timeout' => 8,
                'user_agent' => 'BabelChrome Local Viewer',
            ],
        ]);
        $content = file_get_contents($url, false, $context);
        if (false === $content) {
            return null;
        }

        $path = (string) ($parts['path'] ?? '');

        return new DocumentSource(
            '' === basename($path) ? $url : basename($path),
            $content,
            $this->remoteBaseUri($url),
            false,
            'url',
            $url,
            $this->remoteMimeType($this->lastResponseHeaders()),
            null,
        );
    }

    /**
     * Returns the last modification timestamp for a local file.
     *
     * @param string $file the local file path
     *
     * @return int|null the last modification timestamp
     */
    private function localLastModified(string $file): ?int
    {
        $lastModified = filemtime($file);

        return false === $lastModified ? null : $lastModified;
    }

    /**
     * Returns the headers of the last HTTP wrapper response.
     *
     * @return array<int, string> the response headers
     */
    private function lastResponseHeaders(): array
    {
        $headers = http_get_last_response_headers();
        if (null === $headers) {
            return [];
        }

        return $headers;
    }

    /**
     * Returns a MIME type for a local file.
     *
     * @param string $file the local file path
     *
     * @return string the MIME type
     */
    private function localMimeType(string $file): string
    {
        $mimeType = mime_content_type($file);

        return false === $mimeType ? 'application/octet-stream' : $mimeType;
    }

    /**
     * Extracts the remote MIME type from response headers.
     *
     * @param array<int, string> $headers the HTTP response headers
     *
     * @return string the MIME type
     */
    private function remoteMimeType(array $headers): string
    {
        foreach ($headers as $header) {
            if (str_starts_with(strtolower($header), 'content-type:')) {
                return trim(substr($header, strlen('content-type:')));
            }
        }

        return 'application/octet-stream';
    }

    /**
     * Returns the remote base URI used to resolve links.
     *
     * @param string $url the remote source URL
     *
     * @return string the base URI
     */
    private function remoteBaseUri(string $url): string
    {
        $parts = parse_url($url);
        $scheme = (string) ($parts['scheme'] ?? 'https');
        $host = (string) ($parts['host'] ?? '');
        $port = isset($parts['port']) ? ':'.(string) $parts['port'] : '';
        $path = (string) ($parts['path'] ?? '/');
        $directory = rtrim(str_replace('\\', '/', dirname($path)), '/');

        return $scheme.'://'.$host.$port.('' === $directory ? '/' : $directory.'/');
    }
}
