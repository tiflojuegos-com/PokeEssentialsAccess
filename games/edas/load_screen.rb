# Edas' load screen leaves the title of its Continue row empty (0146_PScreen_Load), the save's panel being the row, so the
# generic reader finds nothing to say there: the row is named by the mod as the cursor rests on it, queued on opening.
module PokeAccess
  module EdasLoad
    # Says the Continue row when the cursor reaches it; any other row is the generic reader's.
    def self.poll(scene)
      win = PokeAccess.sprite(scene, "cmdwindow")
      rows = PokeAccess.ivar(scene, :@commands)
      return unless win && rows.is_a?(Array) && win.active
      if rows[win.index] && rows[win.index].to_s.empty?
        PokeAccess::Cursor.announce(scene, :edas_continue, true, true, false) { PokeAccess::I18n.t(:msv_continue) }
      else
        PokeAccess::Cursor.store(scene, :edas_continue, false)
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("edas") do
  after("PokemonLoadScene", :pbUpdate, :hook_container => true) { |scene, _r, _a| PokeAccess::EdasLoad.poll(scene) }
end
