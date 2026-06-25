<?php

declare(strict_types=1);

use Symfony\Component\HttpFoundation\Response;

/**
 * Runs one BabelChrome web module front controller in an isolated PHP process.
 */
(static function (): void {
    $input = stream_get_contents(STDIN);
    if (!is_string($input)) {
        $input = '';
    }

    /** @var array{modulePath: string, entrypoint: string, get: array<array-key, mixed>, post: array<array-key, mixed>, cookie: array<array-key, mixed>, files: array<array-key, mixed>, server: array<string, string>, env: array<string, string>, responseMarker: string} $payload */
    $payload = json_decode($input, true, 512, JSON_THROW_ON_ERROR);

    $_GET = $payload['get'];
    $_POST = $payload['post'];
    $_COOKIE = $payload['cookie'];
    $_FILES = $payload['files'];
    $_SERVER = array_merge($_SERVER, $payload['server']);
    $_ENV = array_merge($_ENV, $payload['env']);

    foreach ($payload['env'] as $name => $value) {
        putenv($name.'='.$value);
    }

    chdir($payload['modulePath']);

    ob_start();
    $result = require $payload['entrypoint'];
    $content = ob_get_clean();
    if (!is_string($content)) {
        $content = '';
    }

    $statusCode = 200;
    $headers = ['Content-Type' => 'text/html; charset=utf-8'];

    if ($result instanceof Response) {
        $statusCode = $result->getStatusCode();
        $responseContent = $result->getContent();
        $content .= is_string($responseContent) ? $responseContent : '';
        $headers = $result->headers->allPreserveCaseWithoutCookies();
    } elseif (is_string($result) && '' !== $result) {
        $content .= $result;
    }

    echo $payload['responseMarker'].json_encode([
        'statusCode' => $statusCode,
        'headers' => $headers,
        'content' => $content,
    ], JSON_THROW_ON_ERROR);
})();
