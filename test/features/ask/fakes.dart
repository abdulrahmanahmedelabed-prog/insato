// Fakes shared by the ask feature tests.

import 'dart:async';

import 'package:insato/features/ask/ask_controller.dart';
import 'package:insato/features/ask/ask_corpus.dart';
import 'package:insato/minutes/minutes_backend.dart';

class FakeCorpus implements AskCorpusLoader {
  FakeCorpus(this.meetings);

  List<AskMeetingSource> meetings;
  int loads = 0;

  @override
  Future<List<AskMeetingSource>> load() async {
    loads++;
    return meetings;
  }
}

/// Answers each request with the next reply (a String, an Exception or a
/// Completer whose future is awaited).
class FakeBackend implements MinutesBackend {
  FakeBackend(this.replies, {this.engineId = 'gemini', this.offDevice = true});

  final List<Object> replies;
  final List<MinutesBackendRequest> requests = [];
  int closes = 0;

  @override
  final String engineId;

  final bool offDevice;

  @override
  String get displayName => 'Gemini';

  @override
  bool get sendsDataOffDevice => offDevice;

  @override
  Future<MinutesBackendResult> generateStructured(
    MinutesBackendRequest request, {
    MinutesBackendProgressCallback? onProgress,
  }) async {
    requests.add(request);
    onProgress?.call(
      const MinutesBackendProgress(MinutesBackendPhase.thinking),
    );
    final reply = replies.removeAt(0);
    final text = switch (reply) {
      final Completer<String> c => await c.future,
      final Exception e => throw e,
      final Error e => throw e,
      _ => reply as String,
    };
    return MinutesBackendResult(text: text, model: 'fake');
  }

  @override
  void close() => closes++;
}

String json(String answer, {bool found = true}) =>
    '{"answer": ${_quote(answer)}, "answer_found": $found}';

String _quote(String s) => '"${s.replaceAll('"', r'\"')}"';
