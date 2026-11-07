
# Script-only conversations must participate in the same transfer/person rules
# as ordinary Show Text. Visibility is explicit; the pixel scanner is unchanged.
module ScriptedNpcTargetCases
  def self.define(base)
    base.class_eval do
      def setup
        super
        @next_event_id = 80
      end

      def locator; PokeAccess::Locator; end

      def event(commands, sprite = 'NPC_Guide', trigger = 2, inactive = nil)
        @next_event_id += 1
        page = TestPage.new(:trigger => trigger, :sprite => sprite, :list => commands)
        pages = [page]
        pages.push(inactive) if inactive
        TestGameEvent.new(:id => @next_event_id, :name => 'Guide', :pages => pages, :active_page => page)
      end

      def with_visibility(visible = true)
        original = locator.method(:sprite_seen?)
        locator.define_singleton_method(:sprite_seen?) { |_event| visible }
        yield
      ensure
        locator.define_singleton_method(:sprite_seen?, original) if original
      end

      def transfer; TestCmd.new(201, [0, 28, 21, 7, 0, 0]); end

      def with_destination_name
        previous = PokeAccess::MapNames.get(28)
        PokeAccess::MapNames.set(28, 'Harbor')
        yield
      ensure
        previous ? PokeAccess::MapNames.set(28, previous) : PokeAccess::MapNames.delete(28)
      end

      def assert_person(ev)
        with_visibility do
          assert_equal true, locator.live_talks?(ev), 'actual live-page dialogue'
          assert_equal false, locator.transfer_event?(ev), 'a speaking character is not a doorway'
          assert_equal true, locator.in_category?(ev, :people)
          assert_equal false, locator.in_category?(ev, :exits)
        end
      end

      def test_scripted_trainer_with_defeat_only_transfer_is_a_person
        commands = [TestCmd.new(355, ['Kernel.pbNoticePlayer(get_character(0))']),
          TestCmd.new(355, ['fbText("Let us battle!")']),
          TestCmd.new(111, [12, 'pbTrainerBattle(:CAMPER, "Cam", "Well done", false, 0, true)']),
          TestCmd.new(123, ['A', 0], 1), TestCmd.new(411),
          TestCmd.new(201, [0, 28, 21, 7, 0, 0], 1), TestCmd.new(412)]
        assert_person(event(commands, 'allenatore-campeggiatore'))
      end

      def test_scripted_message_transporter_is_a_person
        assert_person(event([TestCmd.new(355, ['Kernel.pbMessage("All aboard!")']), transfer]))
      end

      def test_fullbox_transporter_uses_its_script_only_dialogue
        assert_person(event([TestCmd.new(355, ['fbText("Follow me.")']), transfer]))
      end

      def test_script_continuations_and_battle_conditions_are_dialogue
        calls = [[TestCmd.new(355, ['fbText(']), TestCmd.new(655, ['"Follow me.")'])],
                 [TestCmd.new(111, [12, 'pbTrainerBattle(:CAMPER)']), TestCmd.new(412)]]
        calls.each { |commands| assert_person(event(commands + [transfer])) }
      end

      def test_plain_text_travel_npc_stays_a_person
        assert_person(event([TestCmd.new(101, ['Follow me.']), transfer]))
      end

      def test_doors_warps_and_sprite_less_tiles_keep_their_exit_category
        ['', 'door_001'].each do |sprite|
          ev = event([TestCmd.new(355, ['pbMessage("Entering.")']), transfer], sprite, 1)
          with_visibility do
            assert_equal true, locator.transfer_event?(ev)
            assert_equal true, locator.in_category?(ev, :exits)
            assert_equal false, locator.in_category?(ev, :people)
          end
        end
      end

      def test_silent_and_invisible_touch_portals_stay_exits
        ev = event([transfer], 'Lightbeam')
        with_visibility do
          assert_equal false, locator.live_talks?(ev)
          assert_equal true, locator.transfer_event?(ev)
        end
        hidden = event([TestCmd.new(355, ['fbText("Entering.")']), transfer])
        with_visibility(false) { assert_equal true, locator.transfer_event?(hidden) }
      end

      def test_inactive_scripted_text_does_not_turn_an_active_portal_into_a_person
        inactive = TestPage.new(:trigger => 2, :sprite => 'NPC_Guide',
          :list => [TestCmd.new(355, ['fbText("Not on the active page.")'])])
        ev = event([transfer], 'Lightbeam', 2, inactive)
        with_visibility do
          assert_equal false, locator.live_talks?(ev)
          assert_equal true, locator.transfer_event?(ev)
        end
      end

      def test_item_balls_remain_objects_and_a_speaking_giver_remains_a_person
        pickup = [TestCmd.new(355, ['pbItemBall(:POTION)'])]
        ball = event(pickup, 'item_ball', 0)
        giver = event([TestCmd.new(355, ['fbText("Take this gift.")'])] + pickup, 'NPC_Guide', 0)
        assert_equal true, locator.item_ball?(ball)
        assert_equal :objects, locator.event_category(ball)
        assert_equal false, locator.item_ball?(giver)
        assert_equal :people, locator.event_category(giver)
      end

      def test_scripted_battles_do_not_advertise_their_recovery_transfer_as_transport
        battles = [[TestCmd.new(111, [12, 'pbTrainerBattle(:CAMPER)'])],
          [TestCmd.new(355, ['TrainerBattle.start(:CAMPER)'])],
          [TestCmd.new(355, ['WildBattle.start(']), TestCmd.new(655, [':WEEDLE, 2)'])]]
        with_destination_name do
          with_visibility do
            battles.each do |battle|
              ev = event([TestCmd.new(355, ['fbText("Let us battle!")'])] + battle + [transfer])
              assert_equal locator.event_name(ev), locator.target_name(ev), 'a battle recovery warp is not offered transport'
            end
          end
        end
      end

      def test_scripted_travel_npc_keeps_its_real_destination_hint
        ev = event([TestCmd.new(355, ['pbMessage("All aboard!")']), transfer])
        with_destination_name do
          with_visibility do
            expected = locator.event_name(ev) + ', ' + PokeAccess::I18n.t(:loc_takes_to, :map => 'Harbor')
            assert_equal expected, locator.target_name(ev)
          end
        end
      end

      def test_inactive_battle_page_does_not_suppress_an_active_travel_service
        inactive = TestPage.new(:trigger => 2, :sprite => 'NPC_Guide',
          :list => [TestCmd.new(111, [12, 'pbTrainerBattle(:CAMPER)'])])
        ev = event([TestCmd.new(355, ['pbMessage("All aboard!")']), transfer], 'NPC_Guide', 2, inactive)
        with_destination_name do
          with_visibility do
            expected = locator.event_name(ev) + ', ' + PokeAccess::I18n.t(:loc_takes_to, :map => 'Harbor')
            assert_equal expected, locator.target_name(ev)
          end
        end
      end
    end
  end
end
