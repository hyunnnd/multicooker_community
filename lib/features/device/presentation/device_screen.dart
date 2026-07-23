import 'package:flutter/material.dart';
import 'package:multicooker_bluetooth_sdk/multicooker_bluetooth_sdk.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/main_navigation.dart';
import '../provider/device_provider.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  final List<_SectionDraft> _sections = [_SectionDraft(100, 10)];
  MusicOption _onMusic = MusicOption.option1;
  MusicOption _offMusic = MusicOption.option1;
  LedColor _ledColor = LedColor.grapheneBlue;
  bool _sending = false;
  bool _completedDialogShown = false;

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceProvider>();
    final adapterOff =
        device.connectionEvent == ConnectionEvent.disconnectedByAdapterOff;
    if (device.status?.status != CookingStatus.completed) {
      _completedDialogShown = false;
    } else if (!_completedDialogShown) {
      _completedDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showCookingCompleted(),
      );
    }
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8FAFC),
          foregroundColor: Color(0xFF111827),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF97316),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          leading: const Padding(
            padding: EdgeInsets.only(left: 24),
            child: AppBackButton(),
          ),
          leadingWidth: 60,
          backgroundColor: const Color(0xFFF8FAFC),
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 26),
              child: Center(
                child: Text(
                  '기기 관리',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: const MainNavigationBar(currentIndex: -1),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _ConnectionStatus(device: device),
            if (device.errorMessage != null &&
                !device.reconnectingAfterLoss &&
                !adapterOff) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  device.errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (!device.isConnected) ...[
              FilledButton.icon(
                onPressed: device.isScanning
                    ? device.stopScan
                    : device.scanDevices,
                icon: device.isScanning
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(device.isScanning ? '검색 중지' : '쿠커 검색'),
              ),
              const SizedBox(height: 10),
              for (final name in device.devices)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.kitchen_outlined),
                    title: Text(name),
                    subtitle: const Text('Graphene Cooker'),
                    trailing: FilledButton(
                      onPressed: device.isBusy ? null : () => _connect(name),
                      child: const Text('연결'),
                    ),
                  ),
                ),
              if (device.reconnectingAfterLoss || adapterOff) ...[
                const SizedBox(height: 30),
                _ConnectionRecoveryGuide(
                  reconnecting: device.reconnectingAfterLoss,
                  reconnectAttempt: device.reconnectAttempt,
                ),
              ],
            ] else ...[
              _LiveStatus(status: device.status),
              const SizedBox(height: 14),
              _CookingProgramCard(
                sections: _sections,
                onChanged: () => setState(() {}),
                onAdd: _sections.length == 10
                    ? null
                    : () =>
                          setState(() => _sections.add(_SectionDraft(100, 10))),
                onRemove: (index) => setState(() => _sections.removeAt(index)),
                onStart: _sending
                    ? null
                    : () => _send(
                        () => _sendCookingStatus(device, CookingStatus.cooking),
                        '조리 프로그램을 전송했습니다.',
                      ),
                onStop: _sending
                    ? null
                    : () => _send(
                        () => _sendCookingStatus(device, CookingStatus.stopped),
                        '조리 중지 명령을 전송했습니다.',
                      ),
              ),
              const SizedBox(height: 14),
              _MusicCard(
                onMusic: _onMusic,
                offMusic: _offMusic,
                enabled: !_sending,
                onOnMusicChanged: (value) => setState(() => _onMusic = value),
                onOffMusicChanged: (value) => setState(() => _offMusic = value),
                onPreview: () => _send(
                  () => device.sendMusic(
                    onMusic: _onMusic,
                    offMusic: _offMusic,
                    preview: true,
                  ),
                  '효과음 미리듣기 명령을 전송했습니다.',
                ),
                onApply: () => _send(
                  () => device.sendMusic(
                    onMusic: _onMusic,
                    offMusic: _offMusic,
                    preview: false,
                  ),
                  '효과음 설정을 적용했습니다.',
                ),
              ),
              const SizedBox(height: 14),
              _LedCard(
                color: _ledColor,
                enabled: !_sending,
                onChanged: (value) => setState(() => _ledColor = value),
                onPreview: () => _send(
                  () => device.sendLed(ledColor: _ledColor, preview: true),
                  'LED 미리보기 명령을 전송했습니다.',
                ),
                onApply: () => _send(
                  () => device.sendLed(ledColor: _ledColor, preview: false),
                  'LED 설정을 적용했습니다.',
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _sending ? null : device.disconnect,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  backgroundColor: const Color(0xFFFEF2F2),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                ),
                icon: const Icon(Icons.link_off_rounded),
                label: const Text('연결 해제'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _connect(String name) async {
    final connected = await context.read<DeviceProvider>().connect(name);
    if (!mounted || !connected) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        icon: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Color(0xFFECFDF3),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.check_rounded,
            color: Color(0xFF16A34A),
            size: 30,
          ),
        ),
        title: const Text(
          '쿠커 연결 완료',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          '$name 기기와 연결되었습니다.',
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              minimumSize: const Size(112, 44),
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCookingCompleted() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
        title: const Text('조리 완료'),
        content: const Text(
          '쿠커 본체의 시작 버튼을 눌러 완료 상태를 해제해 주세요. '
          '쿠커가 standby 상태를 전송하면 앱도 자동으로 대기 상태로 전환됩니다.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendCookingStatus(
    DeviceProvider device,
    CookingStatus status,
  ) => device.sendCookingProgram(
    sections: _sections
        .map(
          (section) => CookingSection(
            temperature: section.temperature,
            duration: section.duration,
          ),
        )
        .toList(growable: false),
    cookingStatus: status,
    onMusic: _onMusic,
    offMusic: _offMusic,
    ledColor: _ledColor,
  );

  Future<void> _send(Future<void> Function() action, String success) async {
    setState(() => _sending = true);
    try {
      await action();
      if (mounted) {
        showAppToast(context, success, success: true);
      }
    } catch (error) {
      if (mounted) {
        showAppToast(context, '전송 실패: $error');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _ConnectionRecoveryGuide extends StatelessWidget {
  const _ConnectionRecoveryGuide({
    required this.reconnecting,
    required this.reconnectAttempt,
  });

  final bool reconnecting;
  final int reconnectAttempt;

  @override
  Widget build(BuildContext context) {
    final color = reconnecting
        ? const Color(0xFFF97316)
        : const Color(0xFFDC2626);
    final softColor = reconnecting
        ? const Color(0xFFFFF3E7)
        : const Color(0xFFFFEBEE);
    final title = reconnecting ? '블루투스 연결 끊김' : '블루투스 어댑터가 꺼져있어요';
    final description = reconnecting
        ? '쿠커와 연결을 다시 시도하고 있어요.\n잠시만 기다려주세요.'
        : '쿠커를 사용하려면\n블루투스 어댑터를 켜주세요.';
    final tip = reconnecting
        ? '쿠커를 가까이 두면 자동으로 다시 연결을 시도합니다.'
        : '설정 > 블루투스에서 어댑터를 켜면 연결할 수 있습니다.';

    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(color: softColor, shape: BoxShape.circle),
          child: Icon(
            reconnecting
                ? Icons.sync_rounded
                : Icons.bluetooth_disabled_rounded,
            color: color,
            size: 48,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF4B5563),
            fontSize: 14,
            height: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (reconnecting) ...[
          const SizedBox(height: 18),
          Text(
            '$reconnectAttempt / 3',
            style: TextStyle(
              color: color,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '최대 12초 연결 시도 · 실패 시 2초 뒤 재시도',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 34),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: softColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 20, color: color),
                  const SizedBox(width: 8),
                  Text(
                    '알려드려요',
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                tip,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: reconnecting
                      ? const Color(0xFF9A4D12)
                      : const Color(0xFFB91C1C),
                  fontSize: 13,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (reconnecting) ...[
                const SizedBox(height: 6),
                const Text(
                  '총 3회 시도 후 연결되지 않으면 직접 다시 연결할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF9A4D12),
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.device});
  final DeviceProvider device;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: device.isConnected
          ? const Color(0xFFEAF8F0)
          : const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: device.isConnected
            ? const Color(0xFF2BAE66)
            : const Color(0xFFFDBA74),
      ),
    ),
    child: Row(
      children: [
        Icon(
          device.isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
          color: device.isConnected
              ? const Color(0xFF2BAE66)
              : const Color(0xFFF97316),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.isConnected ? '쿠커 연결됨' : '쿠커를 연결해 주세요',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                device.isConnected
                    ? device.deviceName
                    : '주변 Graphene Cooker를 검색할 수 있어요',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LiveStatus extends StatelessWidget {
  const _LiveStatus({required this.status});
  final CookerState? status;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '실시간 쿠커 상태',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              _Metric('상태', _stateLabel(status?.status)),
              _Metric(
                '구간',
                status == null || status!.section == 0
                    ? '-'
                    : '${status!.section}',
              ),
              _Metric('온도', '${status?.currentTemperature ?? 0}℃'),
              _Metric(
                '시간',
                _time(
                  ((status?.currentMinute ?? 0) * 60) +
                      (status?.currentSecond ?? 0),
                ),
              ),
              _Metric('LED', status?.ledColor.name ?? '-'),
              _Metric(
                'ON/OFF 음',
                '${status?.onMusic.name ?? '-'} / ${status?.offMusic.name ?? '-'}',
              ),
            ],
          ),
        ],
      ),
    ),
  );

  static String _time(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  static String _stateLabel(CookingStatus? state) => switch (state) {
    CookingStatus.standby => '대기',
    CookingStatus.cooking => '조리 중',
    CookingStatus.completed => '완료',
    CookingStatus.stopped => '중지',
    CookingStatus.error => '오류',
    null => '-',
  };
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 130,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _CookingProgramCard extends StatelessWidget {
  const _CookingProgramCard({
    required this.sections,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
    required this.onStart,
    required this.onStop,
  });

  final List<_SectionDraft> sections;
  final VoidCallback onChanged;
  final VoidCallback? onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback? onStart;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: Color(0xFFF97316),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '온도·시간별 조리 설정',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.outlined(
                tooltip: '조리 구간 추가',
                onPressed: onAdd,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFF97316),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          for (var index = 0; index < sections.length; index++) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${index + 1}구간',
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _SettingValue(label: '${sections[index].temperature}℃'),
                      const SizedBox(width: 6),
                      _SettingValue(label: '${sections[index].duration}분'),
                      if (sections.length > 1) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: '구간 삭제',
                          onPressed: () => onRemove(index),
                          color: const Color(0xFFDC2626),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ],
                  ),
                  _ProgramSlider(
                    title: '온도',
                    valueLabel: '${sections[index].temperature}℃',
                    min: 40,
                    max: 200,
                    divisions: 32,
                    value: sections[index].temperature.toDouble(),
                    onChanged: (value) {
                      sections[index].temperature = value.round();
                      onChanged();
                    },
                  ),
                  _ProgramSlider(
                    title: '시간',
                    valueLabel: '${sections[index].duration}분',
                    min: 1,
                    max: 90,
                    divisions: 89,
                    value: sections[index].duration.toDouble(),
                    onChanged: (value) {
                      sections[index].duration = value.round();
                      onChanged();
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onStop,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                  ),
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('조리 중지'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('설정 전송·시작'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SettingValue extends StatelessWidget {
  const _SettingValue({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEDD5),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFFF97316),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _ProgramSlider extends StatelessWidget {
  const _ProgramSlider({
    required this.title,
    required this.valueLabel,
    required this.min,
    required this.max,
    required this.divisions,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String valueLabel;
  final double min;
  final double max;
  final int divisions;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            valueLabel,
            style: const TextStyle(
              color: Color(0xFFF97316),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: const Color(0xFFF97316),
          inactiveTrackColor: const Color(0xFFFED7AA),
          thumbColor: const Color(0xFFF97316),
          overlayColor: const Color(0x33F97316),
        ),
        child: Slider(
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          value: value,
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

class _MusicCard extends StatelessWidget {
  const _MusicCard({
    required this.onMusic,
    required this.offMusic,
    required this.enabled,
    required this.onOnMusicChanged,
    required this.onOffMusicChanged,
    required this.onPreview,
    required this.onApply,
  });
  final MusicOption onMusic;
  final MusicOption offMusic;
  final bool enabled;
  final ValueChanged<MusicOption> onOnMusicChanged;
  final ValueChanged<MusicOption> onOffMusicChanged;
  final VoidCallback onPreview;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('효과음 설정', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<MusicOption>(
                  initialValue: onMusic,
                  decoration: const InputDecoration(labelText: '시작 효과음'),
                  items: _musicItems,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  elevation: 4,
                  iconEnabledColor: const Color(0xFF6B7280),
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  onChanged: enabled
                      ? (value) => onOnMusicChanged(value!)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<MusicOption>(
                  initialValue: offMusic,
                  decoration: const InputDecoration(labelText: '종료 효과음'),
                  items: _musicItems,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  elevation: 4,
                  iconEnabledColor: const Color(0xFF6B7280),
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  onChanged: enabled
                      ? (value) => onOffMusicChanged(value!)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _PreviewApplyButtons(
            enabled: enabled,
            onPreview: onPreview,
            onApply: onApply,
          ),
        ],
      ),
    ),
  );

  static const _musicItems = [
    DropdownMenuItem(value: MusicOption.option1, child: Text('효과음 1')),
    DropdownMenuItem(value: MusicOption.option2, child: Text('효과음 2')),
  ];
}

class _LedCard extends StatelessWidget {
  const _LedCard({
    required this.color,
    required this.enabled,
    required this.onChanged,
    required this.onPreview,
    required this.onApply,
  });
  final LedColor color;
  final bool enabled;
  final ValueChanged<LedColor> onChanged;
  final VoidCallback onPreview;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('LED 설정', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          DropdownButtonFormField<LedColor>(
            initialValue: color,
            decoration: const InputDecoration(labelText: 'LED 색상'),
            items: [
              for (final option in LedColor.values)
                DropdownMenuItem(value: option, child: Text(_ledLabel(option))),
            ],
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(20),
            elevation: 4,
            iconEnabledColor: const Color(0xFF6B7280),
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            onChanged: enabled ? (value) => onChanged(value!) : null,
          ),
          const SizedBox(height: 10),
          _PreviewApplyButtons(
            enabled: enabled,
            onPreview: onPreview,
            onApply: onApply,
          ),
        ],
      ),
    ),
  );

  static String _ledLabel(LedColor color) => switch (color) {
    LedColor.aurora => 'Aurora',
    LedColor.grapheneBlue => 'Graphene Blue',
    LedColor.green => 'Green',
    LedColor.yellow => 'Yellow',
    LedColor.purple => 'Purple',
    LedColor.white => 'White',
  };
}

class _PreviewApplyButtons extends StatelessWidget {
  const _PreviewApplyButtons({
    required this.enabled,
    required this.onPreview,
    required this.onApply,
  });
  final bool enabled;
  final VoidCallback onPreview;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: enabled ? onPreview : null,
          child: const Text('미리보기'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: FilledButton(
          onPressed: enabled ? onApply : null,
          child: const Text('적용'),
        ),
      ),
    ],
  );
}

class _SectionDraft {
  _SectionDraft(this.temperature, this.duration);
  int temperature;
  int duration;
}
