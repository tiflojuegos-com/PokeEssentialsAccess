module PokeAccess
  # The history of what the mod said, browsed with the history keys through every line or one category; each view
  # keeps its own place. Its own readouts are said as Speech::REVIEW and never recorded.
  module History
    # The view that shows every category at once.
    ALL = :all

    # Seconds within which the same line in the same category is taken for a repaint and not filed twice.
    REPEAT_WINDOW = 1.0

    @lines = []
    @cursor = {}
    @view = ALL
    @said_at = 0.0

    # How many lines are kept (the history size setting); the oldest go first.
    def self.capacity
      [(PokeAccess::Config.history_size rescue 0).to_i, 1].max
    end

    # Files a line said, unless it is a history readout or a repeat within REPEAT_WINDOW.
    def self.record(msg)
      return if msg.category == PokeAccess::Speech::REVIEW
      now = PokeAccess.clock
      last = @lines.last
      repeat = last && last.text == msg.text && last.category == msg.category && now - @said_at < REPEAT_WINDOW
      @said_at = now
      return if repeat
      @lines.push(msg)
      cap = capacity
      @lines.shift while @lines.length > cap
    end

    # The views the category keys go through, in order: everything, then each category.
    def self.views
      [ALL].concat(PokeAccess::Speech::CATEGORIES.map { |row| row[0] })
    end

    # The lines a view shows, oldest first.
    def self.lines_of(view)
      view == ALL ? @lines : @lines.select { |m| m.category == view }
    end

    # The view the player is in.
    def self.view; @view; end

    # The spoken name of a view.
    def self.view_name(view)
      view == ALL ? PokeAccess::I18n.t(:msg_cat_all) : PokeAccess::I18n.t(PokeAccess::Speech.label(view))
    end

    # One line back (dir -1) or on (dir 1) in the current view; the first press reads the latest line, and past
    # either end it says so and stays. The place is a line's seq: once that line is dropped, on reads the oldest kept.
    def self.step(dir)
      list = lines_of(@view)
      return say_empty if list.empty?
      seq = @cursor[@view]
      return read(list, list.length - 1) if seq.nil?
      older = list.index { |m| m.seq >= seq } || list.length
      here = older < list.length && list[older].seq == seq
      target = dir < 0 ? older - 1 : (here ? older + 1 : older)
      edge = dir < 0 ? PokeAccess::I18n.t(:hist_top) : PokeAccess::I18n.t(:hist_bottom)
      return say(edge) if target < 0 || target >= list.length
      read(list, target)
    end

    # The first line of the current view (dir -1) or its last (dir 1).
    def self.to_end(dir)
      list = lines_of(@view)
      return say_empty if list.empty?
      read(list, dir < 0 ? 0 : list.length - 1)
    end

    # The previous (dir -1) or next (dir 1) view that has something to show, saying its name and how many lines it
    # holds; the view of everything is always offered.
    def self.switch_category(dir)
      all = views
      i = all.index(@view) || 0
      all.length.times do
        i = (i + dir) % all.length
        break if all[i] == ALL || !lines_of(all[i]).empty?
      end
      @view = all[i]
      say(PokeAccess::I18n.t(:hist_view, :name => view_name(@view), :n => lines_of(@view).length))
    end

    # Reads the line at an index of the view and leaves the cursor on it.
    def self.read(list, idx)
      @cursor[@view] = list[idx].seq
      say(list[idx].text)
    end

    # Says that the current view holds nothing yet.
    def self.say_empty
      say(PokeAccess::I18n.t(:hist_empty, :name => view_name(@view)))
    end

    # A readout of the history: cuts in, and is not recorded.
    def self.say(text)
      PokeAccess.speak(text, true, PokeAccess::Speech::REVIEW)
    end

    # Forgets every line and every place, back to the view of everything (tests).
    def self.clear
      @lines = []
      @cursor = {}
      @view = ALL
      @said_at = 0.0
    end
  end
end

PokeAccess::Speech.observe(:history) { |msg| PokeAccess::History.record(msg) }
