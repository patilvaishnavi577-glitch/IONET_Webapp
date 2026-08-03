import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/update_model.dart';
import '../providers/updates_provider.dart';

class StoryPlayer extends StatefulWidget {
  final SystemUpdate update;
  final VoidCallback onClose;

  const StoryPlayer({
    super.key,
    required this.update,
    required this.onClose,
  });

  @override
  State<StoryPlayer> createState() => _StoryPlayerState();
}

class _StoryPlayerState extends State<StoryPlayer> {
  int _currentSlideIndex = 0;
  double _currentProgress = 0.0;
  Timer? _progressTimer;
  final int _slideDurationMs = 5000; // 5 seconds per slide
  final int _tickIntervalMs = 50;

  List<Map<String, dynamic>> _slides = [];

  @override
  void initState() {
    super.initState();
    _buildSlides();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant StoryPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.update.id != widget.update.id) {
      _progressTimer?.cancel();
      setState(() {
        _currentSlideIndex = 0;
        _currentProgress = 0.0;
      });
      _buildSlides();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _buildSlides() {
    _slides = [];
    // 1. Add media slides
    for (final url in widget.update.fileUrls) {
      _slides.add({
        'type': 'media',
        'url': url,
      });
    }
    // 2. Add text description slide
    _slides.add({
      'type': 'text',
      'title': widget.update.title,
      'description': widget.update.description,
    });
  }

  void _startTimer() {
    _progressTimer?.cancel();
    final totalTicks = _slideDurationMs / _tickIntervalMs;
    int tickCount = 0;

    _progressTimer = Timer.periodic(Duration(milliseconds: _tickIntervalMs), (timer) {
      if (!mounted) return;
      tickCount++;
      setState(() {
        _currentProgress = tickCount / totalTicks;
      });

      if (tickCount >= totalTicks) {
        _nextSlide();
      }
    });
  }

  void _nextSlide() {
    if (_currentSlideIndex < _slides.length - 1) {
      setState(() {
        _currentSlideIndex++;
        _currentProgress = 0.0;
      });
      _startTimer();
    } else {
      // Finished all slides for this update! Auto-advance to the next unseen update if possible.
      final provider = context.read<UpdatesProvider>();
      final list = provider.updates;
      final currentIdx = list.indexWhere((u) => u.id == widget.update.id);
      
      if (currentIdx != -1 && currentIdx < list.length - 1) {
        // Find next update
        final nextUpdate = list[currentIdx + 1];
        provider.selectUpdate(nextUpdate);
      } else {
        // No more updates, close player
        widget.onClose();
      }
    }
  }

  void _prevSlide() {
    if (_currentSlideIndex > 0) {
      setState(() {
        _currentSlideIndex--;
        _currentProgress = 0.0;
      });
      _startTimer();
    } else {
      // On first slide, go back to previous update if possible
      final provider = context.read<UpdatesProvider>();
      final list = provider.updates;
      final currentIdx = list.indexWhere((u) => u.id == widget.update.id);
      
      if (currentIdx > 0) {
        final prevUpdate = list[currentIdx - 1];
        provider.selectUpdate(prevUpdate);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_slides.isEmpty) return const SizedBox.shrink();

    final slide = _slides[_currentSlideIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Slide Content Card
          Positioned.fill(
            child: _buildSlideContent(slide),
          ),

          // 2. Linear Gradient Overlay at top for visibility of controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black54, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 3. Status Progress Segment Bars at top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              children: List.generate(_slides.length, (index) {
                double val = 0.0;
                if (index < _currentSlideIndex) {
                  val = 1.0;
                } else if (index == _currentSlideIndex) {
                  val = _currentProgress;
                }
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: val,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00A884)),
                        minHeight: 3,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // 4. Header Details & Close Options Row
          Positioned(
            top: 28,
            left: 16,
            right: 16,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF00A884),
                  radius: 18,
                  child: const Icon(Icons.security_update_good, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.update.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'System Update • ${_formatTimeAgo(widget.update.timestamp)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // 5. Tap Zones for Navigation
          Positioned.fill(
            child: Row(
              children: [
                // Left 30% goes back
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: _prevSlide,
                    behavior: HitTestBehavior.translucent,
                    child: const SizedBox.expand(),
                  ),
                ),
                // Right 70% goes forward
                Expanded(
                  flex: 7,
                  child: GestureDetector(
                    onTap: _nextSlide,
                    behavior: HitTestBehavior.translucent,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideContent(Map<String, dynamic> slide) {
    if (slide['type'] == 'media') {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Image.network(
          slide['url'],
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, stack) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white38, size: 64),
          ),
          loadingBuilder: (ctx, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A884)),
            );
          },
        ),
      );
    } else {
      // Premium centered text slide with gradient/glassmorphic text status layout
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.new_releases_outlined, color: Color(0xFF00A884), size: 48),
            const SizedBox(height: 24),
            Text(
              slide['title'] ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
              ),
              child: Text(
                slide['description'] ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  String _formatTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    }
    return 'Just now';
  }
}
