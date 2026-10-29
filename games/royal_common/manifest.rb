# Load order for what the games on Pokemon Royal's code share (no .rb): Royal and World Frontier, which ships Royal's
# own scripts ("Scripts del Royal", its "Cambios en LBDS", its edits of the DBK and Hall de la Fama BW), none of which
# Anil and Revival, the other games skyflyer_common serves, have. Imported by both, loaded before each game's own
# modules; each profile names the transcription of its own controls picture (RoyalControls.key).
{
  :modules => %w[
    key_hints
    borde_messages
    controles
    creador
    selectors
    puntos
    tip_menu
    iconos_leyenda
    bag_register
    dex_types
    incubator_level
    super_shiny
    hall_of_fame
    stairs
    daycare_money
  ]
}
