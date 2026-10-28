# Victorian - talking NPC in Godot

A small 3D room with first-person controls, an NPC (June) who idles, and a Windows XP
style chat window. Press **E** while looking at her to talk. Her replies come from a
local LLM through [NobodyWho](https://github.com/nobodywho-ooo/nobodywho).

## Run it
1. Install **Godot 4.6+** (the current NobodyWho Godot extension needs 4.6).
2. Download the NobodyWho Godot release (nobodywho-godot-v12.1.0 tested) and copy its
   `addons/nobodywho` folder into this project's `addons/` folder.
3. Open the project and press F5. The first launch downloads Gemma 3 1B (Q4_K_M, about 800 MB)
   from Hugging Face; after that it works offline. Qwen3 0.6B is lighter but just parroted the
   player in testing; swap `MODEL` in `scripts/npc_brain.gd` if you want it anyway.

Controls: WASD move, Shift run, mouse look, **E** talk, **Esc** closes the chat (or frees the mouse).

## Files
- `scripts/persona.gd` - June's personality, flirt rules, and mood stages. Edit here.
- `scripts/npc_brain.gd` - LLM chat, rapport score (keywords + a judge prompt), and remembered name/facts (saved to `user://june_memory.json`).
- `scripts/chat_window.gd` - WinXP window UI.
- `assets/character/npc.glb` - character model. It only has a walk cycle, so the idle (arms lowered from the T-pose, breathing, sway) is done in code.
