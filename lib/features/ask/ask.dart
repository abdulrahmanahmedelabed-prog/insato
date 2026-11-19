// "Ask your meetings" (F8): public surface for the integrator.
//
// * [AskMeetingsScreen] — the chat screen (navigation entry «اسأل اجتماعاتك»).
// * [askControllerProvider] — the in-memory conversation.
// * [askCitationOpenerProvider] — override to open a meeting at the cited
//   segment (F5).

export 'ask_answer.dart'
    show AskAnswerPart, AskCitation, AskCitationPart, AskLinkedAnswer,
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
        askSettingsOpenerProvider;
export 'strings.dart' show AS;
