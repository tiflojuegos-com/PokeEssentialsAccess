# Victory Road's gem rooms: the crystals with whether they are lit, the Emerald Room's arrows said as they fall down the
# player's column, and the Amethyst Room's orb with the flashing crystal it has to break next.
module PokeAccess
  module RebornVrGemRooms
    CRYSTALS = {
      797 => { 9 => 1176, 10 => 1178, 11 => 1177 },
      804 => { 27 => 1218, 31 => 1219, 32 => 1220, 33 => 1221, 35 => 1222, 37 => 1223, 39 => 1224, 41 => 1225 },
      805 => { 84 => 1239, 85 => 1240, 86 => 1241, 87 => 1242, 104 => 2131 },
      809 => { 47 => 1243 }
    }
    EMERALD_LEVERS = [46, 48, 50, 53, 54, 56, 57]
    ARROW = 102
    ARROW_PARK = [0, 1]
    ORB_TARGETS = { 3 => [35, 32], 4 => [55, 37], 5 => [26, 47], 6 => [17, 62], 7 => [50, 61] }

    # A crystal's name, said on once its switch is.
    def self.crystal_label(ev)
      sw = (CRYSTALS[$game_map.map_id] || {})[ev.id]
      PokeAccess::I18n.t(sw && $game_switches[sw] ? :rbc2_crystal_on : :rbc2_crystal)
    end

    # The flashing crystal the orb has to pass over now, or nil once the room is done.
    def self.orb_target
      ORB_TARGETS[$game_variables[520].to_i]
    end

    # How many of the five crystals the orb has broken.
    def self.broken
      [[$game_variables[520].to_i - 3, 0].max, 5].min
    end

    # Each pulse in the Emerald Room: says once a shot that the arrow falls down the player's column, and with the
    # assist what to do about it.
    def self.tick
      return unless $game_map && $game_player && $game_map.map_id == 805 && PokeAccess::Control.scene_map?
      ev = $game_map.events[ARROW]
      return unless ev
      pos = [ev.x, ev.y]
      if pos == ARROW_PARK
        @shot = false
        return
      end
      return if @shot || ev.x != $game_player.x || ev.y > $game_player.y
      @shot = true
      dodge = PokeAccess::Puzzles.assist? ? PokeAccess::RebornVrEmeraldPlan.dodge_line : nil
      PokeAccess.speak(PokeAccess.sentences([PokeAccess::I18n.t(:rbc2_emerald_arrow), dodge]), true)
    end

    # Forgets the shot, on a new map.
    def self.forget; @shot = false; end

    PokeAccess::Frame.each_pulse { PokeAccess::RebornVrGemRooms.tick } unless @pulsing
    @pulsing = true
  end
end

PokeAccess::Game.define("reborn") do
  rooms = PokeAccess::RebornVrGemRooms
  rooms::CRYSTALS.each do |map, crystals|
    mechanic(:state, map, :part => :crystals) do
      auto
      name crystals.keys, lambda { |ev| rooms.crystal_label(ev) }
      arrival_hint :rbc2_sapphire_rule if map == 804
    end
  end

  mechanic(:state, 805, :part => :emerald) do
    auto
    name rooms::EMERALD_LEVERS, lambda { |ev| PokeAccess::RebornVrMines.lever_label(ev) }
    hide rooms::ARROW
    arrival_hint lambda { $game_variables[521].to_i < 8 ? :rbc2_emerald_rule : nil }
    hint :rbc2_emerald_hint
  end

  mechanic(:state, 806, :part => :amethyst) do
    auto
    obstacle(/\Ashadow4\z/, :moving => true)
    spot :at => lambda { rooms.orb_target }, :label => :rbc2_amethyst_crystal, :onto => true,
         :when => lambda { !rooms.orb_target.nil? }
    count :rbc2_amethyst_count, :value => lambda { rooms.broken }, :of => 5
    arrival_hint :rbc2_amethyst_rule
    hint :rbc2_amethyst_hint
    solved { $game_variables[520].to_i >= 8 }
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::RebornVrGemRooms.forget }
