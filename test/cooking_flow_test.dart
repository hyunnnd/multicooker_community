import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphene_multicooker_app/features/cooking/data/models/cooking_session_state.dart';
import 'package:graphene_multicooker_app/features/cooking/provider/cooking_session_provider.dart';
import 'package:graphene_multicooker_app/features/device/data/ble/cooker_service.dart';
import 'package:graphene_multicooker_app/features/device/data/device_repository.dart';
import 'package:graphene_multicooker_app/features/device/provider/device_provider.dart';
import 'package:graphene_multicooker_app/features/recipe/data/mock_recipe_repository.dart';
import 'package:graphene_multicooker_app/features/recipe/data/models/recipe_compatibility_type.dart';
import 'package:multicooker_bluetooth_sdk/multicooker_bluetooth_sdk.dart';

void main() {
  test('레시피 7개와 호환 타입을 제공한다', () async {
    final recipes = await MockRecipeRepository().getRecipes();

    expect(recipes, hasLength(7));
    expect(
      recipes.map((recipe) => recipe.compatibilityType),
      containsAll([
        RecipeCompatibilityType.fullAuto,
        RecipeCompatibilityType.guidedCook,
        RecipeCompatibilityType.complexGuidedCook,
        RecipeCompatibilityType.partialCook,
      ]),
    );
  });

  test('Guided Cook은 사용자 확인을 요구하고 Full Auto는 바로 진행한다', () async {
    final recipes = await MockRecipeRepository().getRecipes();
    final service = _FakeCookerService();
    final session = CookingSessionProvider(service);

    session.prepareRecipe(
      recipes.firstWhere((recipe) => recipe.id == 'shrimp'),
    );
    await session.startCooking();
    session.moveToNextStep();
    expect(session.needsUserAction, isTrue);

    session.prepareRecipe(recipes.firstWhere((recipe) => recipe.id == 'rice'));
    await session.startCooking();
    session.moveToNextStep();
    expect(session.needsUserAction, isFalse);
    expect(session.state.currentInstructionIndex, 1);

    session.dispose();
    service.dispose();
  });

  test('공식 레시피 설정값을 SDK 조리 명령으로 전송한다', () async {
    final recipes = await MockRecipeRepository().getRecipes();
    final expected = {
      'rice': [(250, 35)],
      'vegetables': [(250, 25)],
      'egg': [(200, 20)],
      'pork': [(200, 18)],
    };

    for (final entry in expected.entries) {
      final service = _FakeCookerService();
      final session = CookingSessionProvider(service);
      session.prepareRecipe(
        recipes.firstWhere((recipe) => recipe.id == entry.key),
      );
      await session.startCooking();

      final command = service.lastCommand!;
      final packet = PacketEncoder.encode(command);
      expect(command.status, CookingStatus.cooking);
      expect(command.sections, hasLength(entry.value.length));
      for (var index = 0; index < entry.value.length; index++) {
        expect(packet[2 + (index * 2)], entry.value[index].$1);
        expect(packet[3 + (index * 2)], entry.value[index].$2);
      }

      session.dispose();
      service.dispose();
    }
  });

  test('여러 조리 스텝을 하나의 SDK 명령으로 전송한다', () async {
    final recipes = await MockRecipeRepository().getRecipes();
    final service = _FakeCookerService();
    final session = CookingSessionProvider(service)
      ..prepareRecipe(recipes.firstWhere((recipe) => recipe.id == 'dakgalbi'));

    await session.startCooking();

    expect(service.commands, hasLength(1));
    expect(service.lastCommand?.sections, hasLength(4));
    expect(
      service.lastCommand?.sections.map(
        (section) => (section.temperature, section.duration),
      ),
      [(180, 3), (180, 8), (170, 8), (200, 3)],
    );

    session.dispose();
    service.dispose();
  });

  test('목표 온도 도달 시 본 조리 프로그램을 자동 전송한다', () async {
    final recipes = await MockRecipeRepository().getRecipes();
    final egg = recipes.firstWhere((recipe) => recipe.id == 'egg');
    final service = _FakeCookerService();
    final session = CookingSessionProvider(service);

    await session.startPreheating(recipe: egg, targetTemperature: 50);
    expect(service.lastCommand?.sections, hasLength(1));
    expect(service.lastCommand?.sections.single.temperature, 50);
    expect(service.lastCommand?.sections.single.duration, 30);
    expect(session.isPreheating, isTrue);

    service.emitState(CookingStatus.cooking, temperature: 50);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    expect(session.isCooking, isTrue);
    expect(service.commands.map((command) => command.status), [
      CookingStatus.cooking,
      CookingStatus.stopped,
      CookingStatus.cooking,
    ]);
    expect(service.lastCommand?.sections, hasLength(1));
    expect(service.lastCommand?.sections.single.temperature, 200);
    expect(service.lastCommand?.sections.single.duration, 20);

    session.dispose();
    service.dispose();
  });

  test('반자동 모드는 목표 온도 도달 후 사용자 입력을 기다린다', () async {
    final recipes = await MockRecipeRepository().getRecipes();
    final egg = recipes.firstWhere((recipe) => recipe.id == 'egg');
    final service = _FakeCookerService();
    final session = CookingSessionProvider(service);

    await session.startPreheating(
      recipe: egg,
      targetTemperature: 50,
      controlMode: CookingControlMode.semiAutomatic,
    );
    service.emitState(CookingStatus.cooking, temperature: 50);
    await Future<void>.delayed(Duration.zero);

    expect(session.isPreheatReady, isTrue);
    expect(service.lastCommand?.status, CookingStatus.stopped);
    expect(service.lastCommand?.sections.single.duration, 30);

    await session.startRecipeStep(
      instructionIndex: 0,
      temperature: 200,
      duration: 20,
    );
    expect(session.isCooking, isTrue);
    expect(service.lastCommand?.sections.single.duration, 20);

    session.dispose();
    service.dispose();
  });

  test('단일 단계 완료는 전체 완료 대신 다음 단계 준비로 이동한다', () async {
    final recipes = await MockRecipeRepository().getRecipes();
    final shrimp = recipes.firstWhere((recipe) => recipe.id == 'shrimp');
    final service = _FakeCookerService();
    final session = CookingSessionProvider(service)..prepareRecipe(shrimp);

    await session.startRecipeStep(
      instructionIndex: 2,
      temperature: 170,
      duration: 5,
    );
    service.emitState(CookingStatus.completed);
    await Future<void>.delayed(Duration.zero);

    expect(session.isCompleted, isFalse);
    expect(session.state.currentInstructionIndex, 3);
    expect(session.state.currentStatusText, '다음 단계 준비');

    session.dispose();
    service.dispose();
  });

  test('밥 가열 완료 뒤에는 5분 뜸 단계로 이동한다', () async {
    final recipes = await MockRecipeRepository().getRecipes();
    final service = _FakeCookerService();
    final session = CookingSessionProvider(service);
    session.prepareRecipe(recipes.firstWhere((recipe) => recipe.id == 'rice'));
    await session.startCooking();

    service.emitState(CookingStatus.completed);
    await Future<void>.delayed(Duration.zero);

    expect(session.isCompleted, isFalse);
    expect(session.state.currentInstructionIndex, 1);
    expect(session.state.remainingSeconds, 5 * 60);

    session.dispose();
    service.dispose();
  });

  test('쿠커 명령 전송 전 온도와 시간 범위를 검증한다', () async {
    final service = _FakeCookerService();
    final provider = DeviceProvider(DeviceRepository(Dio()), service);

    await expectLater(
      provider.sendCookingProgram(
        sections: const [CookingSection(temperature: 39, duration: 10)],
        cookingStatus: CookingStatus.cooking,
        onMusic: MusicOption.option1,
        offMusic: MusicOption.option1,
        ledColor: LedColor.grapheneBlue,
      ),
      throwsArgumentError,
    );

    await provider.sendCookingProgram(
      sections: const [CookingSection(temperature: 250, duration: 35)],
      cookingStatus: CookingStatus.cooking,
      onMusic: MusicOption.option1,
      offMusic: MusicOption.option1,
      ledColor: LedColor.grapheneBlue,
    );
    expect(PacketEncoder.encode(service.lastCommand!)[2], 250);

    for (final color in LedColor.values) {
      await provider.sendLed(ledColor: color, preview: false);
      final command = service.lastCommand!;
      final packet = PacketEncoder.encode(command);
      expect(command.mode, CookerMode.led);
      expect(command.ledColor, color);
      expect(packet[27], color.value); // Byte 28: SDK 색상값
      expect(packet[28], 0x02); // Byte 29: 적용 Click
      expect(packet[29], 0x01); // Byte 30: 적용 Click
    }

    await provider.sendMusic(
      onMusic: MusicOption.option2,
      offMusic: MusicOption.option1,
      preview: false,
    );
    expect(service.lastCommand?.mode, CookerMode.music);
    expect(service.lastCommand?.musicPreviewAction, MusicPreviewAction.apply);
    expect(service.lastCommand?.musicApplyAction, MusicApplyAction.apply);
    final musicPacket = PacketEncoder.encode(service.lastCommand!);
    expect(musicPacket[25], 0x02); // Byte 26: 적용 Click
    expect(musicPacket[26], 0x01); // Byte 27: 적용 Click

    provider.dispose();
  });

  test('iOS Bluetooth 초기화가 끝날 때까지 스캔을 재시도한다', () async {
    final service = _FakeCookerService()..initializationFailures = 2;
    final provider = DeviceProvider(DeviceRepository(Dio()), service);

    await provider.scanDevices();

    expect(service.scanAttempts, 3);
    expect(provider.devices, ['Graphene Multi-Cooker 1']);
    expect(provider.errorMessage, isNull);

    provider.dispose();
  });
}

