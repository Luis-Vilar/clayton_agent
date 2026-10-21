import 'package:clayton_agent/core/injection.dart';
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'presentation/blocs/rag_bloc.dart';
import 'presentation/views/chat_screen.dart';

void main() async {
  // Asegurar enlace de Widgets nativos en Linux Desktop
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar dependencias asíncronas (Dio, ObjectBox, Servicios, Repositorios)
  await initDependencies();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local RAG Flutter - Linux Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: BlocProvider<RagBloc>(
        create: (context) =>
            getIt<RagBloc>(), // Resuelto automáticamente por GetIt
        child: const ChatScreen(),
      ),
    );
  }
}
