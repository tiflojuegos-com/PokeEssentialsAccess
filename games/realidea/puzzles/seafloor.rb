# The Seafloor reached by submarine (maps 274 and 275): invisible currents (events Trainer(n), drawn see-through) push
# the player one or two tiles once in their sight. On map 274 four lead from the arrival (51,12) to the west exit: EV18
# down, EV13 up, EV17 down, EV19 down; the rest send back or into a dead end, whose one current (EV15) leads back up.
module PokeAccess
  module RealideaSeafloor
    MAP = 274
    # Each map's currents, by event: the way it pushes.
    CURRENTS = {
      274 => { 11 => 8, 12 => 8, 13 => 8, 14 => 8, 15 => 8, 16 => 8, 17 => 2, 18 => 2, 19 => 2, 20 => 6, 21 => 6 },
      275 => { 2 => 2 }
    }
    # The stretches of map 274 as [x0, x1, y0, y1] boxes, first match wins, each with what leads on from it: [the good
    # current's place in the chain (0 back out of the dead end), its event, the way it pushes], or nil by the exit.
    ZONES = [
      [[[4, 10, 37, 39]], [0, 15, 8]],
      [[[40, 55, 29, 37], [44, 48, 38, 41]], [4, 19, 2]],
      [[[29, 59, 20, 23], [34, 59, 24, 28], [30, 38, 17, 19], [56, 59, 17, 19]], [3, 17, 2]],
      [[[15, 23, 18, 22], [2, 31, 23, 35], [32, 33, 24, 30]], [2, 13, 8]],
      [[[0, 59, 31, 51]], nil],
      [[[0, 59, 0, 30]], [1, 18, 2]]
    ]
    TOWARD = { 2 => :toward_down, 4 => :toward_left, 6 => :toward_right, 8 => :toward_up }

    # True for a current of these maps.
    def self.current?(ev)
      ids = CURRENTS[($game_map.map_id rescue 0)]
      ids ? ids.key?(ev.id) : false
    end

    # True while an event is drawn see-through: not there for the eye.
    def self.unseen?(ev)
      (ev.opacity rescue 255).to_i == 0
    end

    # What is said as a current pushes the player: the way it pushes.
    def self.pushed(way)
      [:rea_sea_pushed, { :dir => PokeAccess::I18n.t(TOWARD[way]) }]
    end

    # The stretch of map 274 the player stands in, as its place in ZONES.
    def self.zone
      x = $game_player.x
      y = $game_player.y
      ZONES.index { |zone| zone[0].any? { |x0, x1, y0, y1| x >= x0 && x <= x1 && y >= y0 && y <= y1 } }
    end

    # The assist's line for a stretch: the good current to take and the way it pushes, the one out of the dead end, or
    # the exit.
    def self.hint(leads)
      return :rea_sea_hint_exit unless leads
      return :rea_sea_hint_back if leads[0] == 0
      [:rea_sea_hint, { :step => leads[0], :dir => PokeAccess::I18n.t(TOWARD[leads[2]]) }]
    end

    # The name of the good current the assist points at, a way to which ends with the press into its sight.
    def self.spot(leads)
      leads[0] == 0 ? :rea_sea_way_back : [:rea_sea_good, { :step => leads[0] }]
    end
  end
end

PokeAccess::Routes::Effects.touch_source do |ev|
  PokeAccess::RealideaSeafloor.current?(ev) && !PokeAccess::Puzzles.assist? ? :unseen : nil
end

PokeAccess::Game.define("realidea") do
  sea = PokeAccess::RealideaSeafloor
  sea::CURRENTS.each do |map, ways|
    mechanic(:state, map) do
      auto
      hide(/\AShota\z/, :when => lambda { |ev| sea.unseen?(ev) })
      ways.each { |id, way| sent_back lambda { sea.pushed(way) }, :forced => true, :events => id }
      next unless map == sea::MAP
      arrival_hint :rea_sea_rule
      sea::ZONES.each_with_index do |zone, i|
        leads = zone[1]
        spots = leads ? [{ :event => leads[1], :label => lambda { sea.spot(leads) }, :assist => true }] : []
        phase lambda { sea.zone == i }, :quiet => true, :hint => lambda { sea.hint(leads) }, :spots => spots
      end
    end
  end
end
