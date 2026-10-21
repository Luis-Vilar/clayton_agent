import 'dart:io';
import 'package:path/path.dart' as p;
import '../../objectbox.g.dart'; // Importa el archivo generado por ObjectBox

/// Inicializa el almacenamiento físico de ObjectBox en Linux Desktop.
/// Crea una carpeta dedicada en el directorio estándar del usuario: ~/.local/share/flutter_rag_ollama/
Future<Store> openObjectBoxStore() async {
  // 1. Obtener la ruta del HOME del usuario de Linux (~/)
  final home = Platform.environment['HOME'];
  if (home == null) {
    throw Exception("No se pudo determinar el directorio HOME del usuario de Linux.");
  }

  // 2. Construir la ruta estándar para almacenar datos de la app en Linux
  final String dbPath = p.join(home, '.local', 'share', 'flutter_rag_ollama', 'objectbox');
  final Directory directory = Directory(dbPath);
  
  // 3. Crear los directorios físicos de Linux si no existen todavía
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  // 4. Inicializar y abrir el Store de ObjectBox apuntando a esa ruta nativa
  return openStore(directory: directory.path);
}
