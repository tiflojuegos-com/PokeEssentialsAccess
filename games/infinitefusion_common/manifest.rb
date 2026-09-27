# Load order for what both Infinite Fusion games share (no .rb): imported by infinitefusion and infinitefusion_hoenn,
# loaded after core and the plugins and before each game's own modules; Essentials v18 (GameData, but still $Trainer
# and PokeBattle_Scene).
{
  :modules => %w[
    fusion_preview
    storage_fusion
    no_levels
    sprites_page
    entry_pages
    dex_page
    fusion_marks
    outfits
    character_creator
    field_moves
    water_current
    moves_list
    turbo_mode
    radar_banner
    option_screens
    hat_screen
    sprite_credits
    speech_bubbles
    game_lang
    shuffle_progress
  ]
}
