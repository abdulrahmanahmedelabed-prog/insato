// "Ask your meetings" (F8): public surface for the integrator.
//
// * [AskMeetingsScreen] — the chat screen (navigation entry «اسأل اجتماعاتك»).
// * [askControllerProvider] — the in-memory conversation.
// * [askCitationOpenerProvider] — how a citation opens; the default
//   ([openAskCitation]) shows the cited moment in [AskSourceSheet] (excerpt,
//   playback from that line via the F5 evidence controller, "open meeting").

export 'ask_answer.dart'
    show
        AskAnswerPart,
        AskCitation,
        AskCitationPart,
        AskLinkedAnswer,
        AskTextPart;
export 'ask_controller.dart'
    show
        AskController,
        AskFailure,
        AskMessage,
        AskPhase,
        AskProgress,
        AskRole,
        AskState,
        askControllerProvider,
        askCorpusLoaderProvider,
        askRetrievalRunnerProvider;
export 'ask_screen.dart'
    show
        AskCitationOpener,
        AskMeetingsScreen,
        askCitationOpenerProvider,
        askSettingsOpenerProvider,
        openAskCitation;
export 'ask_source_sheet.dart'
    show AskExcerpt, AskSourceSheet, askExcerptAround, showAskSourceSheet;
export 'strings.dart' show AS;
