# The sex is said where the screen draws its sign: none for a genderless Pokemon, nothing but "egg" for an egg (info
# key included), and a battler's displayed sex, which under Illusion is not its own.

Suite.define("sex: the party line says the sign the panel draws, and an egg says nothing but egg") do
  t = PokeAccess::I18n
  male = Poke.build(:name => "Bulba", :level => 5, :hp => 20, :totalhp => 20, :gender => 0)
  none = Poke.build(:name => "Magnet", :level => 9, :hp => 25, :totalhp => 25, :gender => 2)
  egg = Poke.build(:name => "Huevo", :gender => 1)
  def egg.egg?; true; end
  party = [male, none, egg]

  eq "a male member carries his sign", PokeAccess::Party.party_line(party, 0),
     t.t(:pty_member, :name => "Bulba", :sex => " \xE2\x99\x82", :level => 5, :hp => 20, :tot => 20)
  eq "a genderless one carries none", PokeAccess::Party.party_line(party, 1),
     t.t(:pty_member, :name => "Magnet", :sex => "", :level => 9, :hp => 25, :tot => 25)
  eq "an egg is an egg", PokeAccess::Party.party_line(party, 2), t.t(:pty_egg)
  eq "and the info key keeps its secret too", PokeAccess::Info.pokemon_info(egg), t.t(:pty_egg)
  falsy "no sign is left for the value that draws nothing", PokeAccess::Party.gender_glyph(none)
end

# A battler as the databox sees it: its own gender, and the gender of the Pokemon it is shown as.
class SexBattler
  attr_reader :name, :level, :hp, :totalhp
  def initialize(name, gender, shown); @name = name; @gender = gender; @shown = shown; @level = 30; @hp = 50; @totalhp = 100; end
  def gender; @gender; end
  def displayGender; @shown; end
  def status; 0; end
  def pokemon; true; end
end

Suite.define("sex: the battle lines say the sex the databox draws, Illusion included") do
  t = PokeAccess::I18n
  zoroark = SexBattler.new("Zoroark", 0, 1)
  line = PokeAccess::Battle.battler_state(zoroark, true).to_s
  truthy "the HP key says the displayed sex", line.index("Zoroark \xE2\x99\x80")
  falsy "and never the real one it is hiding", line.index("\xE2\x99\x82")

  magnet = SexBattler.new("Magnet", 2, 2)
  falsy "a genderless battler adds nothing", PokeAccess::Battle.battler_state(magnet, true).to_s.index("  ")
  eq "its line starts straight with its name and level",
     PokeAccess::Battle.battler_state(magnet, true).to_s.index("Magnet,"), 0
end
