import 'package:clayton_agent/core/injection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_omarchy/flutter_omarchy.dart';

import 'presentation/blocs/rag_bloc.dart';
import 'presentation/views/chat_screen.dart';

void main() async {
  // Asegurar enlace de Widgets nativos en Linux Desktop
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar configuración y fuentes del tema Omarchy
  await Omarchy.initialize();

  // Inicializar dependencias asíncronas (Dio, ObjectBox, Servicios, Repositorios)
  await initDependencies();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return OmarchyApp(
      debugShowCheckedModeBanner: false,
      home: BlocProvider<RagBloc>(
        create: (context) => getIt<RagBloc>(),
        child: const ChatScreen(),
      ),
    );
  }
}
