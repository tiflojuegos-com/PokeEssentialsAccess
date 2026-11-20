# Baobab Lab (map 536): six trash cans hide a button; pressing one turns its door switch on and others off (245 to
# 250), and each switch opens its pairs of door tiles while on. The Manectite (event 39, at (8,41)) needs the doors of
# switch 249 alone, reached by pressing the cans at (27,36), (28,29), (18,27) and (42,20) in turn and then taking the
# panel at (47,22). NEXT holds, for every set of switches the player can reach, the can a shortest plan presses next,
# found by a search over the switches and the player's place. The switches 245 and 246 are story flags of other maps
# too: off, the invisible Kecleon stands in the way on Route 120 again (maps 341 and 690; the Devon Scope moves it again)
# and Team Aqua's grunts are back on Route 121 (map 343; they leave again as the player walks past). With the assist, a
# can that would turn one of them off warns as it is used, and once the Manectite is taken the cans at (27,36) and then
# (28,29) put both back on, checked from beside the item.
module PokeAccess
  module EmBaobab
    MAP = 536
    ITEM = 39
    CANS = { 8 => [27, 36], 9 => [28, 29], 14 => [37, 36], 21 => [18, 27], 22 => [42, 20], 33 => [20, 21] }
    DOORS = { 1 => 245, 2 => 245, 12 => 246, 13 => 246, 23 => 246, 24 => 246, 15 => 247, 16 => 247, 18 => 248,
              20 => 248, 10 => 249, 11 => 249, 29 => 249, 30 => 249, 31 => 250, 32 => 250 }
    OFFS = { 8 => [246], 9 => [], 14 => [245, 246], 21 => [245], 22 => [245, 246], 33 => [246] }
    UNDO = { [245] => :em_baobab_undo_kecleon, [246] => :em_baobab_undo_grunts, [245, 246] => :em_baobab_undo_both }
    NEXT = {
      [] => 8, [245] => 9, [247] => 8, [245, 246] => 21, [245, 247] => 21, [246, 248] => 22, [245, 248] => 9,
      [247, 248] => 8, [249] => :walk, [248, 250] => 22, [245, 246, 248] => 22, [245, 247, 248] => 22,
      [246, 248, 250] => 22, [249, 250] => :walk, [245, 248, 250] => 22, [245, 247, 248, 250] => 22,
      [247, 248, 250] => 8, [245, 246, 248, 250] => 22
    }

    # Whether the Manectite has been taken.
    def self.taken?
      $game_self_switches[[MAP, ITEM, "A"]] ? true : false
    end

    # The next step of the plan from the switches on now: a can's id, :walk once the way is open, or nil off the plan.
    def self.next_step
      NEXT[(245..250).select { |s| $game_switches[s] }]
    end

    # The warning a can gives before it is pressed: what of the story it would undo now, or nil.
    def self.undo_line(ev)
      UNDO[(OFFS[ev.id] || []).select { |s| $game_switches[s] }]
    end

    # Whether the story flags the cans share are both on.
    def self.story_kept?
      $game_switches[245] && $game_switches[246]
    end

    # The assist's line once the Manectite is taken: the can that puts the story flags back on next.
    def self.restore_hint
      x, y = CANS[$game_switches[245] ? 9 : 8]
      [:em_baobab_restore, { :place => PokeAccess::EmPuzzles.place(x, y) }]
    end

    # The assist's line: the can to press next and where it is, or that the way to the Manectite is open.
    def self.hint
      step = next_step
      return :em_baobab_walk if step == :walk
      x, y = CANS[step]
      [:em_baobab_press, { :place => PokeAccess::EmPuzzles.place(x, y) }]
    end
  end
end

PokeAccess::Game.define("emerald") do
  lab = PokeAccess::EmBaobab
  mechanic(:state, lab::MAP) do
    auto
    name lab::CANS.keys, :em_baobab_can
    name lab::DOORS.keys, lambda { |ev| $game_switches[lab::DOORS[ev.id]] ? :em_baobab_door_open : :em_baobab_door_shut },
         :grouped => true
    on_use lab::CANS.keys, lambda { |ev| lab.undo_line(ev) }, :assist => true
    phase lambda { PokeAccess::Puzzles.assist? && !lab.taken? && lab.next_step }, :quiet => true,
          :hint => lambda { lab.hint }
    phase lambda { PokeAccess::Puzzles.assist? && lab.taken? && !lab.story_kept? }, :quiet => true,
          :hint => lambda { lab.restore_hint }
    solved(nil, :quiet => true) { lab.taken? && lab.story_kept? }
  end
end
