# Pokemon Z's 3rd gym (maps 87 and 89) on the shipped profile: the sprite-less floor plates are found by the switch they
# write, each floor with its own four, and the beams go by their colour and lie; on the ship (maps 143-145) every steam
# jet goes by one name and the Sharpedo are moving traps.
class ZGym3Test < PokeAccessTest
  FLOORS = { 87 => [142, 141, 143, 147], 89 => [144, 145, 146, 148] }
  SWITCH_WORDS = [[:gym3_red, :gym3_on, :gym3_off], [:gym3_blue, :gym3_on, :gym3_off],
                  [:gym3_green, :gym3_on, :gym3_off], [:gym3_power, :gym3_power_on, :gym3_power_off]]
  BEAMS = { "rayosR" => :gym3_rays_red, "rayosRojosV" => :gym3_rays_red_v, "rayosBarrera" => :gym3_rays_blue,
            "rayosAzulesV" => :gym3_rays_blue_v, "rayosV" => :gym3_rays_green }

  test "reads on the info key each floor's own four switches, red, blue, green and the Regent's" do
    FLOORS.each do |map, switches|
      on_map(map)
      switches.each_with_index do |switch, i|
        switches.each { |s| $game_switches[s] = (s == switch) }
        assert_equal room_line(i), info_key, "map #{map}, switch #{switch} on"
      end
    end
  end

  test "says nothing on walking in with a plate already pressed" do
    on_map(87)
    plate(43, 10, 17, 142)
    $game_switches[142] = true
    assert_equal [], tick
  end

  test "says the switch a plate writes as it is pressed and let go, and no other" do
    on_map(87)
    plate(43, 10, 17, 142)
    tick
    $game_switches[142] = true
    assert_equal [["#{t(:gym3_red)}: #{t(:gym3_on)}", false]], tick, "pressed"
    $game_switches[142] = false
    assert_equal [["#{t(:gym3_red)}: #{t(:gym3_off)}", false]], tick, "let go"
  end

  test "lists a plate with no sprite among the puzzles by its switch, as a tile to step onto" do
    on_map(87)
    plate(43, 10, 17, 142)
    targets = PokeAccess::Puzzles.category_targets
    assert_equal [PokeAccess::Locator::SurfaceTarget.new(10, 17, t(:gym3_red), :puzzle_control, 43)], targets
    assert_equal true, PokeAccess::Puzzles.onto?(targets[0]), "the way goes onto it, not beside it"
  end

  test "sounds a plate with no sprite as a control" do
    on_map(87)
    assert_equal :control, PokeAccess::Sound::Scene.family_of(plate(43, 10, 17, 142))
  end

  test "takes no plate writing the other floor's switch for a control" do
    { 87 => 144, 89 => 142 }.each do |map, other|
      World.clear_events
      on_map(map)
      plate(43, 10, 17, other)
      assert_equal [], PokeAccess::Puzzles.category_targets, "map #{map}, a plate of switch #{other}"
    end
  end

  test "names each beam by its colour and lie, as drawn, on both floors" do
    FLOORS.each_key do |map|
      World.clear_events
      on_map(map)
      BEAMS.each_with_index do |(graphic, label), i|
        ev = beam(20 + i, 13 + i, 15, graphic)
        assert_equal t(label), PokeAccess::Locator.target_name(ev), "map #{map}, #{graphic}"
      end
    end
  end

  test "sounds a beam as a wall in the way, not as a moving trap" do
    on_map(87)
    assert_equal :hazard, PokeAccess::Sound::Scene.family_of(beam(20, 13, 15, "rayosR"))
  end

  test "takes a beam for a wall from the frame it goes up to the frame it goes down" do
    on_map(87)
    ev = beam(1, 12, 15, "")
    assert_nil PokeAccess::Puzzles.wall_name(ev), "a barrier down is no wall"
    ev.character_name = "rayosRojosV"
    World.next_frame
    assert_equal t(:gym3_rays_red_v), PokeAccess::Puzzles.wall_name(ev), "the frame after it goes up, it is one"
    ev.character_name = ""
    World.next_frame
    assert_nil PokeAccess::Puzzles.wall_name(ev), "and the frame after it goes down, it is not"
  end

  test "says the beam the player comes beside by its colour and lie and the side it is on, and not again while there" do
    on_map(87)
    beam(20, 8, 5, "rayosR")
    assert_equal [], tick, "walking in three tiles from it"
    $game_player.x = 7
    assert_equal [[near(:gym3_rays_red, :side_right), false]], tick, "a step beside it"
    assert_equal [], tick, "standing there"
  end

  test "says the beams beside the player on walking in, one on two sides with both, in the order the room names them" do
    on_map(87)
    beam(20, 5, 6, "rayosAzulesV")
    beam(21, 4, 5, "rayosR")
    beam(22, 6, 5, "rayosR")
    said = "#{near(:gym3_rays_red, :side_left, :side_right)}. #{near(:gym3_rays_blue_v, :side_down)}"
    assert_equal [[said, false]], tick
  end

  test "a step from beside one beam to beside one of another colour says the new one alone" do
    on_map(87)
    beam(20, 4, 5, "rayosRojosV")
    beam(21, 4, 6, "rayosRojosV")
    beam(22, 5, 7, "rayosAzulesV")
    assert_equal [[near(:gym3_rays_red_v, :side_left), false]], tick, "walking in"
    $game_player.y = 6
    assert_equal [[near(:gym3_rays_blue_v, :side_down), false]], tick, "a step down, the red ones still on the left"
  end

  test "never takes the room for solved: with every switch on it says each and the info key still reads it" do
    on_map(87)
    tick
    FLOORS[87].each { |s| $game_switches[s] = true }
    all_on = SWITCH_WORDS.map { |label, on, _off| "#{t(label)}: #{t(on)}" }
    assert_equal all_on.map { |line| [line, false] }, tick, "each switch, and no win"
    assert_equal room_line(0, 1, 2, 3), info_key
  end

  test "adds how the plates work to the info key with assist" do
    on_map(87)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "#{room_line}. #{t(:gym3_hint)}", info_key
  end

  test "names every steam jet on the ship's three decks alike" do
    [143, 144, 145].each do |map|
      World.clear_events
      on_map(map)
      assert_equal t(:ship_steam), PokeAccess::Locator.target_name(beam(5, 8, 8, "humo")), "map #{map}"
    end
  end

  test "keeps the ship's Sharpedo out of the list, sounding them as moving traps" do
    on_map(145)
    steam = beam(5, 8, 8, "humo")
    shark = beam(6, 9, 9, "sharpedo")
    assert_equal [steam], PokeAccess::Puzzles.category_targets, "the steam jet is listed, the Sharpedo is not"
    assert_equal :trap, PokeAccess::Sound::Scene.family_of(shark)
  end

  private

  # The spoken text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # What is said of a group of obstacles beside the player: its name (an i18n key), then the sides it is on.
  def near(name, *sides)
    "#{t(name)}, #{PokeAccess::Routes::Text.and_list(sides.map { |s| t(s) })}"
  end

  # Declares the shipped Pokemon Z puzzles as the harness loads the profile (games/pokemon_z/puzzles.rb, through
  # Harness.source) and puts the player on map map_id.
  def on_map(map_id)
    path = File.join(Harness::ROOT, "games", "pokemon_z", "puzzles.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    $game_map.map_id = map_id
    World.next_frame
  end

  # A floor plate as the gym's maps have it: no graphic, fired by touch, a page that turns switch on and a self-switch
  # page that turns it off again; placed on the map.
  def plate(id, x, y, switch)
    on = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(121, [switch, switch, 0])])
    off = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(121, [switch, switch, 1])],
                       :condition => { :self_switch_valid => true, :self_switch_ch => "A" })
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [on, off], :active_page => on)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # An event at (x, y) drawn with graphic, placed on the map.
  def beam(id, x, y, graphic)
    ev = World.event(:kind => :npc, :id => id, :x => x, :y => y)
    ev.character_name = graphic
    World.next_frame
    ev
  end

  # Runs one map frame of the puzzles and returns what it said, as [text, interrupt] pairs.
  def tick
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup
  end

  # What the info key says on the map now.
  def info_key
    PokeAccess::Info.map_text
  end

  # The info key's line for the room with the switches at the indexes on (0 red, 1 blue, 2 green, 3 the Regent's)
  # on and the rest off.
  def room_line(*on)
    SWITCH_WORDS.each_with_index.map { |(label, yes, no), i| "#{t(label)}: #{t(on.include?(i) ? yes : no)}" }.join(". ")
  end
end
