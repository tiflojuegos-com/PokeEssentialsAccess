# Sevii's trainer card paints its badge count as text ("Badges 16") and fills the badge slots with one emblem per
# completed chapter of the story ($Trainer.chapter): the emblems are said as the chapters completed.
PokeAccess::Game.define("sevii") do
  override("PokeAccess::TrainerCard", :badge_line) do |_mod, _original, args|
    PokeAccess::I18n.t(:ss2_chapters, :n => args[1])
  end
end
