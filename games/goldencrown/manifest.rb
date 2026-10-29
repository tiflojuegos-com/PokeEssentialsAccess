# Load order of the Pokemon Golden Crown modules (no .rb), after core. Golden Crown is Essentials v19.1 on mkxp-z with
# Ruby 3.0, so core/v21 covers its stock screens, and the symbols its edited summary adds are read here; its
# third-party screens (Elite Battle DX, the ZUD raids and Max Lair, the contests, the pause menu, PokeSearch, the
# phenomena) are read by plugins/, declared under :plugins.
{
  :modules => %w[
    constants
    passability
    summary_marks
  ],
  :plugins => %w[boons_phenomena contest_hall dynamax ebdx encounter_list_ui modular_menu pokesearch zud_max_lair
                 zud_raid_database zud_raid_dens]
}
