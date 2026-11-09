import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../models/workout.dart';
import '../../services/workout_service.dart';

class PushUpVideoAnalysisScreen extends StatefulWidget {
  const PushUpVideoAnalysisScreen({super.key});

  @override
  State<PushUpVideoAnalysisScreen> createState() => _PushUpVideoAnalysisScreenState();
}

class _PushUpVideoAnalysisScreenState extends State<PushUpVideoAnalysisScreen> {
  final ImagePicker _picker = ImagePicker();
  late final PoseDetector _poseDetector;
  VideoPlayerController? _videoController;

  String? _videoPath;
  String? _error;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  int _reps = 0;
  int _processedFrames = 0;
  int _totalFrames = 0;
  int _durationSeconds = 0;
  String _stage = 'up';

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.single,
        model: PoseDetectionModel.base,
      ),
    );
  }

  Future<void> _pickVideo() async {
    try {
      final picked = await _picker.pickVideo(source: ImageSource.gallery);
      if (picked == null || !mounted) return;

      final controller = VideoPlayerController.file(File(picked.path));
      await controller.initialize();
      await controller.setLooping(false);
      final oldController = _videoController;
      setState(() {
        _videoController = controller;
        _videoPath = picked.path;
        _durationSeconds = controller.value.duration.inSeconds;
        _error = null;
        _reps = 0;
        _processedFrames = 0;
        _totalFrames = 0;
        _stage = 'up';
      });
      await oldController?.dispose();
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to open this video. Please choose another video.\n$error');
    }
  }

  double? _calculateAngle(Pose pose) {
    double? angleFor(PoseLandmarkType shoulderType, PoseLandmarkType elbowType, PoseLandmarkType wristType) {
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

    final left = angleFor(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    final right = angleFor(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    if (left == null) return right;
    if (right == null) return left;
    return (left + right) / 2;
  }

  Future<void> _analyzeVideo() async {
    final path = _videoPath;
    final controller = _videoController;
    if (path == null || controller == null || _isAnalyzing) return;

    final durationMs = controller.value.duration.inMilliseconds;
    if (durationMs <= 0) {
      setState(() => _error = 'The selected video has no readable duration.');
      return;
    }

    const sampleIntervalMs = 350;
    final frameTimes = <int>[];
    for (var time = 0; time < durationMs; time += sampleIntervalMs) {
      frameTimes.add(time);
    }

    setState(() {
      _isAnalyzing = true;
      _error = null;
      _reps = 0;
      _processedFrames = 0;
      _totalFrames = frameTimes.length;
      _stage = 'up';
    });

    try {
      for (final timeMs in frameTimes) {
        if (!mounted) return;
        final framePath = await VideoThumbnail.thumbnailFile(
          video: path,
          imageFormat: ImageFormat.JPEG,
          timeMs: timeMs,
          maxWidth: 480,
          quality: 65,
        );
        if (framePath == null) {
          if (mounted) setState(() => _processedFrames++);
          continue;
        }

        try {
          final poses = await _poseDetector.processImage(InputImage.fromFilePath(framePath));
          if (poses.isNotEmpty) {
            final angle = _calculateAngle(poses.first);
            if (angle != null) {
              if (angle < 95) {
                _stage = 'down';
              } else if (angle > 155 && _stage == 'down') {
                _reps++;
                _stage = 'up';
              }
            }
          }
        } finally {
          try {
            await File(framePath).delete();
          } catch (_) {
            // Temporary thumbnail cleanup is best-effort.
          }
        }

        if (mounted) {
          setState(() => _processedFrames++);
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Video analysis failed. Please try a shorter or clearer video.\n$error');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _saveWorkout() async {
    if (_reps == 0 || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await WorkoutService.instance.addWorkout(Workout(
        id: '',
        name: 'AI Push-up (Video)',
        category: 'Strength',
        duration: _durationSeconds < 60 ? 1 : (_durationSeconds / 60).ceil(),
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

  @override
  void dispose() {
    _videoController?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _videoController;
    final progress = _totalFrames == 0 ? 0.0 : _processedFrames / _totalFrames;
    return Scaffold(
      appBar: AppBar(title: const Text('Analyze Push-up Video')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (video == null)
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.video_library_outlined, size: 52),
                      SizedBox(height: 12),
                      Text('Choose a push-up video from your gallery'),
                    ],
                  ),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: video.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(video),
                      IconButton.filledTonal(
                        onPressed: () {
                          setState(() {
                            video.value.isPlaying ? video.pause() : video.play();
                          });
                        },
                        icon: Icon(video.value.isPlaying ? Icons.pause : Icons.play_arrow),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _isAnalyzing ? null : _pickVideo,
              icon: const Icon(Icons.video_library_outlined),
              label: Text(_videoPath == null ? 'Upload Video' : 'Choose Another Video'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _ResultCard(label: 'REPS', value: '$_reps')),
                const SizedBox(width: 12),
                Expanded(child: _ResultCard(label: 'DURATION', value: '${_durationSeconds}s')),
              ],
            ),
            if (_isAnalyzing) ...[
              const SizedBox(height: 18),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text('Analyzing frames: $_processedFrames / $_totalFrames',
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 18),
            Text(
              'For better accuracy, record from the side and keep your shoulders, elbows and wrists visible throughout the video.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _videoPath == null || _isAnalyzing ? null : _analyzeVideo,
              icon: const Icon(Icons.auto_awesome),
              label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Video'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _reps == 0 || _isAnalyzing || _isSaving ? null : _saveWorkout,
              child: Text(_isSaving ? 'Saving...' : 'Save to Workout History'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
