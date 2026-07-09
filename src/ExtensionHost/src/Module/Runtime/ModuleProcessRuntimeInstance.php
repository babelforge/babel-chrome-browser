<?php

declare(strict_types=1);

namespace BabelForge\BabelChrome\LocalViewer\Module\Runtime;

/**
 * Tracks one long-running process-runtime module instance.
 */
final class ModuleProcessRuntimeInstance
{
    private string $stdout = '';

    private string $stderr = '';

    /**
     * @param string                $moduleId      the module identifier
     * @param list<string>          $command       the executed command
     * @param string                $cwd           the process working directory
     * @param array<string, string> $env           the process environment
     * @param string                $stopSignal    the graceful stop signal name
     * @param int                   $stopTimeoutMs the graceful stop timeout in milliseconds
     * @param mixed                 $process       the proc_open resource
     * @param array<int, mixed>     $pipes         the proc_open pipe resources
     */
    public function __construct(
        public readonly string $moduleId,
        public readonly array $command,
        public readonly string $cwd,
        public readonly array $env,
        public readonly string $stopSignal,
        public readonly int $stopTimeoutMs,
        private mixed $process,
        private array $pipes,
    ) {
        foreach ($this->pipes as $pipe) {
            if (is_resource($pipe)) {
                stream_set_blocking($pipe, false);
            }
        }
    }

    /**
     * Returns whether the process is still running.
     *
     * @return bool true when the process is running
     */
    public function isRunning(): bool
    {
        if (!is_resource($this->process)) {
            return false;
        }

        $status = proc_get_status($this->process);

        return $status['running'];
    }

    /**
     * Stops the process and closes all pipes.
     */
    public function stop(): void
    {
        $this->captureLogs();

        $process = $this->process;
        if (is_resource($process) && $this->isRunning()) {
            proc_terminate($process, $this->signalNumber($this->stopSignal));
            $deadline = microtime(true) + ($this->stopTimeoutMs / 1000);

            while ($this->isRunning() && microtime(true) < $deadline) {
                usleep(50_000);
                $this->captureLogs();
            }

            if ($this->isRunning()) {
                proc_terminate($process, 9);
            }
        }

        $this->closePipes();

        if (is_resource($this->process)) {
            proc_close($this->process);
        }

        $this->process = null;
    }

    /**
     * Captures pending stdout and stderr output.
     */
    public function captureLogs(): void
    {
        $this->stdout = $this->boundedLog($this->stdout.$this->readPipe(1));
        $this->stderr = $this->boundedLog($this->stderr.$this->readPipe(2));
    }

    /**
     * Returns captured process output.
     *
     * @return string the captured output
     */
    public function logs(): string
    {
        $this->captureLogs();
        $parts = [];
        if ('' !== trim($this->stdout)) {
            $parts[] = 'stdout: '.trim($this->stdout);
        }

        if ('' !== trim($this->stderr)) {
            $parts[] = 'stderr: '.trim($this->stderr);
        }

        return implode("\n", $parts);
    }

    /**
     * Reads one pipe without blocking.
     *
     * @param int $index the pipe index
     *
     * @return string the pipe output
     */
    private function readPipe(int $index): string
    {
        $pipe = $this->pipes[$index] ?? null;
        if (!is_resource($pipe)) {
            return '';
        }

        $content = stream_get_contents($pipe);

        return false === $content ? '' : $content;
    }

    /**
     * Closes all open pipes.
     */
    private function closePipes(): void
    {
        foreach ($this->pipes as $index => $pipe) {
            if (is_resource($pipe)) {
                fclose($pipe);
            }

            unset($this->pipes[$index]);
        }
    }

    /**
     * Keeps captured logs bounded.
     *
     * @param string $log the accumulated log
     *
     * @return string the bounded log
     */
    private function boundedLog(string $log): string
    {
        if (16384 >= strlen($log)) {
            return $log;
        }

        return substr($log, -16384);
    }

    /**
     * Converts a signal name to a POSIX signal number.
     *
     * @param string $signal the signal name
     *
     * @return int the signal number
     */
    private function signalNumber(string $signal): int
    {
        return match (strtoupper(ltrim($signal, 'SIG'))) {
            'INT' => 2,
            'KILL' => 9,
            'TERM' => 15,
            default => 15,
        };
    }
}
