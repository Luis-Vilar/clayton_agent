import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../blocs/rag_bloc.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _questionController = TextEditingController();
  final List<Map<String, String>> _messages =
      []; // Historial visual local del chat
  final List<String> _ingestedFiles = []; // Lista de archivos aprendidos

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  // Abre el selector nativo de archivos de Linux (GNOME/KDE) filtrando por Markdown
  Future<void> _pickSkillsDirectory(BuildContext context) async {
    // Abre el explorador de Linux en modo selección de directorios
    String? selectedDirectory = await FilePicker.getDirectoryPath();

    if (selectedDirectory != null) {
      // Apunta directamente a la carpeta que contiene las subcarpetas del npx skills
      context.read<RagBloc>().add(
        IngestSkillsDirectoryEvent(selectedDirectory),
      );
    }
  }

  void _sendQuestion(BuildContext context) {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': question});
    });

    context.read<RagBloc>().add(SendQuestionEvent(question));
    _questionController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<RagBloc, RagState>(
        listener: (context, state) {
          if (state is KnowledgeBaseClearedState) {
            setState(() {
              _ingestedFiles
                  .clear(); // Vacía la lista visual de archivos indexados
              _messages.clear(); // Opcional: limpia el chat actual
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '🗑️ Base de datos vectorial vaciada por completo.',
                ),
              ),
            );
          }
          if (state is FileIngestedSuccessState) {
            setState(() {
              _ingestedFiles.add(state.fileName);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✅ Archivo "${state.fileName}" indexado con éxito.',
                ),
              ),
            );
          } else if (state is RagResponseSuccessState) {
            setState(() {
              _messages.add({'role': 'assistant', 'text': state.answer});
            });
          } else if (state is RagErrorState) {
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
              width: 280,
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
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
                    onPressed: () {
                      // Disparar evento de borrado al Bloc
                      context.read<RagBloc>().add(ClearKnowledgeBaseEvent());
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Limpiar Base de Datos'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _pickSkillsDirectory(context),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Importar Markdown'),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Documentos Indexados:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _ingestedFiles.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay documentos cargados.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _ingestedFiles.length,
                            itemBuilder: (context, index) => ListTile(
                              leading: const Icon(
                                Icons.article,
                                color: Colors.blue,
                              ),
                              title: Text(
                                _ingestedFiles[index],
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // SECCIÓN PRINCIPAL DERECHA: Chat Técnico RAG
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
                                  width:
                                      MediaQuery.of(context).size.width * 0.55,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  padding: const EdgeInsets.all(14.0),
                                  decoration: BoxDecoration(
                                    color: isUser
                                        ? Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                        : Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  // RENDERIZADO VISUAL DEL MARKDOWN
                                  child: isUser
                                      ? Text(msg['text'] ?? '')
                                      : MarkdownBody(
                                          data: msg['text'] ?? '',
                                          selectable: true,
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
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                state.message,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
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
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _questionController,
                            decoration: const InputDecoration(
                              hintText: 'Pregúntale al modelo sobre el contexto indexado...',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _sendQuestion(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () => _sendQuestion(context),
                          color: Theme.of(context).colorScheme.primary,
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
