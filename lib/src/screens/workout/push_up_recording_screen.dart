import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'push_up_video_analysis_screen.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _bg = Color(0xFF080D0B);
const _surface = Color(0xFF141B17);
const _border = Color(0xFF27332B);

class PushUpRecordingScreen extends StatefulWidget {
  const PushUpRecordingScreen({super.key});

  @override
  State<PushUpRecordingScreen> createState() => _PushUpRecordingScreenState();
}

class _PushUpRecordingScreenState extends State<PushUpRecordingScreen> {
  CameraController? _controller;
  Timer? _timer;
  bool _initializing = true;
  bool _recording = false;
  bool _openingAnalysis = false;
  int _seconds = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('NoCamera', 'No camera was found.');
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'Unable to start the camera. Please allow camera access in your phone settings.\n$error';
        });
      }
    }
  }

  Future<void> _startRecording() async {
    final camera = _controller;
    if (camera == null || !camera.value.isInitialized || _recording) return;
    try {
      await camera.startVideoRecording();
      if (!mounted) return;
      setState(() {
        _recording = true;
        _seconds = 0;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to start recording: $error')),
        );
      }
    }
  }

  Future<void> _stopAndAnalyze() async {
    final camera = _controller;
    if (camera == null || !_recording || _openingAnalysis) return;
    setState(() => _openingAnalysis = true);
    _timer?.cancel();
    try {
      final video = await camera.stopVideoRecording();
      if (!mounted) return;
      setState(() => _recording = false);
      await camera.dispose();
      _controller = null;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PushUpVideoAnalysisScreen(initialVideoPath: video.path),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _openingAnalysis = false;
          _recording = false;
          _error = 'Unable to finish recording. Please try again.\n$error';
        });
      }
    }
  }

  String get _timeLabel {
    final minutes = _seconds ~/ 60;
    final seconds = _seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _controller;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('AI Push-up Recording', style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
        backgroundColor: _bg,
        iconTheme: const IconThemeData(color: _ink),
      ),
      body: SafeArea(
        child: _initializing
            ? const Center(child: CircularProgressIndicator(color: _lime))
            : _error != null && camera == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _ink)),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
                        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('RECORD YOUR SET', style: TextStyle(color: _lime, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.1)),
                          SizedBox(height: 6),
                          Text('Keep your full upper body in frame.', style: TextStyle(color: _ink, fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('Place the phone at your side so your shoulders, elbows and wrists are visible. After recording, FitTrack will analyze the clip.', style: TextStyle(color: _muted, fontSize: 12)),
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
                        ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
                        child: Column(children: [
                          Text(_timeLabel, style: const TextStyle(color: _lime, fontSize: 32, fontWeight: FontWeight.w800, fontFeatures: [])),
                          const SizedBox(height: 4),
                          Text(_recording ? 'RECORDING' : 'READY', style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      if (!_recording)
                        FilledButton.icon(
                          onPressed: camera == null || _openingAnalysis ? null : _startRecording,
                          style: FilledButton.styleFrom(backgroundColor: _lime, foregroundColor: _bg, padding: const EdgeInsets.symmetric(vertical: 15)),
                          icon: const Icon(Icons.fiber_manual_record_rounded),
                          label: const Text('Start Recording'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: _openingAnalysis ? null : _stopAndAnalyze,
                          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                          icon: const Icon(Icons.stop_rounded),
                          label: Text(_openingAnalysis ? 'Preparing Analysis...' : 'Stop & Analyze Video'),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ],
                    ],
                  ),
      ),
    );
  }
}
