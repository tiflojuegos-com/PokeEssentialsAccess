# Load order for the Pokemon Infinite Fusion 2 (Hoenn) modules (no .rb), loaded after core. The game is
# Essentials v18 (GameData already in, but still $Trainer and PokeBattle_Scene), so the core covers the whole
# vanilla loop; only its bespoke Hoenn screens need readers here. The shared HUD text writer this game draws
# most of its labels through (Kernel.pbDisplayText) lives in the core (field/hud_text), because Infinite
# Fusion 1 ships the very same function.
%w[
  starters
  color_door
  pokenav
  quests
]
