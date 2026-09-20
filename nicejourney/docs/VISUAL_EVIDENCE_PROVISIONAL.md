# Nice Journey — Provisional Visual Evidence

Updated: 2026-09-15

## Scope

This is renderer-active greybox evidence only. It does **not** claim final pixel-art, telegraph, full accessibility, complete supported-aspect-ratio coverage, or final-art acceptance.

Captured with Godot 4.6.2 stable Mono (`71f334935`), GL Compatibility / Intel Iris Xe. The legacy profile/gameplay captures below use Godot Movie Maker image-sequence capture; the size-verified 1280×720 and 640×360 PNG/JSON pairs use `tools/capture_visual_evidence.gd`.

## Captures

### Profile shell — current 1280×720 override

- `docs/evidence/visual/main-profile00000001.png`
- Shows the actual running profile-selection scene, three empty slots, keyboard focus highlight, and the Accessibility & Controls entry.
- Confirms the current UI is rendered rather than inferred from scene text or headless logs.

Capture command:

```text
C:\Users\LENOVO\Desktop\GodotC#\Godot_v4.6.2-stable_mono_win64_console.exe --path . --scene res://src/app/main.tscn --write-movie docs/evidence/visual/main-profile.png --quit-after 2
```

### Gameplay foundation greybox — current 1280×720 override

- `docs/evidence/visual/gameplay-greybox00000001.png`
- Shows the actual running gameplay greybox, DebugHUD, player blockout/weapon, grid, obstacle and current presentation at the default camera state.
- This is provisional geometry/presentation evidence only; it is not representative final raster character art or combat telegraph evidence.

Capture command:

```text
C:\Users\LENOVO\Desktop\GodotC#\Godot_v4.6.2-stable_mono_win64_console.exe --path . --scene res://src/app/gameplay.tscn --write-movie docs/evidence/visual/gameplay-greybox.png --quit-after 2
```


### Current top-level window captures after inspector-first asset migration

Two additional real top-level application-window captures were taken after the Sprite2D/AnimationPlayer + inspector-resource migration:

- `docs/evidence/renderer/main-profile-ui-1280x720.png` — current running profile-selection shell at the supported 1280×720 output, including an existing Ranged save slot and the accessibility entry. This is live window evidence rather than scene-text inference.
- `docs/evidence/renderer/gameplay-v02-player-1280x720.png` — current running gameplay scene with the V02 player body visible in the greybox. The external capture causes the existing focus-loss pause policy to open the pause overlay, so this image is valid for current raster presence/window composition only, not unpaused combat readability.

These captures do **not** close final-art acceptance for Region 3/tower/remaining enemies/boss/UI, which still contain provisional V01 categories. The gameplay capture likewise does not substitute for an unpaused representative combat/VFX/telegraph recording.

### Region 3 authored-town overview — provisional V01 layout composition

- `docs/evidence/renderer/region3-authored-town-layout-v01-routes-fixed.png`
- Shows the actual running `region3_authored_town_preview.tscn` with all 20 structure anchors at their §24.12 reserved-lot centers, functional entrance/approach tiles, a revised closed circulation loop that no longer runs through the service-building centers, four outward approaches, service connectors and the tower/plaza spine.
- The loop is intentionally three tiles wide where the master-reserved service/tower lots physically constrain the four-tile target; the four outward approaches remain four tiles wide. This is still a reversible route draft pending player/NPC footprint and collision traversal tests.
- The overview deliberately zooms out to show topology; the tiny building sprites are the current provisional V01 fixtures and are **not** a pixel-readability/final-art approval.
- Collision, navigation clearance, ground/tile production art, quest anchors and important interiors remain open.

### Asset replacement showrooms — provisional comparison baselines

- `docs/evidence/renderer/generated-v02-enemy-showcase-fixed-duelist.png` — current generated-reference V02 Duelist/Bruiser/Defender/Marksman presentation at runtime windup/telegraph state. The Duelist no longer contains the reference-sheet header rectangle that was caught in the earlier crop.
- `docs/evidence/renderer/remaining-eight-enemy-showcase-v01.png` — current eight unreplaced enemy archetypes in their inspector-owned `Sprite2D + AnimationPlayer` shells. Their textures remain provisional V01 and this capture is a replacement baseline, not approval.
- `docs/evidence/renderer/tower-room-visual-showcase-v01.png` — all eight current tower room visual categories rendered inside the 640×360 internal-canvas contract through inspector-owned visual profiles. These remain provisional V01 and are intentionally presented together for future generated-art comparison.

