# The Fates compendiums (angels, demons and the nine legendary lists, scripts 0226-0237). Twelve separate
# screens that are the same screen twelve times: each file declares a row class, a viewer class holding the
# cursor, and a wrapper. Verified identical across all twelve -- the viewer keeps the focus in @select, the
# rows in @opciones (each row object exposing .nombre), and @interruptores with the game switch that marks an
# entry as discovered; when the switch is off the game itself replaces the name with "¿¿??".
#
# So one parameterised reader registered under the twelve viewer names covers all of them, instead of twelve
# near-identical files. Reading .nombre also means the "not yet registered" placeholder is spoken exactly as
# the game shows it, with no extra bookkeeping on our side.
module PokeAccess
  module AwakeningCompendium
    VIEWERS = ["ListaAngeles", "ListaDemonios", "ListaLegendarios",
               "ListaLegendarios1", "ListaLegendarios2", "ListaLegendarios3", "ListaLegendarios4",
               "ListaLegendarios5", "ListaLegendarios6", "ListaLegendarios7", "ListaLegendarios8",
               "ListaLegendarios9"]

    # Voices the focused entry once per change: its name (or the game's own unknown placeholder) and its
    # position in the list.
    def self.focus(scene)
      idx = PokeAccess.ivar(scene, :@select)
      rows = PokeAccess.ivar(scene, :@opciones)
      return unless idx.is_a?(Integer) && rows.is_a?(Array) && idx >= 0 && idx < rows.length
      name = (rows[idx].nombre rescue nil)
      name = PokeAccess.clean(name.to_s).to_s.strip
      return if name.empty?
      PokeAccess::Cursor.announce(scene, :awk_comp, idx, true) do
        PokeAccess::I18n.t(:list_entry, :name => name, :n => idx + 1, :tot => rows.length)
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("awakening") do
  PokeAccess::AwakeningCompendium::VIEWERS.each do |cname|
    after(cname, :update) { |s, _r, _a| PokeAccess::AwakeningCompendium.focus(s) }
  end
end
