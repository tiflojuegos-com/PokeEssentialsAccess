# The move reminder's opening read (UI::MoveReminder, v22's and Sky's backport): its first move as the screen fades in,
# start_screen, the first thing its main runs, as does the main of its own that Sky's egg-move tutor has. The visuals
# and the move list exist by then.
PokeAccess::Hooks.before_hook("UI::MoveReminder", :start_screen, :optional => true) do |screen, _a|
  PokeAccess::UIV21.reminder_opening(screen)
end
