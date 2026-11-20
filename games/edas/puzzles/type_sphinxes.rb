# Edas' sphinxes of the Amber chapter (switch 177), one on each of eleven routes and caves, which only the Eye of Truth
# shows: each sets a riddle about a type and gives its plate to a party knowing a move of that type, which its page checks
# with pbHasMoveType. The assist says the type, by the game's own name, as a sphinx speaks.
module PokeAccess
  module EdasSphinxes
    MAPS = [4, 7, 10, 14, 23, 24, 32, 33, 34, 35, 132]
    SPHINX = /Esfinge/
    CHECK = /pbHasMoveType\((\d+)\)/

    # The type the sphinx's live page asks for, said by the game's name; nil for a page that asks for none.
    def self.type_line(ev)
      list = PokeAccess.ivar(ev, :@list) || []
      cmd = list.find { |c| c.code == 111 && c.parameters[0] == 12 && c.parameters[1].to_s =~ CHECK }
      return nil unless cmd
      type = cmd.parameters[1].to_s[CHECK, 1].to_i
      PokeAccess::I18n.t(:edas_sphinx_type, :type => PokeAccess::Data.type_name(type))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("edas") do
  sphinxes = PokeAccess::EdasSphinxes
  mechanic(:state, sphinxes::MAPS) do
    auto
    on_use sphinxes::SPHINX, lambda { |ev| sphinxes.type_line(ev) }, :assist => true
  end
end
