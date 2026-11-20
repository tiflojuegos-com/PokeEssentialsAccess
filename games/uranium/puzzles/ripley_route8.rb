# Ripley's mission on Route 8 (map 163): nine S51 sentinels (events 1 to 9) that patrol a loop and see three or four tiles
# straight ahead; whoever they see goes back to (9, 11), except under event 5, which always sends the player to (18, 31).
# The patrol boxes come from the sentinels' move routes: every line of the corridor is seen at some moment, so no way
# is free of sight and the crossing is a matter of timing.
module PokeAccess
  # The sentinels' patrol boxes and their names.
  module UraniumRipley
    # The sentinels that see three tiles; the rest see four.
    def self.short_sight
      [1, 6, 7]
    end

    # Each sentinel's patrol box as x0, y0, x1, y1.
    def self.patrols
      { 1 => [18, 7, 18, 13], 2 => [17, 16, 22, 21], 3 => [17, 16, 22, 21], 4 => [19, 26, 20, 31],
        5 => [17, 26, 18, 31], 6 => [14, 20, 14, 26], 7 => [14, 30, 14, 36], 8 => [22, 33, 27, 37],
        9 => [28, 33, 34, 37] }
    end

    # A sentinel's name: how far it sees and, with the assist, the box it patrols while it stands in it; event 5, once
    # it has seen the player, is set at (22, 19) and walks its route from there for the rest of the visit.
    def self.label(event)
      base = PokeAccess::I18n.t(short_sight.include?(event.id) ? :ura_po_s51_3 : :ura_po_s51_4)
      box = patrols[event.id]
      return base unless box && PokeAccess::Puzzles.assist?
      return base unless event.x.between?(box[0], box[2]) && event.y.between?(box[1], box[3])
      base + ". " + PokeAccess::I18n.t(:ura_po_s51_patrol, :x0 => box[0], :y0 => box[1], :x1 => box[2], :y1 => box[3])
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 163) do
    auto
    arrival_hint :ura_po_s51_rule, :once => true
    name 1..9, lambda { |ev| PokeAccess::UraniumRipley.label(ev) }
    sent_back :ura_po_s51_sent, :to => [9, 11], :events => [1, 2, 3, 4, 6, 7, 8, 9]
    sent_back :ura_po_s51_sent_here, :to => [18, 31], :events => 5
    phase lambda { true }, :quiet => true, :hint => :ura_po_s51_hint
  end
end
