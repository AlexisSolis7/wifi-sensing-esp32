import 'dart:math' as math;

import '../domain/link_reading.dart';
import '../domain/mesh_constants.dart';

class CalibrationResult {
  const CalibrationResult({required this.baseline, required this.noise});

  final List<int?> baseline;
  final List<double> noise;
}

class QuadrantEstimate {
  const QuadrantEstimate({
    required this.scores,
    required this.index,
    required this.confidence,
    required this.isConfident,
  });

  final List<double> scores;
  final int index;
  final double confidence;
  final bool isConfident;
}

class RssiAnalyzer {
  const RssiAnalyzer();

  List<LinkReading> linksFromMatrix(List<int?> matrix) {
    final readings = <LinkReading>[];
    for (var row = 0; row < MeshConstants.nodeNames.length; row++) {
      for (var col = row + 1; col < MeshConstants.nodeNames.length; col++) {
        readings.add(
          LinkReading(
            from: MeshConstants.nodeNames[row],
            to: MeshConstants.nodeNames[col],
            rssi: averageRssi(matrix, row, col),
          ),
        );
      }
    }
    return readings;
  }

  int validReadingCount(List<int?> matrix) {
    return matrix.where(isValidRssi).length;
  }

  List<double?> deltas(List<LinkReading> links, List<int?> baseline) {
    return List.generate(links.length, (index) {
      final current = links[index].rssi;
      final base = baseline[index];
      if (current == null || base == null) return null;
      return (current - base).abs().toDouble();
    });
  }

  List<double?> signals(List<double?> deltas, List<double> noise) {
    return List.generate(deltas.length, (index) {
      final delta = deltas[index];
      if (delta == null) return null;
      return math.max(0, delta - noise[index]);
    });
  }

  int activeQuadrantIndex(List<double> scores) {
    var bestIndex = -1;
    var bestScore = 0.0;
    for (var i = 0; i < scores.length; i++) {
      if (scores[i] > bestScore) {
        bestScore = scores[i];
        bestIndex = i;
      }
    }
    return bestScore >= MeshConstants.quadrantThreshold ? bestIndex : -1;
  }

  QuadrantEstimate estimateQuadrant({
    required List<double?> signals,
    required List<double> noise,
  }) {
    final candidates = <_LinkSignal>[];
    for (var i = 0; i < signals.length; i++) {
      final signal = signals[i] ?? 0;
      if (signal <= 0 || noise[i] > MeshConstants.unstableLinkNoiseLimit) {
        continue;
      }

      final reliability = _linkReliability(noise[i]);
      candidates.add(
        _LinkSignal(index: i, signal: signal, weight: reliability),
      );
    }

    candidates.sort((a, b) => b.signal.compareTo(a.signal));
    final selected = candidates.take(MeshConstants.topSignalLinkCount).toList();
    if (selected.isEmpty) {
      return const QuadrantEstimate(
        scores: [0, 0, 0, 0],
        index: -1,
        confidence: 0,
        isConfident: false,
      );
    }

    final rawScores = List<double>.filled(4, 0);
    var totalSignal = 0.0;
    for (final candidate in selected) {
      final weightedSignal = candidate.signal * candidate.weight;
      totalSignal += weightedSignal;
      final weights = MeshConstants.linkQuadrantWeights[candidate.index];
      for (var quadrant = 0; quadrant < rawScores.length; quadrant++) {
        rawScores[quadrant] += weightedSignal * weights[quadrant];
      }
    }

    final scores = rawScores
        .map((score) => totalSignal == 0 ? 0.0 : score / totalSignal)
        .toList();
    final ranking = List<int>.generate(scores.length, (index) => index)
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    final bestIndex = ranking.first;
    final bestScore = scores[bestIndex];
    final secondScore = scores[ranking[1]];
    final confidence = bestScore - secondScore;
    final isConfident =
        bestScore >= MeshConstants.quadrantMinScore &&
        confidence >= MeshConstants.quadrantMinMargin;

    return QuadrantEstimate(
      scores: scores,
      index: isConfident ? bestIndex : -1,
      confidence: confidence,
      isConfident: isConfident,
    );
  }

