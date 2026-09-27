# Reminiscencia v2.3 profile on the core defaults. Its currencies are the Coin item and Heart Scales, not the
# trainer's money, so the trainer line says those two instead.
PokeAccess::Game.define("reminiscencia") do
  config(:money_label, :rem_coins)
  trainer_part(:coins)  { |_tr| PokeAccess::I18n.t(:rem_coins,  :n => $PokemonBag.pbQuantity(:COIN)) }
  trainer_part(:scales) { |_tr| PokeAccess::I18n.t(:rem_scales, :n => $PokemonBag.pbQuantity(:HEARTSCALE)) }
  trainer_order [:name, :coins, :scales, :playtime]

  # Reminiscencia keeps mkxp-z's own input, but reads several raw keys itself, which the mod lets the player rebind
  # as extras (menus.rb): the letters its hints paint for them are T, S and A.
  key_hints "Z" => :a, "X" => :b, "C" => :c, "D" => :z, "Q" => :l, "W" => :r, "T" => :fast_travel, "S" => :help,
            "A" => :game_a

  # Dungeon entrances are touch tiles whose only command is getToDungeon(<map id>); the capture is the destination.
  transfer_script(/\bgetTo\w*Dungeon\s*\(\s*(\d+)/)

  # The game paints Anthony as "???" until switch 106 is on (0500 Messages.rb:1727); the name filter does the same.
  PokeAccess.register_name_filter do |nm|
    (nm == "Anthony" && !($game_switches[106] rescue true)) ? "???" : nil
  end

  # Names for the ids the game adds past the vanilla enums (its PBStatuses and PBFieldWeather values); two weather
  # names are translated, as the game gives them in English.
  names(:status_names, 6 => "Alarmado")
  names(:field_weather_names, 8 => "Charco", 9 => "Ceniza", 10 => "Fuego")
end
