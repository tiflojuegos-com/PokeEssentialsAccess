# Pokemon Nests, optional zones played with the starter. Sagittopoli's sewers (maps 523, 528, 530 and 531): floor tiles
# drawn with tile 824 crack (tile 825, switches 676 to 736) once stepped on, and a second step on a cracked one drops the
# player out of the nest; the routes keep off them, as they leave the map, and the lists name them as cracked. Isola
# Buconero (map 488): plants alike, five that are cut (events 1, 5, 10, 11 and 23) and the rest hiding a Gastly that sends
# the player out, told apart with the assist alone. Vulcano Pulsar (map 500): a torch with no sprite by each ice rock
# (events 8, 9, 10 and 13) lights to melt it. Saloon Torobrado (map 508): touch tiles with no sprite (events 1 to 14) where
# a Scaracno spots the player, drawn as ghosts once a bell (events 15 to 17) is rung; Percorso 8 (map 535) and Percorso 12
# (map 496): tiles with no sprite where the guardian spots the player. Unseen tiles are listed with the assist alone; all of
# them send the player out of the nest, so the routes keep off them.
module PokeAccess
  module XenoNests
    SALOON = 508
    SALOON_TILES = 1..14
    BELLS = [15, 16, 17]
    WATCHED = { 535 => [22, 23, 25, 26, 36, 37], 496 => [8] }
    SEWERS = [523, 528, 530, 531]
    CRACKED_TILE = 825
    ISLAND = 488
    PLANTS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 23, 24, 26]
    CUT = [1, 5, 10, 11, 23]
    VOLCANO = 500
    TORCHES = [8, 9, 10, 13]

    # True when a sewer tile shows cracked.
    def self.cracked?(ev)
      (ev.tile_id rescue 0).to_i == CRACKED_TILE
    end

    # True when an event shows no sprite.
    def self.unseen?(ev)
      ev.character_name.to_s.empty? && (ev.tile_id rescue 0).to_i == 0
    end

    # A saloon tile's name: a ghost once drawn, a watched tile with the assist before, none without it.
    def self.saloon_label(ev)
      return :xv_nest_ghost unless unseen?(ev)
      PokeAccess::Puzzles.assist? ? :xv_nest_watched : nil
    end

    # A plant's name; with the assist, whether it is cut or hides a Gastly.
    def self.plant_label(ev)
      return :xv_nest_plant unless PokeAccess::Puzzles.assist?
      return :xv_nest_plant_cut if CUT.include?(ev.id)
      [:xv_nest_plant_gastly, { :pokemon => PokeAccess::Data.species_name(:GASTLY) }]
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  nests = PokeAccess::XenoNests
  mechanic(:state, nests::SEWERS) do
    auto
    not_control 1..99
    name 1..99, lambda { |ev| nests.cracked?(ev) ? :xv_nest_cracked : nil },
         :when => lambda { |ev| nests.cracked?(ev) }
  end

  mechanic(:state, nests::ISLAND) do
    auto
    name nests::PLANTS, lambda { |ev| nests.plant_label(ev) }
  end

  mechanic(:state, nests::VOLCANO) do
    auto
    name nests::TORCHES, :xv_nest_torch
  end

  mechanic(:state, nests::SALOON) do
    auto
    name nests::BELLS, :xv_nest_bell
    hide nests::SALOON_TILES, :when => lambda { |ev| nests.unseen?(ev) && !PokeAccess::Puzzles.assist? }
    name nests::SALOON_TILES, lambda { |ev| nests.saloon_label(ev) }
  end

  nests::WATCHED.each do |map, tiles|
    mechanic(:state, map) do
      auto
      hide tiles, :when => lambda { |_ev| !PokeAccess::Puzzles.assist? }
      name tiles, :xv_nest_watched, :assist => true
    end
  end
end
