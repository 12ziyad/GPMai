import '../models/memory_graph_models.dart';
import 'gpmai_api_client.dart';

class GpmaiMemoryApi {
  const GpmaiMemoryApi();

  Future<Map<String, dynamic>> finalStatus({bool full = false}) => GpmaiApiClient.memoryFinalStatus(full: full);

  Future<Map<String, dynamic>> importSyntheticHistory({
    required List<Map<String, dynamic>> entries,
    int batchIndex = 0,
    int totalBatches = 1,
    bool isFirstBatch = true,
    bool isLastBatch = true,
    bool includeOverview = true,
  }) {
    return GpmaiApiClient.memoryImportDatedHistory(
      entries: entries,
      resetLearned: false,
    );
  }

  Future<MemoryGraphResponse> graph({
    int nodeLimit = 50,
    int edgeLimit = 80,
    int eventLimit = 30,
    int candidateLimit = 30,
    bool includeDebug = false,
  }) async {
    final jsonMap = await GpmaiApiClient.memoryGraph(
      mode: GpmaiApiClient.unifiedMemoryMode,
      nodeLimit: nodeLimit,
      edgeLimit: edgeLimit,
      eventLimit: eventLimit,
      candidateLimit: candidateLimit,
      includeDebug: includeDebug,
    );
    return MemoryGraphResponse.fromJson(jsonMap);
  }
}
