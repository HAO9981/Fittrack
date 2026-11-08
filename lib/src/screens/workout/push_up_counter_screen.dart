import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../models/workout.dart';
import '../../services/workout_service.dart';

class PushUpCounterScreen extends StatefulWidget {
  const PushUpCounterScreen({super.key});

  @override
  State<PushUpCounterScreen> createState() => _PushUpCounterScreenState();
}

class _PushUpCounterScreenState extends State<PushUpCounterScreen> {
  CameraController? _cameraController;
  late final PoseDetector _poseDetector;
  Timer? _clock;
  final Stopwatch _stopwatch = Stopwatch();

  bool _initializing = true;
  bool _isProcessing = false;
  bool _isRunning = false;
  bool _isSaving = false;
  String? _error;
  int _reps = 0;
  int _elapsedSeconds = 0;
  String _stage = 'up';
  double? _elbowAngle;

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No camera was found on this device.');
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _cameraController = controller;
      await controller.startImageStream(_processCameraImage);
      setState(() => _initializing = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'Unable to start the camera. Check camera permission and try again.\n$error';
        });
      }
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || !_isRunning || _cameraController == null) return;
    _isProcessing = true;
    try {
      final bytes = _convertYuv420ToNv21(image);
      final rotation = InputImageRotationValue.fromRawValue(
        _cameraController!.description.sensorOrientation,
      );
      if (rotation == null) return;
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
      final poses = await _poseDetector.processImage(inputImage);
      if (!mounted || poses.isEmpty) return;
      final angle = _bestElbowAngle(poses.first);
      if (angle == null) return;
      setState(() {
        _elbowAngle = angle;
        if (angle < 95) {
          _stage = 'down';
        } else if (angle > 155 && _stage == 'down') {
          _reps++;
          _stage = 'up';
        }
      });
    } catch (_) {
      // Ignore an occasional frame that cannot be decoded; keep the stream alive.
    } finally {
      _isProcessing = false;
    }
  }

  Uint8List _convertYuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final output = Uint8List(width * height + (width * height ~/ 2));

    var outputIndex = 0;
    for (var row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      for (var col = 0; col < width; col++) {
        output[outputIndex++] = yPlane.bytes[rowStart + col];
      }
    }

    final chromaHeight = height ~/ 2;
    final chromaWidth = width ~/ 2;
    for (var row = 0; row < chromaHeight; row++) {
      for (var col = 0; col < chromaWidth; col++) {
        final uIndex = row * uPlane.bytesPerRow + col * (uPlane.bytesPerPixel ?? 1);
        final vIndex = row * vPlane.bytesPerRow + col * (vPlane.bytesPerPixel ?? 1);
        output[outputIndex++] = vPlane.bytes[vIndex];
        output[outputIndex++] = uPlane.bytes[uIndex];
      }
    }
    return output;
  }

  double? _bestElbowAngle(Pose pose) {
    final left = _calculateAngle(
      pose.landmarks[PoseLandmarkType.leftShoulder],
      pose.landmarks[PoseLandmarkType.leftElbow],
      pose.landmarks[PoseLandmarkType.leftWrist],
    );
    final right = _calculateAngle(
      pose.landmarks[PoseLandmarkType.rightShoulder],
      pose.landmarks[PoseLandmarkType.rightElbow],
      pose.landmarks[PoseLandmarkType.rightWrist],
    );
    if (left == null) return right;
    if (right == null) return left;
    return (left + right) / 2;
  }

  double? _calculateAngle(PoseLandmark? shoulder, PoseLandmark? elbow, PoseLandmark? wrist) {
    if (shoulder == null || elbow == null || wrist == null) return null;
    if (shoulder.likelihood < 0.45 || elbow.likelihood < 0.45 || wrist.likelihood < 0.45) return null;
    final radians = math.atan2(wrist.y - elbow.y, wrist.x - elbow.x) -
        math.atan2(shoulder.y - elbow.y, shoulder.x - elbow.x);
    var degrees = radians.abs() * 180 / math.pi;
    if (degrees > 180) degrees = 360 - degrees;
    return degrees;
  }

  void _start() {
    if (_cameraController == null || _isRunning) return;
    setState(() {
      _reps = _elapsedSeconds == 0 ? 0 : _reps;
      _stage = 'up';
      _elbowAngle = null;
      _isRunning = true;
    });
    _stopwatch.start();
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
    });
  }

  void _pause() {
    if (!_isRunning) return;
    _stopwatch.stop();
    _clock?.cancel();
    setState(() => _isRunning = false);
  }

  Future<void> _finish() async {
    if (_reps == 0 || _isSaving) return;
    _pause();
    setState(() => _isSaving = true);
    try {
      await WorkoutService.instance.addWorkout(Workout(
        id: '',
        name: 'AI Push-up',
        category: 'Strength',
        duration: math.max(1, (_elapsedSeconds / 60).ceil()),
        date: DateTime.now(),
        reps: _reps,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved $_reps push-ups to Workout History.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save workout: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String get _timeLabel {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _clock?.cancel();
    _stopwatch.stop();
    _cameraController?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _cameraController;
    return Scaffold(
      appBar: AppBar(title: const Text('AI Push-up Counter')),
      body: SafeArea(
        child: _initializing
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ))
                : Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          color: Colors.black,
                          child: camera != null && camera.value.isInitialized
                              ? CameraPreview(camera)
                              : const Center(child: Text('Camera unavailable', style: TextStyle(color: Colors.white))),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _MetricCard(label: 'REPS', value: '$_reps')),
                                const SizedBox(width: 12),
                                Expanded(child: _MetricCard(label: 'TIME', value: _timeLabel)),
                                const SizedBox(width: 12),
                                Expanded(child: _MetricCard(label: 'STAGE', value: _stage.toUpperCase())),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _elbowAngle == null
                                  ? 'Stand sideways and keep your upper body visible.'
                                  : 'Elbow angle: ${_elbowAngle!.round()}° · Move down and return up.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 18),
                            if (!_isRunning)
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _isSaving ? null : _start,
                                  icon: const Icon(Icons.play_arrow),
                                  label: Text(_elapsedSeconds == 0 ? 'Start Counting' : 'Resume'),
                                ),
                              )
                            else
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _pause,
                                  icon: const Icon(Icons.pause),
                                  label: const Text('Pause'),
                                ),
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _reps == 0 || _isRunning || _isSaving ? null : _finish,
                                child: Text(_isSaving ? 'Saving...' : 'Finish & Save Workout'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 5),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
