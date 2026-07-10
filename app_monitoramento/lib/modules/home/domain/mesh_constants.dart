class MeshConstants {
  const MeshConstants._();

  static const defaultEndpoint = 'ws://192.168.4.1:81';
  static const nodeNames = ['A', 'E', 'U', 'Y', 'M'];
  static const linkNames = ['A-E', 'A-U', 'A-Y', 'A-M', 'E-U', 'E-Y', 'E-M', 'U-Y', 'U-M', 'Y-M'];
  static const quadrantLabels = ['Superior esquerdo', 'Superior direito', 'Inferior esquerdo', 'Inferior direito'];
  static const targetCalibrationSamples = 75; //numero de amostras usadas quando estivermos calibrando no mabiente vazio
  static const targetTrainingSamples = 15;
  static const quadrantThreshold = 0.6;
  static const movementSignalThreshold = 0.8; // aqui esta o limite util para detectar movimento
  static const movementDeltaThreshold = 3.0; // ou tbm se a limitacao bruta mudar
  static const defaultNoiseFloor = 2.0; // isso para evitar que por exem. tivermos 2d e for ruido
  static const unstableLinkNoiseLimit = 7.0; // se pasar o link é ruim
  static const topSignalLinkCount = 4;
  static const quadrantMinScore = 0.38;
  static const quadrantMinMargin = 0.14;
  static const quadrantSwitchFrames = 3;
  static const quadrantHoldMs = 1800;

  static const linkQuadrantWeights = [
    [0.65, 0.65, 0.00, 0.00], // A-E
    [0.65, 0.00, 0.65, 0.00], // A-U
    [0.60, 0.10, 0.10, 0.60], // A-Y
    [0.95, 0.25, 0.25, 0.05], // A-M
    [0.10, 0.60, 0.60, 0.10], // E-U
    [0.00, 0.65, 0.00, 0.65], // E-Y
    [0.25, 0.95, 0.05, 0.25], // E-M
    [0.00, 0.00, 0.65, 0.65], // U-Y
    [0.25, 0.05, 0.95, 0.25], // U-M
    [0.05, 0.25, 0.25, 0.95], // Y-M
  ];

  static const fallbackQuadrantWeights = [
    {3: 0.8, 0: 0.55, 1: 0.55, 2: 0.2, 4: 0.2},
    {6: 0.8, 0: 0.55, 5: 0.55, 2: 0.2, 4: 0.2},
    {8: 0.8, 1: 0.55, 7: 0.55, 2: 0.2, 4: 0.2},
    {9: 0.8, 5: 0.55, 7: 0.55, 2: 0.2, 4: 0.2},
  ];
}
