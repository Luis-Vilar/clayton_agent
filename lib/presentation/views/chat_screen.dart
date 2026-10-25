import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_omarchy/flutter_omarchy.dart';

import '../blocs/rag_bloc.dart';
import '../widgets/agent_role_dialog.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_message.dart';
import '../widgets/knowledge_panel.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [];
  final List<String> _ingestedFiles = [];

  double _currentTps = 0.0;
  int _gpuUsage = 0;
  bool _isGenerating = false;
  bool _isScrollScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RagBloc>().add(LoadIngestedFilesEvent());
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_isScrollScheduled) return;
    _isScrollScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isScrollScheduled = false;
      if (_scrollController.hasClients) {
        // jumpTo evita sobrecargar el bucle de eventos con decenas de
        // AnimationControllers concurrentes que se cancelan entre sí.
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _pickMarkdownFiles(BuildContext context) async {
    final pickedFiles = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown'],
    );

    if (pickedFiles.isNotEmpty) {
      final validPaths = pickedFiles
          .map((f) => f.path)
          .whereType<String>()
          .toList();
      if (validPaths.isNotEmpty && context.mounted) {
        context.read<RagBloc>().add(IngestMarkdownFilesEvent(validPaths));
      }
    }
  }

  Future<void> _pickSkillsDirectory(BuildContext context) async {
    final selectedDirectory = await FilePicker.getDirectoryPath();

    if (selectedDirectory != null && context.mounted) {
      context.read<RagBloc>().add(
        IngestSkillsDirectoryEvent(selectedDirectory),
      );
    }
  }

  void _sendQuestion(BuildContext context) {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isGenerating) return;

    setState(() {
      _messages.add({'role': 'user', 'text': question});
      _isGenerating = true;
    });

    context.read<RagBloc>().add(SendQuestionEvent(question));
    _questionController.clear();
    _scrollToBottom();
  }

  String _documentLabel(int count) =>
      '$count ${count == 1 ? 'documento' : 'documentos'}';

  @override
  Widget build(BuildContext context) {
    final theme = OmarchyTheme.of(context);

    return OmarchyScaffold(
      navigationBar: _ShellNavigationBar(
        onConfigureRole: () => showAgentRoleDialog(context),
      ),
      leadingPanel: KnowledgePanel(
        files: _ingestedFiles,
        isBusy: _isGenerating,
        onPickFiles: () => _pickMarkdownFiles(context),
        onPickDirectory: () => _pickSkillsDirectory(context),
        onClear: () => context.read<RagBloc>().add(ClearKnowledgeBaseEvent()),
      ),
      panelInitialSize: const PanelSize.absolute(300),
      minPanelSize: const PanelSize.absolute(240),
      maxPanelSize: const PanelSize.absolute(420),
      status: OmarchyStatusBar(
        leading: [
          const OmarchyStatus(accent: AnsiColor.green, child: Text('● local')),
          OmarchyStatus(child: Text(_documentLabel(_ingestedFiles.length))),
        ],
        trailing: [
          OmarchyStatus(
            accent: AnsiColor.yellow,
            child: Text(
              _currentTps > 0
                  ? '${_currentTps.toStringAsFixed(1)} tok/s'
                  : '-- tok/s',
            ),
          ),
          OmarchyStatus(accent: AnsiColor.blue, child: Text('GPU $_gpuUsage%')),
        ],
      ),
      child: BlocListener<RagBloc, RagState>(
        listener: (context, state) {
          if (state is KnowledgeBaseClearedState) {
            setState(() {
              _ingestedFiles.clear();
              _messages.clear();
              _currentTps = 0.0;
              _isGenerating = false;
            });
            showOmarchyToast(
              context: context,
              accent: AnsiColor.yellow,
              message: const Text(
                'Base de datos vectorial vaciada por completo.',
              ),
            );
          } else if (state is FileIngestedSuccessState) {
            setState(() {
              for (final name in state.fileNames) {
                if (!_ingestedFiles.contains(name)) {
                  _ingestedFiles.add(name);
                }
              }
            });
            showOmarchyToast(
              context: context,
              accent: AnsiColor.green,
              message: Text(
                '${state.fileNames.length} archivo(s) indexado(s) con éxito.',
              ),
            );
          } else if (state is RagLoadedFilesState) {
            setState(() {
              _ingestedFiles.clear();
              _ingestedFiles.addAll(state.fileNames);
            });
          } else if (state is RagStreamingState) {
            setState(() {
              _currentTps = state.currentTps;
              _gpuUsage = state.gpuUsagePercent;
              _isGenerating = true;

              if (_messages.isNotEmpty &&
                  _messages.last['role'] == 'assistant') {
                _messages.last['text'] = state.accumulatedAnswer;
              } else {
                _messages.add({
                  'role': 'assistant',
                  'text': state.accumulatedAnswer,
                });
              }
            });
            _scrollToBottom();
          } else if (state is RagResponseSuccessState) {
            setState(() {
              _currentTps = state.finalTps;
              _gpuUsage = state.gpuUsagePercent;
              _isGenerating = false;

              if (_messages.isNotEmpty &&
                  _messages.last['role'] == 'assistant') {
                _messages.last['text'] = state.answer;
              } else {
                _messages.add({'role': 'assistant', 'text': state.answer});
              }
            });
            _scrollToBottom();
          } else if (state is RagErrorState) {
            setState(() {
              _isGenerating = false;
            });
            showOmarchyToast(
              context: context,
              accent: AnsiColor.red,
              message: Text('Error: ${state.errorMessage}'),
            );
          }
        },
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty ? _emptyState(theme) : _messageList(),
            ),
            BlocBuilder<RagBloc, RagState>(
              builder: (context, state) {
                if (state is RagLoadingState) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const OmarchyLoader(size: 14, accent: AnsiColor.blue),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            state.message,
                            style: theme.text.normal.copyWith(
                              fontSize: 12,
                              color: theme.colors.bright.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            ChatComposer(
              controller: _questionController,
              isGenerating: _isGenerating,
              onSend: () => _sendQuestion(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(OmarchyThemeData theme) {
    return Center(
      child: Text(
        '> Haz una pregunta sobre tus documentos Markdown indexados.',
        style: theme.text.italic.copyWith(color: theme.colors.bright.black),
      ),
    );
  }

  Widget _messageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isUser = message['role'] == 'user';
        final isStreaming =
            _isGenerating && !isUser && index == _messages.length - 1;

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ChatMessage(
                isUser: isUser,
                text: message['text'] ?? '',
                isStreaming: isStreaming,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShellNavigationBar extends StatelessWidget {
  const _ShellNavigationBar({required this.onConfigureRole});

  final VoidCallback onConfigureRole;

  @override
  Widget build(BuildContext context) {
    final panel = OmarchyScaffold.leadingPanelMaybeOf(context);

    return OmarchyNavigationBar(
      title: const Text('clayton_agent'),
      leading: panel != null && panel.isHidden
          ? [
              OmarchyButton(
                onPressed: () => panel.hiddenController.isVisible = true,
                child: const Icon(OmarchyIcons.codMenu, size: 16),
              ),
            ]
          : null,
      trailing: [
        OmarchyTooltip(
          message: 'Configurar rol del agente',
          child: OmarchyButton(
            onPressed: onConfigureRole,
            child: const Icon(OmarchyIcons.codSettingsGear, size: 16),
          ),
        ),
      ],
    );
  }
}