  bool hasMovement({
    required List<double?> deltas,
    required List<double?> signals,
  }) {
    final maxDelta = _maxNullable(deltas);
    final maxSignal = _maxNullable(signals);
    return maxSignal >= MeshConstants.movementSignalThreshold ||
        maxDelta >= MeshConstants.movementDeltaThreshold;
  }

  List<double> quadrantScores({
    required List<double> signals,
    required List<List<double>?> profiles,
  }) {
    final hasProfile = profiles.any((profile) => profile != null);
    if (hasProfile) {
      return _trainedScores(signals, profiles);
    }

    return [
      for (final weights in MeshConstants.fallbackQuadrantWeights)
        _weightedScore(signals, weights),
    ];
  }

  CalibrationResult calibrationResult({
    required List<int> totals,
    required List<int> squares,
    required List<int> counts,
  }) {
    final baseline = List<int?>.generate(MeshConstants.linkNames.length, (
      index,
    ) {
      final count = counts[index];
      if (count == 0) return null;
      return (totals[index] / count).round();
    });

    final noise = List<double>.generate(MeshConstants.linkNames.length, (
      index,
    ) {
      final count = counts[index];
      if (count < 2) return MeshConstants.defaultNoiseFloor;
      final mean = totals[index] / count;
      final meanSquare = squares[index] / count;
      final variance = math.max(0, meanSquare - mean * mean);
      final stdDev = math.sqrt(variance);
      return math.max(MeshConstants.defaultNoiseFloor, stdDev * 2.5);
    });

    return CalibrationResult(baseline: baseline, noise: noise);
  }

  int? averageRssi(List<int?> matrix, int row, int col) {
    final first = cleanRssi(matrix[row * 5 + col]);
    final second = cleanRssi(matrix[col * 5 + row]);
    final values = [first, second].whereType<int>().toList();
    if (values.isEmpty) return null;
    return (values.reduce((a, b) => a + b) / values.length).round();
  }

  int? cleanRssi(int? value) {
    if (!isValidRssi(value)) return null;
    return value;
  }

  bool isValidRssi(int? value) {
    return value != null && value != 0 && value >= -100 && value <= -1;
  }

  double _maxNullable(List<double?> values) {
    final validValues = values.whereType<double>();
    if (validValues.isEmpty) return 0;
    return validValues.reduce((a, b) => a > b ? a : b);
  }

  double _linkReliability(double noise) {
    if (noise <= MeshConstants.defaultNoiseFloor) return 1;
    final range =
        MeshConstants.unstableLinkNoiseLimit - MeshConstants.defaultNoiseFloor;
    if (range <= 0) return 1;
    return (1 - ((noise - MeshConstants.defaultNoiseFloor) / range))
        .clamp(0.25, 1)
        .toDouble();
  }

  List<double> _trainedScores(
    List<double> signals,
    List<List<double>?> profiles,
  ) {
    return List<double>.generate(profiles.length, (index) {
      final profile = profiles[index];
      if (profile == null) return 0;
      final similarity = _cosineSimilarity(signals, profile);
      final intensity =
          signals.fold<double>(0, (total, value) => total + value) /
          signals.length;
      return similarity * intensity;
    });
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  double _weightedScore(List<double> signals, Map<int, double> weights) {
    var total = 0.0;
    var weightTotal = 0.0;
    for (final entry in weights.entries) {
      total += signals[entry.key] * entry.value;
      weightTotal += entry.value;
    }
    if (weightTotal == 0) return 0;
    return total / weightTotal;
  }
}

class _LinkSignal {
  const _LinkSignal({
    required this.index,
    required this.signal,
    required this.weight,
  });

  final int index;
  final double signal;
  final double weight;
}
