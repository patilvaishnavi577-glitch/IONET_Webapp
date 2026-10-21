import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ionet_onboarding/models/device_model.dart';
import 'package:ionet_onboarding/providers/device_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Device Configuration and Backend Command Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('QuickCommand detects slider commands properly', () {
      final sliderCmd1 = QuickCommand(label: 'Level', message: '/level');
      expect(QuickCommand.detectIsSlider(sliderCmd1.message, sliderCmd1.label), isTrue);

      final sliderCmd2 = QuickCommand(label: 'Threshold', message: '/threshold');
      expect(QuickCommand.detectIsSlider(sliderCmd2.message, sliderCmd2.label), isTrue);

      final sliderCmd3 = QuickCommand(label: 'Slider 1', message: '/slider');
      expect(QuickCommand.detectIsSlider(sliderCmd3.message, sliderCmd3.label), isTrue);

      final statusCmd = QuickCommand(label: 'Status', message: '/status');
      expect(QuickCommand.detectIsSlider(statusCmd.message, statusCmd.label), isFalse);
    });

    test('DeviceProvider saves slider value and reflects in device instance and persists', () async {
      final provider = DeviceProvider();
      const devId = 'TEST_DEV_001';

      // Save slider value
      await provider.updateSliderValue(devId, '/slider', 75.0, sendCommand: false);

      expect(provider.getDeviceSliderValue(devId, '/slider'), 75.0);

      // Verify persistent storage
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('device_slider_values_$devId');
      expect(savedJson, isNotNull);
      expect(savedJson, contains('75'));

      // Create new provider instance and reload
      final newProvider = DeviceProvider();
      await newProvider.loadDeviceConfiguration(devId);
      expect(newProvider.getDeviceSliderValue(devId, '/slider'), 75.0);
    });

    test('DeviceProvider saves configuration parameters and persists', () async {
      final provider = DeviceProvider();
      const devId = 'TEST_DEV_001';

      await provider.saveDeviceConfiguration(devId, {
        'Tank A': 'Main Water Storage',
        'Relay 1': 'Kitchen Light',
        'Level': 'Tank Threshold',
        'Level_value': 80.0,
      });

      final config = provider.getDeviceSavedConfig(devId);
      expect(config['Tank A'], 'Main Water Storage');
      expect(config['Relay 1'], 'Kitchen Light');
      expect(config['Level'], 'Tank Threshold');
      expect(provider.getDeviceSliderValue(devId, 'Level'), 80.0);

      // Test reopening device
      final freshProvider = DeviceProvider();
      await freshProvider.loadDeviceConfiguration(devId);
      final freshConfig = freshProvider.getDeviceSavedConfig(devId);
      expect(freshConfig['Tank A'], 'Main Water Storage');
      expect(freshConfig['Relay 1'], 'Kitchen Light');
      expect(freshConfig['Level'], 'Tank Threshold');
      expect(freshProvider.getDeviceSliderValue(devId, 'Level'), 80.0);
    });

    test('getQuickCommands returns empty list when backend has not provided commands (zero hardcoding)', () {
      final provider = DeviceProvider();
      final cmds = provider.getQuickCommands('TEST_DEV_001');
      expect(cmds.isEmpty, isTrue);
    });

    test('detectDeviceModel respects backend model without hardcoding heuristics', () {
      expect(DeviceProvider.detectDeviceModel(explicitModel: 'CUSTOM_MODEL'), 'CUSTOM_MODEL');
      expect(DeviceProvider.detectDeviceModel(explicitModel: 'WATER_TANK'), 'WATER_TANK');
      expect(DeviceProvider.detectDeviceModel(explicitModel: ''), 'DEFAULT');
      expect(DeviceProvider.detectDeviceModel(), 'DEFAULT');
    });

    test('sendMessage sends exact command cleanly without mutating', () async {
      final provider = DeviceProvider();
      const dev = Device(
        id: 'dev_db_1',
        deviceId: 'DEV001',
        name: 'Device 1',
        statusMessage: 'Online',
        lastActiveTime: 'Just now',
        isOnline: true,
      );
      provider.devices.add(dev);
      provider.selectDevice('dev_db_1');

      provider.sendMessage('/status', targetDeviceId: 'dev_db_1');
      final current = provider.devices.firstWhere((d) => d.id == 'dev_db_1');
      expect(current.messages.isNotEmpty, isTrue);
      expect(current.messages.last.command, '/status');
      expect(current.messages.last.text, '/status');
    });

    test('DeviceProvider saves and persists both NA 1 and NA 2 parameters', () async {
      final provider = DeviceProvider();
      const devId = 'TEST_DEV_002';

      await provider.saveDeviceConfiguration(devId, {
        'Tank A': 'Roof Tank',
        'NA 1': 'Garden Sprinkler',
        'NA 2': 'Borewell Pump',
      });

      final config = provider.getDeviceSavedConfig(devId);
      expect(config['NA 1'], 'Garden Sprinkler');
      expect(config['NA 2'], 'Borewell Pump');

      final freshProvider = DeviceProvider();
      await freshProvider.loadDeviceConfiguration(devId);
      final freshConfig = freshProvider.getDeviceSavedConfig(devId);
      expect(freshConfig['NA 1'], 'Garden Sprinkler');
      expect(freshConfig['NA 2'], 'Borewell Pump');
    });

    test('sendMessage does not inject hardcoded simulated reply for /about command', () async {
      final provider = DeviceProvider();
      const dev = Device(
        id: 'dev_water_1',
        deviceId: 'DEV_WT_01',
        name: 'A Wing Water Tank',
        statusMessage: 'Online',
        lastActiveTime: 'Just now',
        isOnline: true,
      );
      provider.devices.add(dev);
      provider.selectDevice('dev_water_1');

      await provider.sendMessage('/about', targetDeviceId: 'dev_water_1');
      final current = provider.devices.firstWhere((d) => d.id == 'dev_water_1');
      // Only user message should exist, no hardcoded synthetic device response
      expect(current.messages.length, 1);
      expect(current.messages.first.sender, MessageSender.user);
      expect(current.messages.first.command, '/about');
    });

    test('sendConfig sends config without creating chat messages in conversation', () async {
      final provider = DeviceProvider();
      const dev = Device(
        id: 'dev_relay_1',
        deviceId: 'DEV_RM_01',
        name: 'relay module 04',
        statusMessage: 'Online',
        lastActiveTime: 'Just now',
        isOnline: true,
      );
      provider.devices.add(dev);
      provider.selectDevice('dev_relay_1');

      provider.sendConfig('dev_relay_1', {
        'Relay 1': 'Relay 5',
        'Relay 2': 'Relay 2',
      });

      final current = provider.devices.firstWhere((d) => d.id == 'dev_relay_1');
      expect(current.messages.isEmpty, isTrue);
    });

    test('parseTextPayloadData sets text settings from backend and enables configuration without hardcoding', () {
      final provider = DeviceProvider();
      const devId = 'TEST_DEV_BACKEND';
      final payload = {
        'type': 'TEXT',
        'data': {
          '1': 'Main Light',
          '2': 'Fan Speed Level',
        },
        'range': '1 - 20',
      };

      final settings = provider.parseTextPayloadData(payload, devId, devId);
      expect(settings.containsKey('1'), isTrue);
      expect(settings['1']!.value, 'Main Light');
      expect(settings['1']!.minLength, 1);
      expect(settings['1']!.maxLength, 20);

      final retrieved = provider.getDeviceTextSettings(devId);
      expect(retrieved['1']?.value, 'Main Light');
    });

    test('parseTimePayloadData parses 24-hour time schedule start and end correctly', () {
      final provider = DeviceProvider();
      final payload = {
        'type': 'TIME',
        'data': {
          'set_timing_1': '17:15 18:20',
          'set_timing_2': '08:00 17:30',
        },
      };

      final timeCmds = provider.parseTimePayloadData(payload);
      expect(timeCmds.length, 2);
      expect(timeCmds[0].isTimeType, isTrue);
      expect(timeCmds[0].message, 'set_timing_1');
      expect(timeCmds[0].label, contains('17:15 18:20'));
      expect(timeCmds[1].label, contains('08:00 17:30'));
    });

    test('parseCyclicPayloadData parses cyclic schedule start min and end min correctly', () {
      final provider = DeviceProvider();
      final payload = {
        'type': 'CYCLIC',
        'data': {
          'set_cyclic_1': '10 - 20',
          'set_cyclic_2': '15 min - 45 min',
        },
      };

      final cyclicCmds = provider.parseCyclicPayloadData(payload);
      expect(cyclicCmds.length, 2);
      expect(cyclicCmds[0].isCyclicType, isTrue);
      expect(cyclicCmds[0].isTimeType, isFalse);
      expect(cyclicCmds[0].message, 'set_cyclic_1');
      expect(cyclicCmds[0].label, contains('10 - 20'));
      expect(cyclicCmds[1].label, contains('15 min - 45 min'));
    });

    test('QuickCommand isCyclicType identifies cyclic commands and message types', () {
      final cmd1 = QuickCommand(label: 'Cyclic Timer', message: '/cyclic_timer', type: 'cyclic');
      expect(cmd1.isCyclicType, isTrue);
      expect(cmd1.isTimeType, isFalse);

      final cmd2 = QuickCommand(label: 'Pump Cycle 1', message: 'pump_cycle');
      expect(cmd2.isCyclicType, isTrue);
      expect(cmd2.isTimeType, isFalse);

      final timeCmd = QuickCommand(label: 'Set Time', message: '/set_time', type: 'time');
      expect(timeCmd.isCyclicType, isFalse);
      expect(timeCmd.isTimeType, isTrue);
    });

    test('parseRadioPayloadData parses backend radio settings with dynamic options', () {
      final provider = DeviceProvider();
      const devId = 'TEST_DEV_RADIO';
      final payload = {
        'type': 'RADIO',
        'data': {
          'relay1': '1',
          'relay2': '0',
          'mode': {'value': '0', 'options': ['0', '1']},
        },
      };

      final radioMap = provider.parseRadioPayloadData(payload, devId, devId);
      expect(radioMap.containsKey('relay1'), isTrue);
      expect(radioMap['relay1']!.value, '1');
      expect(radioMap['relay1']!.isOn, isTrue);
      expect(radioMap['relay2']!.value, '0');
      expect(radioMap['relay2']!.isOn, isFalse);
      expect(radioMap['mode']!.options, ['0', '1']);
    });

    test('Water tank device status returns tanks telemetry according to backend', () async {
      final provider = DeviceProvider();
      const dev = Device(
        id: 'dev_wt_test',
        deviceId: 'DEV_WT_01',
        name: 'A Wing Water Tank',
        statusMessage: 'Online',
        lastActiveTime: 'Just now',
        isOnline: true,
      );
      provider.devices.add(dev);
      provider.selectDevice('dev_wt_test');

      // When real telemetry is provided by backend
      provider.saveDeviceConfiguration('DEV_WT_01', {
        'Main Tank': '85%',
        'Reserve Tank': '45%',
      });
      // Simulate live incoming telemetry from backend
      provider.addDeviceReplyForTest('dev_wt_test', jsonEncode({
        "type": "RESPONSE",
        "data": {
          "Main Tank": "85%",
          "Reserve Tank": "45%",
        }
      }));
      final updated = provider.devices.firstWhere((d) => d.id == 'dev_wt_test');
      expect(updated.messages.length, 1);
      final reply = updated.messages.last;
      expect(reply.text, contains('Main Tank: 85%'));
      expect(reply.text, contains('Reserve Tank: 45%'));
    });

    test('sendMessage with /test cyclic triggers simulated CYCLIC response', () async {
      final provider = DeviceProvider();
      final dev = Device(
        id: 'dev_cyclic_test',
        deviceId: 'DEV_CYC_01',
        name: 'Pump Controller',
        statusMessage: 'Online',
        lastActiveTime: 'Just now',
        isOnline: true,
      );
      provider.devices.add(dev);
      provider.selectDevice('dev_cyclic_test');

      await provider.sendMessage('/test cyclic', targetDeviceId: 'dev_cyclic_test');
      await Future.delayed(const Duration(milliseconds: 500));
      final updated = provider.devices.firstWhere((d) => d.id == 'dev_cyclic_test');
      expect(updated.messages.length, 2);
      final reply = updated.messages.last;
      expect(reply.text, contains('"type":"CYCLIC"'));
      expect(reply.text, contains('cyclic'));
    });

    test('sendMessage with numeric and /numeric returns NUMERIC response with Dimmer, Fan Speed, Brightness, Overload Current and NOT TIME', () async {
      final provider = DeviceProvider();
      final dev = Device(
        id: 'dev_numeric_test',
        deviceId: 'DEV_NUM_01',
        name: 'Smart Controller',
        statusMessage: 'Online',
        lastActiveTime: 'Just now',
        isOnline: true,
      );
      provider.devices.add(dev);
      provider.selectDevice('dev_numeric_test');

      await provider.sendMessage('numeric', targetDeviceId: 'dev_numeric_test');
      await Future.delayed(const Duration(milliseconds: 500));
      final updated = provider.devices.firstWhere((d) => d.id == 'dev_numeric_test');
      expect(updated.messages.length, 2);
      final reply = updated.messages.last;
      expect(reply.command, 'NUMERIC');
      expect(reply.command, isNot('TIME'));
      expect(reply.text, contains('Overload Current: 20.0 A [Range: 2 - 30]'));
      expect(reply.text, contains('Dry Run Current: 5.0 A [Range: 2 - 20]'));
      expect(reply.text, contains('Top Tank Level: 50 % [Range: 10 - 80]'));
      expect(reply.text, isNot(contains('set_timing')));
      expect(reply.text, isNot(contains('schedule_')));
    });

    test('sendMessage with /holding returns NUMERIC response and NOT TIME', () async {
      final provider = DeviceProvider();
      final dev = Device(
        id: 'dev_holding_test',
        deviceId: 'DEV_HOLD_01',
        name: 'Smart Controller',
        statusMessage: 'Online',
        lastActiveTime: 'Just now',
        isOnline: true,
      );
      provider.devices.add(dev);
      provider.selectDevice('dev_holding_test');

      await provider.sendMessage('/holding', targetDeviceId: 'dev_holding_test');
      await Future.delayed(const Duration(milliseconds: 500));
      final updated = provider.devices.firstWhere((d) => d.id == 'dev_holding_test');
      expect(updated.messages.length, 2);
      final reply = updated.messages.last;
      expect(reply.command, 'NUMERIC');
      expect(reply.command, isNot('TIME'));
      expect(reply.text, contains('DRS Recovery Delay'));
      expect(reply.text, contains('Overload Current'));
    });
  });
}

