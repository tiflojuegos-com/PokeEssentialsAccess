# Zeraora's New World (map 847), past the Lost Railcave: six electric pillars worked with the action button add one to
# variable 616 and say so. The pillar to work for each count: (22, 14) at 5, (66, 21) at 8, (114, 18) at 9, (81, 63) at
# 10, (12, 146) at 11 and (59, 84) at 12; at 6, the tile at (75, 26) sets the count to 8.
module PokeAccess
  module RebornZeraora
    MAP = 847
    PILLARS = [6, 7, 8, 9, 10, 11]
    NEXT = { 5 => 6, 8 => 7, 9 => 8, 10 => 9, 11 => 10, 12 => 11 }
    ONWARD = [75, 26]
    DONE = 13

    # The quest's count.
    def self.count
      $game_variables[616].to_i
    end

    # The name of a pillar: with the assist, the next one to work says so.
    def self.label(ev)
      PokeAccess::Puzzles.assist? && NEXT[count] == ev.id ? :rbd_ze_pillar_next : :rbd_ze_pillar
    end
  end
end

PokeAccess::Game.define("reborn") do
  ze = PokeAccess::RebornZeraora
  mechanic(:state, ze::MAP, :part => :pillars) do
    auto
    not_control ze::PILLARS
    name ze::PILLARS, lambda { |ev| ze.label(ev) }
    spot :at => ze::ONWARD, :label => :rbd_ze_onward, :assist => true, :onto => true, :when => lambda { ze.count == 6 }
    hint :rbd_ze_hint
    info { nil }
    active { PokeAccess::Puzzles.assist? && ze.count >= 5 && ze.count < ze::DONE }
    solved(nil, :quiet => true) { ze.count >= ze::DONE }
  end
end
