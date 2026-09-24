# tmux-wifi-dbm

Shows the current Wi-Fi signal strength, in dBm, in your tmux status bar.

macOS only at the moment. Linux support is still to come.

## Installation

With [tpm](https://github.com/tmux-plugins/tpm), add to `~/.tmux.conf`:

```
set -g @plugin 'kvendingoldo/tmux-wifi-dbm'
```

then press `prefix + I`.

## Usage

Add the format string to your `status-right` (or `status-left`) tmux option:

```
set -g status-right 'wifi #{wifi_dbm} dBm'
```

## Formats

| Format | Output |
| --- | --- |
| `#{wifi_dbm}` | `-65` |
| `#{wifi_dbm_label}` | `Good` |
| `#{wifi_dbm_status}` | `-65 [Good]` |

Use `#{wifi_dbm_status}` for the number and the quality word together, or
combine the other two to control the formatting yourself:

```
set -g status-right 'WiFi: #{wifi_dbm} dBm (#{wifi_dbm_label})'
```

## Signal quality

`#{wifi_dbm_label}` maps the reading onto a word. The defaults follow the usual
Wi-Fi reference points — `-67` dBm is the floor for reliable streaming and VoIP,
and below about `-75` dBm a link only carries light traffic:

| Reading | Label |
| --- | --- |
| `-50` and above | `Excellent` |
| `-51` to `-60` | `Good` |
| `-61` to `-67` | `Fair` |
| `-68` to `-75` | `Weak` |
| `-76` and below | `Poor` |

## Options

| Option | Default | Description |
| --- | --- | --- |
| `@wifi_dbm_offline_text` | `--` | Shown when the Wi-Fi radio is off or unassociated |
| `@wifi_dbm_label_excellent` | `Excellent` | Label for the strongest band |
| `@wifi_dbm_label_good` | `Good` | |
| `@wifi_dbm_label_fair` | `Fair` | |
| `@wifi_dbm_label_weak` | `Weak` | |
| `@wifi_dbm_label_poor` | `Poor` | Label for the weakest band |
| `@wifi_dbm_threshold_excellent` | `-50` | Lower bound of `Excellent` |
| `@wifi_dbm_threshold_good` | `-60` | Lower bound of `Good` |
| `@wifi_dbm_threshold_fair` | `-67` | Lower bound of `Fair` |
| `@wifi_dbm_threshold_weak` | `-75` | Lower bound of `Weak`; below this is `Poor` |

```
set -g @wifi_dbm_offline_text 'off'
set -g @wifi_dbm_label_excellent 'Great'
set -g @wifi_dbm_threshold_good '-58'
```

Thresholds must stay in descending order (`excellent` > `good` > `fair` >
`weak`), otherwise a band becomes unreachable.

## How the reading is taken

Apple deprecated the `airport` CLI in macOS 14.4 and removed it entirely in
later releases, so it can no longer be used. This plugin reads the RSSI through
CoreWLAN instead, via a small Swift helper that is compiled once into
`~/.cache/tmux-wifi-dbm/` and then runs in about 10ms. Reading the RSSI does not
require Location Services permission.

The compile happens in the background on first load; until it finishes, and on
machines with no Swift compiler installed, the plugin falls back to
`system_profiler`. That call takes several seconds, so its result is cached and
refreshed in the background — the status bar is never blocked either way.
