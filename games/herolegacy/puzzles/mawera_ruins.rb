# Mawera's ruins: three statues of 3 by 2 on map 335 show a guardian each, Regice, Registeel and Regirock, by their
# graphic alone, and their page asks for that Pokémon first in the party. On map 336 two doors open only with Unown D
# (left, 24, 28) and Unown E (right, 50, 28) in the party.
PokeAccess::Game.define("herolegacy") do
  species = lambda { |id| PokeAccess::Data.species_name(id).to_s }
  statue = lambda { |id| lambda { |_ev| PokeAccess::I18n.t(:hl_statue, :name => species.call(id)) } }
  guardian = lambda { |id| lambda { PokeAccess::I18n.t(:hl_statue_hint, :name => species.call(id)) } }
  door = lambda do |letter|
    lambda { PokeAccess::I18n.t(:hl_unown_door_hint, :name => species.call(:UNOWN), :letter => letter) }
  end
  mechanic(:state, 335) do
    auto
    { 1 => :REGICE, 2 => :REGISTEEL, 3 => :REGIROCK }.each do |ev, id|
      name ev, statue.call(id)
      on_use ev, guardian.call(id), :assist => true
    end
  end

  mechanic(:state, 336) do
    auto
    name [1, 9], :hl_unown_door
    on_use 1, door.call("D"), :assist => true
    on_use 9, door.call("E"), :assist => true
  end
end
