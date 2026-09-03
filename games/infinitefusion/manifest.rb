# Load order for the Pokemon Infinite Fusion (Kanto) modules (no .rb), loaded after core. The game is
# Essentials v18 (GameData already in, but still $Trainer and PokeBattle_Scene), so the core covers the whole
# vanilla loop -- pause menu, party, bag, summary, storage, battle, options, Pokegear and the minigame suite
# all use the stock classes. What needs readers here is what the fusion mechanic added.
# Two things this game shares with Hoenn live in the core instead, since both ship the same class: the HUD
# text writer (Kernel.pbDisplayText -> field/hud_text) and the character creator (menus/character_creator).
{
  :modules => %w[
    fusion_preview
    storage_fusion
  ],
  :plugins => %w[easy_questing multi_save better_region_map]
}
