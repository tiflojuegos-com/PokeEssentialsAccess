# Load order for the Pokemon Infinite Fusion 2 (Hoenn) modules (no .rb), loaded after core. The game is
# Essentials v18 (GameData already in, but still $Trainer and PokeBattle_Scene), so the core covers the
# vanilla loop and only its bespoke Hoenn screens need readers here; the shared HUD text writer
# (Kernel.pbDisplayText) lives in core/field/hud_text. fusion_preview and storage_fusion are DELIBERATE
# TWINS of the infinitefusion ones, not shared code: fusion is one saga's mechanic, not the core's, and
# test/static/twins_spec.rb fails if one copy is edited without the other. The berry dex is a third-party
# plugin shared with another fangame, so its reader lives in plugins/.
{
  :modules => %w[
    starters
    color_door
    pokenav
    quests
    fusion_preview
    storage_fusion
    pokeblocks
  ],
  :plugins => %w[berrydex multi_save better_region_map luka_title]
}
