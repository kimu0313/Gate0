# Revvy Shared Memory

Shared memory for ALL agents (Claude/Codex/Kimi ...) working in this project.
Read it at session start. When you make a durable decision, adopt a convention,
or leave work half-done, append a dated one-line entry under the matching
heading so the next agent (possibly a different model) picks up where you left
off.

## Decisions
- 2026-10-21: GATE 0 prototype is GDScript on Godot 4.7.2 (Steam build), Forward+. Level/props are built procedurally in code (scripts/world/terminal.gd); no art assets. SFX from tools/gen_sfx.py, PA voice from tools/gen_voice.ps1 (Windows SAPI).
- 2026-10-21: StandardMaterial3D screens using a ViewportTexture as emission_texture must set `emission = Color.BLACK` (emission op ADD adds the color to the texture → washed-out white).
- 2026-10-21: UI art direction "SIGNAGE → BOARDING" (시안 canvas: https://claude.ai/artifact/H9AezbpMA5fXwwqWS9HmRF). Tokens, fonts and theme live in scripts/ui/ui_kit.gd: "display" = Bahnschrift condensed (Latin sign text, Hangul falls back to Malgun Gothic), signal yellow #FFC21A = orders/interaction, ALERT red = anomaly, CLEAR teal = normal. As erosion rises the HUD swaps words via UiKit.corrupt() and turns navy (BOARDING) at 75%+.
- 2026-10-21: Rulebook page fonts and stamps are gameplay clues — official pages stay sans + red 시설운영팀 stamp; serif/hand fonts, black 1987, blue 긴급 and 승객운송팀 stamps mark fakes. Restyle paper, never these cues.
- 2026-10-21: Generated UI art (Codex $imagegen) is in assets/ui/: tablet_bezel (screen rect 147,136 1243x718, see Tablet.TEX_SCREEN), binder_cover, binder_rings, paper_sheet, stamp_normal/anomaly/seal_ring/grunge (white ink, tinted in code), clip_bulldog, keypad_full, staff_card, boarding_pass, app_icon. Load through UiArt.tex(); every screen keeps a code-drawn fallback.
- 2026-10-21: World text (Geo.label) has a `style` arg matching the surface: sign (backlit, Bahnschrift DIN + Malgun fallback), print (lit), led/lcd (condensed), hand (bundled Nanum Pen Script), engrave (bundled Nanum Myeongjo). All MSDF. Use Geo.fit(label, max_width) so text never overflows its sign. UiKit "serif"/"hand" also use the bundled fonts in assets/fonts (OFL, license txt alongside).
- 2026-10-21: Terminal.build() ends with Geo.fit_labels(self): every Label3D printed on a box face is shrunk to fit it (min 50%, else treated as a false match). Change world-label text at runtime with Geo.set_text(label, text) so it refits; opt a label out with set_meta("no_fit", true). `--tour` prints which labels were shrunk.
- 2026-10-21: Scope note from the user: this UI pass must not change game logic. Known gameplay issues left as-is (seen in autotest, not fixed): clock-out goal can count itself as unfinished at the punch clock; bot can't complete the Night 2 walkway observation; bot dies at Night 3 GATE 02.
- 2026-10-21: Tablet BOARDING mode shows BoardingPassCard (generated assets/ui/boarding_pass.png, fields printed by the game).
- 2026-10-21: Title logo is drawn in code (scripts/ui/title_logo.gd: tracked GATE + lightbox 0 tile with the 0 optically centred + arrow). The user rejected a generated logo image — don't reintroduce one. Game icon is generated assets/ui/app_icon.png (config/icon) + icon.ico (config/windows_native_icon); icon.svg is unused.
- 2026-10-21: Keypad modal is the generated keypad_full.png (keys painted in); KeypadView puts invisible buttons on the painted key grid (ART_KEY0/STEP in 1024x1536 art space) and draws LCD/LED/press feedback on top.
- 2026-10-21: project.godot sets rendering msaa_2d=2 so rotated papers/cards are not jaggy; papers still settle at rotation 0.
- 2026-10-21: Godot/ICU wraps Korean between any two syllables in every autowrap mode ("정상/이 | 상을"). UiKit.keep_all() glues syllables with U+2060 (zero width, no tofu in any UI font) so lines break at spaces; UiKit.label/rich apply it, and UI text assigned later should go through it too. FlapLabel is left out (its flip animation would show the joiners).

## Conventions
- 2026-10-21: Story/pacing lives in scripts/director/phases/{day,night}{1-3}.gd (PhaseScript); rules/anomalies are data in scripts/data/rules_db.gd and anomaly_db.gd. Facility actions go through Events.player_action(action, target); the ShiftDirector matches them against AnomalyDB fix/lethal lists.
- 2026-10-21: Debug launch args after `--`: `--day N` / `--night N` jump to a phase, `--tour <dir>` screenshot tour, `--autotest <dir> [--ending exit|board]` bot playthrough.
- 2026-10-21: `-- --uigallery <dir> [--night]` (run from the menu scene) captures every UI screen: menu, staff card, HUD, tablet tabs, binder, document, keypad, camera, pause/settings, morning report, BOARDED, prologue. Doesn't touch the save.
- 2026-10-21: UI motion vocabulary: scripts/ui/ui_fx.gd (pop/slide/flicker/shake/stagger/count/typewrite/slam/backdrop), FlapLabel + FlapBoard (split-flap), StampMark, SignRow (menu rows), UiIcon (vector pictograms). Modal backdrops = UiKit.backdrop() + shaders/ui_blur.gdshader. FlapBoard draws each glyph without a width limit and sizes tiles from the widest glyph — a width-limited draw_string silently drops glyphs wider than the box (M, N, D in condensed Bahnschrift).
- 2026-10-21: `-- --ending-scene exit|board|announce <dir>` on scenes/ending.tscn plays one ending directly and saves title/banner/credits shots. Launch autotest bots with a normal (not minimized) window — minimized instances exit early.

## Status
- 2026-10-21: All 6 phases + 3 endings written; Day 1 verified by autotest bot up to the FIDS photo goal. Remaining: full autotest pass Day1→Night3 (bot re-shoots photos while radio talks — make it wait for task completion), visual pass on day lighting/menu/endings, tuning.
