# Madelis' Laboratory (map 124), from Keta's scene (variable 214 at 1) to the throne room (event 97, 214 to 4): seven
# floor plates flip the colour switches (red 1558, blue 1559, green 1560, yellow 1561) and turn grey (self switch B)
# once stepped on; the lasers each read one colour. Plate 81 is painted blue and green but flips red and blue.
module PokeAccess
  module RejuvMadelis
    ORDER = [13, 54, 56, 69, 71, 81, 82]
    COLORS = [1558, 1559, 1560, 1561]
    # The colours lit after each step of ORDER.
    AFTER = [[], [1558], [1561], [1559, 1560, 1561], [1559, 1560], [1559], [1558], [1558, 1560]]
    # A plate's colours as painted, before it turns grey.
    PAINTED = { 13 => :rj_madelis_plate_red, 54 => :rj_madelis_plate_red_yellow, 56 => :rj_madelis_plate_green_blue,
                69 => :rj_madelis_plate_yellow, 71 => :rj_madelis_plate_green, 81 => :rj_madelis_plate_blue_green,
                82 => :rj_madelis_plate_green }
    THRONE = 97
    WORDS = [:rj_madelis_red, :rj_madelis_blue, :rj_madelis_green, :rj_madelis_yellow]

    def self.grey?(id)
      $game_self_switches[[124, id, "B"]] ? true : false
    end

    # True from Keta's scene until the throne room.
    def self.live?
      v = $game_variables[214].to_i
      v >= 1 && v < 4
    end

    # How many plates of ORDER are done, the colours and the grey plates as that step leaves them; nil off the way.
    def self.step
      lit = COLORS.select { |s| $game_switches[s] }
      (0..ORDER.length).each do |k|
        next unless lit == AFTER[k]
        return k if (0...ORDER.length).all? { |i| grey?(ORDER[i]) == (i < k) }
      end
      nil
    end

    # Where the next step is, said by the plate's painted colours or as the way down to the throne room.
    def self.hint(k)
      id = ORDER[k] || THRONE
      ev = $game_map.events[id]
      x, y = ev ? [ev.x, ev.y] : [0, 0]
      return [:rj_madelis_hint_throne, { :x => x, :y => y }] if id == THRONE
      [:rj_madelis_hint_plate, { :name => PokeAccess::I18n.t(PAINTED[id]), :x => x, :y => y }]
    end

    # Each colour and whether it is lit, as the lasers show them.
    def self.colors_line
      COLORS.zip(WORDS).map do |sw, word|
        lit = $game_switches[sw] ? :rj_madelis_lit : :rj_madelis_unlit
        "#{PokeAccess::I18n.t(word)}: #{PokeAccess::I18n.t(lit)}"
      end.join(', ')
    end

    # A plate's name: its painted colours, or grey once stepped on.
    def self.plate_label(ev)
      grey?(ev.id) ? :rj_madelis_plate_grey : PAINTED[ev.id]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  lab = PokeAccess::RejuvMadelis
  mechanic(:state, 124, :part => :plates) do
    watch :switch => 1558, :label => :rj_madelis_red, :on => :rj_madelis_lit, :off => :rj_madelis_unlit
    watch :switch => 1559, :label => :rj_madelis_blue, :on => :rj_madelis_lit, :off => :rj_madelis_unlit
    watch :switch => 1560, :label => :rj_madelis_green, :on => :rj_madelis_lit, :off => :rj_madelis_unlit
    watch :switch => 1561, :label => :rj_madelis_yellow, :on => :rj_madelis_lit, :off => :rj_madelis_unlit
    controls
    obstacle(/madelisgate/i, :label => :rj_madelis_laser)
    name lab::ORDER, lambda { |ev| lab.plate_label(ev) }, :when => lambda { |_ev| lab.live? }
    (0..lab::ORDER.length).each do |k|
      phase lambda { PokeAccess::Puzzles.assist? && lab.live? && lab.step == k },
            :hint => lambda { lab.hint(k) }, :hidden => right_way(lab::ORDER[k] || lab::THRONE)
    end
    phase lambda { PokeAccess::Puzzles.assist? && lab.live? && lab.step.nil? }, :hint => :rj_madelis_reset_hint
    phase lambda { lab.live? }, :title => lambda { lab.colors_line }, :quiet => true
    solved { $game_variables[214].to_i >= 4 }
  end
end
