<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Tests\Service;

use BabelForge\BabelChrome\LocalViewer\DocumentSource;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleManifest;
use BabelForge\BabelChrome\LocalViewer\Module\ModuleRuntimeContext;
use BabelForge\BabelChrome\LocalViewer\Service\SourceLoader;
use BabelForge\BabelChrome\LocalViewer\Service\SourceRegistry;
use BabelForge\BabelChromeMarkdownViewerModule\MarkdownDocumentRenderer;
use BabelForge\BabelChromeMarkdownViewerModule\MarkdownView;
use BabelForge\BabelChromeMarkdownViewerModule\ModuleAssetResolver;
use BabelForge\BabelChromeViewerKit\ViewerSource;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\TestCase;
use Symfony\Component\HttpFoundation\Request;

/**
 * Verifies Markdown link and asset resolution.
 */
#[CoversClass(MarkdownDocumentRenderer::class)]
final class MarkdownDocumentRendererTest extends TestCase
{
    private string $workspaceDirectory;

    /**
     * Registers the Markdown viewer module autoloader.
     */
    public static function setUpBeforeClass(): void
    {
        class_exists(DocumentSource::class);
        class_exists(ModuleManifest::class);
        class_exists(ModuleRuntimeContext::class);
        class_exists(SourceLoader::class);
        class_exists(SourceRegistry::class);

        if (!class_exists(ViewerSource::class) || !class_exists('League\\CommonMark\\GithubFlavoredMarkdownConverter')) {
            require_once dirname(__DIR__, 5).'/babel-chrome-modules/src/markdown-viewer/vendor/autoload.php';
        }

        spl_autoload_register(static function (string $class): void {
            $prefix = 'BabelForge\\BabelChromeMarkdownViewerModule\\';
            if (!str_starts_with($class, $prefix)) {
                return;
            }

            $relativeClass = substr($class, strlen($prefix));
            $path = dirname(__DIR__, 5).'/babel-chrome-modules/src/markdown-viewer/src/'.str_replace('\\', '/', $relativeClass).'.php';
            if (is_file($path)) {
                require $path;
            }
        });
    }

    /**
     * Creates an isolated Markdown workspace.
     */
    protected function setUp(): void
    {
        parent::setUp();

        $root = sys_get_temp_dir().'/babelchrome-markdown-renderer-test-'.bin2hex(random_bytes(6));
        $state = $root.'/state';
        if (!mkdir($root.'/doc/sub', 0o775, true) && !is_dir($root.'/doc/sub')) {
            self::fail('Unable to create test workspace.');
        }

        if (!mkdir($state, 0o775, true) && !is_dir($state)) {
            self::fail('Unable to create test state directory.');
        }

        file_put_contents($root.'/README.md', '# Readme');
        file_put_contents($root.'/doc/a.md', '# A');
        file_put_contents($root.'/doc/sub/file with spaces.md', '# Spaces');
        file_put_contents($root.'/doc/image with spaces.png', 'fake-png');

        $this->workspaceDirectory = $root;
        putenv('BABELCHROME_VIEWER_STATE_DIR='.$state);
    }

    /**
     * Clears the isolated viewer state.
     */
    protected function tearDown(): void
    {
        putenv('BABELCHROME_VIEWER_STATE_DIR');

        parent::tearDown();
    }

    /**
     * Ensures relative Markdown links are routed through stable BabelChrome URLs.
     */
    public function testRelativeMarkdownLinksUseStableBabelChromeFileUrls(): void
    {
        $view = $this->renderMarkdown("[A](./a.md#part)\n\n[Readme](../README.md)\n\n[Spaces](<./sub/file with spaces.md#anchor>)");

        self::assertStringContainsString(
            'href="babelchrome://viewer/file/'.rawurlencode($this->workspaceDirectory.'/doc/a.md').'#part"',
            $view->bodyHtml,
        );
        self::assertStringContainsString(
            'href="babelchrome://viewer/file/'.rawurlencode($this->workspaceDirectory.'/README.md').'"',
            $view->bodyHtml,
        );
        self::assertStringContainsString(
            'href="babelchrome://viewer/file/'.rawurlencode($this->workspaceDirectory.'/doc/sub/file with spaces.md').'#anchor"',
            $view->bodyHtml,
        );
    }

    /**
     * Ensures relative local images are served through the authenticated asset endpoint.
     */
    public function testRelativeImagesUseRegisteredAssetUrls(): void
    {
        $view = $this->renderMarkdown('![Image](<./image with spaces.png>)');

        $matched = preg_match('#src="/asset/([^"]+)\\?token=test-token"#', $view->bodyHtml, $matches);

        self::assertSame(1, $matched);

        $loader = new SourceLoader(new SourceRegistry());
        $asset = $loader->loadById(rawurldecode($matches[1]));

        self::assertNotNull($asset);
        self::assertSame($this->workspaceDirectory.'/doc/image with spaces.png', $asset->value);
    }

    /**
     * Ensures remote Markdown links stay stable and preserve query strings and fragments.
     */
    public function testRemoteMarkdownLinksUseStableBabelChromeUrlUrls(): void
    {
        $source = new ViewerSource(
            'Remote',
            "[Remote](../README.md?plain=1#top)\n\n[Mermaid](./flow.mmd#diagram)",
            'https://example.com/docs/current/',
            false,
            'url',
            'https://example.com/docs/current/page.md',
            'text/markdown',
            null,
        );

        $view = $this->renderer()->render($source, $this->request());

        self::assertStringContainsString(
            'href="babelchrome://viewer/url/'.rawurlencode('https://example.com/docs/README.md?plain=1').'#top"',
            $view->bodyHtml,
        );
        self::assertStringContainsString(
            'href="babelchrome://viewer/url/'.rawurlencode('https://example.com/docs/current/flow.mmd').'#diagram"',
            $view->bodyHtml,
        );
    }

