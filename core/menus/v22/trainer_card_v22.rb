# v22 trainer card (UI::TrainerCard): a static panel, read once on open through TrainerCardData.
if PokeAccess::Engine.has?("UI::TrainerCard")
  PokeAccess::Hooks.read_on_open("UI::TrainerCard", :start_screen) { |_s| PokeAccess::TrainerCardData.text }
end
