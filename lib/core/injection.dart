import 'package:clayton_agent/data/services/gpu_metrics_service.dart';
import 'package:clayton_agent/data/services/ollama_service.dart';
import 'package:clayton_agent/data/services/prompt_settings_service.dart';
import 'package:clayton_agent/data/services/vector_db_service.dart';
import 'package:clayton_agent/data/services/vector_store_initializer.dart';
import 'package:clayton_agent/domain/repositories/rag_repository.dart';
import 'package:clayton_agent/presentation/blocs/rag_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:objectbox/objectbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importa aquí tus capas (Services, Repositories, Blocs) que crearemos abajo

final getIt = GetIt.instance;

Future<void> initDependencies() async {
  // 1. Cliente de Red (Dio) configurado para Ollama Local
  getIt.registerLazySingleton<Dio>(
    () => Dio(
      BaseOptions(
        baseUrl: 'http://localhost:11434/api',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(
          minutes: 1,
        ), // Los LLM pueden tardar en responder
        headers: {'Content-Type': 'application/json'},
      ),
    ),
  );

  // 2. Base de Datos Vectorial (ObjectBox)
  // Nota: Requiere inicializar el Store de ObjectBox (ver paso siguiente)
  final store = await openObjectBoxStore(); // Método auxiliar de tu BD
  getIt.registerSingleton<Store>(store);

  // 3. Servicios (Data Source)
  getIt.registerLazySingleton<GpuMetricsService>(
    () => GpuMetricsServiceImpl(),
  );
  getIt.registerLazySingleton<OllamaService>(
    () => OllamaServiceImpl(dio: getIt()),
  );
  getIt.registerLazySingleton<VectorDbService>(
    () => VectorDbServiceImpl(store: getIt()),
  );

  // 4. Repositorios (Domain / Business Logic)
  final preferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(preferences);
  getIt.registerLazySingleton<PromptSettingsService>(
    () => PromptSettingsServiceImpl(preferences: getIt()),
  );
  final initialAgentRole = await getIt<PromptSettingsService>().loadAgentRole();
  getIt.registerLazySingleton<RagRepository>(
    () => RagRepositoryImpl(
      ollamaService: getIt(),
      vectorDbService: getIt(),
      promptSettingsService: getIt(),
      initialAgentRole: initialAgentRole,
    ),
  );

  // 5. Blocs (Presentación) - registerFactory para que se creen instancias nuevas al usarse
  getIt.registerFactory(
    () => RagBloc(
      repository: getIt(),
      gpuMetricsService: getIt(),
    ),
  );
}
