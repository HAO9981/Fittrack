import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../models/workout.dart';
import '../../services/workout_service.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _bg = Color(0xFF080D0B);
const _surface = Color(0xFF141B17);
const _border = Color(0xFF27332B);

class PushUpLiveCounterScreen extends StatefulWidget {
  const PushUpLiveCounterScreen({super.key});

  @override
  State<PushUpLiveCounterScreen> createState() => _PushUpLiveCounterScreenState();
}

class _PushUpLiveCounterScreenState extends State<PushUpLiveCounterScreen> {
  CameraController? _camera;
  late final PoseDetector _poseDetector;
  Timer? _clock;
  bool _initializing = true;
  bool _running = false;
  bool _processingFrame = false;
  bool _saving = false;
  String? _error;
  int _reps = 0;
  int _elapsedSeconds = 0;
  int _downFrames = 0;
  int _upFrames = 0;
  String _stage = 'up';
  DateTime? _lastRepAt;

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
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('NoCamera', 'No camera was found.');
      final description = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _initializing = false;
      });
    } catch (error) {
      await controller?.dispose();
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'Unable to start the camera. Check camera permission and try again.\n$error';
        });
      }
    }
  }

  Future<void> _startCounter() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _running) return;
    setState(() {
      _running = true;
      _reps = 0;
      _elapsedSeconds = 0;
      _downFrames = 0;
      _upFrames = 0;
      _stage = 'up';
      _lastRepAt = null;
      _error = null;
    });
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _running) setState(() => _elapsedSeconds++);
    });
    try {
      await camera.startImageStream(_processCameraImage);
    } catch (error) {
      _clock?.cancel();
      if (mounted) {
        setState(() {
          _running = false;
          _error = 'Unable to start live pose detection.\n$error';
        });
      }
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_running || _processingFrame || image.planes.isEmpty) return;
    _processingFrame = true;
    try {
      final camera = _camera;
      if (camera == null) return;
      final rotation = InputImageRotationValue.fromRawValue(
            camera.description.sensorOrientation,
          ) ??
          InputImageRotation.rotation0deg;
      final bytes = image.planes.first.bytes;
      final input = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
      final poses = await _poseDetector.processImage(input);
      if (!_running || !mounted || poses.isEmpty) return;
      final angle = _elbowAngle(poses.first);
      if (angle == null) return;

      if (angle < 95) {
        _downFrames++;
        _upFrames = 0;
        if (_downFrames >= 2) _stage = 'down';
      } else if (angle > 155) {
        _upFrames++;
        _downFrames = 0;
        if (_upFrames >= 2 && _stage == 'down') {
          final now = DateTime.now();
          final last = _lastRepAt;
          if (last == null || now.difference(last).inMilliseconds >= 500) {
            _reps++;
            _lastRepAt = now;
          }
          _stage = 'up';
        }
      } else {
        _downFrames = 0;
        _upFrames = 0;
      }
      setState(() {});
    } catch (error) {
      if (mounted && _error == null) {
        setState(() => _error = 'Pose detection could not process the camera frame. Check that the phone is in a side view.\n$error');
      }
    } finally {
      _processingFrame = false;
    }
  }

  double? _elbowAngle(Pose pose) {
    double? sideAngle(PoseLandmarkType shoulderType, PoseLandmarkType elbowType, PoseLandmarkType wristType) {
      final shoulder = pose.landmarks[shoulderType];
      final elbow = pose.landmarks[elbowType];
      final wrist = pose.landmarks[wristType];
      if (shoulder == null || elbow == null || wrist == null) return null;
      if (shoulder.likelihood < 0.45 || elbow.likelihood < 0.45 || wrist.likelihood < 0.45) return null;
      final radians = math.atan2(wrist.y - elbow.y, wrist.x - elbow.x) -
          math.atan2(shoulder.y - elbow.y, shoulder.x - elbow.x);
      var degrees = radians.abs() * 180 / math.pi;
      if (degrees > 180) degrees = 360 - degrees;
      return degrees;
    }

    final left = sideAngle(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    final right = sideAngle(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    if (left == null) return right;
    if (right == null) return left;
    return left < right ? left : right;
  }

  Future<void> _stopCounter() async {
    final camera = _camera;
    _clock?.cancel();
    if (camera != null && camera.value.isStreamingImages) {
      await camera.stopImageStream();
    }
    if (mounted) setState(() => _running = false);
  }

  Future<void> _saveWorkout() async {
    if (_running || _saving || _reps == 0) return;
    setState(() => _saving = true);
    try {
      final minutes = _elapsedSeconds / 60;
      final rate = minutes <= 0 ? 0.0 : _reps / minutes;
      await WorkoutService.instance.addWorkout(Workout(
        id: '',
        name: 'AI Push-up (Live)',
        category: 'Strength',
        duration: _elapsedSeconds,
        durationUnit: 'seconds',
        date: DateTime.now(),
        reps: _reps,
        repsPerMinute: rate,
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
      if (mounted) setState(() => _saving = false);
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
    _camera?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Live Rep Counter', style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
        backgroundColor: _bg,
        iconTheme: const IconThemeData(color: _ink),
      ),
      body: SafeArea(
        child: _initializing
            ? const Center(child: CircularProgressIndicator(color: _lime))
            : ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
                    child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('LIVE PUSH-UP TRACKING', style: TextStyle(color: _lime, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.1)),
                      SizedBox(height: 6),
                      Text('Place your phone at your side and keep your shoulders, elbows and wrists visible.', style: TextStyle(color: _ink, fontSize: 13)),
                      SizedBox(height: 4),
                      Text('The counter increases after a down-and-up movement is detected.', style: TextStyle(color: _muted, fontSize: 11)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  if (camera != null && camera.value.isInitialized)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: camera.value.aspectRatio,
                        child: CameraPreview(camera),
                      ),
                    )
                  else
                    Container(
                      height: 220,
                      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18)),
                      child: Center(child: Text(_error ?? 'Camera unavailable', style: const TextStyle(color: _muted))),
                    ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _LiveMetric(label: 'REPS', value: '$_reps', large: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _LiveMetric(label: 'TIME', value: _timeLabel)),
                  ]),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
                    child: Row(children: [
                      Icon(_running ? Icons.sensors_rounded : Icons.info_outline, color: _lime),
                      const SizedBox(width: 9),
                      Expanded(child: Text(
                        !_running ? 'Ready to start' : _stage == 'down' ? 'Down position detected — push back up' : 'Ready position — lower your body',
                        style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w600),
                      )),
                      if (_running) const SizedBox(width: 8),
                      if (_running) const SizedBox(width: 8, height: 8, child: DecoratedBox(decoration: BoxDecoration(color: _lime, shape: BoxShape.circle))),
                    ]),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                  ],
                  const SizedBox(height: 14),
                  if (!_running)
                    FilledButton.icon(
                      onPressed: camera == null ? null : _startCounter,
                      style: FilledButton.styleFrom(backgroundColor: _lime, foregroundColor: _bg, padding: const EdgeInsets.symmetric(vertical: 15)),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start Live Counting'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _stopCounter,
                      style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Stop Counting'),
                    ),
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                    onPressed: !_running && _reps > 0 && !_saving ? _saveWorkout : null,
                    style: OutlinedButton.styleFrom(foregroundColor: _lime, side: const BorderSide(color: _border), padding: const EdgeInsets.symmetric(vertical: 15)),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save to Workout History'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LiveMetric extends StatelessWidget {
  const _LiveMetric({required this.label, required this.value, this.large = false});
  final String label;
  final String value;
  final bool large;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 17),
    decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: _border)),
    child: Column(children: [
      Text(label, style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(color: _lime, fontSize: large ? 38 : 25, fontWeight: FontWeight.w800)),
    ]),
  );
}
