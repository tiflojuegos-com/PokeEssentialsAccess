# Load order for the Realidea game modules (no .rb), loaded after core. Realidea is gen-6 era (covered by
# core + Neo PauseMenu); its bespoke screens (character selection, Vision Realidea system menu, sticker
# album and the text log) need their own readers here.
{
  :modules => %w[
    constants
    system_scene
    album
    minigames
    story_minigames
  ],
  :plugins => %w[easy_questing gender_selection text_log]
}
