# Load order of the Pokemon Ashen Frost modules (no .rb), after core. Ashen Frost is Essentials v20.1 on mkxp-z with Ruby
# 3.1, so core/v21 covers its stock screens. Its case files, evidence, printed documents, blackjack, Tutor.net and remembered
# moves are its own or edited copies and are read here; the third-party scripts it ships clean, under :plugins.
{
  :modules => %w[
    constants
    passability
    pause
    case_file
    documents
    pictures
    flying
    blackjack
    tutor_net
    move_remember
    intro_options
    field_screens
    puzzles/well_temple
  ],
  :plugins => %w[enhanced_ui_v1 essentials_deluxe ev_allocator fl_roulette hidden_power_type multi_save ocarina poke_poker
                 quest_ui racecourse text_log tip_cards]
}
