# omni-stack

Self-hosted Stremio addon stack for the [Omni](https://github.com/elfhosted/omni) iOS/tvOS app. Omni connects to **one** manifest URL — AIOStreams — which in turn calls a marketplace of stream addons and a metadata addon (AIOMetadata) wrapped inside.

```
                    ┌─────────────────────────────────────────────┐
                    │                  Omni (iOS/tvOS)            │
                    └─────────────────────┬───────────────────────┘
                                          │  single manifest URL
                                          ▼
                    ┌─────────────────────────────────────────────┐
                    │             AIOStreams  :3001               │
                    │  • Torrentio / Comet / MediaFusion          │
                    │  • StremThru Torz                           │
                    │  • Vidhin regex template (auto-sync)        │
                    │  • Tamtaro SEL filters                      │
                    │  • Custom monochrome formatter              │
                    │  • TorBox debrid  (RD wired but disabled)   │
                    └─────────────────────┬───────────────────────┘
                                          │  http://aiometadata:3232 (internal)
                                          ▼
                    ┌─────────────────────────────────────────────┐
                    │            AIOMetadata  :3232               │
                    │  • TMDB (movies) / TVDB (series)            │
                    │  • Tamtaro non-anime catalogs               │
                    │  • RPDB poster service                      │
                    └─────────────────────┬───────────────────────┘
                                          │
                                          ▼
                                  ┌───────────────┐
                                  │ Redis (cache) │
                                  └───────────────┘
```

Reachable from any Tailnet device via MagicDNS (`http://mini:3001`, `http://mini:3232`) and publicly via Cloudflare tunnel at `https://omni.connorleech.dev` (AIOStreams only — AIOMetadata stays internal).

## Quick start

```bash
git clone git@github.com:connor-leech/omni-stack.git
cd omni-stack
cp .env.example .env

# fill in keys (TMDB, TVDB, MDBLIST, RPDB, TorBox)
# generate the secret key with:
openssl rand -hex 32   # paste into AIOSTREAMS_SECRET_KEY
$EDITOR .env

# bring it up + print the one-time UI steps
./scripts/bootstrap.sh
```

`bootstrap.sh` runs `docker compose up -d`, waits for healthchecks, and then prints the two `/configure` URLs and import instructions.

## One-time setup

After `docker compose up -d` succeeds, run `./scripts/render-configs.sh` to produce `configs/rendered/*.json` (gitignored — real keys substituted). Then load the AIOStreams config via the API (more reliable than the UI file picker):

```bash
python3 -c "
import json
with open('configs/rendered/aiostreams.json') as f:
    config = json.load(f)
config['addonPassword'] = '$(grep AIOSTREAMS_PASSWORD .env | cut -d= -f2)'
print(json.dumps({'password': 'choose-a-password', 'config': config}))
" | curl -s -X POST http://localhost:3001/api/v1/user \
     -H 'Content-Type: application/json' --data-binary @-
```

The response contains a `uuid`. Your manifest URL is then:

```
GET http://localhost:3001/api/v1/user?uuid=<UUID>&password=<PASSWORD>
# → encryptedPassword field
# Manifest: http://mini:3001/stremio/<UUID>/<encryptedPassword>/manifest.json
# Public:   https://omni.connorleech.dev/stremio/<UUID>/<encryptedPassword>/manifest.json
```

Save both to `MANIFEST_URL.txt` for reference.

**AIOMetadata one-time steps** — `http://mini:3232`:
- Verify TMDB / TVDB connections are live (Settings → Providers).
- Run the **Trakt OAuth** flow (Settings → Apps → Trakt). This is interactive and can't be automated.

> **Version mismatch warning:** AIOMetadata may warn *"Configuration file version mismatch"* on import — expected, Tamtaro's config predates the current release. The import works fine; spot-check catalog list and provider settings before saving.

## Friend-fork instructions

If you're forking this for your own setup:

1. Fork on GitHub, clone, `cp .env.example .env`, fill in **your** keys.
2. `openssl rand -hex 32` → `AIOSTREAMS_SECRET_KEY`.
3. `./scripts/bootstrap.sh`.
4. Follow the one-time UI walkthrough above.
5. The custom monochrome formatter in `monochrome-formatter.txt` is **not committed** (gitignored — it was sourced from a private Reddit chat). To get it:
   - DM `Grouchy-Factor-9645` on `r/OmniContentHub` and ask for the monochrome formatter, **or**
   - In the AIOStreams `/configure` UI, pick a built-in formatter (e.g. `prism`, `tamtaro`, `gdrive`). They're all fine starting points.

## What's NOT automated

| Item | Why | How |
|------|-----|-----|
| Trakt OAuth | Browser flow with a redirect. | One click in the AIOStreams /configure UI. |
| Omni app-side group/subgroup config | App-side, not addon-side. | Configure in Omni Settings → Sources. |
| Better Covers tiles | Reddit-hosted image packs, no API. | Manual download — see Reddit posts linked in `## Image packs & cosmetics` below. |
| Logo / collection / genre image packs | Same as above. | Same. |
| Custom monochrome formatter (friend forks) | Source is a private chat. | DM the author on Reddit or use a built-in preset. |

## Image packs & cosmetics

The cosmetic add-ons (logo packs, collection covers, genre cards, "Better Covers" tiles) live in iCloud / imgur shared albums in the link sections of:

- https://www.reddit.com/r/OmniContentHub/comments/1plelw7/
- https://www.reddit.com/r/OmniContentHub/comments/1r6fgoc/

Grab them manually and install via the Omni app's *Sources / Catalog Covers* settings.

## Repo layout

```
omni-stack/
├── MANIFEST_URL.txt                 # live manifest URL + UUID/password (gitignored — generated per install)
├── .env.example                     # template; copy to .env (gitignored)
├── .gitignore
├── docker-compose.yml
├── configs/
│   ├── aiostreams.template.json     # baseline AIOStreams config with ${VAR}s
│   ├── aiometadata.template.json    # baseline AIOMetadata config with ${VAR}s
│   ├── vidhin-regex.json            # local mirror of Vidhin's regex template
│   ├── tamtaro-sel.json             # local mirror of Tamtaro's SEL config
│   └── tamtaro-aiometadata.json     # local mirror of Tamtaro's non-anime metadata
├── scripts/
│   ├── bootstrap.sh                 # up + healthcheck wait + print UI steps
│   ├── render-configs.sh            # substitute ${VAR} from .env into *.rendered.json
│   ├── export-configs.sh            # walkthrough for exporting from the UI
│   └── update-mirrors.sh            # refresh Vidhin/Tamtaro mirrors from upstream
├── configs/rendered/                # gitignored — render-configs.sh output, real keys substituted
├── data/                            # runtime data (gitignored)
└── monochrome-formatter.txt         # gitignored — source for the custom formatter
```

## Troubleshooting

**Rebuild from scratch:**
```bash
docker compose down -v   # wipes volumes — you lose your /configure UUIDs!
./scripts/bootstrap.sh
```

If you want to keep your saved configs across a rebuild, skip `-v`:
```bash
docker compose down
docker compose pull
docker compose up -d
```

**Logs:**
```bash
docker logs -f aiostreams
docker logs -f aiometadata
docker logs -f aiometadata_redis
```

**Restoring after wiping a UUID** — re-run the API import command from the *One-time setup* section above. You'll get a fresh UUID; update `MANIFEST_URL.txt` and re-paste into Omni.

**Container can't reach AIOMetadata** — the addon URL must be `http://aiometadata:3232/...` (internal Docker DNS), not `http://mini:3232/...`. AIOStreams runs inside the `omni-stack` network and can't hit the host's published port.

**Refreshing upstream regex / SEL / metadata mirrors:**
```bash
./scripts/update-mirrors.sh
```
This re-fetches Vidhin's regex JSON, Tamtaro's SEL JSON, and Tamtaro's non-anime AIOMetadata config. Re-render and re-import if you want the new versions live.

**Pinning image versions** — `docker-compose.yml` uses `:latest` for both addons. To pin, replace with a specific tag — see [AIOStreams releases](https://github.com/Viren070/AIOStreams/releases) (current stable: `v2.29.5`) and [AIOMetadata releases](https://github.com/cedya77/aiometadata/releases).

## Secret hygiene

`keys.txt`, `monochrome-formatter.txt`, `.env`, `MANIFEST_URL.txt`, and `configs/rendered/` are all in `.gitignore`. **Don't remove those entries.** If `git status` ever shows any of them as tracked or staged, stop and untrack before committing. `MANIFEST_URL.txt` in particular contains your live UUID + addon password — sharing it gives someone a working manifest into your stack.
