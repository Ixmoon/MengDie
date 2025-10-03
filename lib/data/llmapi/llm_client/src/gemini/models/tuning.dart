// lib/src/gemini/models/tuning.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.


/// A fine-tuned model created using ModelService.CreateTunedModel.
class TunedModel {
  /// The tuned model name.
  final String? name;

  /// The name to display for this model in user interfaces.
  final String? displayName;

  /// A short description of this model.
  final String? description;

  /// The state of the tuned model.
  final TunedModelState? state;

  /// The timestamp when this model was created.
  final DateTime? createTime;

  /// The timestamp when this model was updated.
  final DateTime? updateTime;

  /// The tuning task that creates the tuned model.
  final TuningTask? tuningTask;

  /// List of project numbers that have read access to the tuned model.
  final List<String>? readerProjectNumbers;

  /// TunedModel to use as the starting point for training the new model.
  final TunedModelSource? tunedModelSource;

  /// The name of the `Model` to tune.
  final String? baseModel;

  /// Controls the randomness of the output.
  final double? temperature;

  /// For Nucleus sampling.
  final double? topP;

  /// For Top-k sampling.
  final int? topK;

  TunedModel({
    this.name,
    this.displayName,
    this.description,
    this.state,
    this.createTime,
    this.updateTime,
    this.tuningTask,
    this.readerProjectNumbers,
    this.tunedModelSource,
    this.baseModel,
    this.temperature,
    this.topP,
    this.topK,
  });

  factory TunedModel.fromJson(Map<String, dynamic> json) {
    return TunedModel(
      name: json['name'],
      displayName: json['displayName'],
      description: json['description'],
      state: json['state'] != null
          ? TunedModelState.values.firstWhere(
              (e) => e.value == json['state'],
              orElse: () => TunedModelState.unspecified,
            )
          : null,
      createTime: json['createTime'] != null
          ? DateTime.parse(json['createTime'])
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.parse(json['updateTime'])
          : null,
      tuningTask: json['tuningTask'] != null
          ? TuningTask.fromJson(json['tuningTask'])
          : null,
      readerProjectNumbers: json['readerProjectNumbers'] != null
          ? List<String>.from(json['readerProjectNumbers'])
          : null,
      tunedModelSource: json['tunedModelSource'] != null
          ? TunedModelSource.fromJson(json['tunedModelSource'])
          : null,
      baseModel: json['baseModel'],
      temperature: json['temperature']?.toDouble(),
      topP: json['topP']?.toDouble(),
      topK: json['topK'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (displayName != null) 'displayName': displayName,
      if (description != null) 'description': description,
      if (state != null) 'state': state?.value,
      if (createTime != null) 'createTime': createTime?.toIso8601String(),
      if (updateTime != null) 'updateTime': updateTime?.toIso8601String(),
      if (tuningTask != null) 'tuningTask': tuningTask?.toJson(),
      if (readerProjectNumbers != null)
        'readerProjectNumbers': readerProjectNumbers,
      if (tunedModelSource != null)
        'tunedModelSource': tunedModelSource?.toJson(),
      if (baseModel != null) 'baseModel': baseModel,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'topP': topP,
      if (topK != null) 'topK': topK,
    };
  }
}

/// The state of the tuned model.
enum TunedModelState {
  unspecified('STATE_UNSPECIFIED'),
  creating('CREATING'),
  active('ACTIVE'),
  failed('FAILED');

  const TunedModelState(this.value);
  final String value;
}

/// Tuned model as a source for training a new model.
class TunedModelSource {
  /// The name of the `TunedModel` to use as the starting point for training the new model.
  final String tunedModel;

  /// The name of the base `Model` this `TunedModel` was tuned from.
  final String? baseModel;

  TunedModelSource({
    required this.tunedModel,
    this.baseModel,
  });

  factory TunedModelSource.fromJson(Map<String, dynamic> json) {
    return TunedModelSource(
      tunedModel: json['tunedModel'],
      baseModel: json['baseModel'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tunedModel': tunedModel,
      if (baseModel != null) 'baseModel': baseModel,
    };
  }
}

/// Tuning tasks that create tuned models.
class TuningTask {
  /// The timestamp when tuning this model started.
  final DateTime? startTime;

  /// The timestamp when tuning this model completed.
  final DateTime? completeTime;

