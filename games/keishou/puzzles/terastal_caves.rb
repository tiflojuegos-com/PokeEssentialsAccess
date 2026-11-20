# Ancient Terastal Caves (maps 252, 254 and 256 to 265): the socket at (31, 50) of every cave (event 5) takes one of four
# crystals, Damp, Heat, Icy or Smooth (switches 151 to 154), and the whole system changes with the one set, which can be
# taken off again. The same page then transfers the player to the cave of the new combination, on the same tile, so the
# watch has no frame to speak in: a transfer between caves says which crystals are set on arriving, and one that stays on the
# map is heard from the watch. The crossing (map 255) has four sockets of its own (events 4, 5, 10 and 11) writing the same
# switches, and its three entrances pick the cave by them: coming in from it, or into it from a cave, says the crystals set.
PokeAccess::Game.define("keishou") do
  caves = [252, 254] + (256..265).to_a
  crossing = 255
  sockets = { crossing => [4, 5, 10, 11] }
  crystals = [[151, :ks_o_crystal_damp], [152, :ks_o_crystal_heat], [153, :ks_o_crystal_icy], [154, :ks_o_crystal_smooth]]
  set_names = lambda do
    names = crystals.select { |switch, _label| $game_switches[switch] }.map { |_switch, label| PokeAccess::I18n.t(label) }
    names.empty? ? PokeAccess::I18n.t(:ks_o_crystal_none) : names.join(", ")
  end
  crystals_set = lambda { [:ks_o_crystal_shift, { :set => set_names.call }] }
  crystals_now = lambda { [:ks_o_crystal_now, { :set => set_names.call }] }
  (caves + [crossing]).each do |map|
    mechanic(:state, map) do
      auto
      name sockets[map] || 5, :ks_o_crystal_socket
      crystals.each do |switch, label|
        watch :switch => switch, :label => label, :on => :ks_o_crystal_set, :off => :ks_o_crystal_free
      end
      sent_back crystals_set, :maps => caves if map != crossing
      sent_back crystals_now, :maps => map == crossing ? caves : [crossing]
      arrival_hint :ks_o_crystal_rule, :once => true
    end
  end
end
