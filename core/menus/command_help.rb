module PokeAccess
  # The help line of Kernel.pbShowCommandsWithHelp and its variants (every era); the options are read by the generic
  # command-window hook. The help window is the dialogue's class, so it is read only while such a menu runs and no
  # deeper message is up. Always stored for the info key.
  module CommandHelp
    @stack = []
    @held = nil

    # The variant running, or nil: :withhelp (pbShowCommandsWithHelp and its AndText form) or :rogue.
    def self.current; (@stack.last || [])[0]; end

    # Pushes a menu with the message depth it opens at, and holds the help it writes on the way in for release.
    def self.enter(kind)
      @stack.push([kind, PokeAccess.message_depth])
      @held = [[], 0]
    end

    # Pops a menu; when the last closes, drops the held help and the info key's text line (a Pokemon or item stays).
    def self.leave
      @stack.pop
      return unless @stack.empty?
      @held = nil
      PokeAccess::Info.clear_text
    end

    # Stores a help line for the info key and speaks it queued (held while the menu opens) if read_help is on and the
    # verbosity says descriptions; only for the running variant with no message on top, deduped per window.
    def self.note(win, serves, raw)
      return unless current == serves
      return if PokeAccess.message_depth > @stack.last[1]
      txt = PokeAccess.clean(raw.to_s)
      return if txt.empty? || txt == PokeAccess.ivar(win, :@access_cmdhelp)
      win.instance_variable_set(:@access_cmdhelp, txt)
      PokeAccess::Info.set_info(:text, txt)
      return unless (PokeAccess::Config.read_help rescue true) && PokeAccess::Verbosity.descriptions?
      @held ? @held[0].push(txt) : PokeAccess.speak(txt, false)
    rescue StandardError
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

PokeAccess::Keys.on_frame { PokeAccess::CommandHelp.release }

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
