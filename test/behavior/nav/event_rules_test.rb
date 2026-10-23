# The locator's rules from profiles and plugins (DSL event_name, event_category, event_hidden, name_mark): names, the
# newest rule first and the player's label above all; forced categories; events hidden from list and sonar; name marks.
class EventRulesTest < PokeAccessTest
  Loc = PokeAccess::Locator

  test "names an event by the newest rule that gives a name, past those that give none" do
    with_event_rules do
      PokeAccess::Game.define do
        event_name { |ev| ev.name == "estatua_rara" ? "estatua antigua" : nil }
        event_name { |ev| ev.id == 4 ? "estatua de piedra" : nil }
        event_name { |_ev| nil }
      end
      assert_equal "estatua de piedra", Loc.target_name(statue)
    end
  end

  test "passes over a name rule that fails to the one before it" do
    with_event_rules do
      PokeAccess::Game.define do
        event_name { |_ev| "estatua antigua" }
        event_name { |_ev| raise "broken" }
      end
      assert_equal "estatua antigua", Loc.target_name(statue)
    end
  end

  test "lets the player's label beat every rule" do
    with_event_rules do
      ev = statue
      PokeAccess::Game.define { event_name { |_ev| "estatua de piedra" } }
      tagged(ev) do
        PokeAccess::Tags.set($game_map.map_id, ev.id, "mi estatua")
        assert_equal "mi estatua", Loc.target_name(ev)
      end
    end
  end

  test "files an event under the category a rule forces, out of its own" do
    with_event_rules do
      paco = person
      PokeAccess::Game.define { event_category(:objects) { |ev| ev.name == "Paco" } }
      assert_equal [:objects, true, false],
                   [Loc.event_category(paco), Loc.in_category?(paco, :objects), Loc.in_category?(paco, :people)]
    end
  end

  test "takes the category of the newest rule that accepts the event" do
    with_event_rules do
      rock = World.event(:id => 7, :x => 2, :y => 2, :name => "roca", :sprite => "objeto_roca")
      PokeAccess::Game.define do
        event_category(:objects) { |_ev| true }
        event_category(:people) { |ev| ev.name == "roca" }
        event_category(:objects) { |ev| ev.name == "otra" }
      end
      assert_equal :people, Loc.event_category(rock)
    end
  end

  test "forces no category by a rule that fails" do
    with_event_rules do
      paco = person
      PokeAccess::Game.define { event_category(:objects) { |_ev| raise "broken" } }
      assert_equal :people, Loc.event_category(paco)
    end
  end

  test "lets the player's category beat a rule's" do
    with_event_rules do
      paco = person
      PokeAccess::Game.define { event_category(:objects) { |ev| ev.name == "Paco" } }
      tagged(paco) do
        PokeAccess::Tags.set_category($game_map.map_id, paco.id, :people)
        assert_equal [true, false], [Loc.in_category?(paco, :people), Loc.in_category?(paco, :objects)]
      end
    end
  end

  test "leaves an event a rule hides out of the list" do
    with_event_rules do
      paco = person
      shadow = talker(6, 4, 1, "sombra", "NPC 02")
      PokeAccess::Game.define { event_hidden { |ev| ev.name == "sombra" } }
      assert_equal [[paco], true], [all_listed, Loc.hidden?(shadow)]
    end
  end

  test "silences an event a rule hides on the sonar" do
    with_event_rules do
      paco = person
      shadow = talker(6, 4, 1, "sombra", "NPC 02")
      PokeAccess::Game.define { event_hidden { |ev| ev.name == "sombra" } }
      assert_equal [nil, :npc], [PokeAccess::Sound::Scene.family_of(shadow), PokeAccess::Sound::Scene.family_of(paco)]
    end
  end

  test "hides nothing by a hidden rule that fails" do
    with_event_rules do
      paco = person
      PokeAccess::Game.define { event_hidden { |_ev| raise "broken" } }
      assert_equal false, Loc.hidden?(paco)
    end
  end

  test "gives the marks of the rules in the order registered, none twice, skipping those that give none or fail" do
    with_event_rules do
      paco = person
      PokeAccess::Game.define do
        name_mark { |ev| ev.id == 5 ? "con misión" : nil }
        name_mark { |_ev| nil }
        name_mark { |ev| ev.id == 5 ? "con misión" : nil }
        name_mark { |_ev| raise "broken" }
        name_mark { |ev| ev.id == 5 ? "brilla" : nil }
      end
      assert_equal ["con misión", "brilla"], Loc.name_marks(paco)
    end
  end

  test "says the marks right after the name in the target's line" do
    with_event_rules do
      paco = person
      PokeAccess::Game.define do
        name_mark { |_ev| "con misión" }
        name_mark { |_ev| "brilla" }
      end
      all_listed
      Loc.instance_variable_set(:@target, paco)
      Loc.announce_selected(true)
      assert_spoken(/\APaco, con misión, brilla, /)
    end
  end

  private

  # Runs the block with the rules registered in it taken back after.
  def with_event_rules
    rules = Loc.instance_variable_get(:@rules)
    kept = {}
    rules.each { |k, v| kept[k] = v.dup }
    yield
  ensure
    kept.each { |k, v| rules[k] = v }
  end

  # Runs the block, then drops what the player tagged on ev.
  def tagged(ev)
    yield
  ensure
    PokeAccess::Tags.delete($game_map.map_id, ev.id)
  end

  # A statue, event 4, the editor named estatua_rara.
  def statue
    World.event(:id => 4, :x => 3, :y => 1, :name => "estatua_rara")
  end

  # Paco, a person who talks, event 5.
  def person
    talker(5, 3, 1, "Paco", "NPC 01")
  end

  # A person who talks, event id on (x, y), with that name and sprite.
  def talker(id, x, y, name, sprite)
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => [TestCmd.new(101, ["Hola."])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # The locator's list of every target on the map, built afresh.
  def all_listed
    Loc.clear_targets
    Loc.instance_variable_set(:@cat_id, :all)
    Loc.rebuild_targets
    Loc.instance_variable_get(:@targets)
  end
end
