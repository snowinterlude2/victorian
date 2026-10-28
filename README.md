# Victorian - talking NPC in Godot

A small 3D room with first-person controls, an NPC (June) who idles, and a Windows XP
style chat window. Press **E** while looking at her to talk. Her replies come from a
local LLM through [NobodyWho](https://github.com/nobodywho-ooo/nobodywho).

## Run it
1. Install **Godot 4.6+** (the current NobodyWho Godot extension needs 4.6).
2. Download the NobodyWho Godot release and copy its `addons/nobodywho` folder into
   this project's `addons/` folder (or install it from the AssetLib tab).
3. Open the project and press F5. The first launch downloads Qwen3 0.6B (Q4_K_M, about 400 MB)
   from Hugging Face; after that it works offline.

Controls: WASD move, Shift run, mouse look, **E** talk, **Esc** closes the chat (or frees the mouse).

## Files
- `scripts/persona.gd` - June's personality, flirt rules, and mood stages. Edit here.
- `scripts/npc_brain.gd` - LLM chat, rapport score, and remembered facts (saved to `user://june_memory.json`).
- `scripts/chat_window.gd` - WinXP window UI.
- `assets/character/npc.glb` - character model. It only has a walk cycle, so idle is a code-driven sway.
