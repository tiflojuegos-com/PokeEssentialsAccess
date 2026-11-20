# Coastal Cave (map 184, SQ12): the door at (16..18, 7) is three tile events; the middle one (event 9) answers "the key Pokemon
# shall unlock the path" and opens the other two only if the player has an Aerodactyl. Six stone plates (events 17 to 22) are
# two inscriptions of four Unown glyphs each, drawn in the tileset: AERO over the three tiles at x 7 to 9 and DACT over those
# at x 25 to 27.
PokeAccess::Game.define("keishou") do
  inscriptions = { 17 => "AERO", 21 => "AERO", 22 => "AERO", 18 => "DACT", 19 => "DACT", 20 => "DACT" }
  mechanic(:state, 184) do
    auto
    name 9, lambda { PokeAccess::Puzzles.assist? ? :ks_coast_door_key : :ks_coast_door },
         :when => lambda { |ev| !$game_self_switches[[184, ev.id, "A"]] }
    name 17..22, lambda { |ev| [:ks_stone_plate, { :letters => inscriptions[ev.id] }] }
  end
end
