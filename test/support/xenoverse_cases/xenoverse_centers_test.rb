require_relative '../xenoverse_standalone'
load File.join(Harness::ROOT, 'games/xenoverse/naming.rb')

class XenoverseCentersTest < PokeAccessTest
  include PeaStandaloneMethods
  Naming = PokeAccess::XenoverseNaming
  MapData = Struct.new(:events)

  def setup
    super
    Naming.forget_centers
    PokeAccess::Config.language = :en
  end

  def nurse(opts = {})
    list = opts.fetch(:list, [TestCmd.new(355, ['Kernel.pbSetPokemonCenter']), TestCmd.new(314, [0])])
    page = TestPage.new({:sprite => 'Infermiera', :list => list}.merge(opts))
    TestRpgEvent.new([page])
  end

  def api_for(map, outdoor = false, &loader)
    api = Object.new
    api.define_singleton_method(:outdoor?) { |_id| outdoor }
    api.define_singleton_method(:pbLoadRxData, loader || lambda { |_path| map })
    api
  end

  def test_actual_shape_identifies_a_nurse_without_running_its_script
    actor = nurse(:list => [TestCmd.new(355, ['Kernel.pbSetPokemonCenter']),
      TestCmd.new(355, ['raise "Must not execute"']), TestCmd.new(314, [0], 2)])
    map = MapData.new({1 => actor})
    assert Naming.pokecenter?(api_for(map), 14)
    assert Naming.center_nurse?(actor)
  end

  def test_bare_and_empty_parentheses_markers_and_graphic_path_are_supported
    ['pbSetPokemonCenter', ' Kernel.pbSetPokemonCenter( ) '].each do |script|
      actor = nurse(:sprite => 'Characters/INFERMIERA.png',
        :list => [TestCmd.new(355, [script]), TestCmd.new(314, [0])])
      assert Naming.center_nurse?(actor)
    end
  end

  def test_homes_other_healers_empty_and_unrecognized_graphics_are_not_centers
    ['', 'Mamma', 'porygon', 'guardiaofiuchia', 'infermieracreepy', 'Other'].each do |sprite|
      refute Naming.center_nurse?(nurse(:sprite => sprite)), sprite
    end
  end

  def test_respawn_only_and_single_pokemon_recovery_are_not_centers
    refute Naming.center_nurse?(nurse(:list => [TestCmd.new(355, ['Kernel.pbSetPokemonCenter'])]))
    refute Naming.center_nurse?(nurse(:list => [TestCmd.new(355, ['Kernel.pbSetPokemonCenter']), TestCmd.new(314, [1])]))
  end

  def test_cutscene_touch_parallel_and_conditional_nurses_are_not_centers
    [1, 2, 3, 4].each { |trigger| refute Naming.center_nurse?(nurse(:trigger => trigger)) }
    [:switch1_valid, :switch2_valid, :variable_valid, :self_switch_valid].each do |key|
      refute Naming.center_nurse?(nurse(:condition => {key => true}))
    end
    actor = nurse
    actor.pages << TestPage.new
    refute Naming.center_nurse?(actor)
  end

  def test_newer_actor_and_item_conditions_are_not_ignored
    [:actor_valid, :item_valid].each do |key|
      actor = nurse
      actor.pages[0].condition.define_singleton_method(key) { true }
      refute Naming.center_nurse?(actor)
    end
  end

  def test_markers_are_exact_statements_never_comments_strings_or_specific_respawn_calls
    ['# Kernel.pbSetPokemonCenter', '"Kernel.pbSetPokemonCenter"',
     'Kernel.pbSetPokemonCenterSpecific(14,12,11,2)', 'Kernel.pbSetPokemonCenter; other',
     'if ready; Kernel.pbSetPokemonCenter; end', 'Kernel.pbSetPokemonCenter($map)'].each do |script|
      refute Naming.center_nurse?(nurse(:list => [TestCmd.new(355, [script]), TestCmd.new(314, [0])])), script
    end
    refute Naming.center_nurse?(nurse(:list => [TestCmd.new(355, ['Kernel.pbSetPokemonCenter'], 1), TestCmd.new(314, [0])]))
    refute Naming.center_nurse?(nurse(:list => [TestCmd.new(355, ['Kernel.pbSetPokemonCenter']),
      TestCmd.new(655, ['Specific(1,2,3,4)']), TestCmd.new(314, [0])]))
  end

  def test_map_loading_is_strict_and_skips_outdoors_unknown_metadata_and_invalid_ids
    calls = []
    map = MapData.new({1 => nurse})
    [true, nil].each do |outdoor|
      refute Naming.pokecenter?(api_for(map, outdoor) { |path| calls << path; map }, 14)
    end
    api = api_for(map) { |path| calls << path; map }
    [nil, 0, -1, '14', 1.5].each { |id| refute Naming.pokecenter?(api, id) }
    assert_empty calls
    assert Naming.pokecenter?(api, 14)
    assert_equal ['Data/Map014'], calls
  end

  def test_successful_positive_and_negative_file_reads_are_cached_until_reset
    calls = 0
    map = MapData.new({1 => nurse})
    api = api_for(map) { |_path| calls += 1; map }
    2.times { assert Naming.pokecenter?(api, 14) }
    assert_equal 1, calls
    map.events.clear
    assert Naming.pokecenter?(api, 14)
    Naming.forget_centers
    2.times { refute Naming.pokecenter?(api, 14) }
    assert_equal 2, calls
    map.events[1] = nurse
    PokeAccess::Caches.reset_all
    assert Naming.pokecenter?(api, 14)
    assert_equal 3, calls
  end

  def test_negative_cache_survives_a_game_redefining_hash_has_key
    map = MapData.new({})
    cache = {14 => false}
    # Luka utilities in some games treat a stored false as an absent key.
    def cache.has_key?(key); !!self[key]; end
    Naming.instance_variable_set(:@centers, cache)
    calls = 0
    api = api_for(map) { |_path| calls += 1; map }
    2.times { refute Naming.pokecenter?(api, 14) }
    assert_equal 0, calls, 'A cached non-center must not reload its map'
  ensure
    Naming.forget_centers
  end

  def test_missing_loader_bad_maps_and_transient_failure_keep_original_fallback
    refute Naming.pokecenter?(api_for(nil), 14)
    refute Naming.pokecenter?(api_for(MapData.new([])), 14)
    api = Object.new
    api.define_singleton_method(:outdoor?) { |_id| false }
    refute Naming.pokecenter?(api, 14)
    calls = 0
    recovered_map = MapData.new({1 => nurse})
    api = api_for(nil) { |_path| calls += 1; raise 'Unavailable' if calls == 1; recovered_map }
    refute Naming.pokecenter?(api, 14)
    assert Naming.pokecenter?(api, 14)
    assert_equal 2, calls
  end

  def test_malformed_event_data_never_raises
    [nil, Object.new, TestRpgEvent.new(nil), TestRpgEvent.new([]), TestRpgEvent.new([nil])].each do |event|
      refute Naming.center_nurse?(event)
    end
    actor = nurse
    actor.pages[0].condition = nil
    refute Naming.center_nurse?(actor)
  end

  def test_profile_keeps_existing_metadata_and_does_not_read_files_for_it
    with_singleton(PokeAccess::MapMeta, :field, lambda { |*_args| [14,12,11] }) do
      GameFunctions.with(:pbLoadRxData => lambda { |_path| raise 'Must not read' }) do
        assert PokeAccess::MapMeta.pokecenter?(14)
      end
    end
  end

  def test_profile_names_the_entrance_in_both_languages_and_preserves_user_tags
    map = MapData.new({1 => nurse})
    door = TestGameEvent.new(:id => 1, :name => 'EV001',
      :pages => [TestPage.new(:trigger => 1, :list => [TestCmd.new(201, [0,14,12,15,0,0])])])
    field = lambda { |id, modern, *_rest| modern == :outdoor_map ? id != 14 : nil }
    with_singleton(PokeAccess::MapMeta, :field, field) do
      GameFunctions.with(:pbLoadRxData => lambda { |_path| map }, :pbGetMapNameFromId => lambda { |_id| 'Hadwarf City' }) do
        [:en, :pl].each do |language|
          PokeAccess::Config.language = language
          assert_equal PokeAccess::I18n.t(:loc_pokecenter), PokeAccess::Locator.target_name(door)
        end
        with_singleton(PokeAccess::Tags, :get, lambda { |_map_id, _event_id| 'My clinic' }) do
          assert_equal 'My clinic', PokeAccess::Locator.target_name(door)
        end
      end
    end
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
