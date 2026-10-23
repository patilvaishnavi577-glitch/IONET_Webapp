import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/device_model.dart';
import '../providers/device_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_session_provider.dart';
import '../theme/app_theme.dart';
import '../views/device_profile_view.dart';
import 'package:flutter/gestures.dart';

class DeviceChatView extends StatefulWidget {
  final Device device;
  final bool isMobile;
  final VoidCallback? onBack;

  const DeviceChatView({
    super.key,
    required this.device,
    this.isMobile = false,
    this.onBack,
  });

  @override
  State<DeviceChatView> createState() => _DeviceChatViewState();
}

class _DeviceChatViewState extends State<DeviceChatView> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showProfilePane = false;
  bool _showQuickCommands = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDeviceDetails();
    });
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _loadDeviceDetails() {
    final token = context.read<UserSessionProvider>().session.token;
    if (token != null && token.isNotEmpty) {
      final hwId = widget.device.deviceId.isNotEmpty ? widget.device.deviceId : widget.device.id;
      context.read<DeviceProvider>().fetchDeviceDetails(
        token: token,
        dbId: widget.device.id,
        hwId: hwId,
      );
    }
  }

  @override
  void didUpdateWidget(DeviceChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.id != widget.device.id) {
      setState(() {
        _showProfilePane = false;
        _showQuickCommands = false;
      });
      _loadDeviceDetails();
      _scrollToBottom();
    } else {
      if (!widget.device.isOnline && _showQuickCommands) {
        setState(() {
          _showQuickCommands = false;
        });
      }
      if (oldWidget.device.messages.length != widget.device.messages.length) {
        _scrollToBottom();
      }
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend([String? prefilledCommand, String? displayText]) {
    if (_showQuickCommands) {
      setState(() {
        _showQuickCommands = false;
      });
    }
    var text = prefilledCommand ?? _textController.text;
    if (text.trim().isEmpty) return;

    if (prefilledCommand == null) {
      _textController.clear();
    }

    String? display = displayText;
    final lower = text.trim().toLowerCase();
    if (display != null && display.trim().isNotEmpty) {
      // Respect explicit display label from QuickCommand or caller
    } else {
      if (lower == 'live status' || lower == 'get live status' || lower == 'to get live status') {
        text = '/status';
        display = 'Get Live Status';
      } else if (lower == 'status' ||
          lower == '/status' ||
          lower == 'device' ||
          lower == 'device status' ||
          lower == 'get device status') {
        text = '/status';
        display = 'Get device status';
      }
    }

    final devId = widget.device.id.isNotEmpty ? widget.device.id : widget.device.deviceId;
    context.read<DeviceProvider>().sendMessage(text, displayText: display, targetDeviceId: devId);
    _scrollToBottom();
  }



  
  void _showConfigurationDialog(BuildContext context, DeviceProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return DeviceConfigDialog(
          provider: provider,
          device: widget.device,
        );
      },
    );
  }

  void _showWifiSetupDialog(BuildContext context, DeviceProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return WifiSetupDialog(
          provider: provider,
          device: widget.device,
        );
      },
    );
  }

  void _showTimePickerDialog(BuildContext context, QuickCommand cmd) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return TimeScheduleWheelDialog(
          cmd: cmd,
          device: widget.device,
          onSend: (commandPayload, displayText) {
            _handleSend(commandPayload, displayText);
          },
        );
      },
    );
  }

  void _showCyclicPickerDialog(BuildContext context, QuickCommand cmd) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return CyclicScheduleWheelDialog(
          cmd: cmd,
          device: widget.device,
          onSend: (commandPayload, displayText) {
            _handleSend(commandPayload, displayText);
          },
        );
      },
    );
  }

  void _showNumericRangeDialog(
    BuildContext context, {
    required String paramKey,
    required String label,
    required String rawValue,
    required String range,
    required double minVal,
    required double maxVal,
    required String unit,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return NumericRangeDialog(
          paramKey: paramKey,
          label: label,
          rawValue: rawValue,
          range: range,
          minVal: minVal,
          maxVal: maxVal,
          unit: unit,
          onSend: (commandPayload, displayText) {
            _handleSend(commandPayload, displayText);
          },
        );
      },
    );
  }

  void _showBinarySettingDialog(
    BuildContext context, {
    required String paramKey,
    required String label,
    required dynamic currentValue,
    required String range,
    String payloadType = 'NUMERIC',
    List<String> options = const ['1', '0'],
    QuickCommand? onCommand,
    QuickCommand? offCommand,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = options.where((o) => o != '2' && o.toLowerCase() != 'preserve').toList();
    final effectiveOptions = filtered.isNotEmpty ? filtered : const ['1', '0'];
    String selectedValue = currentValue.toString().trim();
    if (!effectiveOptions.contains(selectedValue)) {
      selectedValue = effectiveOptions.firstWhere(
        (o) {
          final curLower = selectedValue.toLowerCase();
          final oLower = o.toLowerCase();
          if (curLower == oLower) return true;
          if ((curLower == '1' || curLower == 'on') && (oLower == '1' || oLower == 'on')) return true;
          if ((curLower == '0' || curLower == 'off') && (oLower == '0' || oLower == 'off')) return true;
          return false;
        },
        orElse: () => effectiveOptions.first,
      );
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: effectiveOptions.length >= 3 ? 340 : 290),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111B21) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E3D46) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A884).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: Color(0xFF00A884),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.pop(context),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Options: dynamically mapped from backend options (compact size)
                      Row(
                        children: [
                          for (int i = 0; i < effectiveOptions.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final opt = effectiveOptions[i];
                                  final isSelected = selectedValue == opt;
                                  final isPositive = opt == '1' || opt.toLowerCase() == 'on' || opt.toLowerCase() == 'true';
                                  final isNegative = opt == '0' || opt.toLowerCase() == 'off' || opt.toLowerCase() == 'false';
                                  final isPreserve = opt == '2' || opt.toLowerCase() == 'preserve';
                                  final activeColor = isPositive
                                      ? const Color(0xFF00A884)
                                      : (isNegative
                                          ? const Color(0xFFEF4444)
                                          : (isPreserve ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8)));
                                  final icon = isPositive
                                      ? Icons.power_settings_new_rounded
                                      : (isNegative
                                          ? Icons.power_off_rounded
                                          : (isPreserve ? Icons.restore_rounded : Icons.radio_button_checked_rounded));
                                  return GestureDetector(
                                    onTap: () => setDialogState(() => selectedValue = opt),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? activeColor.withOpacity(isDark ? 0.22 : 0.12)
                                            : (isDark ? const Color(0xFF1B272C) : const Color(0xFFF8FAFC)),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected
                                              ? activeColor
                                              : (isDark ? const Color(0xFF2E3D46) : const Color(0xFFCBD5E1)),
                                          width: isSelected ? 1.6 : 1.0,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            icon,
                                            size: 16,
                                            color: isSelected
                                                ? activeColor
                                                : (isDark ? Colors.white54 : Colors.black45),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            opt,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? activeColor
                                                  : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Action Buttons (small font and compact padding)
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final isSelectedOn = selectedValue == '1' ||
                                    selectedValue.toLowerCase() == 'on' ||
                                    selectedValue.toLowerCase() == 'true';
                                final isSelectedOff = selectedValue == '0' ||
                                    selectedValue.toLowerCase() == 'off' ||
                                    selectedValue.toLowerCase() == 'false';
                                final cleanKey = paramKey.toLowerCase().replaceAll(' ', '_');
                                final isPsOrPop = cleanKey == 'ps' ||
                                    cleanKey == 'pop' ||
                                    cleanKey.contains('preserve') ||
                                    cleanKey.contains('power_on');

                                if (!isPsOrPop && isSelectedOn && onCommand != null && effectiveOptions.length <= 2) {
                                  _handleSend(
                                    onCommand.message,
                                    onCommand.label.isNotEmpty ? onCommand.label : onCommand.message,
                                  );
                                } else if (!isPsOrPop && isSelectedOff && offCommand != null && effectiveOptions.length <= 2) {
                                  _handleSend(
                                    offCommand.message,
                                    offCommand.label.isNotEmpty ? offCommand.label : offCommand.message,
                                  );
                                } else {
                                  final dynamic valToSend = int.tryParse(selectedValue) ?? selectedValue;
                                  final String jsonPayload = jsonEncode({
                                    'command': '/write_register',
                                    'data': {
                                      paramKey: valToSend,
                                    },
                                  });
                                  _handleSend(jsonPayload, 'Set $label: $selectedValue');
                                  final devId = widget.device.id.isNotEmpty ? widget.device.id : widget.device.deviceId;
                                  context.read<DeviceProvider>().updateRadioSettingOptimistic(devId, paramKey, selectedValue);
                                  context.read<DeviceProvider>().saveDeviceConfiguration(devId, {
                                    paramKey: valToSend,
                                    if (cleanKey == 'ps') 'Preserve Setting': valToSend,
                                    if (cleanKey == 'pop') 'Power On State': valToSend,
                                  });
                                }
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00A884),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text(
                                'Submit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Shows a radio-selection dialog for RADIO type backend response.
  
  void _showRadioOptionDialog(
    BuildContext context, {
    required String fieldKey,    // raw key from backend e.g. "PS"
    required String label,       // human-readable label e.g. "Ps"
    required String currentValue,// current value from backend e.g. "0" or "1"
    required List<String> options,// allowed options from backend e.g. ["0","1"]
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String selectedValue = currentValue;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111B21) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E3D46) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.radio_button_checked_rounded,
                              color: Color(0xFF7C3AED),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => Navigator.pop(context),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Current value label
                      Text(
                        'Current: ${currentValue == "1" ? "1 (ON)" : (currentValue == "2" ? "2 (PRESERVE)" : (currentValue == "0" ? "0 (OFF)" : currentValue))}',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Dynamic Radio Options (from backend options list)
                      ...options.map((opt) {
                        final isSelected = selectedValue == opt;
                        final isOnOpt = opt == '1' || opt.toLowerCase() == 'on';
                        final isOffOpt = opt == '0' || opt.toLowerCase() == 'off';
                        final isPreserveOpt = opt == '2' || opt.toLowerCase() == 'preserve';
                        String optLabel = opt;
                        if (isOnOpt) {
                          optLabel = '1 - ON';
                        } else if (isOffOpt) {
                          optLabel = '0 - OFF';
                        } else if (isPreserveOpt) {
                          optLabel = '2 - PRESERVE (Keep Last State)';
                        }
                        final optColor = isOnOpt
                            ? const Color(0xFF00A884)
                            : (isOffOpt
                                ? const Color(0xFFEF4444)
                                : (isPreserveOpt ? const Color(0xFFF59E0B) : const Color(0xFF7C3AED)));
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() => selectedValue = opt);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? optColor.withOpacity(0.12)
                                  : (isDark ? const Color(0xFF1B272C) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? optColor.withOpacity(0.7)
                                    : (isDark ? const Color(0xFF2E3D46) : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? optColor : (isDark ? Colors.white38 : Colors.black26),
                                      width: 2,
                                    ),
                                    color: isSelected ? optColor : Colors.transparent,
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    optLabel,
                                    style: TextStyle(
                                      color: isSelected
                                          ? optColor
                                          : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                      fontSize: 15,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 6),

                      // Confirm Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: selectedValue == currentValue
                              ? null // no change, disable
                              : () {
                                  // Send backend-compatible radio payload via /write_register
                                  final dynamic valToSend = int.tryParse(selectedValue) ?? selectedValue;
                                  final jsonPayload = jsonEncode({
                                    'command': '/write_register',
                                    'data': {
                                      fieldKey: valToSend,
                                    },
                                  });
                                  _handleSend(jsonPayload, 'Set $label: $selectedValue');
                                  final devId = widget.device.id.isNotEmpty ? widget.device.id : widget.device.deviceId;
                                  context.read<DeviceProvider>().updateRadioSettingOptimistic(devId, fieldKey, selectedValue);
                                  Navigator.pop(context);
                                },
                          child: Text(
                            selectedValue == currentValue
                                ? 'No Changes'
                                : 'Apply  →  ${selectedValue == "1" ? "ON (1)" : (selectedValue == "2" ? "PRESERVE (2)" : (selectedValue == "0" ? "OFF (0)" : selectedValue))}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTextSlotEditDialog(
    BuildContext context, {
    required String slotId,
    required String label,
    required String currentName,
    String? explicitRange,
  }) {
    final devId = widget.device.deviceId.isNotEmpty ? widget.device.deviceId : widget.device.id;
    final textSettings = context.read<DeviceProvider>().getDeviceTextSettings(devId);
    final setting = textSettings[slotId] ?? textSettings['Slot $slotId'] ?? textSettings['Channel $slotId'];

    // Determine character length range strictly from backend
    int minChars = setting?.minLength ?? 1;
    int maxChars = setting?.maxLength ?? 16;
    String rangeStr = setting?.range ?? (explicitRange ?? '$minChars - $maxChars');

    if (explicitRange != null && explicitRange.isNotEmpty) {
      final match = RegExp(r'([0-9]+)\s*-\s*([0-9]+)').firstMatch(explicitRange);
      if (match != null) {
        minChars = int.tryParse(match.group(1)!) ?? minChars;
        maxChars = int.tryParse(match.group(2)!) ?? maxChars;
        rangeStr = explicitRange;
      }
    }

    final textController = TextEditingController(text: currentName);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        String? errorMessage;
        int currentLength = textController.text.trim().length;
        bool isValid = currentLength >= minChars && currentLength <= maxChars;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void validate(String val) {
              final len = val.trim().length;
              setDialogState(() {
                currentLength = len;
                if (len < minChars) {
                  isValid = false;
                  errorMessage = 'Minimum $minChars characters required';
                } else if (len > maxChars) {
                  isValid = false;
                  errorMessage = 'Maximum $maxChars characters allowed';
                } else {
                  isValid = true;
                  errorMessage = null;
                }
              });
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF111B21) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: Color(0xFF00A884)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label.isNotEmpty ? 'Rename $label' : 'Rename Channel $slotId',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.isNotEmpty ? 'Name for $label:' : 'Name for Channel $slotId:',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    maxLength: maxChars + 4,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: validate,
                    decoration: InputDecoration(
                      hintText: 'Enter name for ${label.isNotEmpty ? label : "Slot $slotId"}',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1B272C) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isValid ? (isDark ? const Color(0xFF2E3D46) : const Color(0xFFE2E8F0)) : const Color(0xFFEF4444),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isValid ? (isDark ? const Color(0xFF2E3D46) : const Color(0xFFE2E8F0)) : const Color(0xFFEF4444),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFEF4444)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isValid
                      ? () {
                          final newName = textController.text.trim();
                          final targetKey = (setting?.key.isNotEmpty == true) ? setting!.key : slotId;
                          final jsonPayload = jsonEncode({
                            'command': '/write_register',
                            'data': {
                              targetKey: newName,
                            },
                          });
                          _handleSend(jsonPayload, label.isNotEmpty ? 'Set $label: $newName' : 'Set Channel $slotId: $newName');
                          final labelLower = label.toLowerCase();
                          final isSettingName = labelLower.contains('setting') ||
                              labelLower.contains('preserve') ||
                              labelLower.contains('holding') ||
                              labelLower.contains('radio') ||
                              labelLower == 'ps' ||
                              labelLower == 'pop';
                          context.read<DeviceProvider>().saveDeviceConfiguration(devId, {
                            'Slot $slotId': newName,
                            'slot $slotId': newName,
                            'Channel $slotId': newName,
                            'channel $slotId': newName,
                            'Relay $slotId': newName,
                            'relay $slotId': newName,
                            'relay_$slotId': newName,
                            'channel_$slotId': newName,
                            slotId: newName,
                            if (label.isNotEmpty && !isSettingName && !labelLower.contains('time') && !labelLower.contains('timing')) label: newName,
                          });
                          Navigator.pop(context);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A884),
                    disabledBackgroundColor: isDark ? const Color(0xFF1E2830) : const Color(0xFFE2E8F0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save & Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _getCommandIcon(String label, String message) {
    final l = label.toLowerCase();
    final m = message.toLowerCase();
    if (l.contains('cyclic') || m.contains('cyclic') || l.contains('cycle') || m.contains('cycle') || l.contains('loop')) {
      return Icons.repeat_rounded;
    }
    if (l.contains('time') || m.contains('time') || l.contains('schedule') || l.contains('timer') || l.contains('hold')) {
      return Icons.access_time_filled_rounded;
    }
    if (l.contains('live') || m.contains('live') || l.contains('status') || m.contains('status')) {
      return Icons.trending_up_rounded;
    }
    if (l.contains('relay')) {
      return Icons.chevron_right_rounded;
    }
    if (l.contains('temp')) return Icons.thermostat_rounded;
    if (l.contains('humid')) return Icons.water_drop_outlined;
    if (l.contains('tank') || l.contains('water') || l.contains('level')) {
      return Icons.water_drop_rounded;
    }
    if (l.contains('auto') || l.contains('manual') || l.contains('mode')) {
      return Icons.sync_alt_rounded;
    }
    if (l.contains('wifi')) return Icons.wifi_rounded;
    if (l.contains('volt') || l.contains('curr') || l.contains('power') || l.contains('energy')) {
      return Icons.bolt_rounded;
    }
    if (l.contains('reset') || l.contains('restart')) {
      return Icons.restart_alt_rounded;
    }
    if (l.contains('on') || l.contains('off') || l.contains('relay') || l.contains('switch')) {
      return Icons.power_settings_new_rounded;
    }
    if (l.contains('about') || m.contains('about') || l.contains('info') || m.contains('info')) {
      return Icons.info_outline_rounded;
    }
    return Icons.chevron_right_rounded;
  }

  Widget _buildQuickCommandsPopover(
    BuildContext context,
    DeviceProvider provider,
    Device currentDevice,
    bool isDark,
    Color accentGreen,
    Color textPrimary,
    Color textSecondary,
  ) {
    final devId = currentDevice.deviceId.isNotEmpty ? currentDevice.deviceId : currentDevice.id;
    final allCommands = provider.getQuickCommands(devId, model: currentDevice.model, deviceName: currentDevice.name);
    final cardBg = isDark ? const Color(0xFF1B272C) : Colors.white;
    final borderCol = isDark ? const Color(0xFF2E3D46) : const Color(0xFFE2E8F0);
    final dividerCol = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);
    final width = widget.isMobile ? double.infinity : 340.0;
    final borderRadius = widget.isMobile
        ? const BorderRadius.vertical(top: Radius.circular(22))
        : BorderRadius.circular(18);

    return Material(
      color: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black54,
      borderRadius: borderRadius,
      child: Container(
        width: width,
        constraints: const BoxConstraints(maxHeight: 380),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: borderRadius,
          border: Border.all(color: borderCol, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.5 : 0.14),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: widget.isMobile
            ? EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16)
            : const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: ⚡ Quick Commands
            Row(
              children: [
                Icon(Icons.bolt_rounded, color: accentGreen, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Quick Commands',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _showQuickCommands = false),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: dividerCol, height: 1, thickness: 1),
            const SizedBox(height: 6),

            // Command Items
            if (allCommands.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28.0),
                child: Center(
                  child: Text(
                    'No commands available',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF8696A0) : const Color(0xFF64748B),
                      fontSize: 13.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: allCommands.map((cmd) {
                      if (cmd.isSlider) {
                        final currentSliderVal = (cmd.value ?? provider.getDeviceSliderValue(devId, cmd.message) ?? cmd.minValue)
                            .clamp(cmd.minValue, cmd.maxValue);
                        return StatefulBuilder(
                          builder: (context, setTileState) {
                            double activeVal = currentSliderVal;
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2A3942).withOpacity(0.5) : const Color(0xFFF7F9FA),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF384A56).withOpacity(0.5) : const Color(0xFFE2E8F0),
                                  width: 0.8,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(_getCommandIcon(cmd.label, cmd.message), color: accentGreen, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          cmd.label,
                                          style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Text(
                                        '${activeVal.toInt()}',
                                        style: TextStyle(color: accentGreen, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: Icon(Icons.send_rounded, size: 16, color: accentGreen),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          setState(() => _showQuickCommands = false);
                                          provider.updateSliderValue(devId, cmd.message, activeVal, sendCommand: true);
                                        },
                                      ),
                                    ],
                                  ),
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: accentGreen,
                                      thumbColor: accentGreen,
                                      trackHeight: 2.5,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    ),
                                    child: Slider(
                                      value: activeVal,
                                      min: cmd.minValue,
                                      max: cmd.maxValue,
                                      onChanged: (val) {
                                        setTileState(() => activeVal = val);
                                        provider.updateSliderValue(devId, cmd.message, val, sendCommand: false);
                                      },
                                      onChangeEnd: (val) {
                                        provider.updateSliderValue(devId, cmd.message, val, sendCommand: true);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }

                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() => _showQuickCommands = false);
                          if (cmd.isTimeType) {
                            _showTimePickerDialog(context, cmd);
                          } else if (cmd.isCyclicType) {
                            _showCyclicPickerDialog(context, cmd);
                          } else {
                            _handleSend(cmd.message, cmd.label);
                          }
                        },
                        onLongPress: cmd.isCustom ? () => _showEditCustomDialog(context, cmd, isDark) : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Row(
                            children: [
                              Icon(
                                _getCommandIcon(cmd.label, cmd.message),
                                color: accentGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  cmd.label,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: textSecondary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showEditCustomDialog(BuildContext context, QuickCommand cmd, bool isDark) {
    final formKey = GlobalKey<FormState>();
    final labelController = TextEditingController(text: cmd.label);
    final messageController = TextEditingController(text: cmd.message);
    final devId = widget.device.deviceId.isNotEmpty ? widget.device.deviceId : widget.device.id;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2C34) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? AppTheme.cardBorder : AppTheme.cardBorderLight,
                width: 1,
              ),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Custom Button',
                    style: TextStyle(
                      color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: labelController,
                    decoration: const InputDecoration(labelText: 'Button Label'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: messageController,
                    decoration: const InputDecoration(labelText: 'Command Text'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState?.validate() ?? false) {
                            final newLabel = labelController.text.trim();
                            final newMsg = messageController.text.trim();
                            context.read<DeviceProvider>().editDeviceQuickCommand(
                              devId,
                              cmd,
                              QuickCommand(label: newLabel, message: newMsg, isCustom: true),
                            );
                            Navigator.pop(dialogContext);
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final currentDevice = provider.devices.firstWhere(
      (d) => d.id == widget.device.id || d.deviceId == widget.device.deviceId,
      orElse: () => widget.device,
    );
    final messages = currentDevice.messages;
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final devId = currentDevice.deviceId.isNotEmpty ? currentDevice.deviceId : currentDevice.id;
    final allCommands = provider.getQuickCommands(devId, model: currentDevice.model, deviceName: currentDevice.name);

    final headerBg = isDark ? AppTheme.cardBg : const Color(0xFFF0F2F5);
    final borderCol = isDark ? AppTheme.cardBorder : AppTheme.cardBorderLight;
    final textPrimaryColor = isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
    final textSecondaryColor = isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight;
    final chatBg = isDark ? AppTheme.scaffoldBg : const Color(0xFFEFEAE2);
    final inputBarBg = isDark ? AppTheme.cardBg : const Color(0xFFF0F2F5);
    final textInputFill = isDark ? const Color(0xFF2A3942) : Colors.white;
    final accentGreen = isDark ? const Color(0xFF00A884) : const Color(0xFF008069);

    final mainChatColumn = Column(
      children: [
        // 1. Header Bar
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: headerBg,
            border: Border(
              bottom: BorderSide(color: borderCol, width: 1),
            ),
          ),
          child: GestureDetector(
            onTap: () {
              if (widget.isMobile) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DeviceProfileView(device: currentDevice)),
                );
              } else {
                setState(() {
                  _showProfilePane = !_showProfilePane;
                });
              }
            },
            child: Row(
              children: [
                if (widget.isMobile || widget.onBack != null)
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                    onPressed: widget.onBack,
                  ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: currentDevice.imageUrl != null
                        ? Colors.transparent
                        : (isDark ? const Color(0xFF2A3942) : Colors.white),
                    shape: BoxShape.circle,
                  ),
                  padding: currentDevice.imageUrl != null ? EdgeInsets.zero : const EdgeInsets.all(4),
                  child: ClipOval(
                    child: currentDevice.imageUrl != null
                        ? Image.network(
                            currentDevice.imageUrl!,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Padding(
                              padding: const EdgeInsets.all(4),
                              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                            ),
                          )
                        : Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentDevice.name,
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      InkWell(
                      onTap: currentDevice.isOnline ? null : () {
                        context.read<DeviceProvider>().reconnectCurrentDevice();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: currentDevice.isOnline 
                                  ? const Color(0xFF25D366) 
                                  : (currentDevice.statusMessage == 'Connecting...' ? Colors.orangeAccent : Colors.redAccent),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            currentDevice.isOnline
                                ? 'Online'
                                : (currentDevice.statusMessage == 'Connecting...'
                                    ? 'Connecting...'
                                    : (currentDevice.lastActiveTime.isNotEmpty && currentDevice.lastActiveTime != 'Never'
                                        ? 'Offline • ${currentDevice.lastActiveTime}'
                                        : 'Offline • Tap to retry')),
                            style: TextStyle(
                              color: currentDevice.isOnline ? const Color(0xFF25D366) : (currentDevice.statusMessage == 'Connecting...' ? Colors.orangeAccent : textSecondaryColor),
                              fontSize: 12,
                              decoration: !currentDevice.isOnline && currentDevice.statusMessage != 'Connecting...'
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: textPrimaryColor),
                  tooltip: 'Device Options',
                  onSelected: (val) {
                    final prov = context.read<DeviceProvider>();
                    if (val == 'wifi_setup') {
                      _showWifiSetupDialog(context, prov);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'wifi_setup',
                      child: Row(
                        children: [
                          Icon(Icons.wifi_rounded, size: 20, color: accentGreen),
                          const SizedBox(width: 10),
                          const Text('Wi-Fi Setup'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),

        // 2. Chat Message Stream (WhatsApp classic chat background)
        Expanded(
          child: Container(
            color: chatBg,
            child: messages.isEmpty
                ? _buildEmptyState(currentDevice, isDark, textPrimaryColor, textSecondaryColor, accentGreen)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      // Consecutive duplicate suppression: never render two identical device cards or replies back-to-back
                      if (index > 0) {
                        final prevMsg = messages[index - 1];
                        if (!msg.isUser && !prevMsg.isUser) {
                          if (msg.text.trim() == prevMsg.text.trim()) {
                            return const SizedBox.shrink();
                          }
                          if (_isClickableReport(msg.text) && _isClickableReport(prevMsg.text)) {
                            return const SizedBox.shrink();
                          }
                        }
                      }
                      return _buildMessageBubble(msg, isDark, accentGreen);
                    },
                  ),
          ),
        ),


        // 4. Message / Command Input Bar (WhatsApp styled with inline Status & Quick Commands)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          color: inputBarBg,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  enabled: currentDevice.isOnline,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: IconButton(
                      icon: Icon(
                        Icons.show_chart_rounded,
                        color: currentDevice.isOnline
                            ? accentGreen
                            : (isDark ? const Color(0xFF6E8290) : const Color(0xFF94A3B8)),
                        size: 22,
                      ),
                      tooltip: currentDevice.isOnline ? 'Get device status' : 'Device is offline',
                      onPressed: currentDevice.isOnline
                          ? () {
                              final devId = currentDevice.deviceId.isNotEmpty ? currentDevice.deviceId : currentDevice.id;
                              final cmds = context.read<DeviceProvider>().getQuickCommands(devId);
                              final statusCmd = cmds.firstWhere(
                                (c) => c.message.toLowerCase() == '/status' || c.label.toLowerCase().contains('status'),
                                orElse: () => const QuickCommand(label: 'Get device status', message: '/status'),
                              );
                              _handleSend(statusCmd.message, statusCmd.label.isNotEmpty ? statusCmd.label : 'Get device status');
                            }
                          : null,
                    ),
                    hintText: 'Send command...',
                    hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF6E8290) : const Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: textInputFill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: IconButton(
                      icon: AnimatedRotation(
                        turns: _showQuickCommands ? 0.125 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          _showQuickCommands ? Icons.close_rounded : Icons.bolt_rounded,
                          color: accentGreen,
                          size: 22,
                        ),
                      ),
                      tooltip: 'Quick Commands',
                      onPressed: () {
                        setState(() {
                          _showQuickCommands = !_showQuickCommands;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
              const SizedBox(width: 10),

              // WhatsApp Styled Send Button
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.hardEdge,
                child: InkWell(
                  onTap: _textController.text.trim().isNotEmpty
                      ? () => _handleSend()
                      : null,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _textController.text.trim().isNotEmpty
                          ? accentGreen
                          : (isDark ? const Color(0xFF22313A) : const Color(0xFFE2E8F0)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: _textController.text.trim().isNotEmpty
                          ? Colors.white
                          : (isDark ? const Color(0xFF6E8290) : const Color(0xFF94A3B8)),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final chatContent = Stack(
      children: [
        mainChatColumn,
        if (_showQuickCommands) ...[
          // Dismiss on background touch
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _showQuickCommands = false;
                });
              },
            ),
          ),
          // Positioned directly above the quick commands button (bottom-right)
          Positioned(
            bottom: widget.isMobile ? 0 : 74,
            right: widget.isMobile ? 0 : 64,
            left: widget.isMobile ? 0 : null,
            child: _buildQuickCommandsPopover(
              context,
              provider,
              currentDevice,
              isDark,
              accentGreen,
              textPrimaryColor,
              textSecondaryColor,
            ),
          ),
        ],
      ],
    );

    if (widget.isMobile || !_showProfilePane) {
      return chatContent;
    }

    return Row(
      children: [
        Expanded(child: chatContent),
        Container(
          width: 380,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: isDark ? AppTheme.cardBorder : AppTheme.cardBorderLight, width: 1),
            ),
          ),
          child: DeviceProfileView(
            device: widget.device,
            onClose: () {
              setState(() {
                _showProfilePane = false;
              });
            },
          ),
        ),
      ],
    );
  }

  bool _isTelemetryReport(String text) {
    final trimmedText = text.trim();
    if (trimmedText.startsWith('{') || trimmedText.startsWith('[')) {
      return false;
    }
    final lines = trimmedText.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return false;
    int colonCount = 0;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('/') || trimmed.startsWith('Sent ') || trimmed.startsWith('http')) {
        return false;
      }
      if (trimmed.contains(':')) {
        final colonIdx = trimmed.indexOf(':');
        final keyPart = trimmed.substring(0, colonIdx).trim();
        if (keyPart.contains('{') || keyPart.contains('}') || keyPart.contains('"') || keyPart.contains("'")) {
          return false;
        }
        colonCount++;
      }
    }
    return colonCount > 0 && colonCount >= (lines.length / 2);
  }

  Widget _buildDeviceInfoCard(
    Device currentDevice,
    List<MapEntry<String, String>> items,
    bool isDark,
    Color accentGreen,
    Color secondaryTextColor,
  ) {
    final cardBg = isDark ? const Color(0xFF132228) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E353D) : const Color(0xFFCBD5E1);
    final headerTitleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final badgeBg = isDark ? const Color(0xFF1A2B32) : const Color(0xFFF1F5F9);
    final badgeTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final dividerCol = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06);

    String devId = currentDevice.deviceId.isNotEmpty ? currentDevice.deviceId : currentDevice.id;
    String hwVer = currentDevice.hardwareVersion ??
        (currentDevice.model != null && currentDevice.model!.isNotEmpty && currentDevice.model != 'DEFAULT'
            ? currentDevice.model!
            : '');
    String swVer = currentDevice.softwareVersion ?? '';

    for (final entry in items) {
      final k = entry.key.toLowerCase().trim();
      final v = entry.value.trim();
      if (k == 'device id' || k == 'deviceid' || k == 'id') {
        if (v.isNotEmpty) devId = v;
      } else if (k.contains('hardware')) {
        if (v.isNotEmpty) hwVer = v;
      } else if (k.contains('software') || k.contains('firmware') || k.contains('version')) {
        if (v.isNotEmpty) swVer = v;
      }
    }

    final infoRows = <MapEntry<String, String>>[
      MapEntry('Device Id', devId),
      if (hwVer.isNotEmpty) MapEntry('Hardware Version', hwVer),
      if (swVer.isNotEmpty) MapEntry('Software Version', swVer),
    ];

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Full-width dark teal strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF132D2F) : const Color(0xFFE6F4F1),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1E383C) : const Color(0xFFD1E7E3),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 19,
                      color: Color(0xFF2DD4BF),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'Device Information',
                      style: TextStyle(
                        color: headerTitleColor,
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Rows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: infoRows.asMap().entries.map((indexed) {
                final idx = indexed.key;
                final item = indexed.value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (idx > 0) Divider(color: dividerCol, height: 1, thickness: 0.8),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text(
                              item.key,
                              style: TextStyle(
                                color: labelColor,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 6,
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5.5),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF2E434E).withOpacity(0.6)
                                      : const Color(0xFFCBD5E1),
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                item.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: badgeTextColor,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTelemetryCard(
    ChatMessage msg,
    List<MapEntry<String, String>> items,
    bool isDark,
    Color accentGreen,
    Color secondaryTextColor,
  ) {
    final cardBg = isDark ? const Color(0xFF131E24) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E353D) : const Color(0xFFCBD5E1);
    final headerTitleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final telemetryTagColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
    final labelColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final badgeBg = isDark ? const Color(0xFF182730) : const Color(0xFFF1F5F9);
    final badgeTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final dividerCol = isDark ? const Color(0xFF1E2E36) : const Color(0xFFF1F5F9);

    final devId = widget.device.deviceId.isNotEmpty ? widget.device.deviceId : widget.device.id;
    final savedConfig = context.watch<DeviceProvider>().getDeviceSavedConfig(devId);
    final radioSettings = context.watch<DeviceProvider>().getDeviceRadioSettings(devId);
    final numSettings = context.watch<DeviceProvider>().getDeviceNumericSettings(devId);
    final textSettings = context.watch<DeviceProvider>().getDeviceTextSettings(devId);
    final quickCommands = context.watch<DeviceProvider>().getQuickCommands(devId);
    final rangeRegex = RegExp(r'\[Range:\s*([0-9.]+)\s*-\s*([0-9.]+)\]|\[([0-9.]+)\s*-\s*([0-9.]+)\]|\(Range:\s*([0-9.]+)\s*-\s*([0-9.]+)\)');
    final fullRangeBracketRegex = RegExp(r'\[Range:\s*([^\]]+)\]|\(Range:\s*([^)]+)\)|\[([^\]]+)\]', caseSensitive: false);

    TextSetting? findMatchedTextSetting(String key) {
      final clean = key.toLowerCase().replaceAll(' ', '_');
      if (textSettings.containsKey(key)) return textSettings[key];
      if (textSettings.containsKey(clean)) return textSettings[clean];

      final byKey = textSettings.values.cast<TextSetting?>().firstWhere(
        (s) => s != null && (s.key.toLowerCase() == key.toLowerCase() || s.key.toLowerCase() == clean),
        orElse: () => null,
      );
      if (byKey != null) return byKey;

      final byVal = textSettings.values.cast<TextSetting?>().firstWhere(
        (s) => s != null && s.value.trim().isNotEmpty && s.value.trim().toLowerCase() == key.trim().toLowerCase(),
        orElse: () => null,
      );
      if (byVal != null) return byVal;

      for (final cfgEntry in savedConfig.entries) {
        if (cfgEntry.value?.toString().trim().toLowerCase() == key.trim().toLowerCase()) {
          final sKey = cfgEntry.key;
          final sMatch = RegExp(r'^\d+$').firstMatch(sKey) ?? RegExp(r'^(?:relay|slot|channel)\s*(\d+)$', caseSensitive: false).firstMatch(sKey);
          final sId = sMatch?.group(1) ?? sMatch?.group(0) ?? sKey;
          if (textSettings.containsKey(sId)) return textSettings[sId];
          if (textSettings.containsKey('Slot $sId')) return textSettings['Slot $sId'];
          if (textSettings.containsKey('Relay $sId')) return textSettings['Relay $sId'];
          if (textSettings.containsKey('Channel $sId')) return textSettings['Channel $sId'];
        }
      }

      final isSlotOrRelay = clean.contains('relay') ||
          clean.contains('slot') ||
          clean.contains('channel') ||
          RegExp(r'^\d+$').hasMatch(clean);
      if (isSlotOrRelay) {
        final slotMatch = RegExp(r'^\d+$').firstMatch(key) ?? RegExp(r'^(?:relay|slot|channel)\s*(\d+)$', caseSensitive: false).firstMatch(key);
        final slotId = slotMatch?.group(1) ?? slotMatch?.group(0);
        if (slotId != null) {
          return textSettings[slotId] ??
              textSettings['Slot $slotId'] ??
              textSettings['Channel $slotId'] ??
              textSettings['Relay $slotId'];
        }
      }
      return null;
    }

    RadioSetting? findMatchedRadioSetting(String key) {
      final clean = key.toLowerCase().replaceAll(' ', '_');
      return radioSettings[key] ??
          radioSettings[clean] ??
          radioSettings.values.cast<RadioSetting?>().firstWhere(
            (s) => s != null && (s.key.toLowerCase() == key.toLowerCase() || s.label.toLowerCase() == key.toLowerCase()),
            orElse: () => null,
          );
    }

    NumericSetting? findMatchedNumericSetting(String key) {
      final clean = key.toLowerCase().replaceAll(' ', '_');
      return numSettings[clean] ??
          numSettings[key] ??
          numSettings.values.cast<NumericSetting?>().firstWhere(
            (s) => s != null && (s.key.toLowerCase() == key.toLowerCase() || s.label.toLowerCase() == key.toLowerCase()),
            orElse: () => null,
          );
    }

    QuickCommand? findMatchedTimeCommand(String key, String rawVal) {
      final clean = key.toLowerCase().replaceAll(' ', '_');
      return quickCommands.cast<QuickCommand?>().firstWhere(
        (c) => c != null && c.isTimeType && (c.message.toLowerCase() == clean || c.message.toLowerCase() == key.toLowerCase()),
        orElse: () => null,
      );
    }

    QuickCommand? findMatchedCyclicCommand(String key, String rawVal) {
      final clean = key.toLowerCase().replaceAll(' ', '_');
      return quickCommands.cast<QuickCommand?>().firstWhere(
        (c) => c != null && c.isCyclicType && (c.message.toLowerCase() == clean || c.message.toLowerCase() == key.toLowerCase()),
        orElse: () => null,
      );
    }

    QuickCommand? findMatchingCommand(String key, bool isOn) {
      final keyClean = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (keyClean.isEmpty) return null;
      for (final cmd in quickCommands) {
        final msgClean = cmd.message.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final lblClean = cmd.label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final matchesKey = msgClean.contains(keyClean) || lblClean.contains(keyClean);
        if (matchesKey) {
          if (isOn) {
            final hasOn = (msgClean.contains('on') || lblClean.contains('on')) &&
                !msgClean.contains('off') &&
                !lblClean.contains('off');
            if (hasOn) return cmd;
          } else {
            final hasOff = msgClean.contains('off') || lblClean.contains('off');
            if (hasOff) return cmd;
          }
        }
      }
      return null;
    }

    final cmdUpper = (msg.command ?? '').toUpperCase().trim();
    final bool isSettingsPayload = cmdUpper == 'NUMERIC' ||
        cmdUpper == 'RADIO' ||
        cmdUpper == 'TEXT' ||
        cmdUpper == 'TIME' ||
        cmdUpper == 'CYCLIC' ||
        cmdUpper == 'CYCLE' ||
        cmdUpper == 'HOLDING' ||
        cmdUpper == 'CONFIG' ||
        cmdUpper == 'SETTINGS' ||
        cmdUpper == '/SETTINGS' ||
        cmdUpper == '/RADIO' ||
        cmdUpper == '/HOLDING' ||
        cmdUpper == '/CYCLIC' ||
        cmdUpper == '/CYCLE';

    final bool isResponseReport = !isSettingsPayload && (cmdUpper == 'RESPONSE' ||
        cmdUpper == 'TELEMETRY' ||
        cmdUpper == '/STATUS' ||
        cmdUpper == 'STATUS' ||
        items.any((e) {
          final k = e.key.toLowerCase().replaceAll(' ', '_');
          return k.contains('flush') ||
              k.contains('ac_voltage') ||
              k.contains('ac_current') ||
              k.contains('motor_status') ||
              k.contains('overload_alarm') ||
              k.startsWith('na_') ||
              k.startsWith('na ');
        }));

    final bool cardHasAnyAction = !isResponseReport && items.any((entryItem) {
      final raw = entryItem.value.trim();
      final cleanKey = entryItem.key.toLowerCase().replaceAll(' ', '_');
      final isExplicitNumCmd = cmdUpper == 'NUMERIC' || cmdUpper == '/NUMERIC' || cmdUpper == 'HOLDING' || cmdUpper == '/HOLDING';
      final isClockTime = RegExp(r'\b\d{1,2}:\d{2}\b').hasMatch(raw);
      final matchedTimeCmd = findMatchedTimeCommand(entryItem.key, raw);
      final isTime = !isExplicitNumCmd && (matchedTimeCmd != null ||
          cmdUpper == 'TIME' ||
          cmdUpper == 'TIMINGS' ||
          (!cleanKey.contains('cyclic') && !cleanKey.contains('cycle') &&
              (isClockTime ||
                  cleanKey.contains('time') ||
                  cleanKey.contains('timing') ||
                  cleanKey.contains('schedule'))));
      if (isTime) return true;

      final nSetting = findMatchedNumericSetting(entryItem.key);
      final rMatch = rangeRegex.firstMatch(raw);
      final isNumeric = isExplicitNumCmd || nSetting != null || (rMatch != null && !isClockTime);
      if (isNumeric) return true;

      final matchedCyclicCmd = findMatchedCyclicCommand(entryItem.key, raw);
      final isCyclic = matchedCyclicCmd != null ||
          cmdUpper == 'CYCLIC' ||
          cmdUpper == 'CYCLE' ||
          cleanKey.contains('cyclic') ||
          cleanKey.contains('cycle');
      if (isCyclic) return true;

      final mRadio = findMatchedRadioSetting(entryItem.key);
      if (mRadio != null) return true;

      final tSetting = findMatchedTextSetting(entryItem.key);
      if (tSetting != null) return true;
      if (RegExp(r'^(slot|channel)\s*\d+$', caseSensitive: false).hasMatch(entryItem.key.trim()) ||
          cleanKey.startsWith('slot_') ||
          cleanKey.startsWith('channel_') ||
          cleanKey.contains('relay') ||
          raw.toLowerCase().startsWith('relay')) {
        return true;
      }

      final lower = raw.toLowerCase();
      final isBinaryVal = lower == '0' ||
          lower == '1' ||
          lower == 'on' ||
          lower == 'off' ||
          lower == 'true' ||
          lower == 'false';
      if (isBinaryVal) return true;

      if (findMatchingCommand(entryItem.key, true) != null ||
          findMatchingCommand(entryItem.key, false) != null) {
        return true;
      }

      return false;
    });

    IconData headerIcon = Icons.insert_chart_outlined_rounded;
    String headerTitle = 'Device Status';
    String headerTag = '';

    if (cmdUpper == 'NUMERIC' || cmdUpper == 'HOLDING' || cmdUpper == '/NUMERIC' || cmdUpper == '/HOLDING') {
      headerIcon = Icons.tune_rounded;
      headerTitle = (msg.title != null && msg.title!.trim().isNotEmpty)
          ? msg.title!.trim()
          : 'Device Settings';
      headerTag = '';
    } else if (cmdUpper == 'RADIO') {
      headerIcon = Icons.radio_button_checked_rounded;
      headerTitle = (msg.title != null && msg.title!.trim().isNotEmpty)
          ? msg.title!.trim()
          : 'Device Settings';
      headerTag = '';
    } else if (cmdUpper == 'TEXT' || cmdUpper == 'CONFIG') {
      headerIcon = Icons.edit_note_rounded;
      headerTitle = (msg.title != null && msg.title!.trim().isNotEmpty)
          ? msg.title!.trim()
          : 'Device Configuration';
      headerTag = '';
    } else if (cmdUpper == 'TIME') {
      headerIcon = Icons.access_time_filled_rounded;
      headerTitle = (msg.title != null && msg.title!.trim().isNotEmpty)
          ? msg.title!.trim()
          : 'Device Schedule';
      headerTag = 'Timings';
    } else if (cmdUpper == 'CYCLIC' || cmdUpper == 'CYCLE') {
      headerIcon = Icons.loop_rounded;
      headerTitle = (msg.title != null && msg.title!.trim().isNotEmpty)
          ? msg.title!.trim()
          : 'Cyclic Schedule';
      headerTag = '';
    } else if (cmdUpper == 'RESPONSE' || cmdUpper == 'TELEMETRY' || isResponseReport) {
      headerIcon = Icons.insert_chart_outlined_rounded;
      headerTitle = (msg.title != null && msg.title!.trim().isNotEmpty)
          ? msg.title!.trim()
          : 'Device Status';
      headerTag = '';
    } else if (msg.title != null && msg.title!.trim().isNotEmpty) {
      headerTitle = msg.title!.trim();
    }

    const double uniformBoxWidth = 88.0;
    const double uniformBoxHeight = 28.0;

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Full-width dark teal strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF132D2F) : const Color(0xFFE6F4F1),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1E383C) : const Color(0xFFD1E7E3),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      headerIcon,
                      size: 19,
                      color: telemetryTagColor,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      headerTitle,
                      style: TextStyle(
                        color: headerTitleColor,
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (headerTag.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F3637) : const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: telemetryTagColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          headerTag,
                          style: TextStyle(
                            color: telemetryTagColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Telemetry Data Rows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: items.asMap().entries.map((indexed) {
            final idx = indexed.key;
            final entry = indexed.value;
            final rawVal = entry.value.trim();
            final lowerVal = rawVal.toLowerCase();
            final isOff = lowerVal == 'off';
            final isOn = lowerVal == 'on';
            final displayVal = rawVal;

            // Map custom channel name ONLY if configured for explicit slot/channel and NOT a settings payload
            final cleanKeyLower = entry.key.toLowerCase().trim().replaceAll(' ', '_');
            final cleanKeyLookup = cleanKeyLower;
            final bool isPreserveSettingKey = cleanKeyLower == 'ps' ||
                cleanKeyLower == 'preserve_setting' ||
                cleanKeyLower == 'preserve_state' ||
                cleanKeyLower == 'preserve';
            final bool isPowerOnStateKey = cleanKeyLower == 'pop' ||
                cleanKeyLower == 'power_on_state' ||
                cleanKeyLower == 'power_on_preserve' ||
                cleanKeyLower == 'power_preserve';

            final RadioSetting? matchedRadioSetting = findMatchedRadioSetting(entry.key);
            final NumericSetting? matchedSetting = findMatchedNumericSetting(entry.key);
            final TextSetting? matchedTextSetting = findMatchedTextSetting(entry.key);
            final QuickCommand? matchedTimeCmd = findMatchedTimeCommand(entry.key, rawVal);
            final QuickCommand? matchedCyclicCmd = findMatchedCyclicCommand(entry.key, rawVal);
            final QuickCommand? matchedOnCmd = findMatchingCommand(entry.key, true);
            final QuickCommand? matchedOffCmd = findMatchingCommand(entry.key, false);

            final rMatch = rangeRegex.firstMatch(rawVal);
            final bool isClockTimeVal = RegExp(r'\b\d{1,2}:\d{2}\b').hasMatch(rawVal);

            final bool isExplicitNumericCommand = cmdUpper == 'NUMERIC' ||
                cmdUpper == '/NUMERIC' ||
                cmdUpper == 'HOLDING' ||
                cmdUpper == '/HOLDING' ||
                matchedSetting != null;

            final bool isTimeSetting = !cleanKeyLookup.contains('cyclic') &&
                !cleanKeyLookup.contains('cycle') &&
                !isExplicitNumericCommand &&
                (matchedTimeCmd != null ||
                    cmdUpper == 'TIME' ||
                    cmdUpper == 'TIMINGS' ||
                    isClockTimeVal ||
                    cleanKeyLookup.contains('time') ||
                    cleanKeyLookup.contains('timing') ||
                    cleanKeyLookup.contains('schedule'));

            final bool isExplicitNumeric = !isTimeSetting && (
                isExplicitNumericCommand ||
                (rMatch != null && !isClockTimeVal));

            final bool isCyclicSetting = !isExplicitNumeric && !isTimeSetting && (
                matchedCyclicCmd != null ||
                cmdUpper == 'CYCLIC' ||
                cmdUpper == 'CYCLE' ||
                cleanKeyLookup.contains('cyclic') ||
                cleanKeyLookup.contains('cycle') ||
                (RegExp(r'\d+\s*(?:min)?\s*[-–—]\s*\d+\s*(?:min)?', caseSensitive: false).hasMatch(rawVal) &&
                    (rawVal.toLowerCase().contains('min') || cleanKeyLookup.contains('min') || cleanKeyLookup.contains('cyclic') || cleanKeyLookup.contains('cycle'))));

            double minRangeVal = matchedSetting?.minValue ?? 0.0;
            double maxRangeVal = matchedSetting?.maxValue ?? (isExplicitNumeric ? 100.0 : 100.0);
            String rangeDisplayStr = matchedSetting?.range ?? '';
            String detectedUnit = matchedSetting?.unit ?? '';

            final fMatch = fullRangeBracketRegex.firstMatch(rawVal);
            if (fMatch != null) {
              final extracted = (fMatch.group(1) ?? fMatch.group(2) ?? fMatch.group(3) ?? '').trim();
              if (extracted.isNotEmpty && (rangeDisplayStr.isEmpty || rangeDisplayStr.length < extracted.length)) {
                rangeDisplayStr = extracted;
              }
            }

            if (rMatch != null) {
              final minStr = rMatch.group(1) ?? rMatch.group(3) ?? rMatch.group(5) ?? '0';
              final maxStr = rMatch.group(2) ?? rMatch.group(4) ?? rMatch.group(6) ?? '100';
              minRangeVal = double.tryParse(minStr) ?? minRangeVal;
              maxRangeVal = double.tryParse(maxStr) ?? maxRangeVal;
              if (rangeDisplayStr.isEmpty) {
                rangeDisplayStr = '$minStr - $maxStr';
              }
            } else if (isExplicitNumeric && rangeDisplayStr.isEmpty) {
              rangeDisplayStr = '${minRangeVal.toInt()} - ${maxRangeVal.toInt()}';
            }

            final cleanValWithoutRange = rawVal
                .replaceAll(fullRangeBracketRegex, '')
                .replaceAll(rangeRegex, '')
                .trim();
            final lowerCleanVal = cleanValWithoutRange.toLowerCase();

            // Check if this item is a text slot / renameable name (e.g. Relay 1, Relay 2, Slot 1, custom channel names)
            final bool isStatusOrNumericVal = lowerCleanVal == 'on' ||
                lowerCleanVal == 'off' ||
                lowerCleanVal == '0' ||
                lowerCleanVal == '1' ||
                lowerVal == 'on' ||
                lowerVal == 'off' ||
                lowerVal == 'running' ||
                lowerVal == 'stopped' ||
                lowerVal == 'ok' ||
                lowerVal == 'normal' ||
                lowerVal == 'active' ||
                double.tryParse(cleanValWithoutRange) != null;

            final bool isTextSetting = !isResponseReport &&
                !isStatusOrNumericVal &&
                !isExplicitNumeric &&
                (cmdUpper == 'TEXT' ||
                    cmdUpper == 'CONFIG' ||
                    (matchedTextSetting != null &&
                        (RegExp(r'^(slot|channel)\s*\d+$', caseSensitive: false).hasMatch(entry.key.trim()) ||
                            RegExp(r'^\d+$').hasMatch(entry.key.trim()) ||
                            cleanKeyLookup.startsWith('slot_') ||
                            cleanKeyLookup.startsWith('channel_'))));

            final isExplicitSlotKey = RegExp(r'^(slot|channel|relay)\s*\d+$', caseSensitive: false).hasMatch(entry.key.trim()) ||
                RegExp(r'^\d+$').hasMatch(entry.key.trim());
            String displayLabel = entry.key;

            if (isPreserveSettingKey) {
              displayLabel = 'PS';
            } else if (isPowerOnStateKey) {
              displayLabel = 'POP';
            } else if (!isSettingsPayload) {
              final slotNumMatch = RegExp(r'\d+').firstMatch(entry.key);
              final slotNum = slotNumMatch?.group(0);
              final customLabelRaw = (slotNum != null ? savedConfig['Relay $slotNum'] : null) ??
                  (slotNum != null ? savedConfig['relay $slotNum'] : null) ??
                  (slotNum != null ? savedConfig['Slot $slotNum'] : null) ??
                  (slotNum != null ? savedConfig['slot $slotNum'] : null) ??
                  (slotNum != null ? savedConfig['Channel $slotNum'] : null) ??
                  (slotNum != null ? savedConfig['channel $slotNum'] : null) ??
                  (slotNum != null ? savedConfig[slotNum] : null) ??
                  savedConfig[entry.key] ??
                  savedConfig[entry.key.toLowerCase()] ??
                  (slotNum != null ? textSettings[slotNum]?.value : null) ??
                  (slotNum != null ? textSettings['Relay $slotNum']?.value : null);
              final customLabel = customLabelRaw?.toString().trim();
              if (customLabel != null && customLabel.isNotEmpty) {
                displayLabel = customLabel;
              } else if (isExplicitSlotKey && slotNum != null && RegExp(r'^\d+$').hasMatch(entry.key.trim())) {
                displayLabel = 'Relay $slotNum';
              }
            }

            if (isTextSetting) {
              final slotKey = matchedTextSetting?.key ?? (textSettings.isNotEmpty && idx < textSettings.length ? textSettings.keys.elementAt(idx) : null);
              final custom = (slotKey != null ? savedConfig[slotKey] : null) ??
                  (slotKey != null ? savedConfig['Relay $slotKey'] : null) ??
                  (slotKey != null ? savedConfig['Slot $slotKey'] : null) ??
                  (slotKey != null ? savedConfig['Channel $slotKey'] : null) ??
                  savedConfig[entry.key] ??
                  (slotKey != null ? textSettings[slotKey]?.value : null);
              if (custom != null && custom.toString().trim().isNotEmpty) {
                displayLabel = custom.toString().trim();
              }
            }

            if (!isPreserveSettingKey && !isPowerOnStateKey && displayLabel.contains('_')) {
              displayLabel = displayLabel.split('_').map((w) {
                if (w.isEmpty) return '';
                if (w.toLowerCase() == 'ac') return 'AC';
                if (w.toLowerCase() == 'dc') return 'DC';
                if (w.toLowerCase() == 'hw') return 'HW';
                if (w.toLowerCase() == 'sw') return 'SW';
                if (w.toLowerCase() == 'drs') return 'DRS';
                if (w.toLowerCase() == 'ps') return 'PS';
                if (w.toLowerCase() == 'pop') return 'POP';
                return w[0].toUpperCase() + w.substring(1);
              }).join(' ');
            }

            Color badgeTextCol;
            Color badgeFillCol;
            Border badgeBorderCol;

            if (isOff) {
              badgeTextCol = const Color(0xFFEF5350);
              badgeFillCol = isDark ? const Color(0xFF1B2226) : const Color(0xFFFEF2F2);
              badgeBorderCol = Border.all(
                color: const Color(0xFFEF5350).withOpacity(0.45),
                width: 1.0,
              );
            } else if (isOn) {
              badgeTextCol = const Color(0xFF00A884);
              badgeFillCol = isDark ? const Color(0xFF142D2B) : const Color(0xFFF0FDF4);
              badgeBorderCol = Border.all(
                color: const Color(0xFF00A884).withOpacity(0.5),
                width: 1.0,
              );
            } else {
              badgeTextCol = badgeTextColor;
              badgeFillCol = badgeBg;
              badgeBorderCol = Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.06),
                width: 0.5,
              );
            }

            final bool isBinaryRange = (minRangeVal == 0.0 && maxRangeVal == 1.0 &&
                (rangeDisplayStr.trim() == '0 - 1' || rangeDisplayStr.trim() == '0-1' || rangeDisplayStr.contains('0 - 1') || rangeDisplayStr.contains('0-1')));

            // Dynamic binary setting: 0-1 range from NUMERIC/HOLDING, or RadioSetting, or status ON/OFF
            final bool isBinarySetting = !isTextSetting && (
                isBinaryRange ||
                isPreserveSettingKey ||
                isPowerOnStateKey ||
                matchedRadioSetting != null ||
                cmdUpper == 'RADIO' ||
                (!isExplicitNumeric && (matchedOnCmd != null || matchedOffCmd != null)));

            final bool hasNumericRange = !isBinarySetting && !isTimeSetting && !isCyclicSetting && !isTextSetting &&
                (rMatch != null || matchedSetting != null || isExplicitNumeric);

            if (detectedUnit.isEmpty) {
              final unitMatch = RegExp(r'[0-9.]+\s*([a-zA-Z%]+)').firstMatch(cleanValWithoutRange);
              if (unitMatch != null) {
                detectedUnit = unitMatch.group(1)!.trim();
              } else if (msg.title != null) {
                final tLower = msg.title!.toLowerCase();
                if (tLower.contains('minute') || tLower.contains('min')) {
                  detectedUnit = 'min';
                } else if (tLower.contains('second') || tLower.contains('sec')) {
                  detectedUnit = 'sec';
                } else if (tLower.contains('hour') || tLower.contains('hr')) {
                  detectedUnit = 'hr';
                }
              }
            }

            Widget valueWidget;
            Widget? actionWidget;

            if (isResponseReport) {
              // Strictly Read-Only Status Badges (No edit button, no tune icon, no tap popups)
              Color statusTextCol = badgeTextCol;
              Color statusBgCol = badgeBg;
              Border statusBorder = Border.all(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                width: 0.5,
              );

              if (lowerVal == 'running' || lowerVal == 'on' || lowerVal == 'ok' || lowerVal == 'normal' || lowerVal == 'active') {
                statusTextCol = const Color(0xFF00A884);
                statusBgCol = isDark ? const Color(0xFF142D2B) : const Color(0xFFF0FDF4);
                statusBorder = Border.all(color: const Color(0xFF00A884).withOpacity(0.5), width: 1.0);
              } else if (lowerVal == 'stopped' || lowerVal == 'off' || lowerVal == 'trip' || lowerVal == 'alarm' || lowerVal == 'fault') {
                statusTextCol = const Color(0xFFEF5350);
                statusBgCol = isDark ? const Color(0xFF1B2226) : const Color(0xFFFEF2F2);
                statusBorder = Border.all(color: const Color(0xFFEF5350).withOpacity(0.45), width: 1.0);
              }

              valueWidget = Container(
                constraints: const BoxConstraints(minWidth: 54),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: statusBgCol,
                  borderRadius: BorderRadius.circular(6),
                  border: statusBorder,
                ),
                child: Text(
                  displayVal,
                  style: TextStyle(
                    color: statusTextCol,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
              actionWidget = null;
            } else if (isTimeSetting) {
              void openTimeDialog() {
                final keyMsg = entry.key.toLowerCase().trim().replaceAll(' ', '_');
                _showTimePickerDialog(
                  context,
                  QuickCommand(
                    label: '$displayLabel ($rawVal)',
                    message: keyMsg,
                    type: 'time',
                  ),
                );
              }

              valueWidget = Tooltip(
                message: 'Tap to edit time schedule',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: openTimeDialog,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: uniformBoxWidth, minHeight: uniformBoxHeight),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF16252D) : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF2DD4BF).withOpacity(0.5),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      hasNumericRange ? cleanValWithoutRange : displayVal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF2DD4BF),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );

              actionWidget = Tooltip(
                message: 'Edit $displayLabel',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: openTimeDialog,
                  child: Container(
                    width: 26,
                    height: uniformBoxHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF16252D).withOpacity(0.6) : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF2DD4BF).withOpacity(0.35),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 15,
                      color: Color(0xFF2DD4BF),
                    ),
                  ),
                ),
              );
            } else if (isCyclicSetting) {
              void openCyclicDialog() {
                final keyMsg = entry.key.toLowerCase().trim().replaceAll(' ', '_');
                _showCyclicPickerDialog(
                  context,
                  QuickCommand(
                    label: '$displayLabel ($rawVal)',
                    message: keyMsg,
                    type: 'cyclic',
                  ),
                );
              }

              valueWidget = Tooltip(
                message: 'Tap to edit cyclic timer ($rawVal)',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: openCyclicDialog,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: uniformBoxWidth, minHeight: uniformBoxHeight),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF271C10) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.55),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      hasNumericRange ? cleanValWithoutRange : displayVal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );

              actionWidget = Tooltip(
                message: 'Edit $displayLabel',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: openCyclicDialog,
                  child: Container(
                    width: 26,
                    height: uniformBoxHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF271C10).withOpacity(0.6) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.35),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.repeat_rounded,
                      size: 15,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
              );
            } else if (isTextSetting) {
              void openSlotDialog() {
                String slotId;
                if (matchedTextSetting != null && matchedTextSetting.key.isNotEmpty) {
                  slotId = matchedTextSetting.key;
                } else if (textSettings.isNotEmpty && idx < textSettings.length) {
                  slotId = textSettings.keys.elementAt(idx);
                } else if (RegExp(r'^\d+$').hasMatch(entry.key.trim())) {
                  slotId = entry.key.trim();
                } else {
                  slotId = '${idx + 1}';
                }
                _showTextSlotEditDialog(
                  context,
                  slotId: slotId,
                  label: displayLabel,
                  currentName: rawVal,
                  explicitRange: matchedTextSetting?.range.isNotEmpty == true ? matchedTextSetting!.range : rangeDisplayStr,
                );
              }

              valueWidget = Tooltip(
                message: 'Tap to edit $displayLabel',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: openSlotDialog,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: uniformBoxWidth, minHeight: uniformBoxHeight),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF16252D) : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF2DD4BF).withOpacity(0.5),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      displayVal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF2DD4BF),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );

              actionWidget = Tooltip(
                message: 'Edit $displayLabel',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: openSlotDialog,
                  child: Container(
                    width: 26,
                    height: uniformBoxHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF16252D).withOpacity(0.6) : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF2DD4BF).withOpacity(0.35),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 15,
                      color: Color(0xFF2DD4BF),
                    ),
                  ),
                ),
              );
            } else if (isBinarySetting) {
              final bool isBinaryOn = lowerCleanVal == '1' ||
                  lowerCleanVal == 'on' ||
                  lowerCleanVal == 'true' ||
                  displayVal.trim() == '1';
              final bool isPreserveVal = lowerCleanVal == '2' ||
                  lowerCleanVal == 'preserve' ||
                  displayVal.trim() == '2';
              final dynamic currentValDynamic = cleanValWithoutRange.isNotEmpty ? cleanValWithoutRange : rawVal;
              final targetKey = matchedRadioSetting?.key ??
                  matchedSetting?.key ??
                  (isPreserveSettingKey ? 'PS' : (isPowerOnStateKey ? 'POP' : entry.key));
              final backendRange = (isPreserveSettingKey || isPowerOnStateKey)
                  ? '0 - 1'
                  : (matchedSetting?.range ?? (rangeDisplayStr.isNotEmpty ? rangeDisplayStr : '0 - 1'));
              final bool isZeroOrOne = lowerCleanVal == '0' ||
                  lowerCleanVal == '1' ||
                  displayVal.trim() == '0' ||
                  displayVal.trim() == '1';
              final backendType = (matchedRadioSetting != null || isPreserveSettingKey || isPowerOnStateKey || cmdUpper == 'RADIO')
                  ? 'RADIO'
                  : (matchedSetting != null ? 'NUMERIC' : (isZeroOrOne ? 'NUMERIC' : 'RADIO'));

              final List<String> backendOptions;
              if (matchedRadioSetting != null && matchedRadioSetting.options.isNotEmpty) {
                final filtered = matchedRadioSetting.options.where((o) => o != '2' && o.toLowerCase() != 'preserve').toList();
                backendOptions = filtered.isNotEmpty ? filtered : const ['1', '0'];
              } else if (lowerCleanVal == 'on' || lowerCleanVal == 'off') {
                backendOptions = const ['On', 'Off'];
              } else {
                backendOptions = const ['1', '0'];
              }

              void openBinaryDialog() {
                _showBinarySettingDialog(
                  context,
                  paramKey: targetKey,
                  label: displayLabel,
                  currentValue: currentValDynamic,
                  range: backendRange,
                  payloadType: backendType,
                  options: backendOptions,
                  onCommand: matchedOnCmd,
                  offCommand: matchedOffCmd,
                );
              }

              String badgeDisplayStr;
              if (isPreserveSettingKey || isPowerOnStateKey) {
                badgeDisplayStr = isBinaryOn ? 'ON (1)' : 'OFF (0)';
              } else if (hasNumericRange) {
                badgeDisplayStr = cleanValWithoutRange;
              } else if (isBinaryRange) {
                badgeDisplayStr = isBinaryOn ? '1' : '0';
              } else {
                badgeDisplayStr = displayVal;
              }

              valueWidget = Tooltip(
                message: 'Tap to change $displayLabel (${backendOptions.join(" / ")})',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: openBinaryDialog,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: uniformBoxWidth, minHeight: uniformBoxHeight),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF16252D) : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF2DD4BF).withOpacity(0.5),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      badgeDisplayStr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF2DD4BF),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );

              actionWidget = Tooltip(
                message: 'Edit $displayLabel',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: openBinaryDialog,
                  child: Container(
                    width: 26,
                    height: uniformBoxHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF16252D).withOpacity(0.6) : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF2DD4BF).withOpacity(0.35),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 15,
                      color: Color(0xFF2DD4BF),
                    ),
                  ),
                ),
              );
            } else if (hasNumericRange) {
              void openNumericDialog() {
                _showNumericRangeDialog(
                  context,
                  paramKey: matchedSetting?.key ?? entry.key,
                  label: displayLabel,
                  rawValue: cleanValWithoutRange,
                  range: rangeDisplayStr,
                  minVal: minRangeVal,
                  maxVal: maxRangeVal,
                  unit: detectedUnit,
                );
              }

              valueWidget = Tooltip(
                message: 'Tap to edit $displayLabel',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: openNumericDialog,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: uniformBoxWidth, minHeight: uniformBoxHeight),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF16252D) : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF2DD4BF).withOpacity(0.5),
                        width: 1.0,
                      ),
                    ),
                    child: Builder(
                      builder: (context) {
                        final parsedOpts = parseDiscreteOptions(
                          rangeDisplayStr,
                          paramKey: matchedSetting?.key ?? entry.key,
                          label: displayLabel,
                        );
                        String badgeDisplay = cleanValWithoutRange;
                        if (parsedOpts.isNotEmpty) {
                          final match = parsedOpts.firstWhere(
                            (o) => o.value == cleanValWithoutRange || o.value == int.tryParse(cleanValWithoutRange)?.toString(),
                            orElse: () => DiscreteOption(value: cleanValWithoutRange, label: cleanValWithoutRange, fullText: cleanValWithoutRange),
                          );
                          badgeDisplay = match.label.isNotEmpty ? '${match.label} (${match.value})' : cleanValWithoutRange;
                        }
                        if (badgeDisplay.trim().isEmpty) {
                          badgeDisplay = detectedUnit.isNotEmpty ? '0 $detectedUnit' : '0';
                        }
                        return Text(
                          badgeDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF2DD4BF),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );

              actionWidget = Tooltip(
                message: 'Edit $displayLabel',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: openNumericDialog,
                  child: Container(
                    width: 26,
                    height: uniformBoxHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF16252D).withOpacity(0.6) : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF2DD4BF).withOpacity(0.35),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 15,
                      color: Color(0xFF2DD4BF),
                    ),
                  ),
                ),
              );
            } else if (matchedRadioSetting != null) {
              final opts = matchedRadioSetting.options;
              void openRadioDialog() {
                _showRadioOptionDialog(
                  context,
                  fieldKey: matchedRadioSetting.key,
                  label: matchedRadioSetting.label,
                  currentValue: matchedRadioSetting.value,
                  options: opts,
                );
              }

              valueWidget = Tooltip(
                message: 'Tap to change: ${opts.join(" / ")}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: openRadioDialog,
                  child: Container(
                    width: uniformBoxWidth,
                    height: uniformBoxHeight,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF16252D) : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF2DD4BF).withOpacity(0.5),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      matchedRadioSetting.value.isNotEmpty ? matchedRadioSetting.value : rawVal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF2DD4BF),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );

              actionWidget = Tooltip(
                message: 'Edit ${matchedRadioSetting.label}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: openRadioDialog,
                  child: Container(
                    width: 26,
                    height: uniformBoxHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF16252D).withOpacity(0.6) : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF2DD4BF).withOpacity(0.35),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 15,
                      color: Color(0xFF2DD4BF),
                    ),
                  ),
                ),
              );
            } else {
              valueWidget = Container(
                constraints: const BoxConstraints(minWidth: 54),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5.5),
                decoration: BoxDecoration(
                  color: isOff
                      ? (isDark ? const Color(0xFF1B2226) : const Color(0xFFFEF2F2))
                      : (isOn
                          ? (isDark ? const Color(0xFF142D2B) : const Color(0xFFF0FDF4))
                          : (isDark ? const Color(0xFF182730) : const Color(0xFFF1F5F9))),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOff
                        ? const Color(0xFFEF5350).withOpacity(0.45)
                        : (isOn
                            ? const Color(0xFF00A884).withOpacity(0.5)
                            : (isDark ? const Color(0xFF2D434E).withOpacity(0.6) : const Color(0xFFCBD5E1))),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  displayVal,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isOff
                        ? const Color(0xFFEF5350)
                        : (isOn
                            ? const Color(0xFF00A884)
                            : (isDark ? Colors.white : const Color(0xFF0F172A))),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
              actionWidget = null;
            }

            if (isTextSetting) {
              final effectiveName = displayLabel;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  border: idx < items.length - 1
                      ? Border(
                          bottom: BorderSide(
                            color: isDark ? const Color(0xFF1E353D) : const Color(0xFFE2E8F0),
                            width: 0.8,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () {
                          String slotId;
                          if (matchedTextSetting != null && matchedTextSetting.key.isNotEmpty) {
                            slotId = matchedTextSetting.key;
                          } else if (textSettings.isNotEmpty && idx < textSettings.length) {
                            slotId = textSettings.keys.elementAt(idx);
                          } else if (RegExp(r'^\d+$').hasMatch(entry.key.trim())) {
                            slotId = entry.key.trim();
                          } else {
                            slotId = '${idx + 1}';
                          }
                          _showTextSlotEditDialog(
                            context,
                            slotId: slotId,
                            label: effectiveName,
                            currentName: rawVal,
                            explicitRange: matchedTextSetting?.range.isNotEmpty == true ? matchedTextSetting!.range : rangeDisplayStr,
                          );
                        },
                        child: Text(
                          effectiveName,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    actionWidget ?? const SizedBox(width: 26),
                  ],
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: idx < items.length - 1
                    ? Border(
                        bottom: BorderSide(
                          color: isDark ? const Color(0xFF1E353D) : const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayLabel,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  valueWidget,
                  if (cardHasAnyAction) ...[
                    const SizedBox(width: 8),
                    actionWidget ?? const SizedBox(width: 26),
                  ],
                ],
              ),
            );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  bool _isClickableReport(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('__CLICKABLE__:')) return true;
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final Map parsed = jsonDecode(trimmed);
        return parsed['type']?.toString().toUpperCase() == 'CLICKABLE';
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  List<Map<String, String>> _extractClickableItems(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('__CLICKABLE__:')) {
      final jsonStr = trimmed.substring('__CLICKABLE__:'.length).trim();
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          return decoded.map((item) {
            if (item is Map) {
              final cmd = (item['command'] ?? item['action'] ?? item['key'] ?? item['value'] ?? '').toString().trim();
              final label = (item['label'] ?? item['description'] ?? item['title'] ?? cmd).toString().trim();
              return {'command': cmd, 'label': label};
            }
            final cmd = item.toString().trim();
            return {'command': cmd, 'label': cmd};
          }).where((e) => e['command']!.isNotEmpty).toList();
        } else if (decoded is Map) {
          return decoded.entries.map((e) {
            return {'command': e.key.toString().trim(), 'label': e.value.toString().trim()};
          }).where((e) => e['command']!.isNotEmpty).toList();
        }
      } catch (_) {}
    } else if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final Map parsed = jsonDecode(trimmed);
        if (parsed['type']?.toString().toUpperCase() == 'CLICKABLE') {
          final data = parsed['data'];
          if (data is List) {
            return data.map((item) {
              if (item is Map) {
                final cmd = (item['command'] ?? item['action'] ?? item['key'] ?? item['value'] ?? '').toString().trim();
                final label = (item['label'] ?? item['description'] ?? item['title'] ?? cmd).toString().trim();
                return {'command': cmd, 'label': label};
              }
              final cmd = item.toString().trim();
              return {'command': cmd, 'label': cmd};
            }).where((e) => e['command']!.isNotEmpty).toList();
          } else if (data is Map) {
            return data.entries.map((e) {
              return {'command': e.key.toString().trim(), 'label': e.value.toString().trim()};
            }).where((e) => e['command']!.isNotEmpty).toList();
          }
        }
      } catch (_) {}
    }
    return [];
  }

  Widget _buildClickableCard(
    ChatMessage msg,
    List<Map<String, String>> items,
    bool isDark,
    Color accentGreen,
    Color secondaryTextColor,
  ) {
    final cardBg = isDark ? const Color(0xFF132228) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E353D) : const Color(0xFFCBD5E1);
    final headerTitleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final linkColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);

    String headerTitle = (msg.title != null && msg.title!.trim().isNotEmpty)
        ? msg.title!.trim()
        : 'Device Settings';
    final rawCommand = (msg.command ?? '').replaceAll('/', '').replaceAll('_', ' ').trim();
    if (msg.title != null && msg.title!.trim().isNotEmpty) {
      headerTitle = msg.title!.trim();
    } else if (rawCommand.isNotEmpty && rawCommand.toUpperCase() != 'CLICKABLE') {
      headerTitle = rawCommand.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');
    } else if (items.any((it) => (it['command'] ?? '').toLowerCase().contains('status'))) {
      headerTitle = 'Device Status';
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A884).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.developer_board_rounded,
                      size: 16,
                      color: Color(0xFF00A884),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    headerTitle,
                    style: TextStyle(
                      color: headerTitleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Clickable links list dynamically driven by backend response
          ...items.asMap().entries.map((indexed) {
            final item = indexed.value;
            final cmd = (item['command'] ?? '').trim();
            String label = (item['label'] ?? cmd).trim();
            if (label == cmd) {
              label = cmd.replaceAll('/', '').replaceAll('_', ' ').trim();
              label = label.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');
            }

            final devId = widget.device.deviceId.isNotEmpty ? widget.device.deviceId : widget.device.id;
            final savedConfig = context.watch<DeviceProvider>().getDeviceSavedConfig(devId);

            final slotMatch = RegExp(r'\d+').firstMatch('$label $cmd');
            final slotId = slotMatch?.group(0);
            if (slotId != null) {
              final customLabel = savedConfig['Relay $slotId'] ??
                  savedConfig['relay $slotId'] ??
                  savedConfig['Channel $slotId'] ??
                  savedConfig['channel $slotId'] ??
                  savedConfig['Slot $slotId'] ??
                  savedConfig['slot $slotId'] ??
                  savedConfig[slotId] ??
                  savedConfig[label] ??
                  savedConfig[cmd];
              if (customLabel != null && customLabel.toString().trim().isNotEmpty) {
                label = customLabel.toString().trim();
              }
            }

            // Target command sent is exactly what backend specified
            final targetCmd = cmd.isNotEmpty ? cmd : label;

            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        hoverColor: linkColor.withOpacity(0.08),
                        splashColor: linkColor.withOpacity(0.14),
                        onTap: () {
                          _handleSend(targetCmd, label);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.link_rounded,
                                size: 16,
                                color: linkColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: linkColor,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: linkColor.withOpacity(0.85),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 11,
                                color: linkColor.withOpacity(0.6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Footer timestamp
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                msg.formattedTime,
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark, Color accentGreen) {
    final isUser = msg.isUser;
    final primaryTextColor = isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
    final secondaryTextColor = isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight;

    // Check if device reply is CLICKABLE link list (Zero hardcoding)
    if (!isUser && _isClickableReport(msg.text)) {
      final items = _extractClickableItems(msg.text);
      if (items.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildClickableCard(msg, items, isDark, accentGreen, secondaryTextColor),
          ),
        );
      }
    }

    // Check if device reply is structured status/telemetry
    if (!isUser && _isTelemetryReport(msg.text)) {
      final lines = msg.text
          .trim()
          .split('\n')
          .where((l) => l.trim().isNotEmpty && l.contains(':'))
          .toList();
      final items = lines.map((l) {
        final colonIdx = l.indexOf(':');
        final key = l.substring(0, colonIdx).trim();
        final val = l.substring(colonIdx + 1).trim();
        return MapEntry(key, val);
      }).toList();

      final currentDevice = context.watch<DeviceProvider>().selectedDevice ?? widget.device;

      final bool hasTelemetryKeys = items.any((e) {
        final k = e.key.toLowerCase();
        return k.contains('voltage') ||
            k.contains('current') ||
            k.contains('motor') ||
            k.contains('tank') ||
            k.contains('alarm') ||
            k.contains('level');
      });
      // Only show Device Information card if the message itself is explicitly a device info report
      final bool isDeviceInfoMessage = !hasTelemetryKeys && items.any((e) =>
          e.key.toLowerCase().contains('hardware version') ||
          e.key.toLowerCase().contains('software version') ||
          (e.key.toLowerCase().trim() == 'device id' || e.key.toLowerCase().trim() == 'device_id'));

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: isDeviceInfoMessage
              ? _buildDeviceInfoCard(currentDevice, items, isDark, accentGreen, secondaryTextColor)
              : _buildTelemetryCard(msg, items, isDark, accentGreen, secondaryTextColor),
        ),
      );
    }

    final isStatusUserMsg = isUser &&
        (msg.text.toLowerCase().contains('status') ||
            msg.text.toLowerCase().trim() == 'device' ||
            msg.command?.toLowerCase().contains('status') == true);

    final userBubbleColor = isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3);
    final deviceBubbleColor = isDark ? AppTheme.cardBg : Colors.white;

    // Clean bubble text: filter out commands from message body
    final filteredLines = msg.text.split('\n').where((l) => !l.trim().startsWith('/')).join('\n');
    final bubbleContent = CommandText(
      text: filteredLines.isNotEmpty ? filteredLines : msg.text,
      isUser: isUser,
      isDark: isDark,
      accentGreen: accentGreen,
      primaryTextColor: primaryTextColor,
      onCommandTap: (cmd) => _handleSend(cmd),
    );

    final isResendable = isUser &&
        !msg.text.startsWith('Sent Configuration:') &&
        !msg.text.startsWith('Sent Wi-Fi Setup:');

    // WhatsApp-styled pill for status query buttons
    if (isStatusUserMsg) {
      final t = msg.text.trim();
      final tLower = t.toLowerCase();
      String bubbleText = t;
      if (t == '/status' || tLower == 'status' || tLower == 'device' || tLower == 'device status') {
        bubbleText = 'Get device status';
      } else if (tLower == 'live status') {
        bubbleText = 'Get Live Status';
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                final cmd = msg.command ?? msg.text;
                _handleSend(cmd, bubbleText);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A884),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bubbleText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.refresh_rounded,
                      size: 15,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: isResendable
                ? () {
                    final cmd = msg.command ?? msg.text;
                    _handleSend(cmd, msg.text);
                  }
                : null,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? userBubbleColor : deviceBubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    bubbleContent,
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isResendable) ...[
                          Icon(
                            Icons.replay_rounded,
                            size: 11,
                            color: isDark ? Colors.white.withOpacity(0.7) : AppTheme.textSecondaryLight,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          msg.formattedTime,
                          style: TextStyle(
                            color: isUser
                                ? (isDark ? Colors.white.withOpacity(0.7) : AppTheme.textSecondaryLight)
                                : secondaryTextColor,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  String _getDeviceInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'D';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final p1 = parts[0].isNotEmpty ? parts[0][0] : '';
      final p2 = parts[1].isNotEmpty ? parts[1][0] : '';
      final combined = '$p1$p2'.trim();
      if (combined.isNotEmpty) return combined.toUpperCase();
    }
    if (clean.length >= 2) {
      return clean.substring(0, 2).toUpperCase();
    }
    return clean[0].toUpperCase();
  }

  Widget _buildEmptyState(
    Device currentDevice,
    bool isDark,
    Color textPrimaryColor,
    Color textSecondaryColor,
    Color accentGreen,
  ) {
    final devId = currentDevice.deviceId.isNotEmpty ? currentDevice.deviceId : currentDevice.id;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 46,
            backgroundColor: isDark ? const Color(0xFF24343D) : const Color(0xFFCFD8DC),
            backgroundImage: currentDevice.imageUrl != null
                ? NetworkImage(currentDevice.imageUrl!)
                : null,
            child: currentDevice.imageUrl == null
                ? Text(
                    _getDeviceInitials(currentDevice.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 24),
          Text(
            'Start chat with ${currentDevice.name}',
            style: TextStyle(
              color: textPrimaryColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Request a live status report to see device data\nand available commands.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textSecondaryColor,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: currentDevice.isOnline
                ? () {
                    final cmds = context.read<DeviceProvider>().getQuickCommands(devId);
                    final statusCmd = cmds.firstWhere(
                      (c) => c.message == '/status' || c.label.toLowerCase().contains('status'),
                      orElse: () => const QuickCommand(label: 'Get device status', message: '/status'),
                    );
                    _handleSend(statusCmd.message, statusCmd.label);
                  }
                : null,
            icon: Icon(
              Icons.show_chart_rounded,
              size: 20,
              color: currentDevice.isOnline
                  ? Colors.white
                  : (isDark ? const Color(0xFF6E8290) : const Color(0xFF94A3B8)),
            ),
            label: Text(
              'Get device status',
              style: TextStyle(
                color: currentDevice.isOnline
                    ? Colors.white
                    : (isDark ? const Color(0xFF6E8290) : const Color(0xFF94A3B8)),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentGreen,
              disabledBackgroundColor: isDark ? const Color(0xFF24343D) : const Color(0xFFE2E8F0),
              foregroundColor: Colors.white,
              disabledForegroundColor: isDark ? const Color(0xFF6E8290) : const Color(0xFF94A3B8),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

class CommandText extends StatefulWidget {
  final String text;
  final bool isUser;
  final bool isDark;
  final Color accentGreen;
  final Color primaryTextColor;
  final Function(String) onCommandTap;

  const CommandText({
    super.key,
    required this.text,
    required this.isUser,
    required this.isDark,
    required this.accentGreen,
    required this.primaryTextColor,
    required this.onCommandTap,
  });

  @override
  State<CommandText> createState() => _CommandTextState();
}

class _CommandTextState extends State<CommandText> {
  late List<TapGestureRecognizer> _recognizers;

  @override
  void initState() {
    super.initState();
    _recognizers = [];
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Clear old recognizers if rebuilding
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final RegExp commandRegex = RegExp(r'(/\w+)|(\b(?:On|Off)\b)');
    final Iterable<RegExpMatch> matches = commandRegex.allMatches(widget.text);

    if (matches.isEmpty) {
      return Text(
        widget.text,
        style: TextStyle(
          color: widget.isUser
              ? (widget.isDark ? Colors.white : AppTheme.textPrimaryLight)
              : widget.primaryTextColor,
          fontSize: 14.5,
          height: 1.3,
          fontFamily: 'monospace',
        ),
      );
    }

    List<TextSpan> spans = [];
    int lastMatchEnd = 0;
    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: widget.text.substring(lastMatchEnd, match.start)));
      }
      
      if (match.group(1) != null) {
        final command = match.group(1)!;
        final recognizer = TapGestureRecognizer()..onTap = () => widget.onCommandTap(command);
        _recognizers.add(recognizer);

        spans.add(
          TextSpan(
            text: command,
            style: TextStyle(
              color: widget.accentGreen,
              fontWeight: FontWeight.w600,
            ),
            recognizer: recognizer,
          ),
        );
      } else if (match.group(2) != null) {
        final status = match.group(2)!;
        final color = status == 'On' ? widget.accentGreen : const Color(0xFFF87171); // Red for Off
        spans.add(
          TextSpan(
            text: status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
      
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: widget.isUser
              ? (widget.isDark ? Colors.white : AppTheme.textPrimaryLight)
              : widget.primaryTextColor,
          fontSize: 14.5,
          height: 1.3,
          fontFamily: 'monospace', // To make device output align better like in the image
        ),
        children: spans,
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// Device Configuration Dialog
// -----------------------------------------------------------------------------

class DeviceConfigDialog extends StatefulWidget {
  final DeviceProvider provider;
  final Device device;

  const DeviceConfigDialog({
    super.key,
    required this.provider,
    required this.device,
  });

  @override
  State<DeviceConfigDialog> createState() => _DeviceConfigDialogState();
}

class _DeviceConfigDialogState extends State<DeviceConfigDialog> {
  final List<ConfigItem> configItems = [];

  @override
  void initState() {
    super.initState();
    refillData();
  }

  void refillData({bool isReset = false}) {
    for (final item in configItems) {
      item.dispose();
    }
    configItems.clear();

    final devId = widget.device.deviceId.isNotEmpty ? widget.device.deviceId : widget.device.id;
    if (isReset) {
      widget.provider.clearDeviceConfiguration(devId);
    }
    final savedConfig = isReset ? <String, dynamic>{} : widget.provider.getDeviceSavedConfig(devId);

    // Load status telemetry / configuration items from device status
    final latestData = widget.provider.getLatestDeviceStatusData(devId) ??
        widget.provider.getLatestDeviceStatusData(widget.device.id);

    final Map<String, dynamic> telemetrySource = {};
    if (latestData != null && latestData.isNotEmpty) {
      telemetrySource.addAll(latestData);
    }

    final controlKeys = {
      'deviceid', 'firmwareversion', 'availablecommands', 'additionalcommands',
      'type', 'success', 'message', 'command', 'timestamp', 'id', 'version', 'lastseen',
      'hardwareversion', 'softwareversion', 'status', 'model', 'name', 'action',
      'connected', 'ip', 'rssi', 'mac', 'raw'
    };
    telemetrySource.removeWhere((k, v) => controlKeys.contains(k.toLowerCase().trim()));

    // If telemetrySource is empty, inspect the device's message history for live status/telemetry
    if (telemetrySource.isEmpty) {
      final dev = widget.provider.devices.firstWhere(
        (d) => d.id == widget.device.id || d.deviceId == widget.device.deviceId,
        orElse: () => widget.device,
      );
      for (final msg in dev.messages.reversed) {
        if (!msg.isUser && msg.text.contains(':')) {
          final lines = msg.text
              .trim()
              .split('\n')
              .where((l) => l.trim().isNotEmpty && l.contains(':'))
              .toList();
          if (lines.isNotEmpty) {
            for (final line in lines) {
              final colonIdx = line.indexOf(':');
              final k = line.substring(0, colonIdx).trim();
              final v = line.substring(colonIdx + 1).trim();
              final kLower = k.toLowerCase().trim();
              if (k.isNotEmpty &&
                  !controlKeys.contains(kLower) &&
                  !kLower.contains('version') &&
                  !kLower.contains('device id') &&
                  !kLower.contains('hardware') &&
                  !kLower.contains('software') &&
                  !kLower.startsWith('status:') &&
                  !kLower.startsWith('sent ')) {
                telemetrySource[k] = v;
              }
            }
            if (telemetrySource.isNotEmpty) break;
          }
        }
      }
      telemetrySource.removeWhere((k, v) => controlKeys.contains(k.toLowerCase().trim()));
      if (telemetrySource.isNotEmpty) {
        widget.provider.cacheTelemetryStatus(
          widget.device.deviceId,
          widget.device.id,
          telemetrySource,
        );
      }
    }

    telemetrySource.removeWhere((k, v) => controlKeys.contains(k.toLowerCase().trim()));

    int chIdx = 1;
    for (final entry in telemetrySource.entries) {
      final key = entry.key;
      final val = entry.value;
      final slotNumMatch = RegExp(r'\d+').firstMatch(key);
      final slotNum = slotNumMatch?.group(0);
      final savedNameRaw = (slotNum != null ? savedConfig['Relay $slotNum'] : null) ??
          (slotNum != null ? savedConfig['relay $slotNum'] : null) ??
          (slotNum != null ? savedConfig['Channel $slotNum'] : null) ??
          (slotNum != null ? savedConfig['channel $slotNum'] : null) ??
          (slotNum != null ? savedConfig['Slot $slotNum'] : null) ??
          (slotNum != null ? savedConfig['slot $slotNum'] : null) ??
          (slotNum != null ? savedConfig[slotNum] : null) ??
          savedConfig[key] ??
          savedConfig['Channel $chIdx'] ??
          savedConfig['Relay $chIdx'] ??
          savedConfig[key.toLowerCase()];
      final sName = savedNameRaw?.toString().trim();
      final hasConflict = sName != null &&
          sName.isNotEmpty &&
          sName.toLowerCase() != key.toLowerCase() &&
          telemetrySource.keys.any((k) => k.toLowerCase() == sName.toLowerCase());
      final initialText = isReset || hasConflict
          ? key
          : ((sName != null && sName.isNotEmpty) ? sName : key);
      final isSlider = QuickCommand.detectIsSlider(key, initialText);
      double sliderVal = 0.0;
      if (val is num) {
        sliderVal = val.toDouble();
      } else if (val is String) {
        final cleanedVal = val.replaceAll('%', '').trim();
        sliderVal = double.tryParse(cleanedVal) ?? 0.0;
      }
      final savedSliderVal = widget.provider.getDeviceSliderValue(devId, key);
      if (savedSliderVal != null) sliderVal = savedSliderVal;

      configItems.add(
        ConfigItem(
          key: key,
          value: initialText,
          isSlider: isSlider,
          sliderValue: sliderVal,
          minValue: 0.0,
          maxValue: 100.0,
        ),
      );
      chIdx++;
    }
  }

  @override
  void dispose() {
    for (final item in configItems) {
      item.dispose();
    }
    super.dispose();
  }

  Widget _buildChannelTile(ConfigItem item, int index, bool isDark, String devId) {
    final currentText = item.valueController.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Channel ${index + 1}',
                style: const TextStyle(
                  color: Color(0xFF2DD4BF),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentText.isNotEmpty ? currentText : item.key,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: item.valueController,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? const Color(0xFF1E282D) : const Color(0xFFF1F5F9),
              hintText: 'Enter name for Channel ${index + 1}',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
              suffixIcon: item.valueController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: isDark ? Colors.white60 : Colors.black54,
                      onPressed: () {
                        setState(() {
                          item.valueController.clear();
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF00A884), width: 1.2),
              ),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (item.isSlider) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${item.minValue.toInt()}',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF00A884),
                      thumbColor: const Color(0xFF00A884),
                      inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey[300],
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: item.sliderValue.clamp(item.minValue, item.maxValue),
                      min: item.minValue,
                      max: item.maxValue,
                      onChanged: (newVal) {
                        setState(() {
                          item.sliderValue = newVal;
                        });
                        widget.provider.updateSliderValue(devId, item.key, newVal, sendCommand: false);
                      },
                    ),
                  ),
                ),
                Text(
                  '${item.maxValue.toInt()}',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final devId = widget.device.deviceId.isNotEmpty ? widget.device.deviceId : widget.device.id;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF162024) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF00A884).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.tune_rounded, color: Color(0xFF00A884), size: 20),
          ),
          const SizedBox(width: 10),
          const Text('Device Configuration', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CHANNELS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFF2DD4BF),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: configItems.isEmpty ? null : () => setState(() => refillData(isReset: true)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: Color(0xFF00A884),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF00A884),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (configItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 8.0),
                  child: Center(
                    child: Text(
                      'No status configuration data available.\nPlease query device status to load channels.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: isDark ? const Color(0xFF8696A0) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                )
              else ...[
                const SizedBox(height: 14),
                ...configItems.asMap().entries.map((e) => _buildChannelTile(e.value, e.key, isDark, devId)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: configItems.isEmpty
                  ? null
                  : () {
                      final Map<String, dynamic> configData = {};
                      for (int i = 0; i < configItems.length; i++) {
                        final item = configItems[i];
                        final val = item.valueController.text.trim();
                        final effectiveVal = val.isNotEmpty ? val : item.key;
                        final slotNumMatch = RegExp(r'\d+').firstMatch(item.key);
                        final slotNum = slotNumMatch?.group(0) ?? '${i + 1}';
                        configData[item.key] = effectiveVal;
                        configData['Channel $slotNum'] = effectiveVal;
                        configData['channel $slotNum'] = effectiveVal;
                        configData['Relay $slotNum'] = effectiveVal;
                        configData['relay $slotNum'] = effectiveVal;
                        configData['Slot $slotNum'] = effectiveVal;
                        configData['slot $slotNum'] = effectiveVal;
                        configData[slotNum] = effectiveVal;
                        if (item.isSlider) {
                          configData['${item.key}_value'] = item.sliderValue;
                          widget.provider.updateSliderValue(devId, item.key, item.sliderValue, sendCommand: false);
                        }
                      }

                      widget.provider.sendConfig(devId, configData);
                      // Immediately query status so new channel names are visible right away
                      final cmds = widget.provider.getQuickCommands(devId);
                      final statusCmd = cmds.firstWhere(
                        (c) => c.message.toLowerCase() == '/status' || c.label.toLowerCase().contains('status'),
                        orElse: () => const QuickCommand(label: 'Get device status', message: '/status'),
                      );
                      widget.provider.sendMessage(statusCmd.message, displayText: 'Get device status', targetDeviceId: devId);
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Configuration sent successfully')),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A884),
                disabledBackgroundColor: isDark ? const Color(0xFF2A383F) : const Color(0xFFE2E8F0),
                foregroundColor: Colors.white,
                disabledForegroundColor: isDark ? const Color(0xFF6E8290) : const Color(0xFF94A3B8),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Send', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }
}

class ConfigItem {
  final String key;
  final TextEditingController valueController;
  final bool isSlider;
  double sliderValue;
  final double minValue;
  final double maxValue;
  final double step;

  ConfigItem({
    required this.key,
    required String value,
    this.isSlider = false,
    this.sliderValue = 0.0,
    this.minValue = 0.0,
    this.maxValue = 100.0,
    this.step = 1.0,
  }) : valueController = TextEditingController(text: value);

  void dispose() {
    valueController.dispose();
  }
}

// -----------------------------------------------------------------------------
// Wi-Fi Setup Dialog
// -----------------------------------------------------------------------------

class WifiSetupDialog extends StatefulWidget {
  final DeviceProvider provider;
  final Device device;

  const WifiSetupDialog({
    super.key,
    required this.provider,
    required this.device,
  });

  @override
  State<WifiSetupDialog> createState() => _WifiSetupDialogState();
}

class _WifiSetupDialogState extends State<WifiSetupDialog> {
  final _ssidController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscurePassword = true;
  String? _ssidError;

  @override
  void dispose() {
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.wifi, color: Color(0xFF00A884)),
          SizedBox(width: 8),
          Text('Wi-Fi Setup'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the Wi-Fi credentials to configure on your device.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ssidController,
                decoration: InputDecoration(
                  labelText: 'Wi-Fi SSID',
                  hintText: 'e.g. Home Network',
                  prefixIcon: const Icon(Icons.wifi_rounded, size: 20),
                  errorText: _ssidError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (val) {
                  if (_ssidError != null && val.trim().isNotEmpty) {
                    setState(() => _ssidError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Wi-Fi Password',
                  hintText: 'Enter network password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final ssid = _ssidController.text.trim();
            final pass = _passController.text;

            if (ssid.isEmpty) {
              setState(() => _ssidError = 'SSID is required');
              return;
            }

            final devId = widget.device.deviceId.isNotEmpty ? widget.device.deviceId : widget.device.id;
            widget.provider.sendWifiSetup(devId, ssid, pass);
            Navigator.pop(context);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Wi-Fi setup command sent successfully')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00A884),
            foregroundColor: Colors.white,
          ),
          child: const Text('Send'),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 24-Hour Wheel Scroll Time Schedule Picker Dialog
// -----------------------------------------------------------------------------

class TimeScheduleWheelDialog extends StatefulWidget {
  final QuickCommand cmd;
  final Device device;
  final void Function(String commandPayload, String displayText) onSend;

  const TimeScheduleWheelDialog({
    super.key,
    required this.cmd,
    required this.device,
    required this.onSend,
  });

  @override
  State<TimeScheduleWheelDialog> createState() => _TimeScheduleWheelDialogState();
}

class _TimeScheduleWheelDialogState extends State<TimeScheduleWheelDialog> {
  bool _editingStart = true; // true = Start Time, false = End Time
  int _startHour = 8;
  int _startMinute = 0;
  int _endHour = 17;
  int _endMinute = 30;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    final allMatches = RegExp(r'(\d{1,2}):(\d{2})')
        .allMatches('${widget.cmd.label} ${widget.cmd.message}')
        .toList();
    if (allMatches.length >= 2) {
      _startHour = int.tryParse(allMatches[0].group(1)!) ?? _startHour;
      _startMinute = int.tryParse(allMatches[0].group(2)!) ?? _startMinute;
      _endHour = int.tryParse(allMatches[1].group(1)!) ?? _endHour;
      _endMinute = int.tryParse(allMatches[1].group(2)!) ?? _endMinute;
    } else if (allMatches.length == 1) {
      _startHour = int.tryParse(allMatches[0].group(1)!) ?? _startHour;
      _startMinute = int.tryParse(allMatches[0].group(2)!) ?? _startMinute;
    } else {
      final numMatch = RegExp(r'\((\d+)\)').firstMatch(widget.cmd.label) ??
          RegExp(r'\b(\d+)\b').firstMatch(widget.cmd.label);
      if (numMatch != null) {
        final val = int.tryParse(numMatch.group(1)!) ?? 0;
        if (val < 24) {
          _startHour = val;
          _startMinute = 0;
        } else if (val < 1440) {
          _startHour = (val ~/ 60) % 24;
          _startMinute = val % 60;
        }
      } else {
        _startHour = 0;
        _startMinute = 0;
      }
    }
    _hourController = FixedExtentScrollController(initialItem: _startHour.clamp(0, 23));
    _minuteController = FixedExtentScrollController(initialItem: _startMinute.clamp(0, 59));
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _selectTab(bool isStart) {
    if (_editingStart == isStart) return;
    setState(() {
      _editingStart = isStart;
    });
    final targetH = _editingStart ? _startHour : _endHour;
    final targetM = _editingStart ? _startMinute : _endMinute;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hourController.hasClients) {
        _hourController.animateToItem(
          targetH,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
      if (_minuteController.hasClients) {
        _minuteController.animateToItem(
          targetM,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String _formatDigits(int val) => val.toString().padLeft(2, '0');
  String _formatTime(int h, int m) => '${_formatDigits(h)}:${_formatDigits(m)}';

  String _calculateDuration() {
    int startTotal = _startHour * 60 + _startMinute;
    int endTotal = _endHour * 60 + _endMinute;
    if (endTotal < startTotal) {
      endTotal += 24 * 60; // Next day
    }
    final diff = endTotal - startTotal;
    final h = diff ~/ 60;
    final m = diff % 60;
    if (h == 0) return '${m}m duration';
    if (m == 0) return '${h}h duration';
    return '${h}h ${m}m duration';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFF00A884);
    const accentCyan = Color(0xFF2DD4BF);
    final dialogBg = isDark ? const Color(0xFF111B21) : Colors.white;
    final wheelBg = isDark ? const Color(0xFF0B141A) : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF8696A0) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF222E35) : const Color(0xFFE2E8F0);

    final currentH = _editingStart ? _startHour : _endHour;
    final currentM = _editingStart ? _startMinute : _endMinute;

    final labelLower = widget.cmd.label.toLowerCase();
    final msgLower = widget.cmd.message.toLowerCase();
    final bool isScheduleRange = labelLower.contains('schedule') ||
        msgLower.contains('schedule') ||
        labelLower.contains('timing') ||
        msgLower.contains('timing') ||
        labelLower.contains('-') ||
        msgLower.contains('-') ||
        labelLower.contains('–');
    final bool isSingleTime = !isScheduleRange && (labelLower.contains('time') || msgLower.contains('time'));

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderCol, width: 1),
      ),
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header with Icon and Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.access_time_filled_rounded, color: accentColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.cmd.label.split('(').first.trim().isNotEmpty
                        ? widget.cmd.label.split('(').first.trim()
                        : 'Set Timing',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textSecondary, size: 20),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Start Time & End Time Mode Tabs / Single Time Tab
            if (isSingleTime)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _selectTab(true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentColor,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time_filled_rounded,
                            size: 13,
                            color: accentCyan,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.cmd.label.split('(').first.trim().toUpperCase(),
                            style: const TextStyle(
                              color: accentCyan,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatTime(_startHour, _startMinute),
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _selectTab(true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: _editingStart
                            ? accentColor.withOpacity(isDark ? 0.2 : 0.12)
                            : (isDark ? const Color(0xFF1E2830) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _editingStart ? accentColor : borderCol,
                          width: _editingStart ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_circle_outline_rounded,
                                size: 13,
                                color: _editingStart ? accentCyan : textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'START TIME',
                                style: TextStyle(
                                  color: _editingStart ? accentCyan : textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatTime(_startHour, _startMinute),
                            style: TextStyle(
                              color: _editingStart ? textPrimary : textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _selectTab(false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: !_editingStart
                            ? accentColor.withOpacity(isDark ? 0.2 : 0.12)
                            : (isDark ? const Color(0xFF1E2830) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: !_editingStart ? accentColor : borderCol,
                          width: !_editingStart ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.stop_circle_outlined,
                                size: 13,
                                color: !_editingStart ? accentCyan : textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'END TIME',
                                style: TextStyle(
                                  color: !_editingStart ? accentCyan : textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatTime(_endHour, _endMinute),
                            style: TextStyle(
                              color: !_editingStart ? textPrimary : textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Scroll Wheel Container
            Container(
              height: 140,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: wheelBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderCol, width: 1),
              ),
              child: Column(
                children: [
                  // Top Column Labels
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: Text(
                              'HOURS',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Center(
                            child: Text(
                              'MINUTES',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Wheel Viewport with Selection Box
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Center Selection Highlight Bar
                      Container(
                        height: 36,
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(isDark ? 0.12 : 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accentCyan.withOpacity(0.35),
                            width: 1.0,
                          ),
                        ),
                      ),

                      // Wheel Pickers & Separator Colon
                      Positioned.fill(
                        child: Row(
                          children: [
                            // Hours Wheel
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                controller: _hourController,
                                itemExtent: 36,
                                perspective: 0.003,
                                diameterRatio: 1.6,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: (index) {
                                  setState(() {
                                    if (_editingStart) {
                                      _startHour = index;
                                    } else {
                                      _endHour = index;
                                    }
                                  });
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: 24,
                                  builder: (context, index) {
                                    final isSelected = index == currentH;
                                    return Center(
                                      child: Text(
                                        _formatDigits(index),
                                        style: TextStyle(
                                          color: isSelected
                                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                              : (isDark ? const Color(0xFF52606D) : const Color(0xFF94A3B8)),
                                          fontSize: isSelected ? 20 : 15,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            // Center Separator Colon
                            SizedBox(
                              width: 16,
                              child: Center(
                                child: Text(
                                  ':',
                                  style: TextStyle(
                                    color: accentCyan,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),

                            // Minutes Wheel
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                controller: _minuteController,
                                itemExtent: 36,
                                perspective: 0.003,
                                diameterRatio: 1.6,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: (index) {
                                  setState(() {
                                    if (_editingStart) {
                                      _startMinute = index;
                                    } else {
                                      _endMinute = index;
                                    }
                                  });
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: 60,
                                  builder: (context, index) {
                                    final isSelected = index == currentM;
                                    return Center(
                                      child: Text(
                                        _formatDigits(index),
                                        style: TextStyle(
                                          color: isSelected
                                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                              : (isDark ? const Color(0xFF52606D) : const Color(0xFF94A3B8)),
                                          fontSize: isSelected ? 20 : 15,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final startStr = _formatTime(_startHour, _startMinute);
                final endStr = _formatTime(_endHour, _endMinute);

                final cleanKey = widget.cmd.message.startsWith('/')
                    ? widget.cmd.message.substring(1)
                    : widget.cmd.message;

                final timeVal = isSingleTime ? startStr : '$startStr-$endStr';
                final jsonPayload = jsonEncode({
                  'command': '/write_register',
                  'data': {
                    cleanKey: timeVal,
                  },
                });

                final cleanLabel = widget.cmd.label.split('(').first.trim();
                final displayText = '$cleanLabel: $timeVal';
                widget.onSend(jsonPayload, displayText);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Submit',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Cyclic Schedule (Start Min - End Min) Wheel Picker Dialog
// -----------------------------------------------------------------------------

class CyclicScheduleWheelDialog extends StatefulWidget {
  final QuickCommand cmd;
  final Device device;
  final void Function(String commandPayload, String displayText) onSend;

  const CyclicScheduleWheelDialog({
    super.key,
    required this.cmd,
    required this.device,
    required this.onSend,
  });

  @override
  State<CyclicScheduleWheelDialog> createState() => _CyclicScheduleWheelDialogState();
}

class _CyclicScheduleWheelDialogState extends State<CyclicScheduleWheelDialog> {
  bool _editingStart = true; // true = Start Min, false = End Min
  int _startMin = 10;
  int _endMin = 20;

  late FixedExtentScrollController _startController;
  late FixedExtentScrollController _endController;
  late TextEditingController _startTextController;
  late TextEditingController _endTextController;
  late FocusNode _startFocusNode;
  late FocusNode _endFocusNode;

  static const int _maxMinutes = 999; // Allows 0 to 999 minutes

  @override
  void initState() {
    super.initState();
    String searchStr = widget.cmd.label;
    final paren = RegExp(r'\(([^)]+)\)').firstMatch(widget.cmd.label);
    if (paren != null) {
      searchStr = paren.group(1)!;
    }
    final rangeMatch = RegExp(r'(\d+)\s*(?:min)?\s*[-–—]\s*(\d+)\s*(?:min)?', caseSensitive: false)
        .firstMatch('$searchStr ${widget.cmd.message}');
    if (rangeMatch != null) {
      _startMin = int.tryParse(rangeMatch.group(1)!) ?? _startMin;
      _endMin = int.tryParse(rangeMatch.group(2)!) ?? _endMin;
    } else {
      final nums = RegExp(r'\d+')
          .allMatches(searchStr)
          .map((m) => int.tryParse(m.group(0)!))
          .whereType<int>()
          .toList();
      if (nums.length >= 2) {
        _startMin = nums[0];
        _endMin = nums[1];
      } else if (nums.length == 1) {
        _startMin = nums[0];
      }
    }

    _startMin = _startMin.clamp(0, _maxMinutes);
    _endMin = _endMin.clamp(0, _maxMinutes);

    _startController = FixedExtentScrollController(initialItem: _startMin);
    _endController = FixedExtentScrollController(initialItem: _endMin);
    _startTextController = TextEditingController(text: _startMin.toString());
    _endTextController = TextEditingController(text: _endMin.toString());
    _startFocusNode = FocusNode();
    _endFocusNode = FocusNode();

    _startFocusNode.addListener(() {
      if (_startFocusNode.hasFocus && !_editingStart) {
        setState(() {
          _editingStart = true;
        });
      }
    });

    _endFocusNode.addListener(() {
      if (_endFocusNode.hasFocus && _editingStart) {
        setState(() {
          _editingStart = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _startTextController.dispose();
    _endTextController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _selectTab(bool isStart) {
    if (_editingStart == isStart) return;
    setState(() {
      _editingStart = isStart;
    });
    if (isStart) {
      _startFocusNode.requestFocus();
    } else {
      _endFocusNode.requestFocus();
    }
  }

  void _onStartInputChanged(String val) {
    final parsed = int.tryParse(val.trim());
    if (parsed != null) {
      final clamped = parsed.clamp(0, _maxMinutes);
      setState(() {
        _startMin = clamped;
        _editingStart = true;
      });
      if (_startController.hasClients) {
        _startController.jumpToItem(clamped);
      }
    }
  }

  void _onEndInputChanged(String val) {
    final parsed = int.tryParse(val.trim());
    if (parsed != null) {
      final clamped = parsed.clamp(0, _maxMinutes);
      setState(() {
        _endMin = clamped;
        _editingStart = false;
      });
      if (_endController.hasClients) {
        _endController.jumpToItem(clamped);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentAmber = Color(0xFFF59E0B);
    const accentOrange = Color(0xFFFB923C);
    final dialogBg = isDark ? const Color(0xFF111B21) : Colors.white;
    final wheelBg = isDark ? const Color(0xFF0B141A) : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF8696A0) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF222E35) : const Color(0xFFE2E8F0);

    final cleanTitle = widget.cmd.label.split('(').first.trim().isNotEmpty
        ? widget.cmd.label.split('(').first.trim()
        : 'Set Cyclic Schedule';

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderCol, width: 1),
      ),
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header with Icon and Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accentAmber.withOpacity(0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.repeat_rounded, color: accentAmber, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cleanTitle,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textSecondary, size: 20),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. ON Min & OFF Min Mode Tabs with Direct Inline TextFields
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _selectTab(true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _editingStart
                            ? accentAmber.withOpacity(isDark ? 0.16 : 0.08)
                            : (isDark ? const Color(0xFF1E2830) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _editingStart ? accentAmber : borderCol,
                          width: _editingStart ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_circle_outline_rounded,
                                size: 14,
                                color: _editingStart ? accentAmber : textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'ON MIN',
                                style: TextStyle(
                                  color: _editingStart ? accentAmber : textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Direct editable Input Field
                          Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0B141A) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _editingStart
                                    ? accentAmber.withOpacity(0.85)
                                    : (isDark ? const Color(0xFF2A3942) : const Color(0xFFCBD5E1)),
                                width: _editingStart ? 1.4 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _startTextController,
                                    focusNode: _startFocusNode,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(3),
                                    ],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _editingStart ? textPrimary : textSecondary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none,
                                    ),
                                    onChanged: _onStartInputChanged,
                                  ),
                                ),
                                Text(
                                  'min',
                                  style: TextStyle(
                                    color: _editingStart ? accentAmber : textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _selectTab(false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: !_editingStart
                            ? accentAmber.withOpacity(isDark ? 0.16 : 0.08)
                            : (isDark ? const Color(0xFF1E2830) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: !_editingStart ? accentAmber : borderCol,
                          width: !_editingStart ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.stop_circle_outlined,
                                size: 14,
                                color: !_editingStart ? accentAmber : textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'OFF MIN',
                                style: TextStyle(
                                  color: !_editingStart ? accentAmber : textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Direct editable Input Field
                          Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0B141A) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: !_editingStart
                                    ? accentAmber.withOpacity(0.85)
                                    : (isDark ? const Color(0xFF2A3942) : const Color(0xFFCBD5E1)),
                                width: !_editingStart ? 1.4 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _endTextController,
                                    focusNode: _endFocusNode,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(3),
                                    ],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: !_editingStart ? textPrimary : textSecondary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none,
                                    ),
                                    onChanged: _onEndInputChanged,
                                  ),
                                ),
                                Text(
                                  'min',
                                  style: TextStyle(
                                    color: !_editingStart ? accentAmber : textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Dual Scroll Wheel Container (ON Min - OFF Min)
            Container(
              height: 140,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: wheelBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderCol, width: 1),
              ),
              child: Column(
                children: [
                  // Top Column Labels
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectTab(true),
                            borderRadius: BorderRadius.circular(6),
                            child: Center(
                              child: Text(
                                'ON (MIN)',
                                style: TextStyle(
                                  color: _editingStart ? accentAmber : textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectTab(false),
                            borderRadius: BorderRadius.circular(6),
                            child: Center(
                              child: Text(
                                'OFF (MIN)',
                                style: TextStyle(
                                  color: !_editingStart ? accentAmber : textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Wheel Viewport with Selection Box
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Center Selection Highlight Bar - Only highlights the actively selected column
                        Positioned(
                          left: 14,
                          right: 14,
                          height: 36,
                          child: Row(
                            children: [
                              // Start Min Selection Highlight Box
                              Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: _editingStart
                                        ? accentAmber.withOpacity(isDark ? 0.20 : 0.14)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _editingStart
                                          ? accentOrange.withOpacity(0.65)
                                          : Colors.transparent,
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ),

                              // Separator spacing matching the '-' dash width
                              const SizedBox(width: 20),

                              // End Min Selection Highlight Box
                              Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: !_editingStart
                                        ? accentAmber.withOpacity(isDark ? 0.20 : 0.14)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: !_editingStart
                                          ? accentOrange.withOpacity(0.65)
                                          : Colors.transparent,
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Wheel Pickers & Separator Dash
                        Positioned.fill(
                          child: Row(
                            children: [
                              // Start Min Wheel
                              Expanded(
                                child: Listener(
                                  onPointerDown: (_) => _selectTab(true),
                                  child: ListWheelScrollView.useDelegate(
                                    controller: _startController,
                                    itemExtent: 36,
                                    perspective: 0.003,
                                    diameterRatio: 1.6,
                                    physics: const FixedExtentScrollPhysics(),
                                    onSelectedItemChanged: (index) {
                                      setState(() {
                                        _startMin = index;
                                        if (!_editingStart) _editingStart = true;
                                        if (_startTextController.text != '$index') {
                                          _startTextController.text = '$index';
                                        }
                                      });
                                    },
                                    childDelegate: ListWheelChildBuilderDelegate(
                                      childCount: _maxMinutes + 1,
                                      builder: (context, index) {
                                        final isSelected = index == _startMin;
                                        final isActive = isSelected && _editingStart;
                                        return Center(
                                          child: Text(
                                            '$index',
                                            style: TextStyle(
                                              color: isSelected
                                                  ? (isActive
                                                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                                      : (isDark ? Colors.white70 : const Color(0xFF64748B)))
                                                  : (isDark ? const Color(0xFF52606D) : const Color(0xFF94A3B8)),
                                              fontSize: isSelected ? (isActive ? 20 : 17) : 15,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),

                              // Center Separator Dash
                              SizedBox(
                                width: 20,
                                child: Center(
                                  child: Text(
                                    '-',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),

                              // End Min Wheel
                              Expanded(
                                child: Listener(
                                  onPointerDown: (_) => _selectTab(false),
                                  child: ListWheelScrollView.useDelegate(
                                    controller: _endController,
                                    itemExtent: 36,
                                    perspective: 0.003,
                                    diameterRatio: 1.6,
                                    physics: const FixedExtentScrollPhysics(),
                                    onSelectedItemChanged: (index) {
                                      setState(() {
                                        _endMin = index;
                                        if (_editingStart) _editingStart = false;
                                        if (_endTextController.text != '$index') {
                                          _endTextController.text = '$index';
                                        }
                                      });
                                    },
                                    childDelegate: ListWheelChildBuilderDelegate(
                                      childCount: _maxMinutes + 1,
                                      builder: (context, index) {
                                        final isSelected = index == _endMin;
                                        final isActive = isSelected && !_editingStart;
                                        return Center(
                                          child: Text(
                                            '$index',
                                            style: TextStyle(
                                              color: isSelected
                                                  ? (isActive
                                                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                                      : (isDark ? Colors.white70 : const Color(0xFF64748B)))
                                                  : (isDark ? const Color(0xFF52606D) : const Color(0xFF94A3B8)),
                                              fontSize: isSelected ? (isActive ? 20 : 17) : 15,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4. Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final parsedStart = int.tryParse(_startTextController.text.trim());
                  if (parsedStart != null) _startMin = parsedStart.clamp(0, _maxMinutes);
                  final parsedEnd = int.tryParse(_endTextController.text.trim());
                  if (parsedEnd != null) _endMin = parsedEnd.clamp(0, _maxMinutes);

                  final cyclicVal = '$_startMin - $_endMin';

                  final cleanKey = widget.cmd.message.startsWith('/')
                      ? widget.cmd.message.substring(1)
                      : widget.cmd.message;

                  final jsonPayload = jsonEncode({
                    'command': '/write_register',
                    'data': {
                      cleanKey: cyclicVal,
                    },
                  });

                  final cleanLabel = widget.cmd.label.split('(').first.trim();
                  final displayText = '$cleanLabel: $cyclicVal';
                  widget.onSend(jsonPayload, displayText);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentAmber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Submit',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap, bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2830) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? const Color(0xFF2E3D46) : const Color(0xFFCBD5E1),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF475569),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Discrete Option & Numeric Range Dialog
// -----------------------------------------------------------------------------

class DiscreteOption {
  final String value;
  final String label;
  final String fullText;
  const DiscreteOption({
    required this.value,
    required this.label,
    required this.fullText,
  });
}

List<DiscreteOption> parseDiscreteOptions(String rangeStr, {String? paramKey, String? label}) {
  final cleanRange = rangeStr
      .replaceAll(RegExp(r'^\[Range:\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'\]$'), '')
      .replaceAll(RegExp(r'^\(Range:\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'\)$'), '')
      .trim();

  final List<DiscreteOption> options = [];

  if (cleanRange.contains(',') || cleanRange.contains(';')) {
    final parts = cleanRange.split(RegExp(r'[,;]'));
    for (final p in parts) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) continue;
      final match = RegExp(r'^([0-9a-zA-Z_]+)\s*[-:]\s*(.+)$').firstMatch(trimmed);
      if (match != null) {
        final val = match.group(1)!.trim();
        final lbl = match.group(2)!.trim();
        options.add(DiscreteOption(value: val, label: lbl, fullText: trimmed));
      } else {
        options.add(DiscreteOption(value: trimmed, label: trimmed, fullText: trimmed));
      }
    }
  }

  return options;
}

class NumericRangeDialog extends StatefulWidget {
  final String paramKey;
  final String label;
  final String rawValue;
  final String range;
  final double minVal;
  final double maxVal;
  final String unit;
  final void Function(String commandPayload, String displayText) onSend;

  const NumericRangeDialog({
    super.key,
    required this.paramKey,
    required this.label,
    required this.rawValue,
    required this.range,
    required this.minVal,
    required this.maxVal,
    required this.unit,
    required this.onSend,
  });

  @override
  State<NumericRangeDialog> createState() => _NumericRangeDialogState();
}

class _NumericRangeDialogState extends State<NumericRangeDialog> {
  late TextEditingController _controller;
  double _currentValue = 0.0;
  String? _errorMessage;
  bool _isValid = true;
  List<DiscreteOption> _discreteOptions = [];
  String _selectedOptionVal = '';

  @override
  void initState() {
    super.initState();
    _discreteOptions = parseDiscreteOptions(
      widget.range,
      paramKey: widget.paramKey,
      label: widget.label,
    );

    final numMatch = RegExp(r'[-+]?[0-9]*\.?[0-9]+').firstMatch(widget.rawValue);
    if (numMatch != null) {
      _currentValue = (double.tryParse(numMatch.group(0)!) ?? widget.minVal).roundToDouble();
    } else {
      _currentValue = widget.minVal.roundToDouble();
    }
    if (_currentValue < widget.minVal) _currentValue = widget.minVal;
    if (_currentValue > widget.maxVal) _currentValue = widget.maxVal;

    final initialIntVal = _currentValue.toInt().toString();
    if (_discreteOptions.isNotEmpty) {
      final found = _discreteOptions.firstWhere(
        (o) => o.value == initialIntVal || o.value == widget.rawValue.trim() || o.label.toLowerCase() == widget.rawValue.trim().toLowerCase(),
        orElse: () => _discreteOptions.first,
      );
      _selectedOptionVal = found.value;
    }

    _controller = TextEditingController(text: _formatVal(_currentValue));
    _validate(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatVal(double v) {
    return v.round().toString();
  }

  void _validate(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _isValid = false;
        _errorMessage = 'Value cannot be empty';
      });
      return;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      setState(() {
        _isValid = false;
        _errorMessage = 'Please enter a valid numeric value';
      });
      return;
    }
    final rounded = parsed.roundToDouble();
    final minLimit = widget.minVal.roundToDouble();
    final maxLimit = widget.maxVal.roundToDouble();
    if (rounded < minLimit) {
      setState(() {
        _isValid = false;
        _errorMessage = 'Value ${rounded.toInt()} is below minimum allowed (${minLimit.toInt()}${widget.unit.isNotEmpty ? ' ${widget.unit}' : ''})!';
      });
      return;
    }
    if (rounded > maxLimit) {
      setState(() {
        _isValid = false;
        _errorMessage = 'Value ${rounded.toInt()} exceeds maximum allowed (${maxLimit.toInt()}${widget.unit.isNotEmpty ? ' ${widget.unit}' : ''})!';
      });
      return;
    }
    setState(() {
      _isValid = true;
      _errorMessage = null;
      _currentValue = rounded;
    });
  }

  void _adjustStep(double delta) {
    final newVal = (_currentValue.round() + delta).clamp(widget.minVal, widget.maxVal);
    setState(() {
      _currentValue = newVal.toDouble();
      _controller.text = _formatVal(_currentValue);
      _validate(_controller.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFF00A884);
    const accentCyan = Color(0xFF2DD4BF);
    final dialogBg = isDark ? const Color(0xFF111B21) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1B272C) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF8696A0) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF2E3D46) : const Color(0xFFE2E8F0);

    final bool hasDiscreteOptions = _discreteOptions.isNotEmpty;
    final selectedOpt = hasDiscreteOptions
        ? _discreteOptions.firstWhere((o) => o.value == _selectedOptionVal, orElse: () => _discreteOptions.first)
        : null;

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderCol, width: 1),
      ),
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 380,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header with Icon and Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasDiscreteOptions ? Icons.toggle_on_rounded : Icons.tune_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasDiscreteOptions)
                        Text(
                          'Select mode option',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textSecondary, size: 20),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 2. Discrete Options Selector (Mode options like 0 - On/Off, 1 - RTC, 2 - Cyclic)
            if (hasDiscreteOptions) ...[
              if (_discreteOptions.length == 2) ...[
                Row(
                  children: [
                    for (int i = 0; i < _discreteOptions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final opt = _discreteOptions[i];
                            final isSelected = _selectedOptionVal == opt.value;
                            final isPositive = opt.value == '1' || opt.label.toLowerCase() == 'on' || opt.label.toLowerCase() == 'true';
                            final isNegative = opt.value == '0' || opt.label.toLowerCase() == 'off' || opt.label.toLowerCase() == 'false';
                            final activeColor = isPositive
                                ? const Color(0xFF00A884)
                                : (isNegative ? const Color(0xFFEF4444) : accentCyan);
                            final icon = isPositive
                                ? Icons.power_settings_new_rounded
                                : (isNegative ? Icons.power_off_rounded : Icons.radio_button_checked_rounded);

                            return GestureDetector(
                              onTap: () => setState(() => _selectedOptionVal = opt.value),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? activeColor.withOpacity(isDark ? 0.22 : 0.12)
                                      : (isDark ? const Color(0xFF1B272C) : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? activeColor
                                        : (isDark ? const Color(0xFF2E3D46) : const Color(0xFFCBD5E1)),
                                    width: isSelected ? 1.8 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      icon,
                                      size: 24,
                                      color: isSelected ? activeColor : (isDark ? Colors.white54 : Colors.black45),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      opt.label,
                                      style: TextStyle(
                                        color: isSelected ? activeColor : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Mode ${opt.value}',
                                      style: TextStyle(
                                        color: isSelected ? activeColor.withOpacity(0.85) : textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ] else ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _discreteOptions.map<Widget>((opt) {
                        final isSelected = _selectedOptionVal == opt.value;
                        final lowerLabel = opt.label.toLowerCase();

                        final IconData optIcon;
                        final Color optColor;
                        if (lowerLabel.contains('on') || lowerLabel.contains('off')) {
                          optIcon = Icons.power_settings_new_rounded;
                          optColor = const Color(0xFF00A884);
                        } else if (lowerLabel.contains('rtc') || lowerLabel.contains('time') || lowerLabel.contains('clock')) {
                          optIcon = Icons.schedule_rounded;
                          optColor = const Color(0xFF2DD4BF);
                        } else if (lowerLabel.contains('cyclic') || lowerLabel.contains('cycle') || lowerLabel.contains('loop')) {
                          optIcon = Icons.repeat_rounded;
                          optColor = const Color(0xFFF59E0B);
                        } else {
                          optIcon = Icons.layers_rounded;
                          optColor = const Color(0xFF8B5CF6);
                        }

                        return GestureDetector(
                          onTap: () => setState(() => _selectedOptionVal = opt.value),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? optColor.withOpacity(isDark ? 0.18 : 0.10)
                                  : (isDark ? const Color(0xFF1B272C) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? optColor
                                    : (isDark ? const Color(0xFF2E3D46) : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.6 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: (isSelected ? optColor : textSecondary).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    optIcon,
                                    size: 18,
                                    color: isSelected ? optColor : (isDark ? Colors.white60 : Colors.black54),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        opt.label,
                                        style: TextStyle(
                                          color: isSelected
                                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                              : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                          fontSize: 14.5,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Mode ${opt.value}',
                                        style: TextStyle(
                                          color: isSelected ? optColor : textSecondary,
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? optColor : (isDark ? Colors.white38 : Colors.black26),
                                      width: 2,
                                    ),
                                    color: isSelected ? optColor : Colors.transparent,
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ] else ...[
              // Standard Stepper & Input Field
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _currentValue > widget.minVal
                        ? () => _adjustStep(-1)
                        : null,
                    icon: const Icon(Icons.remove_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF24343D) : const Color(0xFFE2E8F0),
                      foregroundColor: textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _isValid ? textPrimary : const Color(0xFFEF4444),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                      onChanged: (val) => _validate(val),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: cardBg,
                        suffixText: widget.unit.isNotEmpty ? widget.unit : null,
                        suffixStyle: const TextStyle(color: accentCyan, fontWeight: FontWeight.bold, fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _isValid ? borderCol : const Color(0xFFEF4444),
                            width: _isValid ? 1.0 : 1.8,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _isValid ? borderCol : const Color(0xFFEF4444),
                            width: _isValid ? 1.0 : 1.8,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _isValid ? accentColor : const Color(0xFFEF4444),
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  IconButton.filledTonal(
                    onPressed: _currentValue < widget.maxVal
                        ? () => _adjustStep(1)
                        : null,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF24343D) : const Color(0xFFE2E8F0),
                      foregroundColor: textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Slider Control
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accentColor,
                  inactiveTrackColor: isDark ? const Color(0xFF24343D) : const Color(0xFFE2E8F0),
                  thumbColor: accentCyan,
                  overlayColor: accentCyan.withOpacity(0.2),
                  trackHeight: 3.5,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                child: Slider(
                  value: _currentValue.clamp(widget.minVal, widget.maxVal),
                  min: widget.minVal,
                  max: widget.maxVal,
                  divisions: (widget.maxVal - widget.minVal).round() > 0
                      ? (widget.maxVal - widget.minVal).round()
                      : null,
                  onChanged: (newVal) {
                    final roundedVal = newVal.roundToDouble();
                    setState(() {
                      _currentValue = roundedVal;
                      _controller.text = _formatVal(roundedVal);
                      _validate(_controller.text);
                    });
                  },
                ),
              ),

              // Validation Warning Banner
              if (!_isValid && _errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFEF4444)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: 16),

            // Action Buttons (Cancel / Submit)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: borderCol),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Cancel', style: TextStyle(color: textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: hasDiscreteOptions
                        ? () {
                            final valToSend = int.tryParse(_selectedOptionVal) ?? _selectedOptionVal;
                            final jsonPayload = jsonEncode({
                              'command': '/write_register',
                              'data': {
                                widget.paramKey: valToSend,
                              },
                            });

                            final lbl = selectedOpt != null ? selectedOpt.label : _selectedOptionVal;
                            final displayText = 'Set ${widget.label}: $lbl ($_selectedOptionVal)';
                            widget.onSend(jsonPayload, displayText);
                            Navigator.pop(context);
                          }
                        : (_isValid
                            ? () {
                                final pureVal = _formatVal(_currentValue);
                                final displayValStr = widget.unit.isNotEmpty
                                    ? '$pureVal ${widget.unit}'
                                    : pureVal;

                                final jsonPayload = jsonEncode({
                                  'command': '/write_register',
                                  'data': {
                                    widget.paramKey: pureVal,
                                  },
                                });

                                final displayText = 'Set ${widget.label}: $displayValStr';
                                widget.onSend(jsonPayload, displayText);
                                Navigator.pop(context);
                              }
                            : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isDark ? const Color(0xFF1E2830) : const Color(0xFFE2E8F0),
                      disabledForegroundColor: textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 16),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            hasDiscreteOptions && selectedOpt != null
                                ? 'Apply → ${selectedOpt.label}'
                                : 'Update Setting',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

