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
      duration: const Duration(seconds: 2), // 2 seconds hold
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

  @override
  Widget build(BuildContext context) {
    const Color sosRed = Color(0xFFE53935);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Glow
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sosRed.withOpacity(0.05),
            ),
          ),
          // Progress Ring
          SizedBox(
            width: 170,
            height: 170,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CircularProgressIndicator(
                  value: _controller.value,
                  strokeWidth: 6,
                  backgroundColor: sosRed.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(sosRed),
                );
              },
            ),
          ),
          // Inner Button
          CircleAvatar(
            radius: 70,
            backgroundColor: sosRed,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app, color: Colors.white, size: 40),
                Text('HOLD SOS',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
