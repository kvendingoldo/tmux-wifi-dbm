// Reads the current Wi-Fi RSSI (dBm) via CoreWLAN.
//
// CoreWLAN replaces the `airport` CLI, which Apple deprecated in macOS 14.4
// and removed outright in later releases. Unlike -[CWInterface ssid], reading
// rssiValue() does not require Location Services authorization.
//
// Prints the RSSI to stdout, or exits non-zero when no Wi-Fi link is up.

import CoreWLAN
import Foundation

guard let interface = CWWiFiClient.shared().interface(), interface.powerOn() else {
    exit(1)
}

let rssi = interface.rssiValue()
// 0 means "no association"; CoreWLAN has no separate sentinel for it.
guard rssi != 0 else {
    exit(1)
}

print(rssi)
