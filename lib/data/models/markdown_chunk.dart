import 'dart:typed_data';
import 'package:objectbox/objectbox.dart';

@Entity()
class MarkdownChunk {
  @Id()
  int id = 0;

  final String filePath;
  final String skillName; // 👈 Guardará el nombre de la carpeta de la habilidad (ej: layout-fixes)
  final String content;

  @HnswIndex(dimensions: 768)
  @Property(type: PropertyType.floatVector)
  final Float32List embedding;

  MarkdownChunk({
    required this.filePath,
    required this.skillName,
    required this.content,
    required this.embedding,
  });
}