class _FakeCookerService implements CookerService {
  final _states = StreamController<CookerState>.broadcast();
  final _connections = StreamController<ConnectionEvent>.broadcast();
  final _scanResults = StreamController<List<String>>.broadcast(sync: true);
  bool _connected = false;
  CookerCommand? lastCommand;
  final commands = <CookerCommand>[];
  int initializationFailures = 0;
  int scanAttempts = 0;

  @override
  Stream<CookerState> get states => _states.stream;

  @override
  Stream<ConnectionEvent> get connections => _connections.stream;

  @override
  Stream<List<String>> get scanResults => _scanResults.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<List<String>> scanDevices() async {
    await startScan();
    return ['Graphene Multi-Cooker 1'];
  }

  @override
  Future<void> startScan() async {
    scanAttempts++;
    if (initializationFailures > 0) {
      initializationFailures--;
      throw Exception('CBManagerStateUnknown');
    }
    _scanResults.add(['Graphene Multi-Cooker 1']);
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(String deviceId) async {
    _connected = true;
    _connections.add(ConnectionEvent.connected);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _connections.add(ConnectionEvent.disconnectedByUser);
  }

  @override
  Future<void> send(CookerCommand command) async {
    lastCommand = command;
    commands.add(command);
  }

  void emitState(CookingStatus status, {int temperature = 0}) => _states.add(
    CookerState(
      status: status,
      section: 1,
      currentTemperature: temperature,
      currentMinute: 0,
      currentSecond: 0,
      ledColor: LedColor.aurora,
      onMusic: MusicOption.option1,
      offMusic: MusicOption.option1,
    ),
  );

  @override
  void dispose() {
    _states.close();
    _connections.close();
    _scanResults.close();
  }
}
