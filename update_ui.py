import os

file_path = 'e:/usafe_front_end-Dev-Branch/lib/src/pages/home_screen.dart'
chunk_path = 'e:/usafe_front_end-Dev-Branch/ui_chunk.dart'
replacement_path = 'e:/usafe_front_end-Dev-Branch/ui_replacement.txt'

# Load the main file
with open(file_path, 'r', encoding='utf-8') as f:
    text = f.read()

# Replace the first chunk (SOSDashboard UI methods)
with open(chunk_path, 'r', encoding='utf-8') as f:
    target1 = f.read()

with open(replacement_path, 'r', encoding='utf-8') as f:
    replacement1 = f.read()

if target1 in text:
    text = text.replace(target1, replacement1)
    print("Chunk 1 (SOSDashboard methods) replaced successfully.")
else:
    print("ERROR: Target 1 not found in home_screen.dart.")

# Replace the second chunk (SOSHoldInteraction class)
old_hold_class = """class SOSHoldInteraction extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onComplete;

  const SOSHoldInteraction({
    required this.accentColor,
    required this.onComplete,
    super.key,
  });

  @override
  State<SOSHoldInteraction> createState() => _SOSHoldInteractionState();
}

class _SOSHoldInteractionState extends State<SOSHoldInteraction>
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
        widget.onComplete();
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
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.accentColor.withOpacity(0.05),
            ),
          ),
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.accentColor.withOpacity(0.15),
                width: 2,
              ),
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withOpacity(0.1),
                  blurRadius: 40,
                  spreadRadius: 10,
                )
              ],
            ),
          ),
          SizedBox(
            width: 240,
            height: 240,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CircularProgressIndicator(
                  value: _controller.value,
                  strokeWidth: 8,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                  strokeCap: StrokeCap.round,
                );
              },
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.fingerprint_rounded,
                    color: widget.accentColor, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'SOS',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Press & Hold',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
"""

with open('e:/usafe_front_end-Dev-Branch/new_hold_chunk.txt', 'r', encoding='utf-8') as f:
    replacement2 = f.read()

if old_hold_class in text:
    text = text.replace(old_hold_class, replacement2)
    print("Chunk 2 (SOSHoldInteraction) replaced successfully.")
else:
    print("ERROR: Target 2 not found in home_screen.dart.")

# Write back to home_screen.dart
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(text)

print("File write completed.")
