# The character creator of both Infinite Fusion games (infinitefusion_common): each row with its current value, said again when the value
# changes on the same row. Driven through the module functions with a stub presenter, as the hooks call them.

# The game's presenter: the label constants the reader reads (creator_at sets the current values).
class CharacterSelectMenuPresenter
  SKIN_COLOR_IDS = ["Type A", "Type B", "Type C", "Type D", "Type E", "Type F"]
  GENDERS_IDS = ["Female", "Male"]
  HAIR_COLOR_NAMES = ["Blonde", "Light Brown", "Dark Brown", "Black"]
end
load File.expand_path("../../../games/infinitefusion_common/character_creator.rb", File.dirname(__FILE__))

# Builds a presenter sitting on a given row with the creator's own defaults.
def creator_at(index)
  p = CharacterSelectMenuPresenter.new
  p.instance_variable_set(:@options, ["Name", "Gender", "Age", "Skin", "Hair", "Confirm"])
  p.instance_variable_set(:@current_index, index)
  p.instance_variable_set(:@name, "")
  p.instance_variable_set(:@gender, 1)
  p.instance_variable_set(:@age, 10)
  p.instance_variable_set(:@skinTone, 5)
  p.instance_variable_set(:@hairColor, 2)
  p
end

Suite.define("character creator: each row is voiced with its current value") do
  p = creator_at(1)
  PokeAccess::CharacterCreator.focus(p)
  spoke "the gender row reads its value, not just its name", /#{PokeAccess::I18n.t(:chr_male)}/
  spoke "and says which row of how many it is", /2.*6/

  SpeakCapture.clear
  p.instance_variable_set(:@current_index, 2)
  PokeAccess::CharacterCreator.focus(p)
  spoke "the age row reads the number", /10/

  SpeakCapture.clear
  p.instance_variable_set(:@current_index, 3)
  PokeAccess::CharacterCreator.focus(p)
  spoke "the skin row reads the letter the screen shows for tone 5", /E/

  SpeakCapture.clear
  p.instance_variable_set(:@current_index, 4)
  PokeAccess::CharacterCreator.focus(p)
  spoke "the hair row reads the colour name", /#{PokeAccess::I18n.t(:chr_hair_dark_brown)}/
end

Suite.define("character creator: changing a value on the same row speaks again (the half-read bug)") do
  p = creator_at(1)
  PokeAccess::CharacterCreator.focus(p)
  spoke_once "the row is announced on arrival", /#{PokeAccess::I18n.t(:chr_male)}/

  SpeakCapture.clear
  PokeAccess::CharacterCreator.focus(p)
  silent "the same row with the same value is not repeated every frame"

  SpeakCapture.clear
  p.instance_variable_set(:@gender, 0)
  PokeAccess::CharacterCreator.focus(p)
  spoke "pressing left on the SAME row announces the new value", /#{PokeAccess::I18n.t(:chr_female)}/
end

Suite.define("character creator: an empty name says so instead of reading nothing") do
  p = creator_at(0)
  PokeAccess::CharacterCreator.focus(p)
  spoke "a name not yet typed is reported as unset", /#{PokeAccess::I18n.t(:chr_no_name)}/

  SpeakCapture.clear
  p.instance_variable_set(:@name, "Ayoub")
  PokeAccess::CharacterCreator.focus(p)
  spoke "once typed, the name itself is read", /Ayoub/
end

Suite.define("character creator: a row with nothing to edit is read without a value") do
  p = creator_at(5)
  PokeAccess::CharacterCreator.focus(p)
  spoke "confirm is announced as a plain row", /#{PokeAccess::I18n.t(:chr_confirm)}/
  not_spoke "with no stray separator from the value form", /: /
end

Suite.define("character creator: opening the screen reads the first row") do
  p = creator_at(4)
  PokeAccess::CharacterCreator.open(p)
  spoke "the opening read is row 1, which is where main puts the cursor", /#{PokeAccess::I18n.t(:chr_name)}/
end

Suite.define("character creator: Hoenn's rival variant, with fewer rows, still reads") do
  p = creator_at(0)
  p.instance_variable_set(:@options, ["Name", "Skin", "Hair", "Confirm"])
  p.instance_variable_set(:@current_index, 1)
  PokeAccess::CharacterCreator.focus(p)
  spoke "the skin row counts against the four rows this variant shows", /2.*4/
end

Suite.define("character creator: an unknown row falls back to the game's own caption") do
  p = creator_at(0)
  p.instance_variable_set(:@options, ["Name", "Freckles"])
  p.instance_variable_set(:@current_index, 1)
  PokeAccess::CharacterCreator.focus(p)
  spoke "a row this reader does not know is still announced by its English label", /Freckles/
end

Suite.define("character creator: a row's place in the list is said while positions are") do
  p = creator_at(1)
  PokeAccess::Config.verbosity = :brief
  begin
    SpeakCapture.clear
    PokeAccess::CharacterCreator.focus(p)
    spoke "brief: the row reads its value", /#{PokeAccess::I18n.t(:chr_male)}/
    falsy "without which row of how many it is", SpeakCapture.lines.join(" ") =~ /2.*6/
  ensure
    PokeAccess::Config.verbosity = :full
  end
end

# Confirm with no name typed fills in the default ("Red"/"Green") and repaints the name row before asking whether all
# is correct; the name is said then, queued before the question, and the row's own read does not repeat it.
Suite.define("character creator: the name the screen fills in or repaints is said, once") do
  cc = PokeAccess::CharacterCreator
  t = PokeAccess::I18n
  p = creator_at(5)
  cc.open(p)
  SpeakCapture.clear
  cc.name_shown(p)
  silent "a repaint of the name the opening read already said says nothing"
  p.instance_variable_set(:@name, "Red")
  cc.name_shown(p)
  eq "the default name confirm fills in, queued ahead of its question", SpeakCapture.log,
     [[t.t(:chr_value, :name => t.t(:chr_name), :value => "Red"), false]]
  SpeakCapture.clear
  cc.name_shown(p)
  silent "and said once"

  typed = creator_at(0)
  cc.open(typed)
  typed.instance_variable_set(:@name, "Ayoub")
  SpeakCapture.clear
  cc.name_shown(typed)
  cc.focus(typed)
  eq "a name just typed on its own row is said once, not again by the row's read",
     SpeakCapture.lines, [t.t(:chr_value, :name => t.t(:chr_name), :value => "Ayoub")]
end
