# Sourcing the Focus audio

## Why this document exists

The app shipped with **no audio files at all**. Every ambient sound and relaxation
track was a hotlinked third-party URL, and when they were probed:

| Catalogue | Sources | Working |
|---|---|---|
| Ambient sounds (focus timer) | 15 `cdn.pixabay.com` URLs | **3** — the other 12 return `403` |
| Relaxation tracks | 14 Free Music Archive URLs | **3** — the other 11 return `404` |

Every relaxation failure fell through to `soundhelix.com/examples/SoundHelix-Song-N.mp3`,
which is a demo endpoint for an **algorithmic music generator**. So "Deep Sleep Delta
Waves" played procedurally-generated electronica, and the three URLs that *did* resolve
were mislabelled anyway — `oceanWaves` was a Kai Engel piano piece.

Three separate licensing problems came with that:

1. **Pixabay forbids it explicitly.** Their API terms: *"Permanent hotlinking of images
   (using Pixabay URLs in your app) is not allowed. If you intend to use the images, please
   download them to your server first."* The 403s are that policy being enforced.
2. **Two FMA tracks were verified CC BY-NC** — NonCommercial — in an app that ships AdMob,
   with **no attribution anywhere** in the code or UI. NC licensing and ad revenue are
   incompatible, and even the permissive CC-BY tracks were unattributed.
3. **SoundHelix publishes no licence** for its example MP3s. GPLv3 covers the *generator*,
   not the author's pre-rendered recordings, so the default is all rights reserved.

## The rule going forward

**CC0 only, downloaded and bundled.** Not CC-BY, not CC-BY-NC, not "free to use".

CC0 is the only licence that needs no attribution, has no commercial restriction, and no
ambiguity about redistributing the audio *as* the product — which is exactly what a
soundscape feature does. Everything else either forbids our use case or adds an obligation
we then have to keep honouring forever.

Bundling (rather than self-hosting) is deliberate: a bundled asset cannot 404, cannot be
403'd by hotlink protection, cannot be retired by someone else's CDN, and **works on a
plane** — which for a focus and sleep feature is a real feature, not a fallback.

## Where to get it

