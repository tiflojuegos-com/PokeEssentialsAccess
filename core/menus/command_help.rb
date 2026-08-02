module PokeAccess
  # Generic per-option help for Kernel.pbShowCommandsWithHelp, the standard Essentials "menu with a help
  # line" used across gen-6, v21 and v22 (campfire-style menus, the PC, etc.). The option list is read by
  # the generic command-window hook; this adds the help line each option shows in a side message window.
  #
  # That help window is an ordinary Window_AdvancedTextPokemon -- the same class plain dialogue uses, with
  # no tag to tell them apart -- so we only listen to its text= WHILE pbShowCommandsWithHelp is running
  # (a flag set by an around-wrap of that function). Outside it, dialogue is untouched (no double reads).
  # Gated by Config.read_help so the user can switch it off; spoken after the option name (queued, not
  # interrupting) and also stored for the info key.
  module CommandHelp
    @stack = []

    # The variant currently running (or nil): :withhelp for pbShowCommandsWithHelp, :rogue for the Rogue
    # variant. A help-window listener passes which variant ITS window serves and reads only when they match,
    # so the Rogue caption window stays silent and ordinary dialogue (no variant active) is never read.
    def self.current; @stack.last; end
    def self.enter(kind); @stack.push(kind); end
    # Clears the stored help line with the last menu on the stack, the same way RegionMap.forget does on
    # close. In the field the next frame overwrites it, but going straight from one menu to another left
    # the info key answering with the PREVIOUS menu's help.
    def self.leave
      @stack.pop
      PokeAccess::Info.set_info(:text, nil) if @stack.empty?
    end

    # Voices a help line (queued, so it follows the option name) and stores it for the info key, only when
    # the listener's variant is the one running. Deduped per window.
    def self.note(win, serves, raw)
      return unless current == serves && (PokeAccess::Config.read_help rescue true)
      txt = PokeAccess.clean(raw.to_s)
      return if txt.empty? || txt == PokeAccess.ivar(win, :@access_cmdhelp)
      win.instance_variable_set(:@access_cmdhelp, txt)
      PokeAccess::Info.set_info(:text, txt)
      PokeAccess.speak(txt, false)
    rescue StandardError
      nil
    end
  end
end

# The standard pbShowCommandsWithHelp and the fangame pbShowCommandsRogue variant (campfire and
# item menus). Each marks which variant is running so the listener reads only that variant's help window.
{ "pbShowCommandsWithHelp" => :withhelp, "pbShowCommandsRogue" => :rogue }.each do |fn, kind|
  PokeAccess::Hooks.wrap_kernel(fn, "hook_cmdhelp", :around) do |_args, call_next|
    PokeAccess::CommandHelp.enter(kind)
    begin
      call_next.call
    ensure
      PokeAccess::CommandHelp.leave
    end
  end
end

# Help lands in different window classes by variant: WithHelp uses the AdvancedText window, the Rogue
# variant the Unformatted one. Each listener declares which variant it serves so note() reads only when
# that variant is running (and never on the Rogue caption window or plain dialogue).
PokeAccess::Hooks.after_hook("Window_AdvancedTextPokemon", :text=) do |win, _r, args|
  PokeAccess::CommandHelp.note(win, :withhelp, args[0])
end
PokeAccess::Hooks.after_hook("Window_UnformattedTextPokemon", :text=) do |win, _r, args|
  PokeAccess::CommandHelp.note(win, :rogue, args[0])
end
