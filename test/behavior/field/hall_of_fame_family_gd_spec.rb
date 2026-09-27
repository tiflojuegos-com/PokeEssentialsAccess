# The hall-of-fame family reader on the modern screen: a clone bound as a profile binds it reads like the vanilla
# screen, a copy whose panel paints no text falls back to the composed line, the trainer's box comes before the
# closing message, and a records hall keeps a figure it paints twice.

# Fire Ash's Gauntlet records hall: the record's number and its win count painted as rows of their own, which can be
# the same figure. Bound by the spec through HallOfFame.bind, as the profile does.
class Gauntlet_Scene
  attr_accessor :wins
  def writePokemonData(pk, hall = -1)
    rows = [["No. 025", 32, 298], ["#{pk ? pk.name : '?'} Lv. #{pk ? pk.level : 0}", 320, 298]]
    if hall > -1
      rows += [["Hall of Grandeur No.", 48, -6], [hall.to_s, 262, -6], ["Win count:", 360, -6], [@wins.to_s, 440, -6]]
    end
    pbDrawTextPositions(nil, rows)
    hall
  end
  def pbStartSceneEntry(*a); end
end

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

# The closing trainer box on the modern screen: its rows are said as its window takes them, queued ahead of the
# congratulation the same method then shows.
Suite.define("hall of fame: the modern screen's closing trainer box is read before its congratulation") do
  SpeakCapture.clear
  HallOfFame_Scene.new.writeTrainerData
  eq "the box row by row, label and value apart, then the congratulation, both queued",
     SpeakCapture.log,
     [["Name Tester, ID No. 12345, Time 1h 23m, Pokédex 10/20", false], ["League champion! Congratulations!", false]]
end

Suite.define("hall of fame: a records hall keeps a figure it paints twice") do
  fake = Class.new do
    attr_reader :name, :level, :species
    def initialize(name, level); @name = name; @level = level; @species = 25; end
    def egg?; false; end
  end
  eq "binding Fire Ash's Gauntlet hall reports that it took", PokeAccess::HallOfFame.bind("Gauntlet_Scene"), true
  gauntlet = Gauntlet_Scene.new
  gauntlet.wins = 3
  SpeakCapture.clear
  gauntlet.writePokemonData(fake.new("Chispa", 50), 3)
  eq "record number 3 with 3 wins keeps both figures, as the panel paints them",
     SpeakCapture.lines, ["No. 025, Chispa Lv. 50, Hall of Grandeur No., 3, Win count:, 3"]
end
