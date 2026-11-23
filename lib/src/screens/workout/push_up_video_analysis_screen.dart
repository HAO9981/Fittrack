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
  const PushUpVideoAnalysisScreen({
    super.key,
    this.initialVideoPath,
    this.exerciseName = 'Push Up',
  });

  final String? initialVideoPath;
  final String exerciseName;

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
  int _downSamples = 0;
  int _upSamples = 0;
  final List<int> _repTimesMs = [];
  bool _hasAnalyzed = false;
  String _stage = 'up';

  bool get _isSitUp => widget.exerciseName.toLowerCase() == 'sit-up';

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.single,
        model: PoseDetectionModel.base,
      ),
    );
    final initialPath = widget.initialVideoPath;
    if (initialPath != null) _loadVideo(initialPath);
  }

  Future<void> _loadVideo(String path) async {
    try {
      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final previous = _videoController;
      setState(() {
        _videoController = controller;
        _videoPath = path;
        _durationSeconds = controller.value.duration.inSeconds;
        _error = null;
        _reps = 0;
        _processedFrames = 0;
        _totalFrames = 0;
        _stage = _isSitUp ? 'down' : 'up';
        _downSamples = 0;
        _upSamples = 0;
        _repTimesMs.clear();
        _hasAnalyzed = false;
      });
      await previous?.dispose();
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to open this video. Choose another clip.\n$error');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picked = await _picker.pickVideo(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      await _loadVideo(picked.path);
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to open this video. Choose another clip.\n$error');
    }
  }

  double? _calculateAngle(Pose pose) {
    double? angleFor(
      PoseLandmarkType firstType,
      PoseLandmarkType jointType,
      PoseLandmarkType lastType,
    ) {
      final first = pose.landmarks[firstType];
      final joint = pose.landmarks[jointType];
      final last = pose.landmarks[lastType];
      if (first == null || joint == null || last == null) return null;
      if (first.likelihood < 0.45 || joint.likelihood < 0.45 || last.likelihood < 0.45) return null;
      final radians = math.atan2(last.y - joint.y, last.x - joint.x) -
          math.atan2(first.y - joint.y, first.x - joint.x);
      var degrees = radians.abs() * 180 / math.pi;
      if (degrees > 180) degrees = 360 - degrees;
      return degrees;
    }

    final isSquat = widget.exerciseName.toLowerCase() == 'squat';
    final left = _isSitUp
        ? angleFor(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee)
        : isSquat
            ? angleFor(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle)
            : angleFor(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    final right = _isSitUp
        ? angleFor(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee)
        : isSquat
            ? angleFor(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle)
            : angleFor(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
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

    // A 400 ms interval reduces thumbnail extraction and pose inference work
    // while retaining enough samples for normal push-up cadence.
    const sampleIntervalMs = 400;
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
      _stage = _isSitUp ? 'down' : 'up';
      _downSamples = 0;
      _upSamples = 0;
      _repTimesMs.clear();
      _hasAnalyzed = false;
    });

    try {
      for (final timeMs in frameTimes) {
        if (!mounted) return;
        final framePath = await VideoThumbnail.thumbnailFile(
          video: path,
          imageFormat: ImageFormat.JPEG,
          timeMs: timeMs,
          maxWidth: 360,
          quality: 50,
        );
        if (framePath != null) {
          try {
            final poses = await _poseDetector.processImage(InputImage.fromFilePath(framePath));
            if (poses.isNotEmpty) {
              final angle = _calculateAngle(poses.first);
              if (angle != null) {
                // Require two consecutive samples at each end of the movement
                // to reduce false counts caused by a single noisy pose frame.
                final isSitUp = _isSitUp;
                final reachedLowPosition = isSitUp ? angle < 90 : angle < 100;
                final reachedHighPosition = isSitUp ? angle > 145 : angle > 155;
                if (reachedLowPosition) {
                  _downSamples++;
                  _upSamples = 0;
                  if (_downSamples >= 2) _stage = isSitUp ? 'up' : 'down';
                } else if (reachedHighPosition) {
                  _upSamples++;
                  _downSamples = 0;
                  final completedCycle = isSitUp ? _stage == 'up' : _stage == 'down';
                  if (_upSamples >= 2 && completedCycle) {
                    _reps++;
                    _repTimesMs.add(timeMs);
                    _stage = isSitUp ? 'down' : 'up';
                  }
                } else {
                  _downSamples = 0;
                  _upSamples = 0;
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
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _hasAnalyzed = _error == null;
        });
      }
    }
  }

  double get _repsPerMinute =>
      _durationSeconds <= 0 ? 0 : _reps * 60 / _durationSeconds;

  double? get _averageRepIntervalSeconds {
    if (_repTimesMs.length < 2) return null;
    var totalInterval = 0;
    for (var i = 1; i < _repTimesMs.length; i++) {
      totalInterval += _repTimesMs[i] - _repTimesMs[i - 1];
    }
    return totalInterval / (_repTimesMs.length - 1) / 1000;
  }

  String get _performanceSummary {
    if (_reps == 0) {
      return 'No complete repetitions were detected. Try a side-on camera angle and keep your upper body visible throughout the video.';
    }
    final rate = _repsPerMinute;
    if (rate >= 20) return 'Strong pace detected. Keep your movement controlled and maintain a consistent range of motion.';
    if (rate >= 10) return 'Steady pace detected. Focus on keeping each repetition smooth and consistent.';
    return 'A measured pace was detected. Take your time and prioritize controlled movement over speed.';
  }

  Future<void> _saveWorkout() async {
    if (!_hasAnalyzed || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await WorkoutService.instance.addWorkout(Workout(
        id: '',
        name: 'AI ${widget.exerciseName} (Video)',
        category: 'Strength',
        duration: _durationSeconds,
        durationUnit: 'seconds',
        date: DateTime.now(),
        reps: _reps,
        repsPerMinute: _repsPerMinute,
        averageRepIntervalSeconds: _averageRepIntervalSeconds,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved $_reps ${widget.exerciseName.toLowerCase()} reps to Workout History.')),
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
        title: Text('AI ${widget.exerciseName} Analysis', style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${widget.exerciseName.toUpperCase()} ANALYSIS', style: TextStyle(color: _lime, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                SizedBox(height: 6),
                Text('Upload a video and let FitTrack count your ${widget.exerciseName.toLowerCase()} reps.', style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w600)),
                SizedBox(height: 5),
                Text(_isSitUp ? 'For better results, record from the side with your shoulders, hips and knees visible.' : widget.exerciseName.toLowerCase() == 'squat' ? 'For better results, record from the side with your hips, knees and ankles visible.' : 'For better results, record from the side with your shoulders, elbows and wrists visible.', style: TextStyle(color: _muted, fontSize: 12)),
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
            if (_hasAnalyzed) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WORKOUT PERFORMANCE',
                      style: TextStyle(
                        color: _lime,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            label: 'REPS / MIN',
                            value: _repsPerMinute.toStringAsFixed(1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricCard(
                            label: 'AVG. REP GAP',
                            value: _averageRepIntervalSeconds == null
                                ? '--'
                                : '${_averageRepIntervalSeconds!.toStringAsFixed(1)}s',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _performanceSummary,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'These values are estimates based on detected repetitions and the video duration.',
                      style: TextStyle(color: _muted, fontSize: 10, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _reps > 0 ? Icons.check_circle_outline : Icons.info_outline,
                      color: _lime,
                      size: 20,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _reps > 0
                            ? 'Analysis complete. $_reps complete push-ups detected.'
                            : 'Analysis complete, but no complete push-ups were detected. Try a clear side-view video with your shoulders, elbows and wrists visible.',
                        style: const TextStyle(color: _ink, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
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
              onPressed: !_hasAnalyzed || _isAnalyzing || _isSaving ? null : _saveWorkout,
              style: OutlinedButton.styleFrom(foregroundColor: _lime, side: const BorderSide(color: _border), padding: const EdgeInsets.symmetric(vertical: 15)),
              icon: const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Saving...' : 'Save Result to Workout History'),
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
