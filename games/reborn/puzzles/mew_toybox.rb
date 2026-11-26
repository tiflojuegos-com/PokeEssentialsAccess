# Mew's hide and seek in the Triskeline Toybox (map 874): after the Mewtwo battle (variable 636 at 5) Mew hides in one
# plushie per step (events 77, 80 and 82), then waits at (24,11) for the portal. Their event names give it away, so
# without the assist each is named for its sprite; with it, as Mew.
module PokeAccess
  module RebornMewToybox
    DISGUISES = [77, 80, 82]

    # A disguise's name: Mew with the assist, else the species its sprite shows, as the other plushies are.
    def self.label(ev)
      return :rbe_mew_disguised if PokeAccess::Puzzles.assist?
      named = (PokeAccess::Config.name_species rescue true)
      (named && (PokeAccess::Locator.sprite_species_named(ev.character_name.to_s) rescue nil)) || :rbe_plushie
    end
  end
end

PokeAccess::Game.define("reborn") do
  toybox = PokeAccess::RebornMewToybox
  mechanic(:state, 874, :part => :mew) do
    auto
    name toybox::DISGUISES, lambda { |ev| toybox.label(ev) }, :when => lambda { |_ev| PokeAccess::Puzzles.assist? }
    name 84, :rbe_mew
    solved(nil, :quiet => true) { $game_variables[636].to_i >= 9 }
  end
end
