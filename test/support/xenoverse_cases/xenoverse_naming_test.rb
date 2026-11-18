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

  def supply_container(condition = 'Kernel.pbReceiveItem(::PBItems::REVIVE)', opened = false, name = 'EV034')
    closed = TestPage.new(:sprite => 'CloseOpen', :pattern => 1,
      :list => [TestCmd.new(111, [12, condition]), TestCmd.new(123, ['A', 0]), TestCmd.new(0, [])])
    empty = TestPage.new(:sprite => 'CloseOpen', :pattern => 2, :list => [TestCmd.new(0, [])],
      :condition => { :self_switch_valid => true, :self_switch_ch => 'A' })
    actor = TestGameEvent.new(:id => 34, :name => name, :pages => [closed, empty], :active_page => opened ? empty : closed)
    $game_map.events[actor.id] = actor
    Loc.refresh_lever_cache
    actor
  end

  def test_active_unnamed_supply_container_uses_the_games_item_name
    with_singleton(PokeAccess::Data, :item_id, lambda { |id| id == 'REVIVE' ? [232, 'Revive'] : [nil, nil] }) do
      actor = supply_container
      assert_equal :objects, Loc.event_category(actor)
      assert_equal 'Item, Revive, closed', Loc.target_name(actor)
      with_singleton(PokeAccess::Tags, :get, lambda { |_map, _id| 'My supplies' }) do
        assert_equal 'My supplies', Loc.target_name(actor)
      end
    end
  end

  def test_open_named_dynamic_and_disabled_container_labels_do_not_reveal_contents
    with_singleton(PokeAccess::Data, :item_id, lambda { |_| raise 'No item lookup expected' }) do
      assert_equal 'object, open', Loc.target_name(supply_container('Kernel.pbReceiveItem(::PBItems::REVIVE)', true))
      assert_equal 'Supply crate, closed', Loc.target_name(supply_container('Kernel.pbReceiveItem(::PBItems::REVIVE)', false, 'Supply crate'))
      assert_nil Loc.item_name(supply_container('Kernel.pbReceiveItem(getSupply)'))
      with_singleton(PokeAccess::Config, :name_items, lambda { false }) do
        assert_equal 'object, closed', Loc.target_name(supply_container)
      end
    end
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

  def test_verified_proxim_portraits_use_each_events_literal_translated_speaker
    [['Anziano + naso', 'ludopoli/vecchio', 'Niccolò', 'Nicholas'],
     ['scienziato', 'allenatori/professore', 'Rem', 'Rem'],
     ['scienziato', 'allenatori/professore', 'Pippo', 'Pippo']].each do |sprite, portrait, original, translated|
      actor = event(["fbNewMugshot(\"#{original}\",\"#{portrait}\",\"default\",:left)"], sprite)
      calls = []
      with_translation(lambda { |map, name| calls << [map, name]; translated }) do
        assert_equal translated, Loc.target_name(actor)
        assert_equal [[$game_map.map_id, original]], calls
      end
    end
  end

  def test_proxim_aliases_reject_other_portraits_and_ambiguous_speakers_and_keep_user_names
    [['Anziano + naso', 'ludopoli/vecchio'], ['scienziato', 'allenatori/professore']].each do |sprite, portrait|
      script = "fbNewMugshot('Speaker','#{portrait}','default',:left)"
      with_translation do
        assert_nil Naming.event_name(event([script.sub(portrait, 'other/' + portrait.split('/').last)], sprite))
        assert_nil Naming.event_name(event([script], 'Other ' + sprite))
        assert_nil Naming.event_name(event([script, script.sub('Speaker', 'Other')], sprite))
        assert_nil Naming.event_name(event([script], sprite, 'My guide'))
        actor = event([script], sprite)
        with_singleton(PokeAccess::Tags, :get, lambda { |_map, _id| 'My speaker' }) do
          assert_equal 'My speaker', Loc.target_name(actor)
        end
      end
    end
  end

  def torch_event(opts = {})
    page = TestPage.new({:sprite => 'Fiaccola', :list => [TestCmd.new(0, [])]}.merge(opts))
    TestGameEvent.new(:name => 'Fiaccola', :pages => [page])
  end

  def test_stationary_torches_are_objects_in_everything_and_keep_player_category_overrides
    actor = torch_event
    assert_equal :objects, Loc.event_category(actor)
    assert Loc.in_category?(actor, :objects)
    assert Loc.in_category?(actor, :all)
    refute Loc.in_category?(actor, :people)
    with_singleton(Loc, :tag_override, lambda { |_event| :people }) do
      assert Loc.in_category?(actor, :people)
      refute Loc.in_category?(actor, :objects)
    end
  end

  def test_torch_detection_reads_only_the_active_no_op_action_page
    assert Naming.torch?(torch_event(:sprite => 'Characters/FIACCOLA.png',
      :list => [TestCmd.new(108, ['Comment']), TestCmd.new(408, ['Continuation']), TestCmd.new(0, [])]))
    [1, 2, 3, 4].each { |trigger| refute Naming.torch?(torch_event(:trigger => trigger)) }
    [101, 102, 111, 121, 126, 201, 355, 655].each do |code|
      refute Naming.torch?(torch_event(:list => [TestCmd.new(code, ['raise "Must not execute"']), TestCmd.new(0, [])]))
    end
    ['', 'Fiaccola2', 'Other'].each { |sprite| refute Naming.torch?(torch_event(:sprite => sprite)) }
    [nil, []].each { |list| refute Naming.torch?(torch_event(:list => list)) }
    current = TestPage.new(:sprite => 'Fiaccola', :list => [TestCmd.new(101, ['Talking actor'])])
    future = TestPage.new(:sprite => 'Fiaccola', :list => [TestCmd.new(0, [])])
    actor = TestGameEvent.new(:pages => [current, future], :active_page => current)
    refute Naming.torch?(actor)
  end

  def test_torch_name_uses_access_translation_and_preserves_meaningful_names_and_tags
    calls = []
    with_singleton(PokeAccess::I18n, :t, lambda { |key| calls << key; 'Translated torch' }) do
      actor = torch_event
      assert_equal 'Translated torch', Loc.target_name(actor)
      assert_equal [:xenoverse_torch], calls
      actor.name = 'Memorial flame'
      assert_nil Naming.event_name(actor)
      actor.name = 'EV018'
      assert_equal 'Translated torch', Loc.target_name(actor)
      with_singleton(PokeAccess::Tags, :get, lambda { |_map, _id| 'My light' }) do
        assert_equal 'My light', Loc.target_name(actor)
      end
    end
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
