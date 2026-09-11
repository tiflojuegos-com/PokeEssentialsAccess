# Reminiscencia v2.3 profile: same Essentials base as the core defaults. The run does not spend the
# trainer's money (it sits at its starting value for the whole game): its economy is the Coin item, picked
# up on the maps and charged by the shop, Hoopa, the blessing cards and the upgrade tree, with Heart Scales
# as the second currency. The trainer line says those two and drops the dead money.
PokeAccess::Game.define("reminiscencia") do
  config(:money_label, :rem_coins)
  trainer_part(:coins)  { |_tr| PokeAccess::I18n.t(:rem_coins,  :n => $PokemonBag.pbQuantity(:COIN)) }
  trainer_part(:scales) { |_tr| PokeAccess::I18n.t(:rem_scales, :n => $PokemonBag.pbQuantity(:HEARTSCALE)) }
  trainer_order [:name, :coins, :scales, :badges, :pokedex, :playtime]

  # Every dungeon entrance is a sprite-less touch tile whose only command is getToDungeon(<map id>): 55
  # events over 34 maps, none with an editor Transfer command. The captured number is the destination map,
  # which names the exit; the \w* catches a regional sibling of the call if one ever appears.
  transfer_script(/\bgetTo\w*Dungeon\s*\(\s*(\d+)/)

  # The game hides one character behind "???" until switch 106 is flipped, rewriting the name on its way to
  # the box (0500 Messages.rb:1727) -- so the SCREEN says "???" while the code still carries "Anthony", and
  # reading the code raw handed the player the one thing that scene is withholding. The rule is the game's,
  # switch number included, which is why it is declared here and not in the cleaner.
  PokeAccess.register_name_filter do |nm|
    (nm == "Anthony" && !($game_switches[106] rescue true)) ? "???" : nil
  end

  # The game extends two engine enums past the vanilla range (the sixth status, three overworld weathers);
  # the ids are its own PBStatuses and PBFieldWeather values, and two weather names are translated because
  # the game names them in English.
  names(:status_names, 6 => "Alarmado")
  names(:field_weather_names, 8 => "Charco", 9 => "Ceniza", 10 => "Fuego")
end
