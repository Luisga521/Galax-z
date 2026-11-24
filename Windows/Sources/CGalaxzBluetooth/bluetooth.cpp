// Bluetooth MIDI through WinRT (Windows.Devices.Midi, Windows.Devices.Enumeration): galaxz_bluetooth.h says what each does.
#ifdef _WIN32
#include "galaxz_bluetooth.h"

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Enumeration.h>
#include <winrt/Windows.Devices.Midi.h>
#include <winrt/Windows.Devices.Radios.h>
#include <winrt/Windows.Storage.Streams.h>

#include <chrono>
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

using namespace winrt;
using namespace winrt::Windows::Devices::Bluetooth;
using namespace winrt::Windows::Devices::Enumeration;
using namespace winrt::Windows::Devices::Midi;
using namespace winrt::Windows::Devices::Radios;
using namespace winrt::Windows::Storage::Streams;

namespace {

int put(std::wstring const &s, wchar_t *out, int capacity) {
    int n = static_cast<int>(s.size()) + 1;
    if (out && capacity >= n) std::memcpy(out, s.c_str(), n * sizeof(wchar_t));
    return n;
}

// a name or an id, with nothing in it that would break a line apart
std::wstring field(hstring const &h) {
    std::wstring s(h);
    for (auto &c : s) if (c == L'\t' || c == L'\n' || c == L'\r') c = L' ';
    return s;
}

std::wstring why(hresult_error const &e) { return L"!" + field(e.message()); }

struct Link {
    MidiInPort in{nullptr};
    IMidiOutPort out{nullptr};
    event_token token{};
    galaxz_bt_receive receive = nullptr;
    void *context = nullptr;
    std::mutex lock;
    bool closed = false;
};

} // namespace

extern "C" int galaxz_bt_init(void) {
    try {
        init_apartment(apartment_type::multi_threaded);
        return 0;
    } catch (hresult_error const &e) {
        return static_cast<int>(e.code());
    }
}

extern "C" int galaxz_bt_radio(void) {
    try {
        auto adapter = BluetoothAdapter::GetDefaultAsync().get();
        if (!adapter) return 0;
        auto radio = adapter.GetRadioAsync().get();
        if (!radio) return 0;
        return radio.State() == RadioState::On ? 1 : 2;
    } catch (...) {
        return 0;
    }
}

extern "C" int galaxz_bt_ports(wchar_t *out, int capacity) {
    std::wstring s;
    try {
        auto add = [&](wchar_t const *kind, hstring const &selector) {
            for (auto const &d : DeviceInformation::FindAllAsync(selector).get())
                s += std::wstring(kind) + L"\t" + field(d.Id()) + L"\t" + field(d.Name()) + L"\n";
        };
        add(L"in", MidiInPort::GetDeviceSelector());
        add(L"out", MidiOutPort::GetDeviceSelector());
    } catch (hresult_error const &e) {
        s = why(e);
    }
    return put(s, out, capacity);
}

extern "C" int galaxz_bt_nearby(int milliseconds, wchar_t *out, int capacity) {
    // what the watcher finds, shared with its handlers: they may still run while it stops
    struct Found {
        std::mutex lock;
        std::vector<std::pair<std::wstring, std::wstring>> devices;
        void add(DeviceInformation const &d) {
            std::wstring name = field(d.Name());
            if (name.empty()) return;
            std::lock_guard<std::mutex> g(lock);
            for (auto const &x : devices) if (x.first == std::wstring(d.Id())) return;
            devices.emplace_back(field(d.Id()), name);
        }
    };
    auto found = std::make_shared<Found>();
    std::wstring s;
    try {
        auto watcher = DeviceInformation::CreateWatcher(BluetoothLEDevice::GetDeviceSelectorFromPairingState(false),
                                                        std::vector<hstring>{}, DeviceInformationKind::AssociationEndpoint);
        auto added = watcher.Added([found](DeviceWatcher const &, DeviceInformation const &d) { found->add(d); });
        auto updated = watcher.Updated([](DeviceWatcher const &, DeviceInformationUpdate const &) {});
        auto removed = watcher.Removed([](DeviceWatcher const &, DeviceInformationUpdate const &) {});
        watcher.Start();
        std::this_thread::sleep_for(std::chrono::milliseconds(milliseconds));
        watcher.Stop();
        for (int i = 0; i < 100 && watcher.Status() != DeviceWatcherStatus::Stopped && watcher.Status() != DeviceWatcherStatus::Aborted; i++)
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        watcher.Added(added);
        watcher.Updated(updated);
        watcher.Removed(removed);
        std::lock_guard<std::mutex> g(found->lock);
        for (auto const &d : found->devices) s += d.first + L"\t" + d.second + L"\n";
    } catch (hresult_error const &e) {
        s = why(e);
    }
    return put(s, out, capacity);
}

