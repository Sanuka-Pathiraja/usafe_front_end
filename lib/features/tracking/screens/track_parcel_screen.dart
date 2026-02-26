import 'package:flutter/material.dart';
import '../tracking_service.dart';

class TrackParcelScreen extends StatefulWidget {
  const TrackParcelScreen({super.key});

  @override
  State<TrackParcelScreen> createState() => _TrackParcelScreenState();
}

class _TrackParcelScreenState extends State<TrackParcelScreen> {
  final _controller = TextEditingController();
  final _service = TrackingService();
  String? _status;
  bool _loading = false;

  Future<void> _track() async {
    setState(() => _loading = true);
    final status = await _service.getStatus(_controller.text.trim());
    if (!mounted) return;
    setState(() {
      _status = status;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track Parcel')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Tracking ID'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _track,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Track'),
              ),
            ),
            if (_status != null) ...[
              const SizedBox(height: 24),
              Text('Status: $_status'),
            ]
          ],
        ),
      ),
    );
  }
}
