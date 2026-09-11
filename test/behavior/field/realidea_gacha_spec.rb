# Realidea's loot box (games/realidea/gacha.rb): each draw's prize message names the item but not its
# rarity, which the box only shows as a coloured frame. The reader says the rarity first, from the game's
# own tier lists, and only while the box is open. The stub box hands its draws out the way the real one
# does: Kernel.pbReceiveItem for an item, pbAddPokemon for a Pokémon, each voicing its message through the
# dialogue reader as the game's own message would, so the log shows the order and who interrupts whom.
Object.const_set(:COMUNES, [101, 102, 103]) unless Object.const_defined?(:COMUNES)
Object.const_set(:RAROS, [201, 202, 203]) unless Object.const_defined?(:RAROS)
Object.const_set(:LEGENDARIOS, [301, 302]) unless Object.const_defined?(:LEGENDARIOS)
Object.const_set(:EPICOS, [401, 402]) unless Object.const_defined?(:EPICOS)
module Kernel
  def self.pbReceiveItem(item, quantity = 1); PokeAccess.say_dialogue("¡Has obtenido el objeto #{item}!"); true; end
end
def pbAddPokemon(pokemon, level = nil, seeform = true); PokeAccess.say_dialogue("¡Tester ha obtenido un #{pokemon}!"); true; end
class LootBox
  def pbStartMainScene
    ($pa_gacha_draws || []).each { |d| d.is_a?(Symbol) ? pbAddPokemon(d) : Kernel.pbReceiveItem(d) }
  end
end
require File.expand_path("../../../games/realidea/gacha", File.dirname(__FILE__))

Suite.define("realidea gacha: a prize's rarity comes from the game's own lists, in the words of its odds") do
  g = PokeAccess::ReaGacha
  eq "a common item", g.tier_of(COMUNES[0]), "Común"
  eq "a rare one", g.tier_of(RAROS[1]), "Raro"
  eq "a legendary one", g.tier_of(LEGENDARIOS[0]), "Legendario"
  eq "an epic one", g.tier_of(EPICOS[1]), "Épico"
  eq "an item in no list has no rarity", g.tier_of(999), nil
end

Suite.define("realidea gacha: the rarity is said before each prize, and only while the box is open") do
  SpeakCapture.clear
  $pa_gacha_draws = [RAROS[0], :MISDREAVUS, EPICOS[0]]
  begin
    LootBox.new.pbStartMainScene
  ensure
    $pa_gacha_draws = nil
  end
  eq "each rarity queues just ahead of its prize's message, so a quick player never cuts the previous prize",
     SpeakCapture.log,
     [["Raro", false], ["¡Has obtenido el objeto 201!", false], ["Pokémon", false],
      ["¡Tester ha obtenido un MISDREAVUS!", false], ["Épico", false], ["¡Has obtenido el objeto 401!", false]]

  SpeakCapture.clear
  Kernel.pbReceiveItem(COMUNES[1])
  pbAddPokemon(:LEAFEON)
  eq "an item or a Pokémon handed over anywhere else keeps its message to itself",
     SpeakCapture.lines, ["¡Has obtenido el objeto 102!", "¡Tester ha obtenido un LEAFEON!"]
end
