# Anil's Pokemon healer (games/anil/pokemon_healer.rb): the Wobbuffet of Cueva Celeste (map 170, at 14,20), an unnamed
# event drawn by its number that recovers the whole party, is named and listed as a centre's attendant; a numbered
# sprite that heals nobody, or a healer with a name of its own, keeps what it had. Gamedata pass.
class AnilHealerGdTest < PokeAccessTest
  IDS = [66, 67, 68]

  def setup
    super
    @map = $game_map.map_id
    $game_map.map_id = 170
  end

  def teardown
    IDS.each { |id| $game_map.events.delete(id) }
    $game_map.map_id = @map
    PokeAccess::Caches.reset_all
    super
  end

  test "the Wobbuffet that heals in Cueva Celeste is named and listed as the healing attendant" do
    ev = event(66, "EV066", "202", heal_list)
    assert_equal [t(:loc_healing_attendant), :people], [loc.target_name(ev), loc.event_category(ev)]
    assert loc.in_category?(ev, :people), "listed among the people"
  end

  test "a numbered sprite that heals nobody, or a healer with a name of its own, keeps what it had" do
    idle = event(67, "EV067", "202", [TestCmd.new(101, ["¡Wobbuffet!"]), TestCmd.new(0, [])])
    named = event(68, "Wobbuffet", "202", heal_list)
    refute_equal t(:loc_healing_attendant), loc.target_name(idle)
    assert_equal :objects, loc.event_category(idle)
    assert_equal "Wobbuffet", loc.target_name(named)
  end

  private

  def t(*args); PokeAccess::I18n.t(*args); end

  def loc; PokeAccess::Locator; end

  # The Wobbuffet's page as the game draws it: it asks, and on yes plays the jingle, waits and recovers everyone.
  def heal_list
    [TestCmd.new(101, ["¡Este Wobbuffet ha aprendido Enfermería Pokémon!"]),
     TestCmd.new(101, ["¿Quieres curar a tus Pokémon?"]),
     TestCmd.new(102, [["Sí", "No"], 2]),
     TestCmd.new(402, [0, "Sí"]), TestCmd.new(106, [20], 1), TestCmd.new(314, [0], 1), TestCmd.new(0, [], 1),
     TestCmd.new(402, [1, "No"]), TestCmd.new(0, [], 1),
     TestCmd.new(404, []), TestCmd.new(0, [])]
  end

  # An action event at the Wobbuffet's tile with one page of the sprite and commands given.
  def event(id, name, sprite, list)
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
    ev = TestGameEvent.new(:id => id, :x => 14, :y => 20, :name => name, :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    PokeAccess::Caches.reset_all
    ev
  end
end