  /// Metrics collected during tuning.
  final List<TuningSnapshot>? snapshots;

  /// The model training data.
  final Dataset? trainingData;

  /// Hyperparameters controlling the tuning process.
  final Hyperparameters? hyperparameters;

  TuningTask({
    this.startTime,
    this.completeTime,
    this.snapshots,
    this.trainingData,
    this.hyperparameters,
  });

  factory TuningTask.fromJson(Map<String, dynamic> json) {
    return TuningTask(
      startTime:
          json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
      completeTime: json['completeTime'] != null
          ? DateTime.parse(json['completeTime'])
          : null,
      snapshots: json['snapshots'] != null
          ? (json['snapshots'] as List)
              .map((e) => TuningSnapshot.fromJson(e))
              .toList()
          : null,
      trainingData: json['trainingData'] != null
          ? Dataset.fromJson(json['trainingData'])
          : null,
      hyperparameters: json['hyperparameters'] != null
          ? Hyperparameters.fromJson(json['hyperparameters'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (trainingData != null) 'trainingData': trainingData?.toJson(),
      if (hyperparameters != null) 'hyperparameters': hyperparameters?.toJson(),
    };
  }
}

/// Record for a single tuning step.
class TuningSnapshot {
  /// The tuning step.
  final int step;

  /// The epoch this step was part of.
  final int epoch;

  /// The mean loss of the training examples for this step.
  final double meanLoss;

  /// The timestamp when this metric was computed.
  final DateTime computeTime;

  TuningSnapshot({
    required this.step,
    required this.epoch,
    required this.meanLoss,
    required this.computeTime,
  });

  factory TuningSnapshot.fromJson(Map<String, dynamic> json) {
    return TuningSnapshot(
      step: json['step'],
      epoch: json['epoch'],
      meanLoss: json['meanLoss'].toDouble(),
      computeTime: DateTime.parse(json['computeTime']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'step': step,
      'epoch': epoch,
      'meanLoss': meanLoss,
      'computeTime': computeTime.toIso8601String(),
    };
  }
}

/// Dataset for training or validation.
class Dataset {
  /// Inline examples with simple input/output text.
  final TuningExamples? examples;

  Dataset({this.examples});

  factory Dataset.fromJson(Map<String, dynamic> json) {
    return Dataset(
      examples: json['examples'] != null
          ? TuningExamples.fromJson(json['examples'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (examples != null) 'examples': examples?.toJson(),
    };
  }
}

/// A set of tuning examples. Can be training or validation data.
class TuningExamples {
  /// The examples.
  final List<TuningExample> examples;

  TuningExamples({required this.examples});

  factory TuningExamples.fromJson(Map<String, dynamic> json) {
    return TuningExamples(
      examples: (json['examples'] as List)
          .map((e) => TuningExample.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'examples': examples.map((e) => e.toJson()).toList(),
    };
  }
}

/// A single example for tuning.
class TuningExample {
  /// The expected model output.
  final String output;

  /// Text model input.
  final String? textInput;

  TuningExample({required this.output, this.textInput});

  factory TuningExample.fromJson(Map<String, dynamic> json) {
    return TuningExample(
      output: json['output'],
      textInput: json['textInput'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'output': output,
      if (textInput != null) 'textInput': textInput,
    };
  }
}

/// Hyperparameters controlling the tuning process.
class Hyperparameters {
  /// The learning rate hyperparameter for tuning.
  final double? learningRate;

  /// The learning rate multiplier.
  final double? learningRateMultiplier;

  /// The number of training epochs.
  final int? epochCount;

  /// The batch size hyperparameter for tuning.
  final int? batchSize;

  Hyperparameters({
    this.learningRate,
    this.learningRateMultiplier,
    this.epochCount,
    this.batchSize,
  });

  factory Hyperparameters.fromJson(Map<String, dynamic> json) {
    return Hyperparameters(
      learningRate: json['learningRate']?.toDouble(),
      learningRateMultiplier: json['learningRateMultiplier']?.toDouble(),
      epochCount: json['epochCount'],
      batchSize: json['batchSize'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (learningRate != null) 'learningRate': learningRate,
      if (learningRateMultiplier != null)
        'learningRateMultiplier': learningRateMultiplier,
      if (epochCount != null) 'epochCount': epochCount,
      if (batchSize != null) 'batchSize': batchSize,
    };
  }
}