## Output / internal-canvas resize status

The master specification locks **1280×720 as the minimum supported output target** and recommends a **640×360 internal pixel canvas**. A dedicated renderer-active harness now verifies both requested and observed dimensions. Accepted minimum-output evidence is `docs/evidence/visual/minimum-supported-output-1280x720.png` plus its JSON sidecar; both the live window and captured image are recorded as **1280×720**, and the complete profile shell, first-slot focus indicator and settings entry remain visible.

The earlier `--resolution 640x360` Movie Maker attempt still produced 1280×720 because the project window override won. A dedicated renderer-active capture harness now explicitly sets the live root window size before instantiating the target scene and records both requested and observed dimensions. This capture is an **internal-canvas diagnostic**, not a supported-output acceptance claim:

- `docs/evidence/visual/internal-canvas-640x360.png`
- `docs/evidence/visual/internal-canvas-640x360.json`
- observed live window size: **640×360**;
- captured viewport image size: **640×360**;
- the profile shell remains fully visible with all three slot buttons plus `Accessibility & Controls` visible and the first slot focus indicator intact.

Capture command:

```text
C:\Users\LENOVO\Desktop\GodotC#\Godot_v4.6.2-stable_mono_win64_console.exe --path . --script res://tools/capture_visual_evidence.gd -- --scene=res://src/app/main.tscn --out=res://docs/evidence/visual/internal-canvas-640x360.png --width=640 --height=360
```

The capture tool writes a JSON sidecar so the evidence does not rely on filename claims about actual window/image dimensions.

### Maximum current UI/text scale — settings surface at 1280×720

- `docs/evidence/visual/max-scale-settings-1280x720.png`
- `docs/evidence/visual/max-scale-settings-1280x720.json`
- sidecar records `ui_scale = 1.25`, `text_scale = 1.25`, `open_settings = true`, actual window **1280×720** and captured image **1280×720**;
- the first renderer-active attempt exposed real horizontal overflow: focus-follow scrolling moved right and cut off left-side labels at 125%; the shared settings panel was widened within the 640-wide internal canvas and `tests/test_accessibility_settings.gd` now rejects any visible horizontal scrollbar at maximum current scale;
- the refreshed capture shows the left-side labels/instructions and focused Run control without horizontal clipping. Vertical scrolling remains expected for the long settings surface.

This is evidence for the current settings surface only, not a claim that every future UI surface is max-scale approved.

These remain open:

- resize/letterbox inspection across additional representative supported aspect ratios beyond the ultrawide composition check below;
- representative 1×/2× raster aim silhouettes and grip attachment;
- max-scale visual acceptance across required UI surfaces beyond the current settings capture;
- high-contrast/magnification manual checks;
- final-art/pixel-readability approval.

Headless layout tests remain useful executable evidence, but they do not substitute for those remaining visual judgments.

### Ultrawide final-window composition — 1920×800 physical client

The earlier `gameplay-ultrawide-1920x800.png` / JSON pair was captured from `root.get_texture()` and therefore is **not** final-window evidence: the requested/live window was 1920×800 while that root viewport image remained 1280×720.

A separate top-level application-window capture now records the actually displayed Godot window instead of the root viewport texture:

- `docs/evidence/visual/gameplay-ultrawide-os-window-1920x800.png`
- `docs/evidence/visual/gameplay-ultrawide-os-window-1920x800.json`
- capture target: visible `Nice Journey (DEBUG)` top-level window through Auvrynt `capture_window`;
- requested physical client: **1920×800**;
- Windows logical client at the observed 150% display scale: **1280×533** (approximately 1920×800 physical);
- captured top-level window including non-client chrome: **1942×856 physical pixels**;
- measured rendered-game bounds inside that capture: **1280×720 physical pixels**, from x=331..1610 and y=85..804 inclusive;
- the remaining client area is black letterbox/pillarbox space rather than additional world rendering.

This closes the narrow question that the current integer-scale ultrawide window does **not** widen the gameplay view or expose additional off-room greybox world area: the rendered world/UI surface remains the same 1280×720 extent inside the wider 1920×800 client.

The capture contains the pause overlay because the existing focus-loss policy paused gameplay while the external capture tool took focus. Therefore this evidence is accepted only for final-window **composition/letterboxing and world-view extent**; it is not unpaused combat-readability, final telegraph, final art, or full accessibility evidence.
