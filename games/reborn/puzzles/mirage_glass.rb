# Mirage Tower's ground floor (map 668, copy 707): eighteen mirror walls with no graphic, named "Glass", break with Rock
# Smash, each adding one to variable 378; the one that brings it to 18 opens a hole to B1F (self switch B). With the
# assist, the count and what the last one does are said.
module PokeAccess
  module RebornMirageGlass
    MAPS = [668, 707]
    GLASS = /\AGlass\z/
    TOTAL = 18

    # True when the event's self switch is on.
    def self.self_on?(ev, letter)
      $game_self_switches[[$game_map.map_id, ev.id, letter]] ? true : false
    end

    # The name of a mirror: whole, cracked or the hole it left.
    def self.label(ev)
      return :rbd_mt_hole if self_on?(ev, "B")
      self_on?(ev, "A") ? :rbd_mt_cracked : :rbd_mt_mirror
    end

    # True while the mirror can still be broken, or leads down.
    def self.listed?(ev)
      self_on?(ev, "B") || !self_on?(ev, "A")
    end

    # True once the hole is open.
    def self.open?
      ($game_map.events || {}).values.any? { |ev| ev.name.to_s =~ GLASS && self_on?(ev, "B") }
    end
  end
end

PokeAccess::Game.define("reborn") do
  mt = PokeAccess::RebornMirageGlass
  mechanic(:state, mt::MAPS, :part => :glass) do
    auto
    not_control mt::GLASS
    name mt::GLASS, lambda { |ev| mt.label(ev) }, :when => lambda { |ev| mt.listed?(ev) }
    count :rbd_mt_count, :var => 378, :of => mt::TOTAL, :assist => true, :reset => false
    hint :rbd_mt_hint
    info { nil }
    active { PokeAccess::Puzzles.assist? && !mt.open? }
    solved(nil, :quiet => true) { mt.open? }
  end
end
