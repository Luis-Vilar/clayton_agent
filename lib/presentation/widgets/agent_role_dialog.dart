import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/prompt_settings_service.dart';
import '../blocs/rag_bloc.dart';

Future<void> showAgentRoleDialog(BuildContext context) {
  final bloc = context.read<RagBloc>();
  bloc.add(LoadAgentRoleEvent());
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: const AgentRoleDialog(),
    ),
  );
}

class AgentRoleDialog extends StatefulWidget {
  const AgentRoleDialog({super.key});

  @override
  State<AgentRoleDialog> createState() => _AgentRoleDialogState();
}

class _AgentRoleDialogState extends State<AgentRoleDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RagBloc, RagState>(
      listener: (context, state) {
        if (state is AgentRoleUpdatedState) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Rol del agente actualizado.')),
          );
          Navigator.of(context).pop();
        } else if (state is RagErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${state.errorMessage}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      builder: (context, state) {
        // Si el rol ya estaba cargado antes de montar el diálogo, el listener
        // no se dispara: se toma el estado actual aquí (evita quedar en spinner).
        if (!_loaded && state is AgentRoleLoadedState) {
          _controller.text = state.role;
          _loaded = true;
        }
        return AlertDialog(
          title: const Text('Rol del agente'),
          content: _loaded
              ? SizedBox(
                  width: 560,
                  child: TextField(
                    controller: _controller,
                    minLines: 4,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText:
                          'Describe el papel del agente y el dominio de las respuestas.',
                    ),
                  ),
                )
              : const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                ),
          actions: [
            TextButton(
              onPressed: _loaded
                  ? () => setState(() => _controller.text = defaultAgentRole)
                  : null,
              child: const Text('Restaurar ejemplo'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: _loaded
                  ? () => context.read<RagBloc>().add(
                      UpdateAgentRoleEvent(_controller.text),
                    )
                  : null,
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}
