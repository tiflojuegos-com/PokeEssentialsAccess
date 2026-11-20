# The Shyleon Temple in the Giungla Nebulosa. Map 289: with the red mask (switch 421) the stele (events 19 and 22) makes
# four pillars flash, each by its own switch (427 to 430, pillars 1 to 4) and all with the same sound, and asks the order
# in three rounds; the right one sets switch 432 and gives the blue mask. Each flash is said as the pillar lights. Map 290:
# three hollows with no sprite by the statue take the red, blue and green masks in turn (events 1, 5 and 7, switches 422,
# 424 and 426), and the last one opens the gate (switch 438).
module PokeAccess
  module XenoShyleon
    PILLARS_MAP = 289
    STATUE_MAP = 290
    STELE = [19, 22]
    PILLARS = { 427 => 1, 428 => 2, 429 => 3, 430 => 4 }
    ORDER_GUESSED = 432
    HOLLOWS = [[1, 422, :xv_shyleon_hollow_red], [5, 424, :xv_shyleon_hollow_blue], [7, 426, :xv_shyleon_hollow_green]]
    GATE = 438
  end
end

PokeAccess::Game.define("xenoverse") do
  temple = PokeAccess::XenoShyleon
  mechanic(:state, temple::PILLARS_MAP) do
    auto
    name temple::STELE, :xv_shyleon_stele, :grouped => true
    temple::PILLARS.each { |sw, n| watch :switch => sw, :say => [:xv_shyleon_pillar, { :n => n }] }
    right_choice temple::STELE, :takes => { :switch => temple::ORDER_GUESSED }
    active { false }
  end

  mechanic(:state, temple::STATUE_MAP) do
    auto
    temple::HOLLOWS.each do |id, placed, label|
      name id, label, :when => lambda { |_ev| !$game_switches[placed] }
    end
    solved { $game_switches[temple::GATE] }
  end
end
