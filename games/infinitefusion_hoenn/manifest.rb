# Load order for the Pokemon Infinite Fusion 2 (Hoenn) modules (no .rb), loaded after core. The game is
# Essentials v18 (GameData already in, but still $Trainer and PokeBattle_Scene), so the core covers the whole
# vanilla loop; only its bespoke Hoenn screens need readers here. The shared HUD text writer this game draws
# most of its labels through (Kernel.pbDisplayText) lives in the core (field/hud_text), because Infinite
# Fusion 1 ships the very same function.
#
# fusion_preview and storage_fusion are DELIBERATE TWINS of the infinitefusion ones, not shared code: the
# two games ship the same fusion screens, but fusion is one saga's mechanic and the core is for what every
# Essentials game has (minigames, menus, battle). Putting a saga in the core would tie it there for good --
# and leave us entangled if that saga's authors ever asked us to drop it. test/static/twins_spec.rb compares
# the copies and fails if one is edited without the other, so the price of duplicating is paid by a test
# instead of by a silent divergence.
#
# The berry dex is a THIRD-PARTY plugin (TDW Berry Core and Dex) shared with another fangame, so its
# reader lives in plugins/ and is declared below. See plugins/manifest.rb.
{
  :modules => %w[
    starters
    color_door
    pokenav
    quests
    fusion_preview
    storage_fusion
  ],
  :plugins => %w[berrydex easy_questing multi_save]
}
