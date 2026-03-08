import 'package:flutter/material.dart';

class SOSHoldButton extends StatefulWidget {
  final VoidCallback onSOSTriggered;

  const SOSHoldButton({super.key, required this.onSOSTriggered});

  @override
  State<SOSHoldButton> createState() => _SOSHoldButtonState();
}

class _SOSHoldButtonState extends State<SOSHoldButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onSOSTriggered();
        _controller.reset();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startHolding() {
    _controller.forward();
  }

  void _stopHolding() {
    if (_controller.isAnimating) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color sosRed = const Color(0xFFE53935);

    return GestureDetector(
      onTapDown: (_) => _startHolding(),
      onTapUp: (_) => _stopHolding(),
      onTapCancel: _stopHolding,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sosRed.withOpacity(0.1),
              boxShadow: [
                BoxShadow(
                  color: sosRed.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 10,
                )
              ],
            ),
          ),
          SizedBox(
            width: 190,
            height: 190,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CircularProgressIndicator(
                  value: _controller.value,
                  strokeWidth: 8,
                  backgroundColor: sosRed.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(sosRed),
                );
              },
            ),
          ),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: sosRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.touch_app, color: Colors.white, size: 48),
                SizedBox(height: 8),
                Text(
                  'HOLD SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
