# The Infinite Fusion character creator (games/infinitefusion_common/character_creator.rb): each row with its value
# and place, said again when the value changes, and the name the screen fills in said once.

# The game's presenter: the label constants the reader reads, and the methods the profile hooks (main opens the
# screen, three cursor movers, the name row's repaint), with the game's arities. The values live in its ivars.
class CharacterSelectMenuPresenter
  SKIN_COLOR_IDS = ["Type A", "Type B", "Type C", "Type D", "Type E", "Type F"]
  GENDERS_IDS = ["Female", "Male"]
  HAIR_COLOR_NAMES = ["Blonde", "Light Brown", "Dark Brown", "Black"]

  def main; end
  def update_cursor(_index); end
  def move_menu_vertical(_offset); end
  def move_menu_horizontal(_current_index, _incr); end
  def updateDisplayedName(_current_index); end
end

creator_path = File.join(Harness::ROOT, "games", "infinitefusion_common", "character_creator.rb")
eval(Harness.source(creator_path), TOPLEVEL_BINDING, creator_path)

class CharacterCreatorTest < PokeAccessTest
  ROWS = ["Name", "Gender", "Age", "Skin", "Hair", "Confirm"]

  test "says each row with its current value and its place among the rows" do
    { 0 => value(:chr_name, t(:chr_no_name)), 1 => value(:chr_gender, t(:chr_male)), 2 => value(:chr_age, "10"),
      3 => value(:chr_skin, t(:chr_skin_type, :n => "E")), 4 => value(:chr_hair, t(:chr_hair_dark_brown)),
      5 => t(:chr_confirm) }.each do |index, row|
      SpeakCapture.clear
      PokeAccess::CharacterCreator.focus(creator_at(index))
      assert_equal [[entry(row, index + 1, 6), true]], SpeakCapture.log, "row #{ROWS[index]}"
    end
  end

  test "the same row with the same value is not said again" do
    p = creator_at(1)
    PokeAccess::CharacterCreator.focus(p)
    SpeakCapture.clear
    PokeAccess::CharacterCreator.focus(p)
    assert_nothing_spoken
  end

  test "a value changed on the same row is said again" do
    p = creator_at(1)
    PokeAccess::CharacterCreator.focus(p)
    SpeakCapture.clear
    p.instance_variable_set(:@gender, 0)
    PokeAccess::CharacterCreator.focus(p)
    assert_equal [[entry(value(:chr_gender, t(:chr_female)), 2, 6), true]], SpeakCapture.log
  end

  test "says a typed name as the screen shows it, and a blank one as no name" do
    { "Ayoub" => "Ayoub", "\\c[2]Red" => "Red", "   " => t(:chr_no_name) }.each do |typed, said|
      SpeakCapture.clear
      PokeAccess::CharacterCreator.focus(creator_at(0, :@name => typed))
      assert_equal [[entry(value(:chr_name, said), 1, 6), true]], SpeakCapture.log, "for #{typed.inspect}"
    end
  end

  test "a gender or hair colour outside the game's lists is read without a value" do
    { [1, :@gender, 2] => t(:chr_gender), [1, :@gender, -1] => t(:chr_gender), [1, :@gender, nil] => t(:chr_gender),
      [4, :@hairColor, 4] => t(:chr_hair), [4, :@hairColor, "2"] => t(:chr_hair) }.each do |(index, ivar, val), row|
      SpeakCapture.clear
      PokeAccess::CharacterCreator.focus(creator_at(index, ivar => val))
      assert_equal [[entry(row, index + 1, 6), true]], SpeakCapture.log, "#{ivar} #{val.inspect}"
    end
  end

  test "the first and last entries of each list are named" do
    { [1, :@gender, 0] => value(:chr_gender, t(:chr_female)),
      [4, :@hairColor, 0] => value(:chr_hair, t(:chr_hair_blonde)),
      [4, :@hairColor, 3] => value(:chr_hair, t(:chr_hair_black)) }.each do |(index, ivar, val), row|
      SpeakCapture.clear
      PokeAccess::CharacterCreator.focus(creator_at(index, ivar => val))
      assert_equal [[entry(row, index + 1, 6), true]], SpeakCapture.log, "#{ivar} #{val}"
    end
  end

  test "a skin tone is said by the letter its label shows, or by its number where it has no label" do
    { 1 => "A", 6 => "F", 0 => "0", 7 => "7" }.each do |tone, said|
      SpeakCapture.clear
      PokeAccess::CharacterCreator.focus(creator_at(3, :@skinTone => tone))
      assert_equal [[entry(value(:chr_skin, t(:chr_skin_type, :n => said)), 4, 6), true]], SpeakCapture.log,
                   "tone #{tone}"
    end
  end

  test "a build without the skin labels says the tone by its number" do
    labels = CharacterSelectMenuPresenter.send(:remove_const, :SKIN_COLOR_IDS)
    PokeAccess::CharacterCreator.focus(creator_at(3))
    assert_equal [[entry(value(:chr_skin, t(:chr_skin_type, :n => "5")), 4, 6), true]], SpeakCapture.log
  ensure
    CharacterSelectMenuPresenter.const_set(:SKIN_COLOR_IDS, labels) if labels
  end

  test "a row the reader does not know is said by the game's own caption" do
    PokeAccess::CharacterCreator.focus(creator_at(1, :@options => ["Name", "Freckles"]))
    assert_equal [[entry("Freckles", 2, 2), true]], SpeakCapture.log
  end

  test "Hoenn's rival variant counts its rows against the four it shows" do
    PokeAccess::CharacterCreator.focus(creator_at(1, :@options => ["Name", "Skin", "Hair", "Confirm"]))
    assert_equal [[entry(value(:chr_skin, t(:chr_skin_type, :n => "E")), 2, 4), true]], SpeakCapture.log
  end

  test "a row's place is said from the medium verbosity up" do
    said = vb_levels do
      SpeakCapture.clear
      PokeAccess::CharacterCreator.focus(creator_at(1))
      SpeakCapture.lines
    end
    row = value(:chr_gender, t(:chr_male))
    assert_equal [[row], [entry(row, 2, 6)], [entry(row, 2, 6)]], said
  end

  test "a cursor off the rows, or a screen without rows, says nothing" do
    [creator_at(6), creator_at(-1), creator_at(nil), creator_at("1"), creator_at(0, :@options => nil)].each do |p|
      PokeAccess::CharacterCreator.focus(p)
    end
    assert_nothing_spoken
  end

  test "opening the screen reads the first row, wherever the cursor was left" do
    creator_at(4).main
    assert_equal [[entry(value(:chr_name, t(:chr_no_name)), 1, 6), true]], SpeakCapture.log
  end

  test "each move of the cursor reads the row it lands on" do
    { :update_cursor => [3], :move_menu_vertical => [1], :move_menu_horizontal => [3, 1] }.each do |meth, args|
      SpeakCapture.clear
      creator_at(3).send(meth, *args)
      assert_equal [[entry(value(:chr_skin, t(:chr_skin_type, :n => "E")), 4, 6), true]], SpeakCapture.log,
                   "after #{meth}"
    end
  end

  test "the name the confirm fills in is said once, queued ahead of its question" do
    p = creator_at(5)
    p.main
    SpeakCapture.clear
    p.instance_variable_set(:@name, "Red")
    2.times { p.updateDisplayedName(5) }
    assert_equal [[value(:chr_name, "Red"), false]], SpeakCapture.log
  end

  test "a repaint of the name the opening read already said says nothing" do
    p = creator_at(5)
    p.main
    SpeakCapture.clear
    p.updateDisplayedName(5)
    assert_nothing_spoken
  end

  test "a name typed on its own row is said once, not again by the row's read" do
    p = creator_at(0)
    p.main
    SpeakCapture.clear
    p.instance_variable_set(:@name, "Ayoub")
    p.updateDisplayedName(0)
    p.update_cursor(0)
    assert_equal [[value(:chr_name, "Ayoub"), false]], SpeakCapture.log
  end

  test "a name filled in while the cursor is on another row is read when the cursor reaches the name row" do
    p = creator_at(5)
    p.main
    p.instance_variable_set(:@name, "Red")
    p.updateDisplayedName(5)
    SpeakCapture.clear
    p.instance_variable_set(:@current_index, 0)
    p.update_cursor(0)
    assert_equal [[entry(value(:chr_name, "Red"), 1, 6), true]], SpeakCapture.log
  end

  test "a name repainted on a screen that keeps no rows is still said, queued" do
    p = creator_at(0, :@options => nil)
    p.instance_variable_set(:@name, "Red")
    p.updateDisplayedName(0)
    assert_equal [[value(:chr_name, "Red"), false]], SpeakCapture.log
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # A row's "label: value" line.
  def value(label_key, val)
    t(:chr_value, :name => t(label_key), :value => val)
  end

  # A row with its place, as the full verbosity says it.
  def entry(row, n, tot)
    t(:list_entry, :name => row, :n => n, :tot => tot)
  end

  # A presenter on row index with the creator's own defaults (no name, a boy of 10, tone 5, dark brown hair), the
  # given ivars set over them.
  def creator_at(index, ivars = {})
    p = CharacterSelectMenuPresenter.new
    { :@options => ROWS.dup, :@current_index => index, :@name => "", :@gender => 1, :@age => 10, :@skinTone => 5,
      :@hairColor => 2 }.merge(ivars).each { |ivar, val| p.instance_variable_set(ivar, val) }
    p
  end
end
