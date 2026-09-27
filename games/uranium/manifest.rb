# Load order for the Pokemon Uranium modules (no .rb), after core. Uranium is Essentials v16 with v17 back-ports, the
# Elite Battle System and Black/White-style screens, on the RPG Maker XP player that the launcher converts to mkxp-z
# (catalog "convert"); compat.rb is not a module: mkxp.json's preloadScript runs it before the game's scripts.
{
  :modules => %w[
    messages
    load
    new_game
    pause_menu
    battle_menus
    battle_bag
    language
    bag
    pokedex
    options
    berry_mart
    controls
    field
    summary
    trainer_card
    pokepod
  ],
  :plugins => %w[hall_of_fame_bw_gen6 punch_bag]
}
