module PokeAccess
  # Marin's Quest plugin log (Questlog), a sprite UI with no command window. @scene 0: the category buttons (@sel_one:
  # 0 active, 1 completed); 1: the chosen category's list (@mode, focus @sel_two); 2: the open quest's detail (@page
  # 0 description, 1 location).
  module Quests
    # The outline texts drawn since the log opened or since the last list or page load, newest last, up to
    # PAINT_MEMORY: what each copy paints for its counts, empty lists, statuses and a quest's giver or place.
    PAINT_MEMORY = 12

    @painted = []
    @opening = false

    def self.clear_paint; @painted = []; end

    # Records the paint of the log's constructor, which draws the cover before its loop starts.
    def self.open_paint; @opening = true; clear_paint; end
    def self.close_paint; @opening = false; end

    def self.note_paint(text)
      return unless @opening || PokeAccess::QuestsOpen.watching?
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

    # The count the cover painted for a category ("Activas: 2"): of the last two "label: number" lines, the first for
    # active and the second for completed; nil unless it carries n.
    def self.cover_line(sel, n)
      counts = @painted.map { |t| PokeAccess.clean(t) }.select { |t| t =~ /:\s*\d+\z/ }
      return nil if counts.length < 2
      line = counts[sel == 0 ? -2 : -1]
      (line =~ /(\d+)\z/ && $1.to_i == n) ? line : nil
    end

    # The message an empty list paints ("Sin misiones activas"), drawn before its title; nil when the list painted
    # more than that pair.
    def self.empty_line
      return nil unless @painted.length.between?(1, 2)
      PokeAccess.clean(@painted[0])
    end

    # The status the detail page paints for a quest ("Completada", "Not Completed"), the line right after its name;
    # nil when the page did not paint the name.
    def self.painted_status(q)
      nm = (q.name rescue nil).to_s
      return nil if nm.empty?
      i = @painted.rindex(nm)
      row = i ? @painted[i + 1] : nil
      row ? PokeAccess.clean(row) : nil
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

    # The mark a game gives a quest by the colour its name is painted in, or nil; a game's profile overrides it.
    def self.color_mark(_q)
      nil
    end

    # A quest's row at the quest reading's level: the name, and from medium the mark its colour gives it and its
    # status (every row of a list shares it, the list being of one kind).
    def self.quest_row(q)
      nm = (q.name rescue nil)
      return nil if nm.nil? || nm.to_s.empty?
      st = PokeAccess::I18n.t((q.completed rescue false) ? :qu_status_done : :qu_status_pending)
      PokeAccess::Verbosity.line(:quest, [[nm, :brief], [color_mark(q), :medium], [st, :medium]])
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

    # The detail's page among its two, while positions are said and the copy shows the marker over its page boxes
    # (pager, pager2); nil otherwise, as for a copy that turned the second page off and keeps the marker hidden.
    def self.page_mark(ql)
      return nil unless PokeAccess::Verbosity.keep?(:positions, :medium)
      shown = %w[pager pager2].any? do |k|
        s = PokeAccess.sprite(ql, k)
        s && !(s.disposed? rescue false) && (s.opacity rescue 0).to_i > 0
      end
      shown ? PokeAccess::I18n.t(:adv_dex_page, :n => PokeAccess.ivar_i(ql, :@page) + 1, :m => 2) : nil
    end

    # A detail page's line with its page mark after it, when there is one.
    def self.with_page(ql, line)
      mark = page_mark(ql)
      mark ? "#{line}, #{mark}" : line
    end

    # Announces the focus for the current scene: a category button, a quest in the list, or a detail page (the first
    # with the quest's status, the second with when it was received), each with its page mark.
    def self.announce(ql)
      case PokeAccess.ivar(ql, :@scene)
      when 0
        sel = PokeAccess.ivar_i(ql, :@sel_one)
        list = (sel == 0 ? ql.instance_variable_get(:@ongoing) : ql.instance_variable_get(:@completed))
        n = (list.is_a?(Array) ? list.length : 0)
        line = cover_line(sel, n) || PokeAccess::I18n.t(sel == 0 ? :qu_ongoing : :qu_completed, :n => n)
        PokeAccess.speak(line, true)
      when 1
        q = focused(ql)
        PokeAccess::Info.set_info(:text, quest_line(q)) if q
        line = q ? quest_row(q) : empty_line
        PokeAccess.speak(line || PokeAccess::I18n.t(:qu_none), true)
      when 2
        q = focused(ql)
        return unless q
        if PokeAccess.ivar_i(ql, :@page) == 1
          PokeAccess.speak(with_page(ql, PokeAccess::I18n.t(:qu_location, :loc => (q.location rescue nil),
                                                            :when => received_at(q), :npc => (q.npc rescue nil))), true)
        else
          desc = PokeAccess.clean((q.desc rescue '').to_s)
          st = painted_status(q) ||
               PokeAccess::I18n.t((q.completed rescue false) ? :qu_status_done : :qu_status_pending)
          loc = (q.location rescue nil)
          place = painted?(loc) && !painted?((q.npc rescue nil))
          line = if place
                   PokeAccess::I18n.t(:qu_detail_place, :name => q.name, :status => st, :desc => desc,
                                      :loc => loc)
                 else
                   PokeAccess::I18n.t(:qu_detail, :name => q.name, :status => st, :desc => desc,
                                      :npc => (q.npc rescue ''))
                 end
          PokeAccess.speak(with_page(ql, line), true)
        end
      end
    rescue StandardError
      nil
    end
  end
end

# The whole screen is read from one per-frame poll while pbUpdate runs, keyed on the navigation state, not from
# its navigation methods, which run only after a keypress and so miss the opening read.
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

# The paint record opens with the log and each list or page load clears it; the draw listener only records while
# the log is open.
PokeAccess::Hooks.around_hook("Questlog", :initialize, :optional => true) do |_ql, nxt, _a|
  PokeAccess::Quests.open_paint
  begin; nxt.call; ensure; PokeAccess::Quests.close_paint; end
end
PokeAccess::Hooks.before_hook("Questlog", :pbList, :optional => true) do |_ql, _a|
  PokeAccess::Quests.clear_paint
end
PokeAccess::Hooks.before_hook("Questlog", :pbLoad, :optional => true) do |_ql, _a|
  PokeAccess::Quests.clear_paint
end
PokeAccess::Hooks.wrap_kernel("pbDrawOutlineText", "plugin_quests_paint", :before) do |args, _r|
  PokeAccess::Quests.note_paint(args[5])
end

PokeAccess::Verbosity.define_reading(:quest, :vb_quest, :vbh_quest)
