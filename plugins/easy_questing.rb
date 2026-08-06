module PokeAccess
  # Quest log "Favores" (Marin's Quest plugin, class Questlog): a sprite UI with no command window, so the
  # generic readers never see it. Three scenes -- @scene 0 the two category buttons (@sel_one: 0 active,
  # 1 completed), 1 the quest list of the chosen category (@mode, focus @sel_two), 2 the open quest's
  # detail (@page 0 description / 1 location). Read the focus after each navigation. Guarded on the Questlog
  # ivars, so it no-ops if absent.
  module Quests
    # The quest under the cursor in the active list, or nil.
    def self.focused(ql)
      mode = PokeAccess.ivar_i(ql, :@mode)
      list = (mode == 0 ? ql.instance_variable_get(:@ongoing) : ql.instance_variable_get(:@completed))
      idx = PokeAccess.ivar(ql, :@sel_two)
      (list.is_a?(Array) && idx && idx >= 0 && idx < list.length) ? list[idx] : nil
    rescue StandardError
      nil
    end

    # A quest's spoken line: name plus its completed/uncompleted status.
    def self.quest_line(q)
      return nil unless q
      nm = (q.name rescue nil)
      return nil if nm.nil? || nm.to_s.empty?
      st = PokeAccess::I18n.t((q.completed rescue false) ? :qu_status_done : :qu_status_pending)
      PokeAccess::I18n.t(:qu_line, :name => nm, :status => st)
    end

    # Announces the focus for the current scene: a category button, a quest in the list, or the open
    # quest's detail page.
    def self.announce(ql)
      case PokeAccess.ivar(ql, :@scene)
      when 0
        sel = PokeAccess.ivar_i(ql, :@sel_one)
        list = (sel == 0 ? ql.instance_variable_get(:@ongoing) : ql.instance_variable_get(:@completed))
        n = (list.is_a?(Array) ? list.length : 0)
        PokeAccess.speak(PokeAccess::I18n.t(sel == 0 ? :qu_ongoing : :qu_completed, :n => n), true)
      when 1
        PokeAccess.speak(quest_line(focused(ql)) || PokeAccess::I18n.t(:qu_none), true)
      when 2
        q = focused(ql)
        return unless q
        if PokeAccess.ivar_i(ql, :@page) == 1
          PokeAccess.speak(PokeAccess::I18n.t(:qu_location, :loc => (q.location rescue nil), :npc => (q.npc rescue nil)), true)
        else
          desc = PokeAccess.clean((q.desc rescue '').to_s)
          PokeAccess.speak(PokeAccess::I18n.t(:qu_detail, :name => q.name, :desc => desc, :npc => (q.npc rescue '')), true)
        end
      end
    rescue StandardError
      nil
    end
  end
end

# Read the focus after each Questlog navigation (category switch, list move, open/flip a quest, back to
# the categories). Each is a method on Questlog; no-op where the plugin is absent.
["pbSwitch", "pbMove", "pbList", "pbLoad", "pbMain"].each do |m|
  PokeAccess::Hooks.after_hook("Questlog", m, :optional => true) { |ql, _r, _a| PokeAccess::Quests.announce(ql) }
end
