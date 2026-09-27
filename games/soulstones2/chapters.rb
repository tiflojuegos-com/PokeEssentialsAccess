# Soulstones 2 counts completed chapters in the badges: its trainer card draws one numbered icon per chapter, and
# its load and save screens write the same count as "Ch. Completed". Both the card and the info key's trainer line
# say chapters.
PokeAccess::Game.define("soulstones2") do
  override("PokeAccess::TrainerCard", :badge_line) do |_mod, _original, args|
    PokeAccess::I18n.t(:ss2_chapters, :n => args[1])
  end

  trainer_part(:badges) do |tr|
    n = PokeAccess::Util.badge_count(tr)
    n.nil? ? nil : PokeAccess::I18n.t(:ss2_chapters, :n => n)
  end
end
