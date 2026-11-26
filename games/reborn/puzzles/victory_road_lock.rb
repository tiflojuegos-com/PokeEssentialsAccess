# Victory Road's crystal lock (map 796): seven slots, events 29 to 35 at (22..28,22), each holding a star (variables 513
# to 519: 1 Ruby, 2 Sapphire, 3 Emerald, 4 Amethyst, 0 none). The laser (event 26) compares them with the code in
# variables 506 to 512: yellow crystals for colours, white for places; seven white open the way out (switch 1244).
module PokeAccess
  module RebornVrLock
    MAP = 796
    SLOTS = (29..35)
    HELD = 513
    CODE = 506
    STARS = { 1 => :rbc_star_ruby, 2 => :rbc_star_sapphire, 3 => :rbc_star_emerald, 4 => :rbc_star_amethyst }

    # A slot's name, with the star it holds.
    def self.slot(ev)
      k = ev.id - SLOTS.first
      star = STARS[$game_variables[k + HELD].to_i] || :rbc_star_none
      [:rbc_lock_slot, { :n => k + 1, :star => PokeAccess::I18n.t(star) }]
    end

    # The code, slot by slot from the left; nil before the game has drawn it.
    def self.code
      stars = (0...SLOTS.to_a.length).map { |k| STARS[$game_variables[k + CODE].to_i] }
      return nil if stars.include?(nil)
      [:rbc_lock_code, { :code => stars.map { |s| PokeAccess::I18n.t(s) }.join(", ") }]
    end
  end
end

PokeAccess::Game.define("reborn") do
  lock = PokeAccess::RebornVrLock
  mechanic(:state, lock::MAP, :part => :lock) do
    auto
    name lock::SLOTS, lambda { |ev| lock.slot(ev) }
    name 26, :rbc_lock_laser
    lock::SLOTS.to_a.each_with_index do |id, k|
      right_choice id, :takes => { :var => k + lock::HELD, :value => lambda { $game_variables[k + lock::CODE].to_i } }
    end
    hint lambda { lock.code }
    active { !$game_switches[1244] }
    solved { $game_switches[1244] }
  end
end
