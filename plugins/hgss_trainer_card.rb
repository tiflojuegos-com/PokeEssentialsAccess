# Mr. Gela's HGSS Trainer Card: the card's back, read as it paints (TrainerCard.read_face); core reads the front, to
# which the card adds its stars, shown only by the picture it swaps in (card_N, N being $player.stars).
module PokeAccess
  module HGSSTrainerCard
    # Notes the stars as the front's first line, where the card draws them, into the face core is reading.
    def self.note_stars
      return unless PokeAccess::PaintCapture.armed?(:sample)
      n = ($player.stars rescue nil)
      return unless n.is_a?(Integer)
      PokeAccess::PaintCapture.note(PokeAccess::I18n.t(:stars_count, :n => n), :positions, 0, 0)
    end
  end
end

PokeAccess::Hooks.around_hook("PokemonTrainerCard_Scene", :pbDrawTrainerCardFront, :optional => true) do |_scene, nxt, _a|
  ret = nxt.call
  PokeAccess::HGSSTrainerCard.note_stars
  ret
end

PokeAccess::Hooks.around_hook("PokemonTrainerCard_Scene", :pbDrawTrainerCardBack, :optional => true) do |scene, nxt, _a|
  PokeAccess::TrainerCard.read_face(scene, false) { nxt.call }
end
