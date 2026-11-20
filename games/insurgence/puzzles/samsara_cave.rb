# Samsara Cave, the Delta Pidgey room (map 172): six Pidgeotto statues, one of them (event 3, 46,39) drawn with a button
# that asks to be pressed; its Yes turns switch 629 on, which draws an entrance north of the statues (events 8 to 16,
# the door at 48,34 taken facing up, to map 762). A Tesseract rift (event 17, 48,39), drawn once switch 152 is on, gives
# an item when the Tesseract is used within three tiles. No auto: the core would take the entrance being drawn for a
# passage closing.
PokeAccess::Game.define("insurgence") do
  pressed = lambda { $game_switches[629] }
  statue = lambda { |_ev| PokeAccess::Puzzles.assist? && !pressed.call ? :ins_samsara_statue_hint : :ins_samsara_statue }
  rift = lambda do |ev|
    gone = !$game_switches[152] || $game_self_switches[[$game_map.map_id, ev.id, "A"]]
    gone ? nil : (PokeAccess::Puzzles.assist? ? :ins_samsara_rift_hint : :ins_o2_rift)
  end
  mechanic(:state, 172) do
    name 3, statue, :when => lambda { |_ev| !pressed.call }
    right_choice 3, :takes => { :switch => 629 }
    name 17, rift
    solved(:ins_samsara_entrance) { pressed.call }
  end
end
