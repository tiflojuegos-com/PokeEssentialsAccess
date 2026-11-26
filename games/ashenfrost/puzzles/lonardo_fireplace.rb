# The Lonardo Mansion's fireplace of case five (map 243), the way up to the Hidden Room (map 246): the clock (EV2, no
# sprite, faced from below) gives a bucket with the Bronze Key, the kitchen sink (map 240, EV8) fills it and the water
# puts the fire out (EV3, self switch A); with switch 96 on, the fireplace moves its wood aside (self switch C).
module PokeAccess
  module AshenFireplace
    MAP = 243
    CLOCK = 2
    FIRE = 3

    # A self switch of an event of the drawing room.
    def self.self_on?(id, letter); $game_self_switches[[MAP, id, letter]] ? true : false; end

    # Whether the bag holds an item.
    def self.has?(item); ($bag.has?(item) rescue false) ? true : false; end

    # What the way up waits for: the clock, filling the bucket, dousing the fire or the wood; nil while it waits on the
    # story or once the way is open.
    def self.step
      return (self_on?(FIRE, "C") || !$game_switches[96] ? nil : :wood) if self_on?(FIRE, "A")
      return :douse if has?(:BUCKETWATER)
      return :fill if has?(:BUCKET)
      self_on?(CLOCK, "A") ? nil : :clock
    end

    # A hint naming an item as the game names it.
    def self.hint(key, item)
      [key, { :item => PokeAccess::Data.item_name(item) }]
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  fire = PokeAccess::AshenFireplace
  mechanic(:state, fire::MAP, :part => :afa_fireplace) do
    auto
    name fire::CLOCK, :afa_clock
    name fire::FIRE, :afa_fireplace, :when => false
    phase lambda { PokeAccess::Puzzles.assist? && fire.step == :clock },
          :hint => lambda { fire.hint(:afa_clock_hint, :BRONZEKEY) }, :hidden => right_way(fire::CLOCK)
    phase lambda { PokeAccess::Puzzles.assist? && fire.step == :fill }, :hint => lambda { fire.hint(:afa_bucket_hint, :BUCKET) }
    phase lambda { PokeAccess::Puzzles.assist? && fire.step == :douse },
          :hint => lambda { fire.hint(:afa_douse_hint, :BUCKETWATER) }, :hidden => right_way(fire::FIRE)
    phase lambda { PokeAccess::Puzzles.assist? && fire.step == :wood }, :hint => :afa_wood_hint, :hidden => right_way(fire::FIRE)
    solved(nil, :quiet => true) { fire.self_on?(fire::FIRE, "C") }
  end
end
