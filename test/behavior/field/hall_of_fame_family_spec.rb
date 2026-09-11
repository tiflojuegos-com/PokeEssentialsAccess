# The hall-of-fame family reader, on the gen-6 spelling. Its twin hall_of_fame_family_gd_spec.rb covers the
# modern one and the profile-declared clone.
#
# The screen is FL's, and fangames clone it by copy-paste once per records hall they add: Fire Ash ships six
# more with the same methods and the same panels, changing only the class name and the header. Readers
# written against one class name covered one screen of seven, and the other six were mute from end to end,
# with the focused member marked by opacity alone.
#
# What is pinned is that the panel is READ AS PAINTED rather than composed. Composing gives nickname,
# species and level; the panel also paints the dex number and the trainer id, and each per-language build
# paints its own words.
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
