# Ashen Frost's Dugtrio Den (map 776, Case Twenty): variable 351 counts four things on its ice: the Dugtrio (EV2, EV3),
# the Diglett (EV11) and the touch tile at (5,8) (EV10, no graphic). At 4 the den's end (EV12) starts the battle and
# counts the house in variable 353. The tile and what is left come with the puzzle assist.
module PokeAccess
  module AshenDugtrioDen
    MAP = 776
    COUNT = 351
    NEEDED = 4
    TRUFFLES_AT = [5, 8]
    # Each thing that counts: its event, the self switch its page sets once counted, and its words in the hint.
    STEPS = [[2, "B", :afd_den_item_left], [3, "A", :afd_den_item_right], [11, "A", :afd_den_item_diglett],
             [10, "A", :afd_den_item_truffles]]

    # The count variable's value.
    def self.count
      $game_variables[COUNT].to_i
    end

    # Whether a thing has counted.
    def self.done?(step)
      $game_self_switches[[MAP, step[0], step[1]]] ? true : false
    end

    # What has counted, as the den's end checks it.
    def self.found
      [count, NEEDED].min
    end

    # The assist's line: what is left, until the end starts by itself.
    def self.hint
      return nil if count >= NEEDED
      left = STEPS.reject { |s| done?(s) }.map { |s| PokeAccess::I18n.t(s[2]) }
      left.empty? ? nil : [:afd_den_left, { :list => left.join("; ") }]
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  den = PokeAccess::AshenDugtrioDen
  mechanic(:state, den::MAP, :part => :afd_den) do
    auto
    spot :at => den::TRUFFLES_AT, :label => :afd_den_truffles_spot, :onto => true, :assist => true,
         :when => lambda { !den.done?(den::STEPS[3]) }
    count :afd_den_count, :value => lambda { den.found }, :of => den::NEEDED, :assist => true, :hide_zero => true
    hint lambda { den.hint }
    solved(nil, :quiet => true) { den.count >= den::NEEDED }
  end
end
