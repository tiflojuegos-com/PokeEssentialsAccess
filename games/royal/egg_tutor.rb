# Royal's egg-move tutor, a move reminder whose main replaces the reminder's: the opening read hooks its own main.
PokeAccess::Game.define("royal_egg_tutor") do
  before("UI::EggMoveTutor", :main, :optional => true) do |screen, _a|
    PokeAccess::UIV21.reminder_opening(screen)
  end
end
