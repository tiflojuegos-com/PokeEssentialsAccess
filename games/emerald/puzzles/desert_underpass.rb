# The Desert Underpass (maps 841 to 844) and Mirage Tower (maps 809, 810 and 812): wall buttons and levers drawn with a
# tile, each showing a far wall open and bringing the player back. They transfer the player, so without a name they
# would be listed as exits. No button reads another: the order is only the one the walls let the player reach them in,
# and the core says what each opens.
module PokeAccess
  module EmWallButtons
    BUTTONS = { 841 => [25], 842 => [22, 38], 843 => [5, 7], 844 => [2] }
    LEVERS = { 809 => [14], 810 => [3], 812 => [3] }

    # The name of event ev on the map now, if it is one of these controls.
    def self.label(ev)
      map = $game_map.map_id
      return :em_wall_button if (BUTTONS[map] || []).include?(ev.id)
      return :em_lever if (LEVERS[map] || []).include?(ev.id)
      nil
    end
  end
end

PokeAccess::Game.define("emerald") do
  event_name do |ev|
    key = PokeAccess::EmWallButtons.label(ev)
    key ? PokeAccess::I18n.t(key) : nil
  end
end
