# The hall-of-fame family reader on the gen-6 spelling (the modern one and clones: hall_of_fame_family_gd_spec.rb):
# the member panel is read as painted, dex number and trainer id included, and the banner is the screen's own.
Suite.define("hall of fame: the member panel is read as painted, and the banner is the screen's own") do
  fake = Class.new do
    attr_reader :name, :level, :species
    def initialize(name, level); @name = name; @level = level; @species = 25; end
    def egg?; false; end
  end
  scene = HallOfFameScene.new
  chispa = fake.new("Chispa", 50)

  SpeakCapture.clear
  scene.writePokemonData(chispa, -1)
  eq "the panel's own rows are what is spoken, dex number and trainer id included",
     SpeakCapture.lines, ["No. 025, Chispa Nv. 50, IDNo.12345"]
  eq "and the entry animation queues its line instead of cutting the previous one",
     SpeakCapture.log.last[1], false

  SpeakCapture.clear
  scene.writePokemonData(chispa, -1)
  silent "that very member drawn again says nothing"

  SpeakCapture.clear
  scene.writePokemonData(fake.new("Chispa", 50), -1)
  eq "but a DIFFERENT member that reads the same is not swallowed",
     SpeakCapture.lines, ["No. 025, Chispa Nv. 50, IDNo.12345"]

  SpeakCapture.clear
  scene.writePokemonData(fake.new("Otro", 12), 3)
  eq "a different member reads", SpeakCapture.lines, ["No. 025, Otro Nv. 12, IDNo.12345"]
  eq "and in the PC viewer it interrupts, because browsing redraws member by member",
     SpeakCapture.log.last[1], true

  SpeakCapture.clear
  scene.writeWelcome
  eq "the banner is whatever the screen painted", SpeakCapture.lines, ["Bienvenido al Salon de la Fama"]
end

# The closing trainer box (writeTrainerData) is read as its window takes its text, queued ahead of the congratulation
# the same method then blocks on; a text window built anywhere else is left to its own readers.
Suite.define("hall of fame: the closing trainer box is read row by row before the congratulation") do
  SpeakCapture.clear
  HallOfFameScene.new.writeTrainerData
  eq "the box's rows, label and value apart, then the congratulation, both queued",
     SpeakCapture.log,
     [["Name Tester, IDNo. 12345, Time 01:23, Pokédex 10/20", false], ["¡Enhorabuena por tu victoria!", false]]

  SpeakCapture.clear
  Window_AdvancedTextPokemon.new("Name<r>Otro<br>")
  silent "a text window built outside that method says nothing through this reader"
end
