// ToastNotification - Non-blocking notification widget matching AudioFileView Python app
import 'dart:async';
import 'package:flutter/material.dart';

class ToastNotification extends StatefulWidget {
  const ToastNotification({super.key});

  @override
  State<ToastNotification> createState() => ToastNotificationState();
}

class ToastNotificationState extends State<ToastNotification>
    with SingleTickerProviderStateMixin {
  bool _isVisible = false;
  String _message = '';
  String _detail = '';
  bool _showProgress = false;
  double _progress = 0;
  Timer? _autoHideTimer;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void show({
    required String message,
    String detail = '',
    bool showProgress = false,
    bool autoHide = true,
    Duration autoHideDuration = const Duration(seconds: 3),
  }) {
    _autoHideTimer?.cancel();

    setState(() {
      _message = message;
      _detail = detail;
      _showProgress = showProgress;
      _progress = 0;
      _isVisible = true;
    });

    _animationController.forward();

    if (autoHide && !showProgress) {
      _autoHideTimer = Timer(autoHideDuration, hide);
    }
  }

  void updateProgress({
    required int current,
    required int total,
    String? detail,
  }) {
    setState(() {
      _progress = total > 0 ? current / total : 0;
      if (detail != null) _detail = detail;
    });
  }

  void hide() {
    _autoHideTimer?.cancel();
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() => _isVisible = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2d2d2d),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_showProgress)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Color(0xFF4a9eff)),
                        ),
                      )
                    else
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color(0xFF4a9eff),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      color: const Color(0xFF888888),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: hide,
                    ),
                  ],
                ),
                if (_showProgress) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFF1e1e1e),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF4a9eff)),
                    ),
                  ),
                ],
                if (_detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _detail,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
