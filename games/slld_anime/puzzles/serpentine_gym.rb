# Serpentine Gym (episode 6). The Rose Labyrinth (map 362): five groups of thorns ("Thorns <group>-<n>") rise and fall
# on timers, up while the event faces down, and five arrows (BWThornArrow) fly along corridors; a risen thorn (while
# switch 247 is on) or an arrow under the player adds to variable 435 and sends them to 15,37 (events 41 and 42). The
# door at 15,4 (event 34, switch 243) ends it; groups 2 and 4 can be walked round. Map 16: event 18 at 13,14 fights only
# facing west.
module PokeAccess
  module SlldThorns
    MAP = 362
    THORN = /\AThorns \d-\d\z/

    # Whether a thorn event stands up now.
    def self.up?(ev)
      (ev.direction rescue 0) == 2
    end

    # A thorn's name with how it stands.
    def self.label(ev)
      up?(ev) ? :slld_thorns_up : :slld_thorns_down
    end

    # The map's thorns by tile, read once a map: they turn as they rise and fall, but never move.
    def self.thorns
      return @thorns[1] if @thorns && @thorns[0] == $game_map.map_id
      out = {}
      ($game_map.events || {}).each_value { |ev| out[[ev.x, ev.y]] = ev if (ev.name.to_s rescue "") =~ THORN }
      @thorns = [$game_map.map_id, out]
      out
    end

    # Drops the thorns read.
    def self.forget; @thorns = nil; end

    # The thorns on the tile the player faces, or nil.
    def self.ahead
      dx, dy = PokeAccess::DIR_DELTA[$game_player.direction] || [0, 0]
      thorns[[$game_player.x + dx, $game_player.y + dy]]
    end

    # Each frame in the labyrinth while its thorns hurt: the faced thorns' rise or fall as it happens.
    def self.poll
      return @faced = nil unless ($game_map.map_id rescue 0) == MAP && $game_switches[247] && $game_player
      ev = ahead
      state = ev ? [ev.id, up?(ev)] : nil
      if ev && @faced && @faced != state
        PokeAccess.speak(PokeAccess::I18n.t(label(ev)), true)
      end
      @faced = state
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::SlldThorns.forget }

PokeAccess::Game.define("slld_anime") do
  thorns = PokeAccess::SlldThorns
  mechanic(:state, thorns::MAP) do
    auto
    name thorns::THORN, lambda { |ev| thorns.label(ev) }
    obstacle(/\ABWThornArrow\z/, :moving => true, :label => :slld_thorn_arrow)
    avoid [8, 24, 25, 26, 33], :assist => true
    sent_back :slld_thorns_back, :to => [15, 37]
    watch :var => 435, :label => :slld_thorn_hits, :number => true
    arrival_hint :slld_thorns_rule, :once => true
    hint :slld_thorns_hint
    solved(nil, :quiet => true) { $game_switches[243] }
  end
  mechanic(:state, 16) do
    auto
    spot :at => [13, 14], :label => :slld_battle_spot, :onto => true,
         :when => lambda { PokeAccess::SlldField.battle_tile?(18) }
  end
  poll_each_frame { thorns.poll }
end
