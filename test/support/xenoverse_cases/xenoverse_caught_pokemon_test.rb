require_relative '../xenoverse_standalone'

# The actual source runs both loops from initialize, paints the entry out of
# order and removes the nickname command in place before returning index to 0.
class DexObtained
  Rect = Struct.new(:height)
  Color = Struct.new(:alpha)
  Viewport = Struct.new(:rect, :color)
  Pokemon = Struct.new(:type1, :type2)
  attr_accessor :rows, :index, :commands
  def initialize
    @viewport2 = Viewport.new(Rect.new(0), Color.new(0))
    @viewport = Viewport.new(Rect.new(384), Color.new(0))
    @pkmn = Pokemon.new(1, 2)
    @commands, @index = ['pc', 'party', 'nick', 'info'], 0
    @rows = [
      ['It eats its weight in leaves every day.', 260, 220, 0, nil],
      ['It fends off attackers with the needle', 260, 240, 0, nil],
      ['on its head.', 260, 260, 0, nil],
      ['Hairy Bug Pokémon', 265, 79, 0, nil],
      ['0.3 m', 339, 141, 0, nil], ['3.2 kg', 339, 166, 0, nil],
      ['Weedle', 303, 28, 0, nil], ['011', 268, 28, true, nil]]
  end
  def addPokemonInfo
    pbDrawTextPositions(Object.new, @rows)
    :original_paint
  end
  def inloop; yield(self) if block_given?; :original_entry; end
  def whatToDo; yield(self) if block_given?; :original_menu; end
  def update; :original_update; end
  def message; yield(self) if block_given?; :original_message; end
  def endscene; yield(self) if block_given?; :original_close; end
  def reveal(height = 384); @viewport2.rect.height = height; end
  def fade(alpha); @viewport.color.alpha = alpha; end
  def monotype; @pkmn.type2 = @pkmn.type1; end
end
load File.join(Harness::ROOT, 'games/xenoverse/caught_pokemon.rb')

