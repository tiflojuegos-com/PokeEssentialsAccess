# The ability changer of Misc Scripts Añil ("¿Qué habilidad quieres para X?"). Its helper,
# MessageUI.show_commands_with_help_and_text, paints the focused ability's description into a
# Window_AdvancedTextPokemon on every cursor move -- the window core's command help already listens to, but
# only while a help-carrying command call is marked as running. Without the mark the names were read and
# the descriptions never, and the info key kept the previous menu's help. Pokémon Z spells the same helper
# Kernel.pbShowCommandsWithHelpAndText, which the core list covers; this one is a module singleton, hence
# wrap_singleton.
PokeAccess::Hooks.wrap_singleton("MessageUI", :show_commands_with_help_and_text, "hook_cmdhelp_anil", :around) do |_args, call_next|
  PokeAccess::CommandHelp.enter(:withhelp)
  begin
    call_next.call
  ensure
    PokeAccess::CommandHelp.leave
  end
end