**[Freesound](https://freesound.org)** — the deepest CC0 field-recording library there is.
Create a free account, then for each sound below:

1. Search the term.
2. **Filter to CC0.** In the left sidebar under *Licenses*, tick **Creative Commons 0**.
   This is the one step that matters — do not skip it, and do not accept "Attribution".
3. Prefer long recordings (60 s+) with steady character and no speech, music, sudden
   clipping, or recognisable one-off events near the loop point.
4. Download the original, then encode per the table below.

Direct CC0-filtered searches:

| # | Asset filename | Search | Notes |
|---|---|---|---|
| 1 | `rain.m4a` | [rain loop](https://freesound.org/search/?q=rain&f=license:%22Creative+Commons+0%22) | steady, no thunder |
| 2 | `thunderstorm.m4a` | [thunderstorm](https://freesound.org/search/?q=thunderstorm&f=license:%22Creative+Commons+0%22) | thunder should not clip |
| 3 | `ocean.m4a` | [ocean waves](https://freesound.org/search/?q=ocean+waves&f=license:%22Creative+Commons+0%22) | needs 90–120 s (waves are recognisable) |
| 4 | `forest.m4a` | [forest ambience](https://freesound.org/search/?q=forest+ambience&f=license:%22Creative+Commons+0%22) | |
| 5 | `fireplace.m4a` | [fireplace crackle](https://freesound.org/search/?q=fireplace+crackle&f=license:%22Creative+Commons+0%22) | |
| 6 | `wind.m4a` | [wind](https://freesound.org/search/?q=wind&f=license:%22Creative+Commons+0%22) | avoid mic buffeting |
| 7 | `birds.m4a` | [birds morning](https://freesound.org/search/?q=birds+morning&f=license:%22Creative+Commons+0%22) | |
| 8 | `river.m4a` | [stream water](https://freesound.org/search/?q=stream+water&f=license:%22Creative+Commons+0%22) | |
| 9 | `cafe.m4a` | [cafe ambience](https://freesound.org/search/?q=cafe+ambience&f=license:%22Creative+Commons+0%22) | **no intelligible speech** |
| 10 | `library.m4a` | [room tone quiet](https://freesound.org/search/?q=room+tone&f=license:%22Creative+Commons+0%22) | |
| 11 | `night_sounds.m4a` | [crickets night](https://freesound.org/search/?q=crickets+night&f=license:%22Creative+Commons+0%22) | |
| 12 | `meditation.m4a` | [singing bowl](https://freesound.org/search/?q=singing+bowl&f=license:%22Creative+Commons+0%22) | |

**You do not need to source these three.** `whiteNoise`, `brownNoise` and `pinkNoise` are
pure DSP — I generate them directly as bundled WAVs, so they are correct by construction,
need no licence and no attribution, and loop perfectly. (They were also the clearest sign
the old catalogue was untended: `whiteNoise` and `pinkNoise` pointed at the *same URL*.)

## Encoding targets

| Content | Codec | Length | Expected size |
|---|---|---|---|
| Broadband, no melodic content (rain, wind, noise) | AAC **64–96 kbps mono** | 30–60 s | 0.25–0.7 MB |
| Textured, identifiable events (ocean, forest, fireplace, birds) | AAC **96–128 kbps stereo** | 60–120 s | 0.7–1.8 MB |

Whole library ≈ **10–25 MB**. That is far below every store threshold, so no Play Asset
Delivery and no iOS Background Assets are needed. (Note iOS On-Demand Resources is
deprecated as of iOS 27 — do not start one.)

```bash
# broadband, mono
ffmpeg -i in.wav -ac 1 -c:a aac -b:a 80k -movflags +faststart assets/audio/rain.m4a
# textured, stereo
ffmpeg -i in.wav -ac 2 -c:a aac -b:a 112k -movflags +faststart assets/audio/ocean.m4a
```

M4A/AAC is chosen over MP3 because `just_audio` documents M4A as the reliable format for
seeking.

**Trim for the loop before encoding.** Cut both ends at a zero crossing and apply a short
(~250 ms) crossfade so the tail matches the head. No player setting fixes a file whose end
doesn't meet its start — and the loop is played as a repeating playlist rather than
`LoopMode.one` specifically because that mode has an open iOS 17+ clicking-seam bug
(just_audio #1151).

## Recording the provenance

Every file needs an entry in `assets/audio/LICENSES.json`:

```json
{
  "rain.m4a": {
    "title": "Steady rain on pavement",
    "author": "freesound_username",
    "source": "https://freesound.org/s/123456/",
    "license": "CC0 1.0",
    "licenseUrl": "https://creativecommons.org/publicdomain/zero/1.0/"
  },
  "white_noise.wav": {
    "title": "White noise",
    "author": "generated",
    "source": "synthesised in-repo (tool/gen_noise.dart)",
    "license": "n/a — generated, not licensed",
    "licenseUrl": null
  }
}
```

CC0 requires no attribution, so this manifest is not a legal obligation — it is what turns
an app-store or legal question from an archaeology project into a five-minute answer. Given
how this feature got here, that is worth the ten minutes it costs.

## The order to do it in

All twelve are being sourced. They land in **waves**, because the catalogue in
`audio_service.dart` only ever declares what is on disk — so the guard is green after every
commit instead of red for however many days the sourcing takes.

| Wave | Files | Why grouped |
|---|---|---|
| **1** | `rain`, `ocean`, `forest`, `fireplace` | Deep CC0 pools, steady character, they loop cleanly. Also restores three relaxation tracks (`rainOnWindow`, `oceanWaves`, `forestBirds`), taking that picker from 3 playable to 6 |
| **2** | `wind`, `birds`, `river`, `night_sounds` | Findable, but each needs auditioning — see the notes in the table above |
| **3** | `thunderstorm`, `cafe`, `library`, `meditation` | The genuinely hard four |

### Why wave 3 is hard — these are constraints, not excuses

- **`thunderstorm`** — a thunderclap is a *recognisable one-off event*, so a 60 s loop turns
  it into a metronome. Source 120 s+, and put the loop seam inside continuous rain with no
  clap near it.
- **`cafe`** — the blocker is not scarcity. **CC0 waives copyright; it does not waive the
  personality and publicity rights of the people recorded.** Bundling café ambience with
  intelligible speech ships identifiable voices *as product*, in an ad-supported app. The
  "no intelligible speech" note in the table above is a legal check, not a taste one:
  audition the whole file, not the first ten seconds.
- **`library`** — "library ambience" *is* room tone, which is quiet filtered noise. A field
  recording here will be a worse version of the pink noise already bundled. A low-level
  generated bed is the honest option, **explicitly recorded as generated** in
  `LICENSES.json` — that is legitimate for the same reason `gen_noise.dart` is: room tone is
  a spec, not a claim about a place.
- **`meditation`** — CC0 singing-bowl recordings are almost all one-shots with long decays,
  which loop audibly badly. Look for a sustained drone, not a struck bowl.

**Never synthesise `rain` or `ocean`.** Filtered noise approximates both well enough to pass
the gate, and that is precisely the dishonesty this whole document exists to undo — the old
catalogue's clearest tell was two different sounds pointing at one URL. `gen_noise.dart` is
legitimate because white, pink and brown noise each *are* a DSP definition. "Rain" is a
claim about a recording.

## Adding one sound

Three things land in **one commit**, and the guard fails if you forget any of them:

1. Drop the encoded file into `assets/audio/`.
2. Add its line to `_ambientAssets` in `lib/core/services/audio_service.dart` — and, if a
   relaxation track maps onto the same recording, its line in `_relaxationAssets`.
3. Add its provenance block to `assets/audio/LICENSES.json`, moving the name out of
   `pending`.

Nothing else changes. The picker filters on `AudioService.hasAmbientAudio`, so the chip
appears on its own; `AchievementType.soundExplorer` derives its target from
`AudioService.playableAmbientSounds.length`, so the achievement stays earnable without being
touched. Then:

```bash
~/flutter/bin/flutter test test/features/focus/focus_guards_test.dart
```

## How you'll know it worked

`test/features/focus/focus_guards_test.dart` gates all of this:

- *no audio source is a remote URL* — fails if any `http` URL reappears in
  `audio_service.dart`.
- *every declared audio asset exists on disk* — names the exact missing filename. This is
  deliberately stronger than a reachability probe: it also catches a typo'd asset path,
  which a `HEAD` request never would.
- *pubspec bundles the audio directory* — fails unless `assets/audio/` is declared, because
  an undeclared asset only fails at runtime, on a user's device.
- *every playable sound is reachable, and Sound Explorer tracks them* — pins the picker and
  the achievement to the same catalogue, so trimming or growing it can never leave a visible
  achievement permanently out of reach. It was hardcoded to 15 against a 3-sound catalogue.

A network reachability test was considered and rejected: it would make the build depend on
two third-party CDNs' uptime, go red on a Tuesday for reasons nobody can fix, and the first
response to a flaky gate is to switch it off — which is how 23 dead URLs survived a green
suite in the first place. Local assets make the failure mode impossible instead of merely
monitored.
