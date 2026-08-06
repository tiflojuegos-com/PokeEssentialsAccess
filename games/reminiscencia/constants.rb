# Reminiscencia v2.3 profile: same Essentials base as the core defaults. Its currency is shown as a bare
# "$" (not "pokedolares"), so the spoken money uses a neutral label.
PokeAccess::Game.define("reminiscencia") do
  config(:money_label, :tr_money_generic)

  # This game extends two engine enums past the vanilla range, so the core tables stopped short and the
  # additions read as nothing: a Pokemon with the sixth status had no condition spoken at all, and three
  # overworld weathers that fill the screen were announced as clear skies. The ids are the game's own, from
  # its PBStatuses and PBFieldWeather; two of the weather names are translated here, because the game names
  # them in English while everything else it says is in Spanish.
  names(:status_names, 6 => "Alarmado")
  names(:field_weather_names, 8 => "Charco", 9 => "Ceniza", 10 => "Fuego")
end
