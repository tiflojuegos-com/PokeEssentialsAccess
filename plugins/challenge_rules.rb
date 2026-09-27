# Challenge and randomizer rule editors (Challenge Modes, Randomizer EX): each rule with its on/off state, kept in
# @text_key where the generic reader misses it, the focused rule's description, and the rule summary (display_rules)
# both plugins show before confirming and from the rule book.
module PokeAccess
  module ChallengeRules
    # The focused rule with its on/off state (from a [name, toggle] pair or @text_key), or a plain option (Confirm).
    def self.text(win, i)
      cmds = win.instance_variable_get(:@commands)
      keys = win.instance_variable_get(:@text_key)
      c = (cmds[i] rescue nil)
      name = c.is_a?(Array) ? c[0] : c
      tog  = c.is_a?(Array) ? c[1] : (keys[i] rescue nil)
      return (name.is_a?(String) ? name : nil) if tog.nil?
      state = (tog == 1) ? PokeAccess::I18n.t(:val_on) : PokeAccess::I18n.t(:val_off)
      name.is_a?(String) ? "#{name}, #{state}" : nil
    rescue StandardError
      nil
    end

    # The watched rule lists, innermost last, each [list, message depth it opened at, its description panel].
    @lists = []
    @summary = 0

    # Watches a rule list over any still open (the randomizer's generation list opens over its rules); the first
    # text window described after it is its description panel.
    def self.arm(win)
      @lists.push([win, PokeAccess.message_depth, nil])
    end

    # Forgets every watched list and any rule summary.
    def self.reset
      @lists = []
      @summary = 0
    end

    # The innermost rule list still open, dropping the closed ones above it; back on an outer list, the info key
    # gets that list's description again. nil when none is open.
    def self.top
      popped = false
      while !@lists.empty? && closed?(@lists.last[0])
        @lists.pop
        popped = true
      end
      entry = @lists.last
      restore(entry) if popped && entry
      entry
    rescue StandardError
      nil
    end

    # Whether a list is gone: nil, disposed, or unable to say.
    def self.closed?(win)
      win.nil? || (win.disposed? rescue true)
    end

    # Puts a list's last description back on the info key.
    def self.restore(entry)
      desc = entry[2] ? PokeAccess.ivar(entry[2], :@access_rule_desc) : nil
      PokeAccess::Info.set_info(:text, desc) if desc && !desc.to_s.empty?
    end

    # True while a rule list is open; keeps the description listener off ordinary dialogue.
    def self.open?
      !top.nil?
    rescue StandardError
      false
    end

    # The focused rule's description, kept for the info key and, with read_help on and descriptions said, queued
    # after the rule; another window's text (a question such as how many lives) is always said. Skipped under a
    # message the screen puts up over its list.
    def self.describe(win, raw)
      entry = top
      return unless entry
      return if PokeAccess.message_depth > (entry[1] || 0)
      txt = PokeAccess.clean(raw.to_s)
      return if txt.empty? || txt == PokeAccess.ivar(win, :@access_rule_desc)
      win.instance_variable_set(:@access_rule_desc, txt)
      PokeAccess::Info.set_info(:text, txt)
      entry[2] ||= win
      return PokeAccess.speak(txt, true) unless entry[2].equal?(win)
      return unless (PokeAccess::Config.read_help rescue true) && PokeAccess::Verbosity.descriptions?
      PokeAccess.speak(txt, false)
    rescue StandardError
      nil
    end

    # Marks a rule summary as up (display_rules runs).
    def self.summary_open; @summary += 1; end

    # Marks it done; when none is left up, its last page leaves the info key.
    def self.summary_close
      @summary = [@summary - 1, 0].max
      PokeAccess::Info.clear_text if @summary == 0
    end

    # A page of the rule summary as the window is given it, its "- " bullets read as sentences, and kept for the info
    # key; the window's first, empty text says nothing.
    def self.summary_page(raw)
      return if @summary <= 0
      lines = raw.to_s.split(/\r?\n/).map { |l| PokeAccess.clean(l).sub(/\A-\s*/, "") }.reject { |l| l.empty? }
      txt = PokeAccess.sentences(lines)
      return if txt.empty?
      PokeAccess::Info.set_info(:text, txt)
      PokeAccess.speak(txt, true)
    rescue StandardError
      nil
    end

    # What a text window was just given: a rule list's description, or a page of the rule summary.
    def self.on_text(win, raw)
      describe(win, raw)
      summary_page(raw)
    end

    # Brackets a plugin's display_rules (a module function, called as Owner.display_rules), so the pages its window
    # is given while it runs are said.
    def self.wire_summary(owner)
      PokeAccess::Hooks.wrap_singleton(owner, :display_rules, "plugin_challenge_summary", :around) do |_args, nxt|
        summary_open
        begin
          nxt.call
        ensure
          summary_close
        end
      end
    end
  end
end

PokeAccess::Menus.def_extractor("Window_CommandPokemon_Challenge") do |win, i|
  PokeAccess::ChallengeRules.text(win, i)
end

# A toggle rebuilds the list through commands= under a still cursor: reset the row's dedup so it is read again.
PokeAccess::Hooks.after_hook("Window_CommandPokemon_Challenge", :commands=, :optional => true) do |win, _r, _a|
  PokeAccess::ChallengeRules.top
  PokeAccess::Cursor.reset(win, :cmd_focus)
end

PokeAccess::Hooks.after_hook("Window_CommandPokemon_Challenge", :initialize, :optional => true) do |win, _r, _a|
  PokeAccess::ChallengeRules.arm(win)
end

# A list closing hands the info key back to the list under it at once.
PokeAccess::Hooks.around_hook("Window_CommandPokemon_Challenge", :dispose, :optional => true) do |_win, nxt, _a|
  ret = nxt.call
  PokeAccess::ChallengeRules.top
  ret
end

PokeAccess::Hooks.after_hook("Window_AdvancedTextPokemon", :text=, :optional => true) do |win, _r, args|
  PokeAccess::ChallengeRules.on_text(win, args[0])
end

%w[ChallengeModes RandomizerConfigurator].each { |owner| PokeAccess::ChallengeRules.wire_summary(owner) }
