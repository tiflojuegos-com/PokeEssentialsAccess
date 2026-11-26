# Suspiciously Nice Place (map 773, Case Twenty): variable 347 counts the basement's finds, the present box behind
# boulders (EV14, pbPushThisBoulder, no field move asked) and Truffles' scene (EV15, 44,34). At 2 Ramira's call (EV16)
# goes to Map557 and sets 3; the owner (EV12) is asked about the place (self switch A) and the box (B), setting 4.
module PokeAccess
  module AshenNicePlace
    MAP = 773
    FINDS = 347
    BOX = 14
    TRUFFLES = 15
    TRUFFLES_AT = [44, 34]
    OWNER = 12

    # The finds variable's value.
    def self.finds
      $game_variables[FINDS].to_i
    end

    # Whether an event of the house has run its page once: its self switch A.
    def self.found?(id)
      $game_self_switches[[MAP, id, "A"]] ? true : false
    end

    # The assist's line: what the basement still holds, then the owner's two questions.
    def self.hint
      v = finds
      return nil if v >= 4
      return :afd_nice_owner if v >= 3
      left = []
      left.push(PokeAccess::I18n.t(:afd_nice_item_box)) unless found?(BOX)
      left.push(PokeAccess::I18n.t(:afd_nice_item_truffles)) unless found?(TRUFFLES)
      left.empty? ? nil : [:afd_nice_left, { :list => left.join("; ") }]
    end

    # What the owner's right option sets: the place first, then the box; nil before the call or once both are asked.
    def self.question
      return nil unless finds == 3
      return { :self => "A" } unless $game_self_switches[[MAP, OWNER, "A"]]
      $game_self_switches[[MAP, OWNER, "B"]] ? nil : { :self => "B" }
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  nice = PokeAccess::AshenNicePlace
  push_script(/strengthUsed\s*=\s*true[\s\S]*pbPushThisBoulder/)

  mechanic(:state, nice::MAP, :part => :afd_nice) do
    auto
    spot :at => nice::TRUFFLES_AT, :label => :afd_nice_truffles_spot, :onto => true, :assist => true,
         :when => lambda { nice.finds < 2 && !nice.found?(nice::TRUFFLES) }
    right_choice nice::OWNER, :takes => lambda { nice.question }
    hint lambda { nice.hint }
    active { nice.finds < 4 }
    solved(nil, :quiet => true) { nice.finds >= 4 }
  end
end
