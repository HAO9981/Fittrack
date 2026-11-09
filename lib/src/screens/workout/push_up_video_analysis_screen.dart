import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../models/workout.dart';
import '../../services/workout_service.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _surface = Color(0xFF141B17);
const _border = Color(0xFF27332B);

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
      final previous = _videoController;
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
      await previous?.dispose();
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to open this video. Choose another clip.\n$error');
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
      setState(() => _error = 'This video has no readable duration.');
      return;
    }

    const sampleIntervalMs = 300;
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
        if (framePath != null) {
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
            } catch (_) {}
          }
        }
        if (mounted) setState(() => _processedFrames++);
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Analysis failed. Try a shorter, clearer side-view video.\n$error');
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
      backgroundColor: const Color(0xFF080D0B),
      appBar: AppBar(
        title: const Text('AI Video Analysis', style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF080D0B),
        iconTheme: const IconThemeData(color: _ink),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('PUSH-UP ANALYSIS', style: TextStyle(color: _lime, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                SizedBox(height: 6),
                Text('Upload a video and let FitTrack count your reps.', style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w600)),
                SizedBox(height: 5),
                Text('For better results, record from the side with your shoulders, elbows and wrists visible.', style: TextStyle(color: _muted, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 14),
            if (video == null)
              Container(
                height: 210,
                decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
                child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.video_library_outlined, color: _lime, size: 48),
                  SizedBox(height: 10),
                  Text('No video selected', style: TextStyle(color: _ink, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Choose a video from your gallery', style: TextStyle(color: _muted, fontSize: 12)),
                ])),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: video.value.aspectRatio > 0 ? video.value.aspectRatio : 16 / 9,
                  child: Stack(alignment: Alignment.center, children: [
                    VideoPlayer(video),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: _lime, foregroundColor: const Color(0xFF080D0B)),
                      onPressed: () => setState(() => video.value.isPlaying ? video.pause() : video.play()),
                      icon: Icon(video.value.isPlaying ? Icons.pause : Icons.play_arrow),
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isAnalyzing ? null : _pickVideo,
              style: OutlinedButton.styleFrom(foregroundColor: _lime, side: const BorderSide(color: _lime), padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: const Icon(Icons.video_library_outlined),
              label: Text(_videoPath == null ? 'Select Video from Gallery' : 'Choose Another Video'),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _MetricCard(label: 'REPS', value: '$_reps')),
              const SizedBox(width: 10),
              Expanded(child: _MetricCard(label: 'DURATION', value: '${_durationSeconds}s')),
            ]),
            if (_isAnalyzing) ...[
              const SizedBox(height: 18),
              const Text('Analyzing video frames...', style: TextStyle(color: _ink, fontSize: 12)),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress, color: _lime, backgroundColor: _border),
              const SizedBox(height: 6),
              Text('$_processedFrames / $_totalFrames frames', style: const TextStyle(color: _muted, fontSize: 11)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _videoPath == null || _isAnalyzing ? null : _analyzeVideo,
              style: FilledButton.styleFrom(backgroundColor: _lime, foregroundColor: const Color(0xFF080D0B), padding: const EdgeInsets.symmetric(vertical: 15)),
              icon: const Icon(Icons.auto_awesome),
              label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Video'),
            ),
            const SizedBox(height: 9),
            OutlinedButton.icon(
              onPressed: _reps == 0 || _isAnalyzing || _isSaving ? null : _saveWorkout,
              style: OutlinedButton.styleFrom(foregroundColor: _lime, side: const BorderSide(color: _border), padding: const EdgeInsets.symmetric(vertical: 15)),
              icon: const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Saving...' : 'Save to Workout History'),
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
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: _border)),
    child: Column(children: [
      Text(label, style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(color: _lime, fontSize: 24, fontWeight: FontWeight.w800)),
    ]),
  );
}
