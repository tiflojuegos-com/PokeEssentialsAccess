# v22 trainer card (Essentials v22: UI::TrainerCard): the same static $player panel (name, ID, money,
# pokedex tally, badges, play time) with nothing to navigate, read all once on open. The spoken content is
# the agnostic TrainerCardData (no dependency on the v21 file).
if PokeAccess::Engine.has?("UI::TrainerCard")
  PokeAccess::Hooks.read_on_open("UI::TrainerCard", :start_screen) { |_s| PokeAccess::TrainerCardData.text }
end
