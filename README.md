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

Reachable from any Tailnet device as `http://mini:3001/configure` and `http://mini:3232/configure` (MagicDNS).

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

`bootstrap.sh` runs `docker compose up -d`, waits for healthchecks, and then prints the two `/configure` URLs and the AIOStreams manifest pattern.

## One-time UI walkthrough

After `docker compose up -d` succeeds, the rendered configs are in `configs/rendered/*.json` (gitignored — they contain your real keys). The `.json` extension matters: both addons' `/configure` UIs filter the file picker by extension and reject `.rendered.json`.

> **Note:** AIOMetadata may show *"Configuration file version mismatch: this file was exported from 1.24.2, but you're running 2.3.0"* on import. That's expected — Tamtaro's published non-anime config hasn't been re-exported since AIOMetadata went 2.x. The import works; just spot-check the catalog list and provider settings in the UI before saving.

1. **AIOMetadata** — `http://mini:3232/configure`
   - Click *Import / Restore* and select `configs/rendered/aiometadata.json`.
   - Save. The page gives you a manifest URL containing your UUID, e.g. `http://mini:3232/<UUID>/manifest.json`.
   - Copy the **path portion** (`/<UUID>/manifest.json`) — you'll splice it into the AIOStreams custom addon URL next.

2. **AIOStreams** — `http://mini:3001/configure`
   - Set the addon password to whatever you put in `AIOSTREAMS_PASSWORD`.
   - Click *Import / Restore* and select `configs/rendered/aiostreams.json`.
   - Find the *AIOMetadata* entry in the addon list and change its manifest URL from `http://aiometadata:3232/manifest.json` to `http://aiometadata:3232/<UUID>/manifest.json` (using the UUID from step 1). Internal Docker DNS is mandatory here — `aiometadata` is the container name on the `omni-stack` network.
   - Save. Copy the manifest URL it gives you, e.g. `http://mini:3001/<UUID>/manifest.json`.
   - **Trakt:** under Catalogs / Apps, run the Trakt OAuth flow once. This is interactive and can't be baked into the config.

3. **Paste the AIOStreams manifest URL into Omni.** Done.

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

**Restoring after wiping a UUID** — re-import `configs/*.rendered.json` via the `/configure` UI. You'll get a fresh UUID, so update the Omni manifest URL.

**Container can't reach AIOMetadata** — the addon URL must be `http://aiometadata:3232/...` (internal Docker DNS), not `http://mini:3232/...`. AIOStreams runs inside the `omni-stack` network and can't hit the host's published port.

**Refreshing upstream regex / SEL / metadata mirrors:**
```bash
./scripts/update-mirrors.sh
```
This re-fetches Vidhin's regex JSON, Tamtaro's SEL JSON, and Tamtaro's non-anime AIOMetadata config. Re-render and re-import if you want the new versions live.

**Pinning image versions** — `docker-compose.yml` uses `:latest` for both addons. To pin, replace with a specific tag — see [AIOStreams releases](https://github.com/Viren070/AIOStreams/releases) (current stable: `v2.29.5`) and [AIOMetadata releases](https://github.com/cedya77/aiometadata/releases).

## Secret hygiene

`keys.txt`, `monochrome-formatter.txt`, `.env`, and `configs/*.rendered.json` are all in `.gitignore`. **Don't remove those entries.** If `git status` ever shows any of them as tracked or staged, stop and untrack before committing.
