import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../blocs/rag_bloc.dart';
import '../widgets/agent_role_dialog.dart';
import '../widgets/telemetry_badge.dart';

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
      final validPaths =
          pickedFiles.map((f) => f.path).whereType<String>().toList();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: BlocListener<RagBloc, RagState>(
        listener: (context, state) {
          if (state is KnowledgeBaseClearedState) {
            setState(() {
              _ingestedFiles.clear();
              _messages.clear();
              _currentTps = 0.0;
              _isGenerating = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '🗑️ Base de datos vectorial vaciada por completo.',
                ),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✅ ${state.fileNames.length} archivo(s) indexado(s) con éxito.',
                ),
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

              if (_messages.isNotEmpty && _messages.last['role'] == 'assistant') {
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

              if (_messages.isNotEmpty && _messages.last['role'] == 'assistant') {
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Error: ${state.errorMessage}'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        child: Row(
          children: [
            // PANEL LATERAL IZQUIERDO: Control de Archivos Markdown
            Container(
              width: 290,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Conocimiento Local',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isGenerating
                        ? null
                        : () {
                            context.read<RagBloc>().add(ClearKnowledgeBaseEvent());
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text('Limpiar Base de Datos'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isGenerating ? null : () => _pickMarkdownFiles(context),
                    icon: const Icon(Icons.note_add, size: 18),
                    label: const Text('Subir Archivo(s)'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isGenerating ? null : () => _pickSkillsDirectory(context),
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Subir Carpeta'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isGenerating ? null : () => showAgentRoleDialog(context),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Configurar rol del agente'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Documentos Indexados (${_ingestedFiles.length}):',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _ingestedFiles.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay documentos cargados.\nAgrega archivos .md o carpetas.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _ingestedFiles.length,
                            separatorBuilder: (context, _) => const Divider(height: 1),
                            itemBuilder: (context, index) => ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              leading: const Icon(
                                Icons.article,
                                color: Colors.blueAccent,
                                size: 20,
                              ),
                              title: Text(
                                _ingestedFiles[index],
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // SECCIÓN PRINCIPAL DERECHA: Chat Técnico RAG y Telemetría
            Expanded(
              child: Column(
                children: [
                  // Área del historial de conversación
                  Expanded(
                    child: _messages.isEmpty
                        ? const Center(
                            child: Text(
                              'Haz una pregunta sobre tus documentos Markdown indexados.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final isUser = msg['role'] == 'user';
                              return Align(
                                alignment: isUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  width: MediaQuery.of(context).size.width * 0.58,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  padding: const EdgeInsets.all(14.0),
                                  decoration: BoxDecoration(
                                    color: isUser
                                        ? theme.colorScheme.primaryContainer
                                        : theme.colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: isUser
                                      ? Text(
                                          msg['text'] ?? '',
                                          style: TextStyle(
                                            color: theme.colorScheme.onPrimaryContainer,
                                          ),
                                        )
                                      : MarkdownBody(
                                          data: msg['text'] ?? '',
                                          // Se desactiva la selección en el mensaje activo durante la generación
                                          // para evitar el cálculo continuo del árbol de selección en cada chunk.
                                          selectable: !_isGenerating || index != _messages.length - 1,
                                        ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Indicador visual dinámico de carga usando el Bloc State
                  BlocBuilder<RagBloc, RagState>(
                    builder: (context, state) {
                      if (state is RagLoadingState) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  state.message,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
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

                  // Barra inferior de entrada de texto
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _questionController,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Pregúntale al modelo sobre el contexto indexado...',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _sendQuestion(context),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton.filled(
                              icon: _isGenerating
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              onPressed: _isGenerating
                                  ? null
                                  : () => _sendQuestion(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Barra fija inferior derecha con métricas de hardware y tokens
                        Row(
                          children: [
                            const Spacer(),
                            TelemetryBadge(
                              tokensPerSecond: _currentTps,
                              gpuUsagePercent: _gpuUsage,
                              isGenerating: _isGenerating,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
