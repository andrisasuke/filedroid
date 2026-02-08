import 'dart:convert';
import 'dart:io';

abstract class ProcessRunner {
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  });

  Future<Process> start(String executable, List<String> arguments);
}

class RealProcessRunner implements ProcessRunner {
  const RealProcessRunner();

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  }) {
    return Process.run(
      executable,
      arguments,
      stdoutEncoding: stdoutEncoding ?? systemEncoding,
      stderrEncoding: stderrEncoding ?? systemEncoding,
    );
  }

  @override
  Future<Process> start(String executable, List<String> arguments) {
    return Process.start(executable, arguments);
  }
}
