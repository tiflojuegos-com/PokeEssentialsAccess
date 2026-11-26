# Darchlight Caves, chapter 10: two caves, each in two dimensions under one name (TWINS). A gem set in a drawn pillar,
# used from the tile below it facing up with the Darchlight Mirror, takes the player to the same place in the other
# dimension. WAY lists the gems and passages to follow, by map; gem 14 of map 494 lies in a pocket nobody reaches.
module PokeAccess
  module RejuvDarchlight
    TWINS = { 494 => 227, 227 => 494, 363 => 137, 137 => 363, 498 => 499, 499 => 498 }
    GEMS = { 227 => [3], 494 => [15], 363 => [19, 20, 74], 137 => [2, 7, 59], 498 => [1], 499 => [1] }
    # [step, event, test while it is ahead], by map.
    WAY = {
      494 => [[1, 15, lambda { (10..11).include?($game_variables[296].to_i) }]],
      227 => [[2, 15, lambda { $game_variables[296].to_i < 13 && RejuvDarchlight.live? }]],
      363 => [[3, 14, lambda { RejuvDarchlight.live? }], [4, 20, lambda { RejuvDarchlight.live? }],
              [9, 30, lambda { RejuvDarchlight.live? }]],
      137 => [[5, 9, lambda { RejuvDarchlight.live? }], [6, 16, lambda { RejuvDarchlight.live? }],
              [7, 29, lambda { RejuvDarchlight.live? }], [8, 2, lambda { RejuvDarchlight.live? }]]
    }

    # True from the caves' chapter until the scene before the second cave's way out, on either route.
    def self.live?
      erin = $game_variables[296].to_i
      flora = $game_variables[294].to_i
      (erin >= 10 || flora >= 9) && erin < 19 && flora < 15
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  caves = PokeAccess::RejuvDarchlight
  caves::TWINS.each do |map, twin|
    mechanic(:state, map, :part => :darchlight) do
      auto
      name caves::GEMS[map], :rj_darch_gem
      hide 14 if map == 494
      sent_back :rj_darch_shift, :maps => [twin]
      (caves::WAY[map] || []).each do |n, id, ahead|
        spot :event => id, :label => [:rj_darch_step, { :n => n }], :assist => true, :when => lambda { ahead.call }
      end
      hint :rj_darch_caves_hint
      active { caves.live? }
    end
  end
end
