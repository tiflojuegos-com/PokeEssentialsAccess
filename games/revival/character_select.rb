# Revival's PHS (CharacterSelecion, opened from the pause menu and the preparation menu): six portraits slide in, the
# lit one with its name on a banner (CHARACTER_NAMES), up and down moving among those the story allows (@able) and Use
# or Back keeping the lit one. Its name and how to choose as it opens, then the lit character on each move.
module PokeAccess
  module RevivalPHS
    # The lit character as its banner names it, with its place among the selectable ones; the info key keeps the name.
    def self.entry(scene)
      sel = PokeAccess.ivar(scene, :@select)
      able = PokeAccess.ivar(scene, :@able)
      names = PokeAccess.const_at("CHARACTER_NAMES")
      return nil unless sel.is_a?(Integer) && names.is_a?(Array) && names[sel]
      name = names[sel].to_s
      PokeAccess::Info.set_info(:text, name)
      n = able.is_a?(Array) ? able.index(sel) : nil
      n ? PokeAccess::Verbosity.list_entry(name, n + 1, able.length) : name
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The switch's name and, while key hints are said, how to choose.
    def self.opening
      PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:rv_phs_title), PokeAccess::I18n.t(:rv_phs_hint))
    end
  end
end

PokeAccess::Game.define("revival") do
  around("CharacterSelecion", :startScene) do |_scene, nxt, _a|
    (PokeAccess.speak(PokeAccess::RevivalPHS.opening, false) rescue nil)
    begin; nxt.call; ensure; PokeAccess::Info.clear_text; end
  end
  focus_reader("CharacterSelecion", :on => :update, :index => :@select, :slot => :rv_phs,
               :hook_container => true) do |_i, scene|
    PokeAccess::RevivalPHS.entry(scene)
  end
end

# Its end is a return to the pause menu that opened it, which says its lit button again.
PokeAccess::MenuReturn.bare("CharacterSelecion", :startScene)
