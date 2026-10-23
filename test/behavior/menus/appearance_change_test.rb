# The appearance pbChangePlayer puts on (core/menus/appearance.rb): said with its number and, where it has one, its
# gender, only when it changes; Insurgence puts the same one on again on every map transfer, and a refused id changes
# nothing.
class AppearanceChangeTest < PokeAccessTest
  # A trainer type's gender as the engine's helper answers it: 0 boy, 1 girl, 2 either.
  BOY = 0
  GIRL = 1
  EITHER = 2

  # GameData::PlayerMetadata (v21 on): each appearance's trainer type, by its id.
  class PlayerMetadata
    def self.get(id); Struct.new(:trainer_type).new(:"POKEMONTRAINER_#{id}"); end
  end

  test "says the appearance pbChangePlayer puts on, numbered from one, interrupting" do
    [0, 3, 7].each do |id|
      SpeakCapture.clear
      with_player_id(-1) { pbChangePlayer(id) }
      assert_equal [[t(:ap_number, :n => id + 1), true]], SpeakCapture.log, "appearance #{id}"
    end
  end

  test "says nothing when pbChangePlayer puts on the appearance already in use" do
    with_player_id(2) { pbChangePlayer(2) }
    assert_nothing_spoken
  end

  test "says nothing when the game refuses the appearance" do
    with_player_id(0) { [9, -1].each { |id| pbChangePlayer(id) } }
    assert_nothing_spoken
  end

  test "adds whether the appearance is a boy or a girl, by its trainer type" do
    { BOY => :ap_boy, GIRL => :ap_girl }.each do |gender, key|
      SpeakCapture.clear
      with_trainer_types(gender) { with_player_id(-1) { pbChangePlayer(1) } }
      assert_equal ["#{t(:ap_number, :n => 2)}, #{t(key)}"], SpeakCapture.lines, "trainer type gender #{gender}"
    end
  end

  test "adds the player's own gender where the trainer type is of either" do
    with_trainer(Struct.new(:gender).new(GIRL)) do
      with_trainer_types(EITHER) { with_player_id(-1) { pbChangePlayer(1) } }
    end
    assert_equal ["#{t(:ap_number, :n => 2)}, #{t(:ap_girl)}"], SpeakCapture.lines
  end

  test "numbers the appearances as they come where GameData keeps a PlayerMetadata, from one elsewhere" do
    { PlayerMetadata => 2, nil => 3 }.each do |metadata, n|
      SpeakCapture.clear
      with_game_data(metadata) { with_player_id(-1) { pbChangePlayer(2) } }
      assert_equal [t(:ap_number, :n => n)], SpeakCapture.lines, "PlayerMetadata #{metadata.inspect}"
    end
  end

  test "adds the gender of the trainer type GameData's PlayerMetadata gives the appearance" do
    with_game_data(PlayerMetadata) do
      GameFunctions.with(:pbGetTrainerTypeGender => lambda { |type| type == :POKEMONTRAINER_2 ? GIRL : nil }) do
        with_player_id(-1) { pbChangePlayer(2) }
      end
    end
    assert_equal ["#{t(:ap_number, :n => 2)}, #{t(:ap_girl)}"], SpeakCapture.lines
  end

  test "says the appearance asked for where the engine keeps no readable record" do
    meta = $PokemonGlobal.singleton_class
    meta.send(:alias_method, :pa_readable_player_id, :playerID)
    meta.send(:define_method, :playerID) { raise NoMethodError, "playerID" }
    with_player_id(0) { pbChangePlayer(4) }
    assert_equal [t(:ap_number, :n => 5)], SpeakCapture.lines
  ensure
    meta.send(:alias_method, :playerID, :pa_readable_player_id)
    meta.send(:remove_method, :pa_readable_player_id)
  end

  test "reads the appearance in use from the player where the engine keeps it there, else from the save" do
    with_player_id(2) do
      assert_equal 3, with_trainer(Struct.new(:character_ID).new(3)) { PokeAccess::Appearance.current_id }, "v19 on"
      assert_equal 2, PokeAccess::Appearance.current_id, "gen 6"
    end
  end

  private

  # The mod's line for key in the running language.
  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # Runs the block with the gen-6 save's appearance record at id, put back afterwards.
  def with_player_id(id)
    was = $PokemonGlobal.instance_variable_get(:@playerID)
    $PokemonGlobal.playerID = id
    yield
  ensure
    $PokemonGlobal.instance_variable_set(:@playerID, was)
  end

  # Runs the block with trainer as the player, answering the block's value.
  def with_trainer(trainer)
    was = $Trainer
    $Trainer = trainer
    yield
  ensure
    $Trainer = was
  end

  # Runs the block with the gen-6 metadata giving every appearance a trainer type of the given gender.
  def with_trainer_types(gender)
    Object.const_set(:MetadataPlayerA, 8)
    GameFunctions.with(:pbGetMetadata => lambda { |map, field| map == 0 && field == 9 ? [:POKEMONTRAINER_B] : nil },
                       :pbGetTrainerTypeGender => lambda { |type| type == :POKEMONTRAINER_B ? gender : nil }) { yield }
  ensure
    Object.send(:remove_const, :MetadataPlayerA)
  end

  # Runs the block on a GameData engine, keeping the appearances in metadata as GameData::PlayerMetadata where given.
  def with_game_data(metadata)
    Object.const_set(:GameData, Module.new)
    GameData.const_set(:PlayerMetadata, metadata) if metadata
    yield
  ensure
    Object.send(:remove_const, :GameData)
  end
end
