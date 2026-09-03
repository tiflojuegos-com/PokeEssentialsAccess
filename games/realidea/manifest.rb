# Load order for the Realidea game modules (no .rb), loaded after core. Realidea is gen-6 era (covered by
# core + Neo PauseMenu); its bespoke screens (character selection, Vision Realidea system menu, sticker
# album and the text log) need their own readers here.
{
  :modules => %w[
    constants
    system_scene
    album
    minigames
    mouse_minigames
    story_minigames
    hall_of_fame
  ],
  :plugins => %w[easy_questing gender_selection text_log book_scene hatcher simple_encounter_list]
}
