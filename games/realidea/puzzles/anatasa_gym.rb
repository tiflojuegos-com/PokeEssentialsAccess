# Realidea's gym of Anatasa City (map 238): the guide sends the player to find decoration boxes around the gym (events 6, 9 and
# 10, switches 292 to 294). Taking one says nothing: it sets off a scene that leaves the map and comes back. The boxes are
# drawn as a small light the lists would name by its sprite.
module PokeAccess
  module ReaAnatasa
    BOXES = { 6 => 292, 9 => 293, 10 => 294 }

    # The name of a decoration box, told apart once its decoration is taken.
    def self.box(ev)
      $game_switches[BOXES[ev.id]] ? :rea_deco_box_done : :rea_deco_box
    end
  end
end

PokeAccess::Game.define("realidea") do
  anatasa = PokeAccess::ReaAnatasa
  mechanic(:state, 238) do
    auto
    name anatasa::BOXES.keys, lambda { |ev| anatasa.box(ev) }
    count :rea_deco_count, :switches => 292..294, :assist => true
  end
end
