module PokeAccess
  # The help line of Kernel.pbShowCommandsWithHelp and its variants (every era); the options are read by the generic
  # command-window hook. The help window is the dialogue's class, so it is read only while such a menu runs and no
  # deeper message is up. Always stored for the info key; Ctrl+T says the focused option before it.
  module CommandHelp
    @stack = []
    @held = nil

    # The variant running, or nil: :withhelp (pbShowCommandsWithHelp and its AndText form) or :rogue.
    def self.current; (@stack.last || [])[0]; end

    # Pushes a menu as [variant, the message depth it opens at, its command window, its last help], and holds the
    # help it writes on the way in for release.
    def self.enter(kind)
      @stack.push([kind, PokeAccess.message_depth, nil, nil])
      @held = [[], 0]
    end

    # Takes the active command window the running menu updates, with no message above it, as the one whose focused
    # option heads Ctrl+T's row; a help noted before that window first updated is published again with its row.
    def self.focus(win)
      top = @stack.last
      return unless top && win.active && PokeAccess.message_depth <= top[1]
      return if win.equal?(top[2])
      top[2] = win
      help = top[3]
      PokeAccess::Info.set_info(:text, help, row(help)) if help && PokeAccess::Info.info_text == help
    end

    # Ctrl+T's row for a help line: the menu's focused option, then the help (none for an option without one); nil
    # before its window updates.
    def self.row(help)
      win = (@stack.last || [])[2]
      head = win ? PokeAccess.clean(PokeAccess::Menus.focused_text(win).to_s) : ""
      return nil if head.empty?
      help ? PokeAccess.sentences([head, help]) : head
    end

    # Pops a menu; when the last closes, drops the held help and the info key's text line (a Pokemon or item stays).
    def self.leave
      @stack.pop
      return unless @stack.empty?
      @held = nil
      PokeAccess::Info.clear_text
    end

    # Stores a help line for the info key, with the focused option before it for Ctrl+T, and speaks it queued (held
    # while the menu opens) if read_help is on and the verbosity says descriptions; only for the running variant with
    # no message on top. The same help written again (an option that shares it) or none once one was written (options
    # with no help) only renews what the keys say, deduped per window.
    def self.note(win, serves, raw)
      return unless current == serves
      return if PokeAccess.message_depth > @stack.last[1]
      txt = PokeAccess.clean(raw.to_s)
      last = PokeAccess.ivar(win, :@access_cmdhelp)
      return if txt.empty? && last.nil?
      help = txt.empty? ? nil : txt
      win.instance_variable_set(:@access_cmdhelp, help || "")
      @stack.last[3] = help
      PokeAccess::Info.set_info(:text, help, row(help))
      return if help.nil? || help == last
      return unless (PokeAccess::Config.read_help rescue true) && PokeAccess::Verbosity.descriptions?
      @held ? @held[0].push(help) : PokeAccess.speak(help, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # From the frame poller: counts the menu's first frames, and on the second says what it held.
    def self.release
      return unless @held
      @held[1] += 1
      return if @held[1] < 2
      lines = @held[0]
      @held = nil
      lines.each { |t| PokeAccess.speak(t, false) }
    end
  end
end

PokeAccess::Frame.each_pulse { PokeAccess::CommandHelp.release }

# Marks the running variant around pbShowCommandsWithHelp, pbShowCommandsWithHelpAndText (Pokémon Z's ability
# changer) and Reminiscencia's pbShowCommandsRogue; Añil's MessageUI helper is marked from its profile.
[["pbShowCommandsWithHelp", :withhelp], ["pbShowCommandsWithHelpAndText", :withhelp],
 ["pbShowCommandsRogue", :rogue]].each do |fn, kind|
  PokeAccess::Hooks.wrap_kernel(fn, "hook_cmdhelp", :around) do |_args, call_next|
    PokeAccess::CommandHelp.enter(kind)
    begin
      call_next.call
    ensure
      PokeAccess::CommandHelp.leave
    end
  end
end

# The help windows: AdvancedText holds :withhelp's help and :rogue's caption, Unformatted holds :rogue's help. Each
# listener passes the variant it serves, so plain dialogue is never read.
PokeAccess::Hooks.after_hook("Window_AdvancedTextPokemon", :text=) do |win, _r, args|
  PokeAccess::CommandHelp.note(win, PokeAccess::CommandHelp.current == :rogue ? :rogue : :withhelp, args[0])
end
PokeAccess::Hooks.after_hook("Window_UnformattedTextPokemon", :text=) do |win, _r, args|
  PokeAccess::CommandHelp.note(win, :rogue, args[0])
end

# The running menu's command window, whose focused option heads Ctrl+T's row.
PokeAccess::Hooks.after_hook("Window_DrawableCommand", :update) do |win, _r, _a|
  PokeAccess::CommandHelp.focus(win) if PokeAccess::CommandHelp.current
end
