import 'package:flutter/material.dart';
import 'package:multicooker_bluetooth_sdk/multicooker_bluetooth_sdk.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/main_navigation.dart';
import '../../../core/widgets/main_route_back_scope.dart';
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
    if (device.status?.status != CookingStatus.completed) {
      _completedDialogShown = false;
    } else if (!_completedDialogShown) {
      _completedDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showCookingCompleted(),
      );
    }
    return MainRouteBackScope(
      child: Scaffold(
        appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('쿠커'),
      ),
        bottomNavigationBar: const MainNavigationBar(currentIndex: 2),
        body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ConnectionStatus(device: device),
          if (device.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              device.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 14),
          if (!device.isConnected) ...[
            FilledButton.icon(
              onPressed: device.isScanning ? null : device.scanDevices,
              icon: device.isScanning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth_searching),
              label: Text(device.isScanning ? '8초간 검색 중...' : '쿠커 검색'),
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
          ] else ...[
            _LiveStatus(status: device.status),
            const SizedBox(height: 14),
            _CookingProgramCard(
              sections: _sections,
              onChanged: () => setState(() {}),
              onAdd: _sections.length == 10
                  ? null
                  : () => setState(() => _sections.add(_SectionDraft(100, 10))),
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
              icon: const Icon(Icons.link_off),
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
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
        title: const Text('쿠커 연결 완료'),
        content: Text('$name 기기와 연결되었습니다.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('전송 실패: $error')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
          : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: device.isConnected
            ? const Color(0xFF2BAE66)
            : const Color(0xFFE5E7EB),
      ),
    ),
    child: Row(
      children: [
        Icon(
          device.isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
          color: device.isConnected ? const Color(0xFF2BAE66) : Colors.grey,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.isConnected ? '연결됨' : '연결된 쿠커 없음',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(device.deviceName),
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
                child: Text(
                  '온도·시간별 조리 설정',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: '조리 구간 추가',
                onPressed: onAdd,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          for (var index = 0; index < sections.length; index++) ...[
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${index + 1}구간 · ${sections[index].temperature}℃ · ${sections[index].duration}분',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (sections.length > 1)
                  IconButton(
                    tooltip: '구간 삭제',
                    onPressed: () => onRemove(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            Slider(
              min: 40,
              max: 200,
              divisions: 32,
              label: '${sections[index].temperature}℃',
              value: sections[index].temperature.toDouble(),
              onChanged: (value) {
                sections[index].temperature = value.round();
                onChanged();
              },
            ),
            Slider(
              min: 1,
              max: 90,
              divisions: 89,
              label: '${sections[index].duration}분',
              value: sections[index].duration.toDouble(),
              onChanged: (value) {
                sections[index].duration = value.round();
                onChanged();
              },
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop),
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
