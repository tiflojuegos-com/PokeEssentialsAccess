# Load order for the Relict game modules (no .rb), loaded after core. Relict is modern Essentials + MUI
# (covered by core/v21) plus ArcyGame edits; only its bespoke screens need readers here.
{
  :modules => %w[
    pausemenu
    difficulty
    plates
    itemget
    arcy
  ],
  :plugins => %w[bag_screen_party encounter_list_ui tip_cards dbk_battle dbk_enhanced_ui]
}
