import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/analysis_result.dart';

final apiClientProvider = Provider((ref) => ApiClient());

// Состояния экрана
sealed class AnalysisState {}
class AnalysisInitial extends AnalysisState {}
class AnalysisLoading extends AnalysisState {}
class AnalysisSuccess extends AnalysisState {
  final AnalysisResult result;
  AnalysisSuccess(this.result);
}
class AnalysisError extends AnalysisState {
  final String message;
  AnalysisError(this.message);
}

class AnalysisNotifier extends Notifier<AnalysisState> {
  @override
  AnalysisState build() => AnalysisInitial();

  Future<void> analyze(String text) async {
    state = AnalysisLoading();
    try {
      final api = ref.read(apiClientProvider);
      final json = await api.analyze(text: text);
      state = AnalysisSuccess(AnalysisResult.fromJson(json));
    } catch (e) {
      state = AnalysisError('Ошибка: ${e.toString()}');
    }
  }

  void reset() => state = AnalysisInitial();
}

final analysisProvider = NotifierProvider<AnalysisNotifier, AnalysisState>(
  AnalysisNotifier.new,
);
