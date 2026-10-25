import 'package:flutter/widgets.dart';
import 'package:flutter_omarchy/flutter_omarchy.dart';

/// Panel lateral que muestra la base de conocimiento local y sus acciones.
class KnowledgePanel extends StatelessWidget {
  const KnowledgePanel({
    super.key,
    required this.files,
    required this.isBusy,
    required this.onPickFiles,
    required this.onPickDirectory,
    required this.onClear,
  });

  /// Nombres de los documentos indexados.
  final List<String> files;

  /// Indica si hay una operación de conocimiento en curso.
  final bool isBusy;

  /// Abre el selector de archivos Markdown.
  final VoidCallback onPickFiles;

  /// Abre el selector de carpeta de skills.
  final VoidCallback onPickDirectory;

  /// Vacía la base de conocimiento.
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = OmarchyTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 12),
            child: Text('Conocimiento local', style: theme.text.bold),
          ),
          _ActionButton(
            key: const Key('knowledge-add-files'),
            icon: OmarchyIcons.codFile,
            label: 'Subir archivo(s)',
            accent: AnsiColor.blue,
            onPressed: isBusy ? null : onPickFiles,
          ),
          const SizedBox(height: 8),
          _ActionButton(
            key: const Key('knowledge-add-folder'),
            icon: OmarchyIcons.codFolder,
            label: 'Subir carpeta',
            accent: AnsiColor.blue,
            onPressed: isBusy ? null : onPickDirectory,
          ),
          const SizedBox(height: 18),
          Text(
            'Documentos indexados (${files.length})',
            style: theme.text.normal.copyWith(
              fontSize: 12,
              color: theme.colors.bright.black,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: files.isEmpty
                ? Center(
                    child: Text(
                      'No hay documentos cargados.\n'
                      'Agrega archivos .md o carpetas.',
                      textAlign: TextAlign.center,
                      style: theme.text.normal.copyWith(
                        fontSize: 12,
                        color: theme.colors.bright.black,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final name = files[index];
                      return OmarchyTile(
                        leading: const Icon(OmarchyIcons.codFile, size: 16),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.text.normal.copyWith(fontSize: 12),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          _ActionButton(
            key: const Key('knowledge-clear'),
            icon: OmarchyIcons.codTrash,
            label: 'Limpiar base de datos',
            accent: AnsiColor.red,
            onPressed: isBusy ? null : onClear,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final AnsiColor accent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = OmarchyTheme.of(context);
    return OmarchyButton(
      style: OmarchyButtonStyle.outline(accent),
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.text.normal.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
