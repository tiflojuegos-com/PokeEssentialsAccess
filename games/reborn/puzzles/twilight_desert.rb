# The Twilight Desert (map 841) wraps from east to west: its parallel event 12 moves a player west of x 10 to 164 tiles
# further east, and one east of x 174 as far back west, on the same row. The rule is said on arriving, and each wrap in
# place of a teleport.
module PokeAccess
  module RebornTwilightDesert
    MAP = 841
    SPAN = 164

    # The line for a move the wrap made, or nil for any other.
    def self.wrap_line(from, to)
      return nil unless from[2] == MAP && to[2] == MAP && from[1] == to[1] && (from[0] - to[0]).abs == SPAN
      PokeAccess::I18n.t(:rbe_td_wrapped)
    end
  end
end

PokeAccess::Game.define("reborn") do
  desert = PokeAccess::RebornTwilightDesert
  mechanic(:state, desert::MAP, :part => :wrap) do
    auto
    arrival_hint :rbe_td_rule, :once => true
  end
  PokeAccess::Locator.teleport_cause(:rbe_desert_wrap) { |from, to| desert.wrap_line(from, to) }
end
