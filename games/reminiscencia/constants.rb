# Reminiscencia v2.3 profile: same Essentials base as the core defaults. The run does not spend the
# trainer's money (it sits at its starting value for the whole game): its economy is the Coin item, picked
# up on the maps and charged by the shop, Hoopa, the blessing cards and the upgrade tree, with Heart Scales
# as the second currency. The trainer line says those two and drops the dead money.
PokeAccess::Game.define("reminiscencia") do
  config(:money_label, :rem_coins)
  trainer_part(:coins)  { |_tr| PokeAccess::I18n.t(:rem_coins,  :n => $PokemonBag.pbQuantity(:COIN)) }
  trainer_part(:scales) { |_tr| PokeAccess::I18n.t(:rem_scales, :n => $PokemonBag.pbQuantity(:HEARTSCALE)) }
  trainer_order [:name, :coins, :scales, :badges, :pokedex, :playtime]

  # This game extends two engine enums past the vanilla range, so the core tables stopped short and the
  # additions read as nothing: a Pokemon with the sixth status had no condition spoken at all, and three
  # overworld weathers that fill the screen were announced as clear skies. The ids are the game's own, from
  # its PBStatuses and PBFieldWeather; two of the weather names are translated here, because the game names
  # them in English while everything else it says is in Spanish.
  names(:status_names, 6 => "Alarmado")
  names(:field_weather_names, 8 => "Charco", 9 => "Ceniza", 10 => "Fuego")
end
