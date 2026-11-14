require_relative '../xenoverse_standalone'
load File.join(Harness::ROOT, 'games/xenoverse/naming.rb')

class XenoverseNamingTest < PokeAccessTest
  include PeaStandaloneMethods
  Loc = PokeAccess::Locator
  Naming = PokeAccess::XenoverseNaming

  def setup
    super
    PokeAccess::Config.language = :en
  end

  def event(scripts, sprite = 'Ezio', name = 'EV005')
    page = TestPage.new(:sprite => sprite, :list => scripts.map { |s| TestCmd.new(355, [s]) })
    TestGameEvent.new(:id => 5, :name => name, :pages => [page])
  end

  def with_translation(body = lambda { |_map, name| name })
    with_singleton(MessageTypes, :getFromMapHash, body) { yield }
  end

  def test_map_uses_game_language_and_observes_language_changes_without_a_stale_cache
    language = 'Stardust Beach'
    GameFunctions.with(:pbGetMapNameFromId => lambda { |id| id == 40 ? language : '' }) do
      assert_equal 'Stardust Beach', Loc.map_name(40)
      language = 'Spiaggia Polvostella'
      assert_equal language, Loc.map_name(40)
      assert_nil Loc.map_name(39) # This fixture has no MapInfos entry for 39.
    end
  end

  def test_user_map_name_wins_without_calling_game_lookup
    GameFunctions.with(:pbGetMapNameFromId => lambda { |_id| raise 'Must not be called' }) do
      with_singleton(PokeAccess::MapNames, :get, lambda { |_id| 'My beach' }) do
        assert_equal 'My beach', Loc.map_name(40)
      end
    end
  end

  def test_map_missing_blank_invalid_and_failed_api_keep_existing_fallback
    [nil, '', '  '].each do |value|
      GameFunctions.with(:pbGetMapNameFromId => lambda { |_id| value }) do
        assert_equal 'Mapa 40', Loc.map_name(40)
      end
    end
    GameFunctions.with(:pbGetMapNameFromId => lambda { |_id| raise 'Unavailable translation' }) do
      assert_equal 'Mapa 40', Loc.map_name(40)
    end
    GameFunctions.with(:pbGetMapNameFromId => lambda { |_id| 123 }) do
      assert_nil Naming.map_name(Loc, 40)
    end
    unavailable = Object.new
    with_singleton(unavailable, :respond_to?, lambda { |*_args| false }) do
      assert_nil Naming.map_name(unavailable, 40)
    end
  end

  def test_matching_active_portrait_names_its_own_actor_and_uses_map_translation
    actor = event(['fbNewMugshot("Aster","ludopoli/ezio","default",:left)'])
    calls = []
    with_translation(lambda { |map, name| calls << [map, name]; 'Professor Aster' }) do
      assert_equal 'Professor Aster', Loc.target_name(actor)
      assert_equal [[$game_map.map_id, 'Aster']], calls
    end
    assert_equal 'Ezio', actor.character_name
  end

  def test_user_event_tag_and_meaningful_editor_name_win
    with_translation do
      actor = event(['fbNewMugshot("Aster","ludopoli/ezio","default",:left)'])
      with_singleton(PokeAccess::Tags, :get, lambda { |_map, _id| 'My professor' }) do
        assert_equal 'My professor', Loc.target_name(actor)
      end
      assert_nil Naming.event_name(event(['fbNewMugshot("Aster","ludopoli/ezio","default",:left)'], 'Ezio', 'Guide'))
    end
  end

  def test_other_actors_invisible_triggers_and_future_pages_do_not_supply_a_name
    with_translation do
      assert_nil Naming.event_name(event(['fbNewMugshot("Aster","ludopoli/ezio","default",:left)'], 'Other'))
      assert_nil Naming.event_name(event(['fbNewMugshot("Aster","ludopoli/ezio","default",:left)'], ''))
      future = TestPage.new(:sprite => 'Ezio', :list => [TestCmd.new(355, ['fbNewMugshot("Aster","ludopoli/ezio","default",:left)'])])
      current = TestPage.new(:sprite => 'Ezio', :list => [TestCmd.new(355, ['fbText("Hello")'])])
      actor = TestGameEvent.new(:id => 5, :pages => [current, future], :active_page => current)
      assert_nil Naming.event_name(actor)
    end
  end

  def test_ambiguous_dynamic_escaped_and_unknown_names_keep_original_fallback
    with_translation do
      scripts = ['fbNewMugshot("Aster","ludopoli/ezio","default",:left)',
                 'fbNewMugshot("Other","ludopoli/ezio","default",:left)']
      assert_nil Naming.event_name(event(scripts))
      ['fbNewMugshot($secret,"ludopoli/ezio","default",:left)',
       'fbNewMugshot("#{raise :never}","ludopoli/ezio","default",:left)',
       'fbNewMugshot("A\\ster","ludopoli/ezio","default",:left)',
       'fbNewMugshot("???","ludopoli/ezio","default",:left)',
       'fbText("Aster")'].each { |script| assert_nil Naming.event_name(event([script])) }
    end
  end

  def test_missing_blank_and_failed_translation_keep_sprite_name
    actor = event(['fbNewMugshot("Aster","ludopoli/ezio","default",:left)'])
    assert_nil Naming.event_name(actor)
    [nil, '', '  ', 123].each do |name|
      with_translation(lambda { |_map, _text| name }) { assert_nil Naming.event_name(actor) }
    end
    with_translation(lambda { |_map, _text| raise 'Unavailable translation' }) do
      assert_equal 'Ezio', Loc.target_name(actor)
    end
  end

  def test_existing_trainer_item_and_puzzle_names_are_preserved
    actor = event(['fbNewMugshot("Aster","ludopoli/ezio","default",:left)'])
    with_translation do
      ['Potion', 'Youngster Luke', 'Door', 'Puzzle piece'].each do |meaningful|
        with_singleton(Loc, :event_name, lambda { |_event| meaningful }) do
          assert_nil Naming.event_name(actor)
        end
      end
    end
  end

  def test_unrelated_events_do_not_repeat_core_name_resolution
    calls = 0
    with_singleton(Loc, :event_name, lambda { |_event| calls += 1; 'Ezio' }) do
      assert_nil Naming.event_name(event(['fbText("Hello")']))
      assert_nil Naming.event_name(event(['fbNewMugshot("Other","other","default",:left)']))
    end
    assert_equal 0, calls
  end

  def test_single_quoted_paths_case_and_repeated_same_speaker_are_supported
    script = "fbNewMugshot('Aster','ludopoli/EZIO.png','default',:left)"
    with_translation do
      assert_equal 'Aster', Naming.event_name(event([script, script]))
    end
  end

  def test_leader_portrait_alias_reads_the_game_translation_on_each_active_page
    ['default', 'addormentato'].each do |expression|
      script = "fbNewMugshot(\"Alisso\",\"ludopoli/danilo\",\"#{expression}\",:left)"
      actor = event([script], 'Capopalestra1', 'NoShadow')
      with_translation(lambda { |_map, name| name == 'Alisso' ? 'Basil' : name }) do
        assert_equal 'Basil', Loc.target_name(actor)
        assert_equal 'Capopalestra1', actor.character_name
      end
    end
    actor = event(["fbNewMugshot('Alisso','LUDOPOLI/DANILO.PNG','default',:left)"], 'CAPOPALESTRA1')
    with_translation { assert_equal 'Alisso', Loc.target_name(actor) }
  end

  def test_leader_alias_preserves_other_actors_tags_and_meaningful_names
    script = 'fbNewMugshot("Alisso","ludopoli/danilo","default",:left)'
    with_translation do
      assert_nil Naming.event_name(event([script], 'Capopalestra2'))
      assert_nil Naming.event_name(event([script.sub('ludopoli/danilo', 'other/danilo')], 'Capopalestra1'))
      assert_nil Naming.event_name(event([script], 'Capopalestra1', 'My gardener'))
      actor = event([script], 'Capopalestra1')
      with_singleton(PokeAccess::Tags, :get, lambda { |_map, _id| 'My leader' }) do
        assert_equal 'My leader', Loc.target_name(actor)
      end
      assert_nil Naming.event_name(event([script, script.sub('Alisso', 'Other')], 'Capopalestra1'))
    end
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