class XenoverseCaughtPokemonTest < PokeAccessTest
  include PeaStandaloneMethods
  def setup
    super
    PokeAccess::Config.language = :en
    @reader, @scene = PokeAccess::XenoverseCaughtPokemon, DexObtained.new
  end
  def with_types(&block)
    with_singleton(PokeAccess::Data, :type_name, lambda { |id| {1 => 'Bug', 2 => 'Poison'}[id] }, &block)
  end

  def test_actual_entry_paint_is_ordered_and_kept_for_the_info_key
    assert_equal :original_paint, @scene.addPokemonInfo
    with_types do
      assert_equal :original_entry, @scene.inloop { |scene|
        scene.update
        assert_nothing_spoken
        scene.reveal
        scene.update; scene.update
        assert_equal 1, SpeakCapture.lines.length
        line = SpeakCapture.lines.first
        expected = ['011 Weedle', 'Hairy Bug Pokémon', 'Type: Bug, Poison', 'Height: 0.3 m',
          'Weight: 3.2 kg', 'It eats its weight in leaves every day.',
          'It fends off attackers with the needle on its head.']
        positions = expected.map { |text| assert_includes line, text; line.index(text) }
        assert_equal positions.sort, positions
        assert_equal line, PokeAccess::Info.info_text
        assert_equal [false], SpeakCapture.log.map { |row| row[1] }
      }
    end
    assert_nil PokeAccess::Info.info_text
  end

  def test_form_text_units_and_single_type_come_from_the_actual_paint
    @scene.rows = [['Actual form species',303,28],['???',268,28],['Actual form kind',265,79],
      ["1'00\"",339,141],['7.1 lbs.',339,166],['Actual form description.',260,220]]
    @scene.monotype
    @scene.addPokemonInfo; @scene.reveal
    with_types { @scene.inloop { |scene| scene.update } }
    line = SpeakCapture.lines.first
    ['??? Actual form species', 'Actual form kind', "Height: 1'00\"", 'Weight: 7.1 lbs.',
     'Actual form description.'].each { |text| assert_includes line, text }
    assert_equal 1, line.scan('Bug').length
    refute_includes line, 'Poison'
  end

  def test_missing_paint_and_unrelated_instances_remain_silent
    @scene.reveal
    with_types { @scene.inloop { |scene| scene.update; DexObtained.new.update } }
    assert_nothing_spoken
    @scene.addPokemonInfo; @scene.update
    assert_nothing_spoken
  end

  def test_actual_choices_open_change_wrap_and_reopen_with_correct_info
    2.times do
      SpeakCapture.clear
      @scene.index = 0
      assert_equal :original_menu, @scene.whatToDo { |scene|
        scene.update; scene.update
        [1, 3, 0, 2].each { |index| scene.index = index; scene.update }
        assert_equal [_INTL('Send to PC'), _INTL('Add to Party'), _INTL('Info'),
          _INTL('Send to PC'), _INTL('Nickname')], SpeakCapture.lines
        assert_equal _INTL('Nickname'), PokeAccess::Info.info_text
        assert_equal [false, true, true, true, true], SpeakCapture.log.map { |row| row[1] }
      }
      assert_nil PokeAccess::Info.info_text
    end
  end

  def test_safari_command_subset_uses_its_actual_indices
    @scene.commands = ['pc', 'nick', 'info']
    @scene.whatToDo do |scene|
      [0, 1, 2].each { |index| scene.index = index; scene.update }
    end
    assert_equal [_INTL('Send to PC'), _INTL('Nickname'), _INTL('Info')], SpeakCapture.lines
  end

  def test_message_child_suppresses_parent_and_reannounces_only_on_return
    @scene.whatToDo do |scene|
      scene.update
      SpeakCapture.clear
      assert_equal :original_message, scene.message { |parent|
        parent.update
        assert_nothing_spoken
        assert_nil PokeAccess::Info.info_text
      }
      scene.update
      assert_equal [_INTL('Send to PC')], SpeakCapture.lines
    end
  end

  def test_nickname_removal_waits_for_real_reindex_and_fade
    @scene.whatToDo do |scene|
      scene.index = 2; scene.update
      SpeakCapture.clear
      scene.commands.delete('nick')
      scene.fade(128); scene.update
      scene.fade(0); scene.update
      assert_nothing_spoken
      scene.index = 0; scene.update
      assert_equal [_INTL('Send to PC')], SpeakCapture.lines
      scene.index = 2; scene.update
      assert_equal _INTL('Info'), SpeakCapture.lines.last
    end
  end

  def test_child_and_game_failures_release_ownership_and_preserve_result
    @scene.whatToDo do |scene|
      scene.update
      assert_raises(RuntimeError) { @reader.child { raise 'Actual child failure' } }
      SpeakCapture.clear
      scene.update
      assert_equal [_INTL('Send to PC')], SpeakCapture.lines
    end
    assert_raises(RuntimeError) { @scene.inloop { raise 'Actual entry failure' } }
    SpeakCapture.clear
    @scene.update
    assert_nothing_spoken
    PokeAccess::Info.set_info(:text, 'Other screen')
    assert_equal :unrelated_result, @reader.child { :unrelated_result }
    assert_equal 'Other screen', PokeAccess::Info.info_text
  end

  def test_invalid_choices_and_explicit_close_do_not_publish_an_old_row
    @scene.whatToDo do |scene|
      [-1, 99, nil].each { |index| scene.index = index; scene.update }
      scene.commands = ['unknown']; scene.index = 0; scene.update
      assert_nothing_spoken
    end
    @scene.commands = ['pc']
    @scene.whatToDo do |scene|
      scene.update
      assert_equal :original_close, scene.endscene
      assert_nil PokeAccess::Info.info_text
    end
  end

  def test_terminal_close_animation_does_not_reannounce_the_committed_choice
    @scene.index = 1
    @scene.whatToDo do |scene|
      scene.update
      scene.message { |parent| parent.update }
      SpeakCapture.clear
      assert_equal :original_close, scene.endscene { |parent|
        3.times { parent.update }
        assert_nothing_spoken
        assert_nil PokeAccess::Info.info_text
      }
    end
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
