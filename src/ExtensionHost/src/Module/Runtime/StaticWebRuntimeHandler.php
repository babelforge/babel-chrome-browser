<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module\Runtime;

use BabelForge\BabelChrome\LocalViewer\Module\Exception\ModuleDispatchException;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleManifest;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRuntimeContext;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Serves module-owned static web documents.
 */
final readonly class StaticWebRuntimeHandler implements ModuleRuntimeHandlerInterface
{
    /**
     * Returns whether this handler can execute a module.
     *
     * @param ModuleManifest $module the module manifest
     *
     * @return bool true when this handler supports the module runtime
     */
    public function supports(ModuleManifest $module): bool
    {
        return ModuleRuntimeType::isStaticWeb($module->runtimeType);
    }

    /**
     * Dispatches one static web module route.
     *
     * @param ModuleManifest $module  the module manifest
     * @param string         $route   the requested module route
     * @param Request        $request the current HTTP request
     *
     * @return Response the module response
     *
     * @throws ModuleDispatchException when the module static document cannot be served
     */
    public function dispatch(ModuleManifest $module, string $route, Request $request): Response
    {
        $documentRoot = $this->resolvedDocumentRoot($module);
        $documentPath = $this->resolvedIndexPath($module, $documentRoot);
        $content = file_get_contents($documentPath);
        if (false === $content) {
            throw new ModuleDispatchException(sprintf('Module "%s" static index "%s" could not be read.', $module->id, $module->indexFile));
        }

        $contentType = $this->mimeType($documentPath);

        return new Response(
            $this->interpolatedContent($content, $contentType, $module, $route, $request),
            Response::HTTP_OK,
            ['Content-Type' => $contentType],
        );
    }

    /**
     * Resolves the static document root and ensures it stays inside the module.
     *
     * @param ModuleManifest $module the module manifest
     *
     * @return string the resolved document root
     *
     * @throws ModuleDispatchException when the document root is invalid
     */
    private function resolvedDocumentRoot(ModuleManifest $module): string
    {
        $modulePath = realpath($module->path);
        $documentRoot = realpath($module->path.'/'.ltrim('' !== $module->documentRoot ? $module->documentRoot : 'public', '/'));
        if (false === $modulePath || false === $documentRoot || !is_dir($documentRoot)) {
            throw new ModuleDispatchException(sprintf('Module "%s" static document root "%s" was not found.', $module->id, $module->documentRoot));
        }

        $normalizedModulePath = rtrim($modulePath, DIRECTORY_SEPARATOR).DIRECTORY_SEPARATOR;
        if ($documentRoot !== $modulePath && !str_starts_with($documentRoot, $normalizedModulePath)) {
            throw new ModuleDispatchException(sprintf('Module "%s" static document root escapes the module directory.', $module->id));
        }

        return $documentRoot;
    }

    /**
     * Resolves the static index file and ensures it stays inside the document root.
     *
     * @param ModuleManifest $module       the module manifest
     * @param string         $documentRoot the resolved document root
     *
     * @return string the resolved index file
     *
     * @throws ModuleDispatchException when the index file is invalid
     */
    private function resolvedIndexPath(ModuleManifest $module, string $documentRoot): string
    {
        $indexFile = '' !== $module->indexFile ? $module->indexFile : 'index.html';
        $documentPath = realpath($documentRoot.'/'.ltrim($indexFile, '/'));
        if (false === $documentPath || !is_file($documentPath) || !is_readable($documentPath)) {
            throw new ModuleDispatchException(sprintf('Module "%s" static index "%s" was not found.', $module->id, $indexFile));
        }

        $normalizedDocumentRoot = rtrim($documentRoot, DIRECTORY_SEPARATOR).DIRECTORY_SEPARATOR;
        if (!str_starts_with($documentPath, $normalizedDocumentRoot)) {
            throw new ModuleDispatchException(sprintf('Module "%s" static index escapes the document root.', $module->id));
        }

        return $documentPath;
    }

    /**
     * Replaces static document placeholders with request-scoped BabelChrome values.
     *
     * @param string         $content     the original document content
     * @param string         $contentType the response content type
     * @param ModuleManifest $module      the module manifest
     * @param string         $route       the requested route
     * @param Request        $request     the current HTTP request
     *
     * @return string the interpolated content
     */
    private function interpolatedContent(string $content, string $contentType, ModuleManifest $module, string $route, Request $request): string
    {
        if (!$this->isTextContent($contentType)) {
            return $content;
        }

        $context = ModuleRuntimeContext::fromRequest($request);
        $assetBaseUrl = $context->baseUrl.'/module/'.rawurlencode($module->id).'/assets';
        $assetTokenQuery = '' === $context->token ? '' : '?'.http_build_query(['token' => $context->token], '', '&', PHP_QUERY_RFC3986);

        return strtr($content, [
            '{{ BABELCHROME_MODULE_ID }}' => $module->id,
            '{{ BABELCHROME_MODULE_NAME }}' => $module->name,
            '{{ BABELCHROME_MODULE_VERSION }}' => $module->version,
            '{{ BABELCHROME_MODULE_ROUTE }}' => $route,
            '{{ BABELCHROME_MODULE_ASSET_BASE_URL }}' => $assetBaseUrl,
            '{{ BABELCHROME_MODULE_ASSET_TOKEN_QUERY }}' => $assetTokenQuery,
            '{{ BABELCHROME_LOCAL_SERVICE_BASE_URL }}' => $context->baseUrl,
            '{{ BABELCHROME_LOCAL_SERVICE_TOKEN }}' => $context->token,
            '{{ BABELCHROME_SOURCE_URL }}' => $context->sourceUrl,
        ]);
    }

    /**
     * Returns whether a content type can be safely interpolated as text.
     *
     * @param string $contentType the response content type
     *
     * @return bool true when content interpolation is safe
     */
    private function isTextContent(string $contentType): bool
    {
        return str_starts_with($contentType, 'text/')
            || str_starts_with($contentType, 'application/json')
            || str_starts_with($contentType, 'application/javascript')
            || str_starts_with($contentType, 'image/svg+xml');
    }

    /**
     * Returns a stable web MIME type for a static document.
     *
     * @param string $path the resolved document path
     *
     * @return string the MIME type
     */
    private function mimeType(string $path): string
    {
        $extension = strtolower(pathinfo($path, PATHINFO_EXTENSION));
        $mimeTypes = [
            'css' => 'text/css; charset=utf-8',
            'gif' => 'image/gif',
            'html' => 'text/html; charset=utf-8',
            'ico' => 'image/x-icon',
            'jpeg' => 'image/jpeg',
            'jpg' => 'image/jpeg',
            'js' => 'text/javascript; charset=utf-8',
            'json' => 'application/json; charset=utf-8',
            'map' => 'application/json; charset=utf-8',
            'png' => 'image/png',
            'svg' => 'image/svg+xml; charset=utf-8',
            'txt' => 'text/plain; charset=utf-8',
            'webp' => 'image/webp',
        ];

        if (isset($mimeTypes[$extension])) {
            return $mimeTypes[$extension];
        }

        $mimeType = mime_content_type($path);

        return false === $mimeType ? 'application/octet-stream' : $mimeType;
    }
}
