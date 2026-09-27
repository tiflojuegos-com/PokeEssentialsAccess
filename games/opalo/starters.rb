# Opalo's starter selector (Map005): a full-screen picture per starter, lit on its platform, with the prompt painted
# into it; left and right show the next one round the three, and C asks to confirm the one lit.
module PokeAccess
  module OpaloStarters
    # The prompt every selector picture paints.
    PROMPT = "Elige a tu Pokémon inicial."

    # Selector picture => the species it lights and its type in the words of the confirmation that follows ("¿Eliges
    # a Snampery, el Pokémon de tipo Planta?"); the game's type table holds the English names, which it never paints.
    STARTERS = { "iniciales1" => [:SNAMPERY, "Planta"], "iniciales2" => [:FLASINGE, "Fuego"],
                 "iniciales3" => [:SWOLPHIN, "Agua"] }

    @open = false

    # The starter a selector picture lights, as the species' name and its type; nil for any other picture.
    def self.starter(name)
      sym, type = STARTERS[name]
      id = sym ? (PBSpecies.const_get(sym) rescue nil) : nil
      return nil unless id
      PokeAccess::I18n.t(:op_starter, :name => PokeAccess::Data.species_name(id), :type => type)
    end

    # Says the starter lit: on the selector's first picture queued after its prompt and, while key hints are said,
    # the keys; on a move, interrupting.
    def self.on_picture(name)
      line = starter(name)
      return unless line
      if @open
        PokeAccess.speak(line, true)
      else
        @open = true
        hint = PokeAccess::I18n.t(:op_starter_keys, :key => PokeAccess::KeyHints.key(:c, "C"))
        PokeAccess.speak(PokeAccess::Verbosity.with_hint("#{PROMPT} #{line}", hint), false)
      end
    end

    # Closes the selector on a map change (Caches), so the next one opens with its prompt.
    def self.reset
      @open = false
    end
  end
end

PokeAccess::Caches.register(:opalo_starters) { PokeAccess::OpaloStarters.reset }

PokeAccess::Game.define("opalo") do
  on_picture { |name, _args| PokeAccess::OpaloStarters.on_picture(name) }
end
