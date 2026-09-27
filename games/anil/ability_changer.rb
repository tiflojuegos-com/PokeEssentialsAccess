# Anil's ability changer, MessageUI.show_commands_with_help_and_text (a module singleton, hence wrap_singleton): the
# call is marked as a help-carrying command list, so CommandHelp reads the description painted on each cursor move.
PokeAccess::Hooks.wrap_singleton("MessageUI", :show_commands_with_help_and_text, "hook_cmdhelp_anil", :around) do |_args, call_next|
  PokeAccess::CommandHelp.enter(:withhelp)
  begin
    call_next.call
  ensure
    PokeAccess::CommandHelp.leave
  end
end
