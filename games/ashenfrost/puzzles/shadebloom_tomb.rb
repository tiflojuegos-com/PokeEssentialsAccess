# Candles in Shadebloom Tomb (map 666, Case Sixteen): the switch (EV7) lights candles (EV2 to EV6, one over each stand
# EV8 to EV12) in turn and the stands must be pressed in that order, variable 243 counting presses and 244 the round.
# Rounds: 1 2 3, then 5 3 5 2, then 5 4 1 3 2; each won sinks spikes (self switch A of EV13, EV16, EV19).
module PokeAccess
  module AshenTombCandles
    MAP = 666
    ROUND = 244
    DONE = 3
    SWITCH = 7
    # Each stand by the game's number: its event, the event of its candle and the key of where it stands.
    STANDS = { 1 => [8, 2, :afe_candle_bl], 2 => [9, 3, :afe_candle_tl], 3 => [10, 4, :afe_candle_c],
               4 => [12, 5, :afe_candle_br], 5 => [11, 6, :afe_candle_tr] }
    ORDERS = [[1, 2, 3], [5, 3, 5, 2], [5, 4, 1, 3, 2]]
    SPIKES = [13, 16, 19]

    # The round the candles stand at, 0 to 3.
    def self.round
      $game_variables[ROUND].to_i
    end

    # Whether the three rounds are won.
    def self.done?
      round >= DONE
    end

    # The words for where a stand is.
    def self.place(number)
      PokeAccess::I18n.t(STANDS[number][2])
    end

    # The line as a stand's candle lights.
    def self.lit(number)
      [:afe_candle_lit, { :where => place(number) }]
    end

    # The assist's hint for a round: the order it asks for.
    def self.hint(r)
      [:afe_candles_hint, { :list => ORDERS[r].map { |n| place(n) }.join(", ") }]
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  tomb = PokeAccess::AshenTombCandles
  mechanic(:state, tomb::MAP, :part => :afe_candles) do
    active { PokeAccess::Puzzles.assist? && !tomb.done? }
    arrival_hint :afe_candles_rule
    solved(nil, :quiet => true) { tomb.done? }
    name tomb::SWITCH, :afe_candle_switch
    tomb::STANDS.each do |number, stand|
      name stand[0], lambda { |_ev| [:afe_candle_stand, { :where => tomb.place(number) }] }
      watch :event => stand[1], :say => lambda { tomb.lit(number) }
    end
    tomb::SPIKES.each { |ev| watch :self => [ev, "A"], :say => :afe_spikes_sank }
    tomb::ORDERS.each_index { |r| phase lambda { tomb.round == r }, :hint => lambda { tomb.hint(r) } }
  end
end
