# The v22 party screen (UI::PartyVisuals), voiced only by the set_index hook: the members as their panels show them, and
# the trailing button, Cancel normally but Confirm in choose-entry-order mode (Cancel one further along).

# A member's panel as the game keeps it: the Pokemon in @pokemon and, in @text, the annotation it draws in place of
# the member's HP and state, each with its reader.
class UI::PartyVisualsPanel
  attr_reader :pokemon, :text
  def initialize(pokemon, index = 0, viewport = nil); @pokemon = pokemon; @index = index; @text = nil; end
  def text=(value); @text = value; end
end

class PartyV22GdTest < PokeAccessTest
  MALE = " \xE2\x99\x82"
  FEMALE = " \xE2\x99\x80"
  BUTTON = Settings::MAX_PARTY_SIZE

  test "reads the focused member with name, sex, level and HP" do
    UI::PartyVisuals.new(party).set_index(0)
    assert_equal [[line("Bulba", MALE, 12, 22, 22), true]], SpeakCapture.log
  end

  test "says nothing when the cursor is set again on the same slot" do
    vis = UI::PartyVisuals.new(party)
    vis.set_index(0)
    SpeakCapture.clear
    vis.set_index(0)
    assert_nothing_spoken
  end

  test "says each member's own sex and state" do
    { 1 => "#{line("Fainty", FEMALE, 9, 0, 30)}, #{word(:pk_fainted)}",
      2 => "#{line("Brilli", MALE, 30, 50, 50)}, #{word(:pk_shiny)}" }.each do |idx, want|
      SpeakCapture.clear
      UI::PartyVisuals.new(party).set_index(idx)
      assert_equal [want], SpeakCapture.lines, "the member at #{idx}"
    end
  end

  test "reads the slot again on a party screen opened anew" do
    members = party
    UI::PartyVisuals.new(members).set_index(0)
    SpeakCapture.clear
    UI::PartyVisuals.new(members).set_index(0)
    assert_equal [[line("Bulba", MALE, 12, 22, 22), true]], SpeakCapture.log
  end

  test "names the button past the last slot Cancel" do
    UI::PartyVisuals.new(party).set_index(BUTTON)
    assert_equal [[word(:pc_cancel), true]], SpeakCapture.log
  end

  test "names the entry-order screen's buttons Confirm, then Cancel" do
    { BUTTON => word(:pc_confirm), BUTTON + 1 => word(:pc_cancel) }.each do |idx, want|
      SpeakCapture.clear
      UI::PartyVisuals.new(party, :choose_entry_order).set_index(idx)
      assert_equal [want], SpeakCapture.lines, "the button at #{idx}"
    end
  end

  test "says what a member holds and the icons its panel draws, after its state" do
    plain = line("Pika", MALE, 25, 40, 40)
    fainted = line("Pika", MALE, 25, 0, 40)
    cases = { "an item" => [pika(:item => 5), "#{plain}, #{word(:pty_item)}"],
              "mail" => [pika(:item => 5, :mail => true), "#{plain}, #{word(:pty_mail)}"],
              "the Exp. Share" => [pika(:expshare => true), "#{plain}, #{word(:pty_expshare)}"],
              "a shiny holding an item, with the Exp. Share" =>
                [pika(:shiny => true, :item => 5, :expshare => true),
                 "#{plain}, #{word(:pk_shiny)}, #{word(:pty_item)}, #{word(:pty_expshare)}"],
              "a fainted member holding an item" =>
                [pika(:hp => 0, :item => 5), "#{fainted}, #{word(:pk_fainted)}, #{word(:pty_item)}"] }
    cases.each do |what, (pk, want)|
      assert_equal [want], focused_lines(pk), what
    end
  end

  test "says a member's ailment, and fainting before it" do
    poison = GameData::Status.get(:POISON).name
    { "poisoned" => [pika(:status => :POISON), "#{line("Pika", MALE, 25, 40, 40)}, #{poison}"],
      "an ailment of NONE" => [pika(:status => :NONE), line("Pika", MALE, 25, 40, 40)],
      "fainted and poisoned" => [pika(:hp => 0, :status => :POISON), "#{line("Pika", MALE, 25, 0, 40)}, #{word(:pk_fainted)}"],
      "one HP left" => [pika(:hp => 1), line("Pika", MALE, 25, 1, 40)] }.each do |what, (pk, want)|
      assert_equal [want], focused_lines(pk), what
    end
  end

  test "says an egg as an egg" do
    egg = pika
    egg.define_singleton_method(:egg?) { true }
    assert_equal [word(:pty_egg)], focused_lines(egg)
  end

  test "says a member at the party reading's level" do
    { :brief => word(:pty_member_nolv, :name => "Bulba", :sex => "", :hp => 22, :tot => 22),
      :medium => word(:pty_member, :name => "Bulba", :sex => "", :level => 12, :hp => 22, :tot => 22),
      :full => line("Bulba", MALE, 12, 22, 22) }.each do |level, want|
      PokeAccess::Config.verbosity = level
      SpeakCapture.clear
      UI::PartyVisuals.new(party).set_index(0)
      assert_equal [want], SpeakCapture.lines, "at #{level}"
    end
  end

  test "keeps the member's whole line for the info key, whatever the reading's level" do
    PokeAccess::Config.verbosity = :brief
    UI::PartyVisuals.new(party).set_index(0)
    assert_equal line("Bulba", MALE, 12, 22, 22), PokeAccess::Info.row_text
  end

  test "says pokerus in a member's empty state slot, where the v22 panel draws it" do
    assert_equal ["#{line("Pika", MALE, 25, 40, 40)}, #{word(:pk_pokerus)}"], focused_lines(pika(:pokerusStage => 1))
  end

  test "says the annotation a panel writes in place of its member's HP and state" do
    pk = pika(:hp => 0)
    vis = UI::PartyVisuals.new([pk])
    vis.sprites["pokemon0"] = UI::PartyVisualsPanel.new(pk)
    vis.sprites["pokemon0"].text = "APTO"
    vis.set_index(0)
    assert_equal ["#{word(:pty_head, :name => "Pika, Species1", :sex => MALE, :level => 25)}, APTO"], SpeakCapture.lines
  end

  test "leaves out the shiny star under an annotation, as the v22 panel does" do
    pk = pika(:shiny => true)
    vis = UI::PartyVisuals.new([pk])
    vis.sprites["pokemon0"] = UI::PartyVisualsPanel.new(pk)
    vis.sprites["pokemon0"].text = "APTO"
    vis.set_index(0)
    assert_equal ["#{word(:pty_head, :name => "Pika, Species1", :sex => MALE, :level => 25)}, APTO"], SpeakCapture.lines
  end

  private

  # The text of i18n key with args.
  def word(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # A member's line as its panel shows it in full: name, the species its icon shows after the nickname (species 1's),
  # sex sign, level and HP.
  def line(name, sex, level, hp, tot)
    word(:pty_member, :name => "#{name}, Species1", :sex => sex, :level => level, :hp => hp, :tot => tot)
  end

  # Bulba, a fainted Fainty and a shiny Brilli.
  def party
    [Poke.build(:name => "Bulba", :level => 12, :hp => 22, :totalhp => 22, :gender => 0),
     Poke.build(:name => "Fainty", :level => 9, :hp => 0, :totalhp => 30, :gender => 1),
     Poke.build(:name => "Brilli", :level => 30, :hp => 50, :totalhp => 50, :gender => 0, :shiny => true)]
  end

  # Pika, level 25 with 40 HP of 40; opts :hp, :status, :item and :shiny set its own, any other name answers its
  # value.
  def pika(opts = {})
    own = [:hp, :status, :item, :shiny]
    pk = Poke.build({ :name => "Pika" }.merge(opts.select { |k, _v| own.include?(k) }))
    opts.each { |name, v| pk.define_singleton_method(name) { v } unless own.include?(name) }
    pk
  end

  # What the screen says with the cursor on pk, the party's only member.
  def focused_lines(pk)
    SpeakCapture.clear
    UI::PartyVisuals.new([pk]).set_index(0)
    SpeakCapture.lines
  end
end
