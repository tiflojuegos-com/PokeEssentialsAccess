# Well Temple candle room (map 686, Case Seventeen): five bases (events 13 to 17) and a switch (event 23) lighting their
# candles (events 18 to 22) in the level's order, variable 252. A base used in order lights its candle and advances 253;
# a wrong one buzzes and resets it. Levels: 1 5 4 2, 3 4 1 2 3, 4 5 5 3 2 1 5; the last lowers spikes (events 10 to 12).
module PokeAccess
  module AshenTempleCandles
    MAP = 686
    LEVEL = 252
    STEP = 253
    BASES = { 13 => 1, 14 => 2, 15 => 3, 16 => 4, 17 => 5 }
    CANDLES = { 18 => 1, 19 => 2, 20 => 3, 21 => 4, 22 => 5 }
    SWITCH = 23
    SPIKES = 10
    LEVELS = [[1, 5, 4, 2], [3, 4, 1, 2, 3], [4, 5, 5, 3, 2, 1, 5]]

    # Whether the three levels are done.
    def self.done?
      $game_variables[LEVEL].to_i >= LEVELS.length
    end

    # Whether the level and step stand at these.
    def self.at_step?(level, step)
      $game_variables[LEVEL].to_i == level && $game_variables[STEP].to_i == step
    end

    # A base's name by its number, marked as due to the assist.
    def self.label(ev)
      level = $game_variables[LEVEL].to_i
      order = LEVELS[level]
      base = [:afc_candle_base, { :n => BASES[ev.id] }]
      due = PokeAccess::Puzzles.assist? && order && order[$game_variables[STEP].to_i] == BASES[ev.id]
      due ? [:afc_due, { :name => PokeAccess::Puzzles.label_of(base) }] : base
    end

    # The assist's line for a step: the level, the base due and its place in the level.
    def self.next_line(level, step)
      [:afc_candles_next, { :level => level + 1, :base => LEVELS[level][step], :n => step + 1, :of => LEVELS[level].length }]
    end

    # Says a candle as the game lights it: a Set Move Route on one of them, on this map, that wears the candles'
    # graphic.
    def self.route_set(id, route)
      return unless $game_map.map_id == MAP
      n = CANDLES[id]
      return unless n && route.list.any? { |m| m.code == 41 && m.parameters[0].to_s =~ /Candles/ }
      PokeAccess.speak(PokeAccess::I18n.t(:afc_candle_lit, :n => n), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  candles = PokeAccess::AshenTempleCandles
  room = at(1, 15, 3, 10)
  before("Interpreter", :command_209, :optional => true) do |interp, _a|
    params = PokeAccess.ivar(interp, :@parameters)
    PokeAccess::AshenTempleCandles.route_set(params[0], params[1]) if params.is_a?(Array)
  end
  mechanic(:state, candles::MAP, :part => :candles) do
    name candles::BASES.keys, lambda { |ev| PokeAccess::AshenTempleCandles.label(ev) }
    name candles::SWITCH, :afc_candle_switch
    watch :self => [candles::SPIKES, "A"], :say => :afc_candles_spikes_down
    candles::LEVELS.each_with_index do |order, level|
      order.each_index do |step|
        phase lambda { PokeAccess::Puzzles.assist? && room.call && PokeAccess::AshenTempleCandles.at_step?(level, step) },
              :hint => lambda { PokeAccess::AshenTempleCandles.next_line(level, step) }
      end
    end
    phase lambda { room.call && !PokeAccess::AshenTempleCandles.done? }, :title => :afc_candles_rule
    solved(nil, :quiet => true) { PokeAccess::AshenTempleCandles.done? }
  end
end