extern "C" int galaxz_bt_pair(wchar_t const *id) {
    try {
        auto d = DeviceInformation::CreateFromIdAsync(id).get();
        if (d.Pairing().IsPaired()) return 19;                       // AlreadyPaired
        if (!d.Pairing().CanPair()) return 3;                         // NotReadyToPair
        auto custom = d.Pairing().Custom();
        // nothing to show or type on an OP-Z: whatever Windows asks to confirm, confirmed
        auto token = custom.PairingRequested([](DeviceInformationCustomPairing const &, DevicePairingRequestedEventArgs const &a) { a.Accept(); });
        auto result = custom.PairAsync(DevicePairingKinds::ConfirmOnly | DevicePairingKinds::DisplayPin | DevicePairingKinds::ConfirmPinMatch).get();
        custom.PairingRequested(token);
        return static_cast<int>(result.Status());
    } catch (...) {
        return -1;
    }
}

extern "C" void *galaxz_bt_open(wchar_t const *in_id, wchar_t const *out_id, void *context, galaxz_bt_receive receive) {
    try {
        auto link = std::make_shared<Link>();
        link->receive = receive;
        link->context = context;
        // a device that does not answer leaves these waiting: 5 s each, then nothing
        auto in = MidiInPort::FromIdAsync(in_id);
        if (in.wait_for(std::chrono::seconds(5)) != winrt::Windows::Foundation::AsyncStatus::Completed) { in.Cancel(); return nullptr; }
        link->in = in.GetResults();
        auto out = MidiOutPort::FromIdAsync(out_id);
        if (out.wait_for(std::chrono::seconds(5)) != winrt::Windows::Foundation::AsyncStatus::Completed) { out.Cancel(); return nullptr; }
        link->out = out.GetResults();
        if (!link->in || !link->out) return nullptr;
        std::weak_ptr<Link> weak = link;
        link->token = link->in.MessageReceived([weak](MidiInPort const &, MidiMessageReceivedEventArgs const &a) {
            auto l = weak.lock();
            if (!l) return;
            auto raw = a.Message().RawData();
            std::lock_guard<std::mutex> g(l->lock);
            if (!l->closed && raw.Length() > 0) l->receive(l->context, raw.data(), raw.Length());
        });
        return new std::shared_ptr<Link>(link);
    } catch (...) {
        return nullptr;
    }
}

extern "C" int galaxz_bt_send(void *p, uint8_t const *bytes, size_t count) {
    if (!p || !bytes || count == 0) return -1;
    auto &link = *static_cast<std::shared_ptr<Link> *>(p);
    try {
        Buffer b(static_cast<uint32_t>(count));
        std::memcpy(b.data(), bytes, count);
        b.Length(static_cast<uint32_t>(count));
        link->out.SendBuffer(b);
        return 0;
    } catch (...) {
        return -1;
    }
}

extern "C" void galaxz_bt_close(void *p) {
    if (!p) return;
    auto held = static_cast<std::shared_ptr<Link> *>(p);
    auto link = *held;
    delete held;
    {
        std::lock_guard<std::mutex> g(link->lock);                   // a message being handed over ends first
        link->closed = true;
    }
    try {
        link->in.MessageReceived(link->token);
        link->in.Close();
        link->out.Close();
    } catch (...) {
    }
}
#endif
