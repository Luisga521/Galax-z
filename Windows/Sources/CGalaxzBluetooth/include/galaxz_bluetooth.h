// Bluetooth MIDI on Windows, for Swift: Windows lets only WinRT (Windows.Devices.Midi) reach a Bluetooth MIDI device, not WinMM.
// A plain C door to a little C++/WinRT (bluetooth.cpp). Every call but send waits for Windows: call them from a thread of
// your own (galaxz_bt_init on it first), never the window's.
#ifndef GALAXZ_BLUETOOTH_H
#define GALAXZ_BLUETOOTH_H

#include <stddef.h>
#include <stdint.h>
#include <wchar.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Bytes from the device: one whole MIDI message (a SysEx from F0 to F7), on a thread of Windows'.
typedef void (*galaxz_bt_receive)(void *context, const uint8_t *bytes, size_t count);

/// Makes the calling thread able to talk to WinRT. 0, or an HRESULT.
int galaxz_bt_init(void);

/// This computer's Bluetooth: 0 none, 1 on, 2 off.
int galaxz_bt_radio(void);

/// Every MIDI port WinRT has now, a line each, "in|out <TAB> id <TAB> name". Text lengths here count UTF-16 units with the
/// closing 0; when `capacity` is too small nothing is written and the length needed comes back. A line "!" + why on failure.
int galaxz_bt_ports(wchar_t *out, int capacity);

/// Bluetooth LE devices near, not paired yet, looked for during `milliseconds`: "id <TAB> name" a line.
int galaxz_bt_nearby(int milliseconds, wchar_t *out, int capacity);

/// Pair one of those (it asks for nothing: an OP-Z has no screen). Windows' DevicePairingResultStatus: 0 paired,
/// 19 already paired; -1 when it could not be asked.
int galaxz_bt_pair(const wchar_t *id);

/// Open a device's input and output ports. NULL when Windows will not.
void *galaxz_bt_open(const wchar_t *in_id, const wchar_t *out_id, void *context, galaxz_bt_receive receive);

/// Send one whole MIDI message. 0, or -1 when the device is gone.
int galaxz_bt_send(void *link, const uint8_t *bytes, size_t count);

/// Close it: no more bytes come after this returns.
void galaxz_bt_close(void *link);

#ifdef __cplusplus
}
#endif

#endif
