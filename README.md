# Victorian - talking NPC in Godot

A small 3D room with first-person controls and an NPC (June) you can talk to by voice or text.
Walk into her zone, look at her (her name shows under the crosshair) and press **E**. Her replies
float above her head in an XP-style balloon. Her replies come from a
local LLM through [NobodyWho](https://github.com/nobodywho-ooo/nobodywho).

## Run it
1. Install **Godot 4.6+** (the current NobodyWho Godot extension needs 4.6).
2. Download the NobodyWho Godot release (nobodywho-godot-v12.1.0 tested) and copy its
   `addons/nobodywho` folder into this project's `addons/` folder.
3. Open the project and press F5. The first launch downloads Gemma 3 1B (Q4_K_M, about 800 MB)
   from Hugging Face; after that it works offline. Qwen3 0.6B is lighter but just parroted the
   player in testing; swap `MODEL` in `scripts/npc_brain.gd` if you want it anyway.

Press **F3** in game for a debug overlay (mouse/keyboard state). If the mouse won't look around, hold right mouse and drag.
Controls: WASD move, Shift run, mouse look, **E** start talking, hold **V** to speak (push to talk),
**Enter** to type, **Esc** pause menu (voice mode, microphone picker with level meter, free-talk sensitivity).
Speech recognition is Whisper base via NobodyWho (about 150 MB, downloaded on first run, offline after).

## Files
- `scripts/persona.gd` - June's personality, flirt rules, and mood stages. Edit here.
- `scripts/npc_brain.gd` - LLM chat, rapport score (keywords + a judge prompt), and remembered name/facts (saved to `user://june_memory.json`).
- `scripts/voice_input.gd` - mic capture, push-to-talk / free-talk detection, Whisper transcription.
- `scripts/npc_voice.gd` - June's spoken voice (Kokoro text-to-speech via NobodyWho, ~330 MB first run). Change `VOICE` to try another.
- `scripts/talk_bubble.gd` - speech balloon above her head.
- `scripts/pause_menu.gd` - Esc menu with the voice mode toggle (saved to `user://settings.cfg`).
- `assets/character/npc.glb` - character model. It only has a walk cycle, so the idle (arms lowered from the T-pose, breathing, sway) is done in code.
