module PokeAccess
  # Rejuvenation's move relearner (MoveRelearnerScene, read by core's MoveRelearnerGen6), whose pages list the TM,
  # tutor, natural and egg moves: the page's label it paints above the list follows the Pokemon's line, and a page with
  # no moves says the message it paints in the description's place.
  module RejuvRelearner
    # The Pokemon's line with the page's painted label after it.
    def self.head(scene, base)
      label = PokeAccess.clean(PokeAccess.ivar(scene, :@label).to_s)
      return base if label.empty?
      [base, label].compact.join(". ")
    end

    # Says a page with no moves by its painted message, led by the Pokemon's line as a move is; false on a page with
    # moves, left to the move's detail.
    def self.empty_page(scene)
      moves = PokeAccess.ivar(scene, :@moves)
      err = PokeAccess.clean(PokeAccess.ivar(scene, :@error).to_s)
      return false unless moves.is_a?(Array) && moves.empty? && !err.empty?
      head = PokeAccess::MoveRelearnerGen6.pokemon_head(scene)
      err = "#{head}. #{err}" if head && PokeAccess::Cursor.changed?(scene, :relearn_pokemon, head)
      PokeAccess.speak(err, !PokeAccess::Menus.read_queued?(scene))
      true
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  override("PokeAccess::MoveRelearnerGen6", :pokemon_head) do |_mod, original, args|
    PokeAccess::RejuvRelearner.head(args[0], original.call)
  end

  override("PokeAccess::MoveRelearnerGen6", :detail) do |_mod, original, args|
    PokeAccess::RejuvRelearner.empty_page(args[0]) ? nil : original.call
  end
end
