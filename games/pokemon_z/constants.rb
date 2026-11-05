# Pokemon Z 2.18 profile: only what differs from core/foundation/config.rb.
PokeAccess::Game.define("pokemon_z") do
  # Per-game button relabels for the remap menu (Z maps X/Y/Z to its field actions); added to the core
  # defaults, never replacing them.
  button_labels :x => "Pokevial", :y => "PokeRider", :z => "DexNav"

  # Z keeps RPG Maker XP's default keys, so its hints paint those letters (the pause panel's "[A] Curar").
  key_hints PokeAccess::KeyHints::RGSS_LETTERS

  # The gym's beam barriers ("rayos" sprites), said as beams with the zap cue; rayosLegend is the legendary
  # encounters' graphic, not a barrier.
  hazard(/rayos(?!Legend)/i, :loc_beam)

  # The light in the Reflection Chambers, the portal back to the Luminalia palace, takes the teleporter cue.
  teleporter(/\Aluz\z/i)

  # Z's two statuses past the vanilla five (PBStatuses ids), capitalised here; the game writes them lowercase.
  names(:status_names, 6 => "Caduco", 7 => "Hemorragia")

  # Z surfs on a mount, never with a Pokemon's move: Kernel.pbSurf asks for Surf's badge and the Montura Surf.
  field_move_tool(:SURF, :SURFMONTURA, true)

  # Its Kernel.pbSurf refuses while someone walks along without the following Pokemon (its pbHasDependentEvents? is
  # false whenever the "Dependent" event is one of them); the switch it would let them past by,
  # Following_Activated_Switch, Z never defines, so that check raises.
  surf_company(:dependents)

  # Its maps clear with alchemy, not field moves: a bush gives way to a Hachuela Endeble and a rock to a Polvo
  # Explosivo, each used up by the event that takes it.
  field_gate(/pbDeleteItem\(:HACHAENDEBLE/, :loc_bush, :HACHAENDEBLE)
  field_gate(/pbDeleteItem\(:POLVOEXPLOSIVO/, :loc_rock_smash, :POLVOEXPLOSIVO)

  # What the puzzle maps' events are, which core would say by a sprite's file name or as "another part" of the same
  # place: sprites of objects that are never people, and single events by map: Chateau Lanto's mirrors, chalice and
  # hidden button, and the mirrors of its copy in the Arma Definitiva; the Torre Oscura's jukebox; the Maraña Oscura's
  # ropes and cobwebs, and the Arma's; its library's hidden books; the Cueva Talasia's doors, each by its own side and not
  # by where it lands; Fort Leviatán's cell table, a way out once moved; the Romantis keep's purple symbol, a witch's event
  # until switch 479; the Bastión Fractal's soldiers, while frozen, and its ice tiles once broken, which a page's transfer
  # would list as passages.
  sprites = { "rocaElectrica" => :z_crystal, "estatuasHypno" => :z_tower_statue, "pinchos" => :z_spikes,
              "espinasArma" => :z_arma_thorns, "floresIndicadores" => :z_arma_flower_mark }
  named = {}
  [[:z_lanto_mirror_alt, 88, [2, 18, 19]], [:z_lanto_mirror_real, 94, [9, 10, 11]], [:z_lanto_chalice, 86, [12]],
   [:z_lanto_mirror_alt, 473, [38, 64]], [:z_lanto_mirror_real, 473, [39, 65]],
   [:z_lanto_button, 109, [2]], [:z_tower_jukebox_name, 262, [18]],
   [:z_tangle_rope_down, 387, [2, 4, 6, 8, 10]], [:z_tangle_rope_up, 387, [3, 5, 7, 9]],
   [:z_tangle_web, 387, [11, 12, 13, 14, 15, 16, 17, 18, 19]],
   [:z_tangle_rope_down, 388, [2, 5]], [:z_tangle_rope_up, 388, [1, 3, 4, 6]], [:z_tangle_web, 388, [7]],
   [:z_tangle_rope_down, 384, [1, 2]], [:z_tangle_web, 477, [4, 5, 6, 7, 8]], [:z_tangle_web, 470, [1]],
   [:z_arma_book_nw, 472, [11]], [:z_arma_book_e, 472, [10]],
   [:z_talasia_door_n, 433, [6, 7, 11, 15, 21, 25, 29, 32]], [:z_talasia_door_s, 433, [10, 14, 18, 19, 26, 27, 34]],
   [:z_talasia_door_e, 433, [2, 9, 12, 17, 22, 23, 30, 33]],
   [:z_talasia_door_w, 433, [3, 8, 13, 16, 20, 24, 28, 31]]].each do |key, map, events|
    events.each { |id| named[[map, id]] = key }
  end
  named[[126, 2]] = lambda { $game_switches[265] ? :z_fort_way_out : :z_fort_table }
  named[[277, 4]] = lambda { $game_switches[479] ? :z_romantis_symbol : nil }
  [63, 65, 66].each { |id| named[[321, id]] = lambda { $game_self_switches[[321, id, "A"]] ? nil : :z_fractal_soldier } }
  (1..38).each { |id| named[[321, id]] = lambda { $game_self_switches[[321, id, "A"]] ? :z_ice_tile_broken : nil } }
  event_name do |ev|
    key = sprites[ev.character_name.to_s] || named[[$game_map.map_id, ev.id]]
    name = key ? PokeAccess::Puzzles.label_of(key) : ""
    name.empty? ? nil : name
  end
  event_category(:objects) { |ev| sprites[ev.character_name.to_s] ? true : false }

  # Out of the lists and the sonar: what the player walks through wearing those sprites (the caves' decorative crystals,
  # lowered spikes), and the player's reflection in the mirror rooms, an event named "ref" the floor before each mirror
  # moves.
  event_hidden do |ev|
    sprite = ev.character_name.to_s
    ev.name.to_s =~ /\Aref\// || (sprites[sprite] && PokeAccess::World::Mechanics.walked_through?(ev)) ? true : false
  end
end
