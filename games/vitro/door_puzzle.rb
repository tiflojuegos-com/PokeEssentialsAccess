# Vitro's room of doors (PuzzlePuertas, 0349_Puzzle Puertas, map 128): six rooms, three above and three below, and ten doors with a
# switch each, 151 to 160, open while on. Three buttons on the north wall of the top middle room toggle six doors each, and the game
# shows it only by animating them. The doors read their switches, so the routes follow them, and a flip is said per door. Any order
# of pressing all three once opens the way to the exit at the bottom right. Past that exit, one more door (switch 161) opens for
# good from a switch on the wall beside it, with no sprite and only a sound.
module PokeAccess
  module VitroDoorPuzzle
    # Each door's event (DOOR_EVENTS), its switch and its name.
    DOORS = [[23, 151, :vitro_door_top_left], [17, 152, :vitro_door_top_right], [20, 153, :vitro_door_bottom_left],
             [21, 154, :vitro_door_bottom_right], [22, 155, :vitro_door_left], [18, 156, :vitro_door_middle],
             [19, 157, :vitro_door_right], [24, 158, :vitro_door_exit_top_left], [16, 159, :vitro_door_entrance_top_right],
             [25, 160, :vitro_door_exit_bottom_right], [27, 161, :vitro_door_of_switch]]
    # The buttons' events (ev13 to ev15, each page's press_button) and the wall switch of the last door (ev28).
    BUTTONS = { 13 => :vitro_button_green, 14 => :vitro_button_blue, 15 => :vitro_button_red, 28 => :vitro_door_switch }
    MAP = 128

    # A door's or a button's name, on this map, or nil.
    def self.name(ev)
      return nil unless $game_map.map_id == MAP
      door = DOORS.find { |row| row[0] == ev.id }
      return PokeAccess::I18n.t(:vitro_door_named, :door => PokeAccess::I18n.t(door[2])) if door
      key = BUTTONS[ev.id]
      key ? PokeAccess::I18n.t(key) : nil
    end
  end
end

PokeAccess::Game.define("vitro") do
  event_name { |ev| PokeAccess::VitroDoorPuzzle.name(ev) }
  mechanic(:state, PokeAccess::VitroDoorPuzzle::MAP) do
    PokeAccess::VitroDoorPuzzle::DOORS.each do |_ev, switch, label|
      watch :switch => switch, :label => label, :on => :vitro_door_open, :off => :vitro_door_closed
    end
    active { $game_player.y < 30 }
    arrival_hint :vitro_doors_rule
    hint :vitro_doors_hint
  end
end
