# Revvy Shared Memory

Shared memory for ALL agents (Claude/Codex/Kimi ...) working in this project.
Read it at session start. When you make a durable decision, adopt a convention,
or leave work half-done, append a dated one-line entry under the matching
heading so the next agent (possibly a different model) picks up where you left
off.

## Decisions
- 2026-10-21: GATE 0 prototype is GDScript on Godot 4.7.2 (Steam build), Forward+. Level/props are built procedurally in code (scripts/world/terminal.gd); no art assets. SFX from tools/gen_sfx.py, PA voice from tools/gen_voice.ps1 (Windows SAPI).
- 2026-10-21: StandardMaterial3D screens using a ViewportTexture as emission_texture must set `emission = Color.BLACK` (emission op ADD adds the color to the texture → washed-out white).

## Conventions
- 2026-10-21: Story/pacing lives in scripts/director/phases/{day,night}{1-3}.gd (PhaseScript); rules/anomalies are data in scripts/data/rules_db.gd and anomaly_db.gd. Facility actions go through Events.player_action(action, target); the ShiftDirector matches them against AnomalyDB fix/lethal lists.
- 2026-10-21: Debug launch args after `--`: `--day N` / `--night N` jump to a phase, `--tour <dir>` screenshot tour, `--autotest <dir> [--ending exit|board]` bot playthrough.

## Status
- 2026-10-21: All 6 phases + 3 endings written; Day 1 verified by autotest bot up to the FIDS photo goal. Remaining: full autotest pass Day1→Night3 (bot re-shoots photos while radio talks — make it wait for task completion), visual pass on day lighting/menu/endings, tuning.
