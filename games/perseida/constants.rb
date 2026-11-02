# Pokemon Perseida, on Essentials BES (v16.2, gen-6): the profile's name and its game-wide settings.
PokeAccess::Game.define("perseida") do
  # Its Input (0185_PSystem_Controls) keeps RPG Maker XP's letters: the crafting bar's "C: Crear" and "X: Salir", the quest
  # list's "Q/W" (0227_Item Crafter, 0237_Quest_UI).
  key_hints PokeAccess::KeyHints::RGSS_LETTERS
  # On the map and in the pause menu (0060_Scene_Map, 0212_Menu_Base) A opens the party, S saves, D opens the Pokegear menu
  # and W the arcane clock; Q uses the dark gem, on the map alone.
  button_labels :x => :perseida_btn_x, :y => :perseida_btn_y, :z => :perseida_btn_z, :l => :edas_btn_l,
                :r => :perseida_btn_r
  # F opens the message log on the map and the quests in the pause menu (0230_TextLog Kyu, 0212_Menu_Base); B the bag; M
  # the region map (0060_Scene_Map, 0212_Menu_Base), all read as buttons of its Input (0185_PSystem_Controls). The mod's
  # coordinates hold M, so the map ships on Alt + M; in battle, where Alt sets the speed and the coordinates say nothing, M
  # stays the game's and opens the battle's information (0268_NewBattle_WSED_Commands).
  remap_extra(:text_log, 0x46, :perseida_key_f, :button => :F)
  remap_extra(:clara_bag, 0x42, :perseida_key_b, :button => :B2)
  remap_extra(:clara_map, 0x4D, :perseida_key_m, :button => :M)
  # T talks to Cometry from the pause menu (0212_Menu_Base) and is the mod's info key.
  remap_extra(:clara_cometry, 0x54, :perseida_key_t, :button => :T)
  field_key_defaults(:clara_map => "Alt+M", :clara_cometry => "Alt+T")
  # Its sixth status, the mana overload (0069_PBStatuses), and the weathers its battles and maps add (0080_PBWeather,
  # 0105_PField_FieldWeather).
  names(:status_names, 6 => :perseida_st_overload)
  names(:weather_names, 9 => :w_storm, 10 => :perseida_w_toxic, 11 => :w_fog, 12 => :w_snow)
  names(:field_weather_names, 8 => :w_shadow_sky, 9 => :w_storm, 10 => :perseida_w_toxic, 11 => :w_fog)
end
