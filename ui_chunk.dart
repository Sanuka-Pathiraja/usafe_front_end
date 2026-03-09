  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: AppColors.background,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusPill(),
                // ── Settings button ──────────────────────────────────────
                IconButton(
                  icon: const Icon(Icons.settings_outlined,
                      color: AppColors.textSecondary),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
                  tooltip: 'Settings',
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (isSOSActive) _buildSOSHeader(),
            if (!isSOSActive)
              const Text(
                'Hold button in emergency',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
            const Spacer(),
            Center(
              child: isSOSActive ? _buildSOSActiveView() : _buildHoldButton(),
            ),
            const Spacer(),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Your Area: Safe',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSHeader() {
    return Column(
      children: [
        const Text(
          'EMERGENCY\nACTIVATED',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.alert,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.alertBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Dispatching alerts...',
            style:
                TextStyle(color: AppColors.alert, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildHoldButton() {
    return SOSHoldInteraction(
      accentColor: AppColors.alert,
      onComplete: () {
        setState(() => isSOSActive = true);
        _startSosCountdown();
      },
    );
  }

  Widget _buildSOSActiveView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 260,
              height: 260,
              child: CircularProgressIndicator(
                value: _remaining.inSeconds / _sosDuration.inSeconds,
                strokeWidth: 12,
                backgroundColor: AppColors.surfaceElevated,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.alert),
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDuration(_remaining),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                  ),
                ),
                const Text(
                  'Auto-dispatch in',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 48),
        _buildActionButton(
          label: 'SEND HELP NOW',
          bg: AppColors.alert,
          text: Colors.white,
          icon: Icons.flash_on_rounded,
          onTap: _openEmergencyProcess,
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          label: 'CANCEL SOS',
          bg: AppColors.surfaceElevated,
          text: AppColors.textPrimary,
          icon: Icons.close_rounded,
          onTap: () {
            _resetSosCountdown();
            setState(() => isSOSActive = false);
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color bg,
    required Color text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: text,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

