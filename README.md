# Arr Downloads Plasma widget

Panel chip for a Sonarr/Radarr-family stack. Shows a count badge in the
panel; click it to drop down a list of what's finished downloading
recently, grouped as Movies / TV / Anime, freshest first. Defaults to
the last 24 hours so it doesn't turn into a wall of history.

## Install / update / remove

```bash
kpackagetool6 --type Plasma/Applet --install .
kpackagetool6 --type Plasma/Applet --upgrade .
kpackagetool6 --type Plasma/Applet --remove dev.demrich.arrdownloads
```

Then **Add Widgets** → search **Arr Downloads**.

Never run `--upgrade` against the already-installed directory
(`~/.local/share/plasma/plasmoids/dev.demrich.arrdownloads`).
kpackagetool removes that path first, so upgrading in place deletes the
package. Run it from a separate source checkout instead.

## Configure

API keys are not stored in the widget config (that would be visible on
the command line via `/proc` to any process running as you). Instead
edit `~/.config/arr-downloads/config.json` (already created, `chmod 600`):

```json
{
  "instances": [
    { "name": "Sonarr",       "url": "https://sonarr.example.com",       "api_key": "", "category": "tv" },
    { "name": "Sonarr Anime", "url": "https://sonarr-anime.example.com", "api_key": "", "category": "anime" },
    { "name": "Radarr",       "url": "https://radarr.example.com",       "api_key": "", "category": "movies" },
    { "name": "Radarr 4K",    "url": "https://radarr4k.example.com",     "api_key": "", "category": "movies" }
  ]
}
```

List only the instances you actually run. One Sonarr and one Radarr covers
most setups; the four above are just there to show you can point multiple
instances of the same app at different categories.

Fill in each `api_key` (Settings → General → Security in that
instance's web UI). An instance with a blank `api_key` is skipped
silently. Remove ones you don't want tracked entirely, or just leave
the key blank. `category` controls which section (Movies/TV/Anime) an
instance's downloads land in. Set it to whatever fits if you add more
instances (Lidarr, Readarr, etc. would need the fetch script taught
their response shape first; it only understands Sonarr/Radarr's
`history/since` payload today).

Poll interval, the time window, and max popup rows are on the widget's
own config page (right-click → Configure).

## How it works

`contents/scripts/fetch_downloads.py` reads the config file, hits each
instance's `GET /api/v3/history/since` with its API key, keeps only
`downloadFolderImported` events within the configured window, and
prints one JSON summary. The QML side shells out to it on a timer via
Plasma's `executable` DataSource (same pattern as the SABnzbd widget)
and never touches the API keys itself.
