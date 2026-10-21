"""
IONET Virtual Device Simulator
Simulates a real ESP32 / IoT device connecting to the IONET cloud WebSocket.
Receives /status and control commands, and replies with telemetry & sliders.
"""
import asyncio
import json
import sys

try:
    import websockets
except ImportError:
    import subprocess
    print("Installing websockets library...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "websockets"])
    import websockets

DEVICE_ID = "IONET001"
WS_URL = f"wss://api.ionet.sunshineiot.in/ws?deviceId={DEVICE_ID}&type=device"

state = {
    "relay1": "On",
    "relay2": "Off",
    "Relay 1": "Relay 1",
    "Relay 2": "Relay 2",
    "1": "Relay 1",
    "2": "Relay 2",
    "dimmer": 50,
    "fan_speed": 3,
    "brightness": 75,
    "cyclic_timer": "10-20",
    "PS": "0",
    "POP": "0",
}

def get_status_payload():
    return {
        "type": "RESPONSE",
        "data": {
            "ac_voltage": "230.5 V",
            "ac_current": "12.3 A",
            "motor_status": "Running",
            "tank_top_level": "80 %",
            "tank_bottom_level": "20 %",
            "overload_alarm": "Active",
            "hw_version": "1.2",
            "sw_version": "4.101"
        },
        "availableCommands": [
            { "command": "/remote_start", "description": "Start Motor" },
            { "command": "/remote_stop", "description": "Stop Motor" },
            { "command": "/remote_reset", "description": "Reset Fault" },
            { "command": "/status", "description": "Get Device Status" },
            { "command": "/holding", "description": "Get Device Settings" },
            { "command": "/config", "description": "Rename status fields by slot id" },
            { "command": "/about", "description": "About Device" }
        ]
    }

async def run_simulator():
    print(f"Connecting Virtual Device Simulator for deviceId={DEVICE_ID} to {WS_URL}...")
    try:
        async with websockets.connect(WS_URL) as ws:
            print("Connected to IONET Cloud Server successfully!")
            # Send initial online handshake and status
            await ws.send(json.dumps({"type": "device_online", "deviceId": DEVICE_ID}))
            await ws.send(json.dumps(get_status_payload()))
            print("Sent device_online and initial status payload.")

            async for message in ws:
                print(f"Received from app: {message}")
                try:
                    data = json.loads(message)
                    cmd_raw = str(data.get("command", "")).strip()
                    cmd = cmd_raw.lower()
                    if cmd in ["/status", "status"]:
                        reply = get_status_payload()
                        await ws.send(json.dumps(reply))
                        print(f"Replied with status: {reply}")
                    elif cmd in ["/holding", "/numeric", "/test numeric", "holding", "numeric", "/test range", "test range"]:
                        reply = {
                            "type": "NUMERIC",
                            "data": {
                                "overload_current": {
                                    "value": state.get("overload_current", "20.0 A"),
                                    "range": "2 - 30"
                                },
                                "dry_run": {
                                    "value": state.get("dry_run", 1),
                                    "range": "0 - 1"
                                },
                                "dry_run_current": {
                                    "value": state.get("dry_run_current", "5.0 A"),
                                    "range": "2 - 20"
                                },
                                "drs_recovery_delay": {
                                    "value": state.get("drs_recovery_delay", "15 min"),
                                    "range": "0 - 999"
                                },
                                "top_tank_level": {
                                    "value": state.get("top_tank_level", "50 %"),
                                    "range": "10 - 80"
                                },
                                "bottom_tank": {
                                    "value": state.get("bottom_tank", 1),
                                    "range": "0 - 1"
                                },
                                "bottom_tank_level": {
                                    "value": state.get("bottom_tank_level", "20 %"),
                                    "range": "10 - 30"
                                },
                                "remote_start": {
                                    "value": state.get("remote_start", 0),
                                    "range": "0 - 1"
                                },
                                "remote_stop": {
                                    "value": state.get("remote_stop", 0),
                                    "range": "0 - 1"
                                },
                                "remote_reset": {
                                    "value": state.get("remote_reset", 0),
                                    "range": "0 - 1"
                                }
                            },
                            "availableCommands": [
                                { "command": "/remote_start", "description": "Start Motor" },
                                { "command": "/remote_stop", "description": "Stop Motor" },
                                { "command": "/remote_reset", "description": "Reset Fault" },
                                { "command": "/status", "description": "Get Device Status" },
                                { "command": "/holding", "description": "Get Device Settings" },
                                { "command": "/config", "description": "Rename status fields by slot id" },
                                { "command": "/about", "description": "About Device" }
                            ]
                        }
                        await ws.send(json.dumps(reply))
                        print(f"Replied with NUMERIC payload: {reply}")
                    elif cmd in ["/time", "/test time", "time"]:
                        reply = {
                            "type": "TIME",
                            "data": {
                                "schedule_1": "08:00 17:30",
                                "schedule_2": "18:00 22:00"
                            },
                            "availableCommands": get_status_payload()["availableCommands"]
                        }
                        await ws.send(json.dumps(reply))
                        print(f"Replied with TIME payload: {reply}")
                    elif cmd in ["/cyclic", "/test cyclic", "cyclic", "/cyclic_timer"]:
                        reply = {
                            "type": "CYCLIC",
                            "data": {
                                "cyclic": state.get("cyclic", state.get("cyclic_timer", "10-20"))
                            },
                            "availableCommands": get_status_payload()["availableCommands"]
                        }
                        await ws.send(json.dumps(reply))
                        print(f"Replied with CYCLIC payload: {reply}")
                    elif cmd in ["/settings", "settings", "/setting", "setting", "Settings", "Setting"]:
                        reply = {
                            "type": "CLICKABLE",
                            "data": [
                                {"command": "/device_setting", "label": "Device Setting"},
                                {"command": "/preserve_state", "label": "Preserve State"},
                                {"command": "/rename_relay", "label": "Rename Relay"}
                            ],
                            "availableCommands": get_status_payload()["availableCommands"]
                        }
                        await ws.send(json.dumps(reply))
                        print(f"Replied with Settings menu: {reply}")
                    elif cmd in [
                        "/device_setting", "device_setting", "device setting", "Device Setting",
                        "/device_settings", "device_settings", "device settings", "Device Settings",
                        "device seeting", "/device seeting"
                    ]:
                        r1_label = state.get("Relay 1", state.get("1", "Relay 1"))
                        r2_label = state.get("Relay 2", state.get("2", "Relay 2"))
                        reply = {
                            "type": "CLICKABLE",
                            "data": [
                                {"command": r1_label, "label": r1_label},
                                {"command": r2_label, "label": r2_label}
                            ],
                            "availableCommands": get_status_payload()["availableCommands"]
                        }
                        await ws.send(json.dumps(reply))
                        print(f"Replied with Device Setting (Relays): {reply}")
                    elif cmd in ["/preserve_state", "preserve_state", "Preserve State", "/radio", "radio", "/test radio", "test radio"]:
                        radio_data = data.get("data", {})
                        if isinstance(radio_data, dict):
                            for k, v in radio_data.items():
                                val_str = str(v)
                                state[k] = val_str
                                state[k.upper()] = val_str
                                state[k.lower()] = val_str
                        reply = {
                            "type": "RADIO",
                            "data": {
                                "PS": str(state.get("PS", "0")),
                                "POP": str(state.get("POP", "0"))
                            }
                        }
                        await ws.send(json.dumps(reply))
                        print(f"Replied with Preserve State / Radio: {reply}")
                    elif cmd in ["/clickable", "clickable", "/test clickable", "test clickable", "/timing", "timing", "/time_slots", "time_slots", "/set_timing", "set_timing"]:
                        reply = {
                            "type": "CLICKABLE",
                            "data": [
                                "set_timing_1",
                                "set_timing_2",
                                "set_timing_3",
                                "set_timing_4",
                                "set_timing_5"
                            ]
                        }
                        await ws.send(json.dumps(reply))
                        print(f"Replied with CLICKABLE timings: {reply}")
                    elif cmd in ["/rename_relay", "rename_relay", "Rename Relay", "/text", "text", "/test text", "test text"]:
                        r1_label = state.get("Relay 1", state.get("1", "Relay 1"))
                        r2_label = state.get("Relay 2", state.get("2", "Relay 2"))
                        reply = {
                            "type": "TEXT",
                            "data": {
                                "1": r1_label,
                                "2": r2_label
                            },
                            "availableCommands": get_status_payload()["availableCommands"]
                        }
                        await ws.send(json.dumps(reply))
                        print(f"Replied with Rename Relay: {reply}")
                    elif cmd.lower() in [
                        state.get("Relay 1", "Relay 1").lower(),
                        state.get("Relay 2", "Relay 2").lower(),
                        "/relay_1", "relay_1", "/relay_2", "relay_2",
                        "relay 1", "relay 2", "relay 4", "/relay_4", "relay_4"
                    ] or cmd.lower().startswith("relay"):
                        if "relay 4" in cmd.lower() or "relay_4" in cmd.lower():
                            state["Relay 1"] = "Relay 4"
                            state["1"] = "Relay 4"
                        r1_label = state.get("Relay 1", state.get("1", "Relay 1"))
                        r2_label = state.get("Relay 2", state.get("2", "Relay 2"))
                        reply = {
                            "type": "TEXT",
                            "data": {
                                "1": r1_label,
                                "2": r2_label
                            },
                            "availableCommands": get_status_payload()["availableCommands"]
                        }
                        await ws.send(json.dumps(reply))
                        print(f"Replied with Relays for command '{cmd}': {reply}")
                    elif cmd.startswith("/config") or data.get("command") == "/config":
                        cfg_data = data.get("data", {})
                        print(f"Config applied: {cfg_data}")
                        for k, v in cfg_data.items():
                            state[k] = v
                            if str(k).isdigit():
                                state[f"Relay {k}"] = v
                                state[f"relay_{k}"] = v
                        r1_label = state.get("Relay 1", state.get("1", "Relay 1"))
                        r2_label = state.get("Relay 2", state.get("2", "Relay 2"))
                        reply = {
                            "type": "TEXT",
                            "data": {
                                "1": r1_label,
                                "2": r2_label
                            },
                            "success": True,
                            "message": f"Updated configuration: {cfg_data}"
                        }
                        await ws.send(json.dumps(reply))
                        print(f"Replied with updated config TEXT: {reply}")
                    elif cmd.startswith("/write_register") or data.get("command") == "/write_register":
                        reg_data = data.get("data", {})
                        print(f"Write Register applied: {reg_data}")
                        for k, v in reg_data.items():
                            state[k] = v
                            if str(k).isdigit():
                                state[f"Relay {k}"] = v
                        await ws.send(json.dumps({"success": True, "message": f"Updated registers: {reg_data}", "data": reg_data}))
                    elif cmd.startswith("/dimmer"):
                        val = data.get("value") or (int(cmd.split()[-1]) if len(cmd.split()) > 1 else state["dimmer"])
                        state["dimmer"] = int(val)
                        await ws.send(json.dumps({"success": True, "message": f"Dimmer set to {state['dimmer']}", "data": state}))
                    elif cmd.startswith("/fan_speed"):
                        val = data.get("value") or (int(cmd.split()[-1]) if len(cmd.split()) > 1 else state["fan_speed"])
                        state["fan_speed"] = int(val)
                        await ws.send(json.dumps({"success": True, "message": f"Fan Speed set to {state['fan_speed']}", "data": state}))
                except Exception as e:
                    print(f"Error handling command: {e}")
    except Exception as e:
        print(f"Connection error: {e}")

if __name__ == "__main__":
    asyncio.run(run_simulator())
