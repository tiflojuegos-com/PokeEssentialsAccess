# The Psychic-type Contest on Route 3 (episode 13, map 370): sixteen boxes (events 84 to 99, graphic Boxes, colour by
# the way the graphic faces) go to the field of their colour in the corners. Using one lifts it (common event 21, its
# self switch A, switch 386); the arrows then move the box and confirm drops it, and on its field it stays (self switch
# B). Four Vambat (events 109 to 112) fly around, and a box that hits one falls where it is. All sixteen placed end the
# round (switch 418).
module PokeAccess
  module SlldContest
    MAP = 370
    BOXES = (84..99).to_a
    # Facing of a box's graphic => its colour's word and its field, [x0, y0, x1, y1].
    COLOURS = { 2 => [:slld_red, [11, 17, 12, 18]], 4 => [:slld_blue, [11, 24, 12, 25]],
                6 => [:slld_green, [28, 17, 29, 18]], 8 => [:slld_yellow, [28, 24, 29, 25]] }

    # A box's colour entry, by the facing of its graphic, which lifting and dropping keep.
    def self.colour(ev)
      COLOURS[(ev.direction rescue 2)] || COLOURS[2]
    end

    # True for a box already on its field.
    def self.placed?(id)
      $game_self_switches[[MAP, id, "B"]] ? true : false
    end

    # True for the box in the air.
    def self.lifted?(id)
      $game_switches[386] && $game_self_switches[[MAP, id, "A"]] && !placed?(id)
    end

    # A box's name: its colour and, once there, that it is on its field.
    def self.label(ev)
      word = PokeAccess::I18n.t(colour(ev)[0])
      [placed?(ev.id) ? :slld_box_placed : :slld_box, { :colour => word }]
    end
  end
end

PokeAccess::Game.define("slld_anime") do
  contest = PokeAccess::SlldContest
  mechanic(:state, contest::MAP) do
    auto
    name contest::BOXES, lambda { |ev| contest.label(ev) }
    contest::COLOURS.each_value do |word, (x0, y0, _x1, _y1)|
      spot :at => [x0, y0], :label => lambda { [:slld_field, { :colour => PokeAccess::I18n.t(word) }] }, :onto => true,
           :when => lambda { $game_switches[384] && !$game_switches[418] }
    end
    obstacle(/\AVAMBAT_high\z/, :moving => true, :label => :slld_vambat)
    contest::BOXES.each do |id|
      phase lambda { contest.lifted?(id) }, :quiet => true, :hint => :slld_contest_hint,
            :track => { :event => id, :label => lambda { contest.label($game_map.events[id]) } }
    end
    phase lambda { true }, :quiet => true, :hint => :slld_contest_hint
    count :slld_boxes, :selfs => [contest::BOXES, "B", contest::MAP], :of => 16, :hide_zero => true
    active { $game_switches[384] && !$game_switches[418] }
    solved(nil, :quiet => true) { $game_switches[418] }
  end
end
