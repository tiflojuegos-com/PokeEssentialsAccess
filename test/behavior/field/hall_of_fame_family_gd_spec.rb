# The modern half of hall_of_fame_family_spec.rb, and the part that matters most: a CLONE, bound the way a
# profile binds one, reads with the same code as the vanilla screen. Duet_Scene paints nothing, so it also
# pins the fallback: a copy whose panel drew no text still says who the member is.
Suite.define("hall of fame: a profile-declared clone gets the same reader, and a silent panel still reads") do
  fake = Class.new do
    attr_reader :name, :level, :species
    def initialize(name, level); @name = name; @level = level; @species = 25; end
    def egg?; false; end
  end

  SpeakCapture.clear
  HallOfFame_Scene.new.writePokemonData(fake.new("Chispa", 50), -1)
  eq "the vanilla modern screen reads its painted panel",
     SpeakCapture.lines, ["No. 025, Chispa Lv. 50"]

  eq "binding a clone reports that it took", PokeAccess::HallOfFame.bind("Duet_Scene"), true
  SpeakCapture.clear
  Duet_Scene.new.writePokemonData(fake.new("Chispa", 50), 3)
  eq "and a clone that paints nothing falls back to the composed line",
     SpeakCapture.lines, [PokeAccess::HallOfFame.member_text(fake.new("Chispa", 50))]

  SpeakCapture.clear
  Duet_Scene.new.writeWelcome
  eq "a banner that paints nothing falls back to the mod's own welcome",
     SpeakCapture.lines, [PokeAccess::I18n.t(:hof_welcome)]

  eq "binding the clone with no entry animation reports that it took",
     PokeAccess::HallOfFame.bind("Challenge_Scene"), true
  SpeakCapture.clear
  Challenge_Scene.new.writePokemonData(fake.new("Chispa", 50))
  eq "it reads its painted panel", SpeakCapture.lines, ["Chispa Lv. 50"]
  truthy "and it INTERRUPTS, because a screen with no animation is only ever browsed: it redraws on every " +
         "cursor move, and queueing read the whole walk instead of the member the player stopped on",
         SpeakCapture.log.last[1]

  falsy "and no group of the family is left unbound", PokeAccess::Hooks.unbound.any? { |u| u =~ /hall_of_fame/ }
end
