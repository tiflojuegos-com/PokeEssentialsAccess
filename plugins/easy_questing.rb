module PokeAccess
  # Quest log "Favores" (Marin's Quest plugin, class Questlog): a sprite UI with no command window, so the
  # generic readers never see it. Three scenes -- @scene 0 the two category buttons (@sel_one: 0 active,
  # 1 completed), 1 the quest list of the chosen category (@mode, focus @sel_two), 2 the open quest's
  # detail (@page 0 description / 1 location). Read the focus after each navigation. Guarded on the Questlog
  # ivars, so it no-ops if absent.
  module Quests
    # What the screen has drawn with outline text since the last page load, newest last.
    #
    # The detail page is laid out differently per copy: three print who gave the quest and keep the place
    # for a second page, and the fourth has that second page commented out and prints the place here
    # instead. Every quest object carries both fields, so the only witness to which one is on screen is
    # what the screen drew. Bounded because one page never draws many lines.
    PAINT_MEMORY = 12

    @painted = []

    def self.clear_paint; @painted = []; end

    def self.note_paint(text)
      return unless PokeAccess::QuestsOpen.watching?
      t = text.to_s
      return if t.empty?
      @painted.push(t)
      @painted.shift while @painted.length > PAINT_MEMORY
    end

    # True when the page printed this value (the copies prefix it, e.g. "From Bill", so a substring).
    def self.painted?(value)
      v = value.to_s
      return false if v.empty?
      @painted.any? { |t| t.include?(v) }
    end

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

    # When the quest was received, sliced out of Time#to_s the way the second page builds it, so the two
    # agree. A quest with no usable stamp answers nothing, as the screen's own rescue does.
    def self.received_at(q)
      parts = (q.time.to_s.split(" ") rescue nil)
      return nil unless parts.is_a?(Array) && parts.length >= 4
      hm = parts[3].split(":")
      return nil unless hm.length >= 2
      "#{parts[1]} #{parts[2]}, #{hm[0]}:#{hm[1]}"
    rescue StandardError
      nil
    end

    # Announces the focus for the current scene: a category button, a quest in the list, or a detail page.
    # Page one carries the Pendiente/Terminada status beside the name and page two the received time under
    # the place, which is what tells the two pages apart.
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
          PokeAccess.speak(PokeAccess::I18n.t(:qu_location, :loc => (q.location rescue nil),
                                              :when => received_at(q), :npc => (q.npc rescue nil)), true)
        else
          desc = PokeAccess.clean((q.desc rescue '').to_s)
          st = PokeAccess::I18n.t((q.completed rescue false) ? :qu_status_done : :qu_status_pending)
          loc = (q.location rescue nil)
          place = painted?(loc) && !painted?((q.npc rescue nil))
          line = if place
                   PokeAccess::I18n.t(:qu_detail_place, :name => q.name, :status => st, :desc => desc,
                                      :loc => loc)
                 else
                   PokeAccess::I18n.t(:qu_detail, :name => q.name, :status => st, :desc => desc,
                                      :npc => (q.npc rescue ''))
                 end
          PokeAccess.speak(line, true)
        end
      end
    rescue StandardError
      nil
    end
  end
end

# The whole screen is read from one per-frame poll, not from the five navigation methods.
#
# Those five (pbSwitch, pbMove, pbList, pbLoad, pbMain) run from inside pbUpdate and only after a keypress,
# so they cannot give the opening read; the constructor paints the focused category and then blocks in
# pbUpdate, which the poll rides. The poll REPLACES them rather than joining them, or every move would be
# announced twice. Its key is the whole navigation state, so it changes exactly when one of the five would
# have fired.
module PokeAccess
  module QuestsOpen
    @ql = nil
    @last = nil

    def self.watch(ql); @ql = ql; @last = nil; end
    def self.unwatch; @ql = nil; @last = nil; end
    def self.watching?; !@ql.nil?; end

    def self.poll
      ql = @ql
      return unless ql
      key = [PokeAccess.ivar(ql, :@scene), PokeAccess.ivar(ql, :@sel_one),
             PokeAccess.ivar(ql, :@sel_two), PokeAccess.ivar(ql, :@page), PokeAccess.ivar(ql, :@mode)]
      return if key == @last
      @last = key
      PokeAccess::Quests.announce(ql)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.around_hook("Questlog", :pbUpdate, :optional => true) do |ql, nxt, _a|
  PokeAccess::QuestsOpen.watch(ql)
  begin; nxt.call; ensure; PokeAccess::QuestsOpen.unwatch; end
end
PokeAccess::Keys.on_frame { PokeAccess::QuestsOpen.poll }

# Every page starts from an empty slate, so the witness of what THIS page carries is only this page's own
# draw calls. The listener is a string append gated on the log being open, which is what keeps it off every
# other screen in the game.
PokeAccess::Hooks.before_hook("Questlog", :pbLoad, :optional => true) do |_ql, _a|
  PokeAccess::Quests.clear_paint
end
PokeAccess::Hooks.wrap_kernel("pbDrawOutlineText", "plugin_quests_paint", :before) do |args, _r|
  PokeAccess::Quests.note_paint(args[5])
end