    /**
     * Ensures same-page anchors stay local to the rendered document.
     */
    public function testSamePageAnchorsStayLocal(): void
    {
        $view = $this->renderMarkdown('[Section](#section)');

        self::assertStringContainsString('href="#section"', $view->bodyHtml);
    }

    /**
     * Ensures standalone Mermaid files are rendered as Mermaid source blocks.
     */
    public function testStandaloneMermaidDocumentRendersMermaidBlock(): void
    {
        $source = new ViewerSource(
            'Flow',
            "graph TD\nA-->B",
            'file://'.$this->workspaceDirectory.'/doc/',
            true,
            'file',
            $this->workspaceDirectory.'/doc/flow.mmd',
            'text/plain',
            null,
        );

        $view = $this->renderer()->render($source, $this->request());

        self::assertStringContainsString('<code class="language-mermaid">', $view->bodyHtml);
        self::assertStringContainsString('graph TD', $view->bodyHtml);
    }

    /**
     * Ensures the requested Markdown theme is propagated to the view model.
     */
    public function testSupportedThemeIsPropagatedToView(): void
    {
        $view = $this->renderMarkdownWithRequest('# Theme', Request::create('/markdown', 'GET', [
            'token' => 'test-token',
            'theme' => 'compact',
        ]));

        self::assertSame('compact', $view->theme);
    }

    /**
     * Ensures unsupported Markdown themes fall back to the default theme.
     */
    public function testUnsupportedThemeFallsBackToDefault(): void
    {
        $view = $this->renderMarkdownWithRequest('# Theme', Request::create('/markdown', 'GET', [
            'token' => 'test-token',
            'theme' => 'unknown',
        ]));

        self::assertSame('github-light', $view->theme);
    }

    /**
     * Ensures local auto-refresh metadata is exposed for file-backed Markdown sources.
     */
    public function testLocalMarkdownExposesAutoRefreshMetadata(): void
    {
        $view = $this->renderMarkdown('# Refresh');

        self::assertTrue($view->autoRefreshEnabled);
        self::assertNotSame('', $view->sourceId);
        self::assertIsInt($view->lastModified);
    }

    /**
     * Ensures missing linked Markdown files still produce stable viewer URLs.
     */
    public function testMissingRelativeMarkdownLinkStillUsesStableViewerUrl(): void
    {
        $view = $this->renderMarkdown('[Missing](<./missing file.md#lost>)');

        self::assertStringContainsString(
            'href="babelchrome://viewer/file/'.rawurlencode($this->workspaceDirectory.'/doc/missing file.md').'#lost"',
            $view->bodyHtml,
        );
    }

    /**
     * Renders Markdown from the isolated local document directory.
     *
     * @param string $markdown the Markdown source
     *
     * @return MarkdownView the rendered view
     */
    private function renderMarkdown(string $markdown): MarkdownView
    {
        return $this->renderMarkdownWithRequest($markdown, $this->request());
    }

    /**
     * Renders Markdown from the isolated local document directory with a custom request.
     *
     * @param string  $markdown the Markdown source
     * @param Request $request  the viewer request
     *
     * @return MarkdownView the rendered view
     */
    private function renderMarkdownWithRequest(string $markdown, Request $request): MarkdownView
    {
        $source = new ViewerSource(
            'Main',
            $markdown,
            'file://'.$this->workspaceDirectory.'/doc/',
            true,
            'file',
            $this->workspaceDirectory.'/doc/main.md',
            'text/markdown',
            $this->lastModified($this->workspaceDirectory.'/doc/a.md'),
        );

        $sourceId = new SourceRegistry()->register('file', $source->value);
        $request->attributes->set('sourceId', $sourceId);

        return $this->renderer()->render($source, $request);
    }

    /**
     * Creates the renderer under test.
     *
     * @return MarkdownDocumentRenderer the renderer
     */
    private function renderer(): MarkdownDocumentRenderer
    {
        return new MarkdownDocumentRenderer(
            new ModuleAssetResolver($this->moduleManifest(), new ModuleRuntimeContext('http://127.0.0.1:12345', 'test-token', '')),
            new SourceRegistry(),
        );
    }

    /**
     * Returns the real Markdown viewer module manifest.
     *
     * @return ModuleManifest the module manifest
     */
    private function moduleManifest(): ModuleManifest
    {
        $modulePath = dirname(__DIR__, 5).'/babel-chrome-modules/src/markdown-viewer';

        return ModuleManifest::fromArray($this->manifestData($modulePath), $modulePath);
    }

    /**
     * Decodes a module manifest with string keys.
     *
     * @param string $modulePath the module root path
     *
     * @return array<string, mixed> the decoded manifest data
     */
    private function manifestData(string $modulePath): array
    {
        $decoded = json_decode((string) file_get_contents($modulePath.'/manifest.json'), true, 512, JSON_THROW_ON_ERROR);
        self::assertIsArray($decoded);

        $data = [];
        foreach ($decoded as $key => $value) {
            if (is_string($key)) {
                $data[$key] = $value;
            }
        }

        return $data;
    }

    /**
     * Creates a viewer request with a valid test token.
     *
     * @return Request the request
     */
    private function request(): Request
    {
        return Request::create('/markdown', 'GET', ['token' => 'test-token']);
    }

    /**
     * Returns the last modification timestamp for a test file.
     *
     * @param string $path the file path
     *
     * @return int|null the last modification timestamp
     */
    private function lastModified(string $path): ?int
    {
        $lastModified = filemtime($path);

        return false === $lastModified ? null : $lastModified;
    }
}
