# Pokemon Ashen Frost: the profile's name and its game-wide settings.
PokeAccess::Game.define("ashenfrost") do
  # The letters its tip cards name (Tip Cards/000_Settings.rb): Input::ACTION on Z, JUMPUP on A, AUX2 on W, as RPG Maker XP's.
  key_hints "Z" => :a, "X" => :b, "C" => :c, "A" => :x, "S" => :y, "D" => :z, "Q" => :l, "W" => :r

  # Its Game.exe adds three buttons to mkxp-z's and binds them by default: Input::D (Move Info, read only in battle, Enhanced
  # UI's [002] Battle UI.rb) on Shift and M, Input::F (Skip Text, TEXT_SKIP_BUTTON, Easy Text Skip.rb) on F7 and left Ctrl.
  # Shift and Ctrl are the mod's modifiers, so Move Info goes on Alt plus its M and Skip Text keeps only F7. Input::L (the
  # speed, Better Speed Up/01_Speed_Up.rb) is on Q and left Alt: it keeps Q, or that Alt would change the speed.
  remap_extra(:ashen_move_info, 0x4D, :ashen_key_move_info, :button => :D)
  remap_extra(:ashen_skip, 0x76, :ashen_key_skip, :button => :F)
  key_defaults(:ashen_move_info => "Alt+M", :ashen_skip => "F7", :l => "Q")

  # The battle weathers 015_BattleWeather.rb adds, by the names it gives them.
  names(:weather_names, :FreezingRain => :ashen_w_freezing_rain, :FrozenStorm => :ashen_w_frozen_storm,
        :HolyInferno => :ashen_w_holy_inferno, :SolarWinds => :ashen_w_solar_winds)

  # The pause menu and the panels of the save and load screens paint the case and the level cap (001_UI_PauseMenu.rb,
  # 014_UI_Save.rb, 013_UI_Load.rb).
  trainer_part(:case_file) do |_player|
    n = ($PokemonGlobal.case_num rescue nil)
    n ? PokeAccess::I18n.t(:ashen_case_number, :n => n) : nil
  end
  trainer_part(:level_cap) do |player|
    n = (player.level_cap rescue nil)
    n ? PokeAccess::I18n.t(:ashen_level_cap, :n => n) : nil
  end
  trainer_order [:name, :money, :badges, :case_file, :level_cap, :pokedex, :playtime]
end
