# The v22 title and save screens (UI::LoadVisuals, UI::SaveVisuals): the focused command, the save Continue would
# load, the slot cycled through, and each slot's summary, the free one past the last save read as empty.
class LoadSaveV22GdTest < PokeAccessTest
  COMMANDS = { :continue => "Continuar", :new_game => "Partida nueva" }
  Player = Struct.new(:name, :pokedex, :party)
  Dex = Struct.new(:seen_count)
  Stats = Struct.new(:play_time)

  test "Continue says the command and a summary of the save it would load" do
    UI::LoadVisuals.new(COMMANDS, saves).set_index(:continue)
    assert_equal [["Continuar. #{ayoub}", true]], SpeakCapture.log
  end

  test "Continue summarises the slot the screen starts on" do
    UI::LoadVisuals.new(COMMANDS, saves, 1).set_index(:continue)
    assert_equal [["Continuar. #{marta}", true]], SpeakCapture.log
  end

  test "Continue with no saves says the command alone" do
    { "an empty save list" => [], "none at all" => nil }.each do |what, save_data|
      SpeakCapture.clear
      UI::LoadVisuals.new(COMMANDS, save_data).set_index(:continue)
      assert_equal [["Continuar", true]], SpeakCapture.log, what
    end
  end

  test "another command is said by its name alone" do
    UI::LoadVisuals.new(COMMANDS, saves).set_index(:new_game)
    assert_equal [["Partida nueva", true]], SpeakCapture.log
  end

  test "cycling the slot says its number out of the total and its save" do
    vis = UI::LoadVisuals.new(COMMANDS, saves)
    vis.set_slot_index(1)
    assert_equal [["#{PokeAccess::I18n.t(:load_slot, :n => 2, :tot => 2)}. #{marta}", true]], SpeakCapture.log
    SpeakCapture.clear
    vis.set_slot_index(0)
    assert_equal [["#{PokeAccess::I18n.t(:load_slot, :n => 1, :tot => 2)}. #{ayoub}", true]], SpeakCapture.log
  end

  test "cycling says the slot the screen settles on, past the first one the last" do
    UI::LoadVisuals.new(COMMANDS, saves).set_slot_index(-1)
    assert_equal [["#{PokeAccess::I18n.t(:load_slot, :n => 2, :tot => 2)}. #{marta}", true]], SpeakCapture.log
  end

  test "below the medium level the slot's number goes without the total" do
    vis = UI::LoadVisuals.new(COMMANDS, saves)
    said = vb_levels do
      SpeakCapture.clear
      vis.set_slot_index(1, true)
      SpeakCapture.lines.dup
    end
    bare = "#{PokeAccess::I18n.t(:load_slot_bare, :n => 2)}. #{marta}"
    whole = "#{PokeAccess::I18n.t(:load_slot, :n => 2, :tot => 2)}. #{marta}"
    assert_equal [[bare], [whole], [whole]], said, "brief, medium and full"
  end

  test "cycling with no saves says nothing" do
    UI::LoadVisuals.new(COMMANDS, nil).set_slot_index(1)
    assert_nothing_spoken
  end

  test "the save screen says the focused slot's summary" do
    UI::SaveVisuals.new(saves).set_index(1)
    assert_equal [[marta, true]], SpeakCapture.log
  end

  test "the save screen reads the free slot past the last save as empty" do
    UI::SaveVisuals.new(saves).set_index(2)
    assert_equal [[PokeAccess::I18n.t(:pc_empty), true]], SpeakCapture.log
  end

  test "a slot's summary says only what its save holds" do
    t = PokeAccess::I18n
    {
      Player.new(nil, Dex.new(12), nil) => [t.t(:load_play, :h => 0, :m => 10), t.t(:load_dex, :n => 12)].join(". "),
      Player.new("Marta", nil, nil) => [t.t(:load_save, :name => "Marta"), t.t(:load_play, :h => 0, :m => 10)].join(". "),
      Player.new("Marta", Dex.new(12), []) =>
        [t.t(:load_save, :name => "Marta"), t.t(:load_play, :h => 0, :m => 10), t.t(:load_dex, :n => 12)].join(". ")
    }.each do |player, want|
      SpeakCapture.clear
      UI::SaveVisuals.new([["Game.rxdata", { :player => player, :stats => Stats.new(600) }]]).set_index(0, true)
      assert_equal [want], SpeakCapture.lines, "for #{player.inspect}"
    end
  end

  test "a save holding no player and no play time reads as empty" do
    UI::SaveVisuals.new([["Game.rxdata", {}]]).set_index(0, true)
    assert_equal [PokeAccess::I18n.t(:pc_empty)], SpeakCapture.lines
  end

  private

  # Two saves: Ayoub's, with a team of a Pikachu and an egg, and Marta's, with none.
  def saves
    pikachu = Poke.build(:species => :PIKACHU)
    egg = Poke.build(:species => :TOGEPI)
    def egg.egg?; true; end
    [["Game.rxdata", { :player => Player.new("Ayoub", Dex.new(80), [pikachu, egg]), :stats => Stats.new(7380) }],
     ["Game2.rxdata", { :player => Player.new("Marta", Dex.new(12), nil), :stats => Stats.new(600) }]]
  end

  # Ayoub's save as a slot summary says it.
  def ayoub
    t = PokeAccess::I18n
    [t.t(:load_save, :name => "Ayoub"), t.t(:load_play, :h => 2, :m => 3), t.t(:load_dex, :n => 80),
     t.t(:load_party, :list => "SpeciesPIKACHU, #{t.t(:pty_egg)}")].join(". ")
  end

  # Marta's save as a slot summary says it.
  def marta
    t = PokeAccess::I18n
    [t.t(:load_save, :name => "Marta"), t.t(:load_play, :h => 0, :m => 10), t.t(:load_dex, :n => 12)].join(". ")
  end
end
