require_relative '../xenoverse_standalone'

class PokemonScreen_Scene
  CommandSprite = Struct.new(:disposed) do
    def disposed?; disposed; end
  end
  # Replace the harness's original body, preserving core's installed question
  # wrapper as the real game does when Access loads after all game scripts.
  def pbShowCommands__pa_orig_PokemonScreen_Scene(help, commands, y = nil, index = 0, pokemon = nil, x = 0)
    return -1 unless pokemon
    @index = 0
    @cmds = {}
    commands.each_with_index { |_command, i| @cmds["cmd#{i}"] = CommandSprite.new(false) }
    updateCmds
    yield self if block_given?
    @index
  end
  def updateCmds; :original_update; end
  def choose(index); @index = index; updateCmds; end
end
load File.join(Harness::ROOT, 'games/xenoverse/party.rb')

class XenoversePartyTest < PokeAccessTest
  def setup
    super
    PokeAccess::Config.language = :en
    @scene = PokemonScreen_Scene.new
    @pokemon = Poke.build
  end

  def test_actual_commands_wrap_revisit_reopen_and_do_not_repeat_while_idle
    commands = ['Actual Summary', 'Actual Item', 'Actual Quit']
    2.times do
      SpeakCapture.clear
      result = @scene.pbShowCommands('', commands, nil, 0, @pokemon) do |scene|
        assert_equal 'Actual Summary', PokeAccess::Info.info_text
        scene.updateCmds
        scene.choose(2)
        scene.choose(0)
        scene.choose(1)
        assert_equal 'Actual Item', PokeAccess::Info.info_text
      end
      assert_equal 1, result
      assert_equal ['Actual Summary', 'Actual Quit', 'Actual Summary', 'Actual Item'], SpeakCapture.lines
      assert_equal [false, true, true, true], SpeakCapture.log.map { |row| row[1] }
      assert_equal :pokemon, PokeAccess::Info.instance_variable_get(:@kind)
    end
  end

  def test_invalid_selection_missing_sprites_and_no_pokemon_stay_silent
    assert_equal(-1, @scene.pbShowCommands('', ['Actual Summary']))
    assert_nothing_spoken
    @scene.pbShowCommands('', ['Actual Summary'], nil, 0, @pokemon) do |scene|
      SpeakCapture.clear
      [-1, 99, nil].each { |index| scene.choose(index) }
      scene.instance_variable_set(:@cmds, {})
      scene.choose(0)
      assert_nothing_spoken
    end
    SpeakCapture.clear
    @scene.updateCmds
    assert_nothing_spoken
  end

  def test_original_error_propagates_and_clears_modal_ownership
    assert_raises(RuntimeError) do
      @scene.pbShowCommands('', ['Actual Summary'], nil, 0, @pokemon) { raise 'Actual game failure' }
    end
    assert_equal :pokemon, PokeAccess::Info.instance_variable_get(:@kind)
    SpeakCapture.clear
    @scene.updateCmds
    assert_nothing_spoken
  end

  def test_changed_label_at_the_same_index_is_read_without_translating_it
    commands = ['Actual localized label']
    @scene.pbShowCommands('', commands, nil, 0, @pokemon) do |scene|
      commands[0] = 'Actual changed label'
      scene.updateCmds
      assert_equal ['Actual localized label', 'Actual changed label'], SpeakCapture.lines
    end
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
