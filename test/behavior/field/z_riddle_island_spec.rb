# Pokemon Z's Isla Certijo (map 123) on the shipped profile: the Riddle King's four riddles, staged by switches, with
# and without assist (which alone gives the answers).

def load_z_riddles
  path = File.join(Harness::ROOT, "games", "pokemon_z", "puzzles.rb")
  eval(File.read(path), TOPLEVEL_BINDING, path)
  PokeAccess::Puzzles.instance_variable_get(:@defs)[123]
end

# An event at (x, y) whose live page runs list (a found star's page is empty).
def riddle_event(id, x, y, list, sprite = "")
  pg = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
  ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [pg], :active_page => pg)
  $game_map.events[id] = ev
  ev
end

def riddle_switches(on)
  (226..232).each { |s| $game_switches[s] = on.include?(s) }
end

def riddle_names(targets)
  targets.map { |t| t.respond_to?(:key) && t.is_a?(Struct) ? t.name : PokeAccess::Locator.target_name(t) }
end

Suite.define("z riddle island: the four riddles are staged by the switches the map sets") do
  d = load_z_riddles
  truthy "map 123 is declared, as a staged puzzle", d.is_a?(Hash) && d[:kind] == :stages
  pz = PokeAccess::Puzzles
  begin
    riddle_switches([])
    falsy "before the challenge is accepted nothing is live, so the info key keeps its usual job", pz.stage_of(d)
    riddle_switches([226])
    eq "accepting opens the first riddle", pz.stage_of(d)[:title], :riddle1_title
    riddle_switches([226, 227])
    eq "solved, the King has the next one", pz.stage_of(d)[:title], :riddle_back
    riddle_switches([226, 227, 228])
    eq "then the signs", pz.stage_of(d)[:title], :riddle2_title
    riddle_switches([226, 227, 228, 229, 230])
    eq "then the Pikachu", pz.stage_of(d)[:title], :riddle3_title
    riddle_switches([226, 227, 228, 229, 230, 231])
    eq "then the last riddle", pz.stage_of(d)[:title], :riddle4_title
    riddle_switches((226..232).to_a)
    truthy "and the King beaten is the island solved", pz.stages_solved?(d)
  ensure
    riddle_switches([])
  end
end

Suite.define("z riddle island: the star-shaped bushes are listed while unfound, and the count keeps its word") do
  pz = PokeAccess::Puzzles
  d = load_z_riddles
  World.clear_events
  begin
    pz.register($game_map.map_id, d)
    pz.reset_state
    riddle_switches([226])
    $game_variables[112] = 0
    text = [TestCmd.new(101, ["!"])]
    riddle_event(9, 24, 16, text)
    riddle_event(8, 30, 30, text)
    riddle_event(6, 24, 41, [TestCmd.new(0, [])])
    names = riddle_names(pz.category_targets)
    eq "every bush still to press is listed, as what the map draws", names.count(PokeAccess::I18n.t(:riddle_star)), 2
    truthy "and the King's statue with them", names.include?(PokeAccess::I18n.t(:riddle_king))

    SpeakCapture.clear
    pz.read
    line = SpeakCapture.lines.join(" ")
    truthy "the info key names the riddle", line.include?(PokeAccess::I18n.t(:riddle1_title))
    falsy "and keeps the count quiet at zero, since its label is the answer",
          line.include?(PokeAccess::I18n.t(:riddle_stars))
    falsy "and without assist no hint", line.include?(PokeAccess::I18n.t(:riddle1_hint))

    $game_variables[112] = 2
    SpeakCapture.clear
    pz.read
    truthy "once one is found the count is read", SpeakCapture.lines.join(" ").include?(
      PokeAccess::I18n.t(:puzzle_progress, :label => PokeAccess::I18n.t(:riddle_stars), :n => 2, :of => 5))

    PokeAccess::Config.puzzle_assist = true
    SpeakCapture.clear
    pz.read
    truthy "with assist the hint gives the answer", SpeakCapture.lines.join(" ").include?(PokeAccess::I18n.t(:riddle1_hint))
  ensure
    PokeAccess::Config.puzzle_assist = false
    riddle_switches([])
    $game_variables[112] = 0
    World.clear_events
    pz.reset_state
  end
end

Suite.define("z riddle island: each number sign says what it shows, and the plate is found") do
  pz = PokeAccess::Puzzles
  d = load_z_riddles
  World.clear_events
  begin
    pz.register($game_map.map_id, d)
    pz.reset_state
    riddle_switches([226, 227, 228])
    (113..116).each { |v| $game_variables[v] = 0 }
    [[11, 12, 57], [12, 18, 57], [13, 12, 60], [14, 18, 60]].each { |id, x, y| riddle_event(id, x, y, [TestCmd.new(122, [])]) }
    pz.tick
    $game_variables[113] = 2
    SpeakCapture.clear
    pz.tick
    eq "pressing a sign says its new number, as its tile now shows it", SpeakCapture.lines,
       [PokeAccess::I18n.t(:puzzle_value, :label => PokeAccess::I18n.t(:riddle_sign, :n => 1), :v => 2)]

    names = riddle_names(pz.category_targets)
    truthy "the locator lists the sign with its number", names.include?(
      PokeAccess::I18n.t(:puzzle_value, :label => PokeAccess::I18n.t(:riddle_sign, :n => 1), :v => 2))
    truthy "and the plate that checks them", names.include?(PokeAccess::I18n.t(:riddle_plate))

    $game_variables[115] = 3
    SpeakCapture.clear
    pz.read
    truthy "the info key reads every sign and their total",
           SpeakCapture.lines.join(" ").include?(PokeAccess::I18n.t(:puzzle_sum, :n => 5))
  ensure
    riddle_switches([])
    (113..116).each { |v| $game_variables[v] = 0 }
    World.clear_events
    pz.reset_state
  end
end

Suite.define("z riddle island: the pushed Pikachu is followed, and with assist so is how far it still is") do
  pz = PokeAccess::Puzzles
  d = load_z_riddles
  World.clear_events
  had = [$game_player.x, $game_player.y]
  begin
    pz.register($game_map.map_id, d)
    pz.reset_state
    riddle_switches([226, 227, 228, 229, 230])
    pika = riddle_event(16, 13, 20, [TestCmd.new(209, [])], "025")
    riddle_event(2, 12, 20, [TestCmd.new(101, ["?"])], "flecha")
    $game_player.x = 12; $game_player.y = 20
    pz.tick
    pika.x = 15
    SpeakCapture.clear
    pz.tick
    eq "after a push, where it went from the player", SpeakCapture.lines,
       [PokeAccess::I18n.t(:puzzle_track_rel, :label => PokeAccess::I18n.t(:riddle_pikachu),
                           :dist => "3 #{PokeAccess::I18n.t(:dir_right)}")]
    targets = pz.category_targets
    truthy "the Pikachu itself is a target, so the guides follow it", targets.include?(pika)
    truthy "and the arrow that resets it is named", riddle_names(targets).include?(PokeAccess::I18n.t(:riddle_reset))
    falsy "the goal waits for assist", riddle_names(targets).include?(PokeAccess::I18n.t(:riddle_goal))

    PokeAccess::Config.puzzle_assist = true
    pika.x = 16
    SpeakCapture.clear
    pz.tick
    eq "with assist, how far it still is from Donphan's corner", SpeakCapture.lines,
       [PokeAccess::I18n.t(:puzzle_track_goal, :label => PokeAccess::I18n.t(:riddle_pikachu),
                           :dist => "38 #{PokeAccess::I18n.t(:dir_right)}, 20 #{PokeAccess::I18n.t(:dir_down)}",
                           :goal => PokeAccess::I18n.t(:riddle_goal))]
    truthy "and the goal is listed", riddle_names(pz.category_targets).include?(PokeAccess::I18n.t(:riddle_goal))
    pika.x = 55; pika.y = 42
    SpeakCapture.clear
    pz.tick
    eq "inside it, it says so", SpeakCapture.lines,
       [PokeAccess::I18n.t(:puzzle_track_in, :label => PokeAccess::I18n.t(:riddle_pikachu),
                           :goal => PokeAccess::I18n.t(:riddle_goal))]
  ensure
    PokeAccess::Config.puzzle_assist = false
    $game_player.x = had[0]; $game_player.y = had[1]
    riddle_switches([])
    World.clear_events
    pz.reset_state
  end
end

Suite.define("z riddle island: the last riddle's count is assist's, and the win is said once") do
  pz = PokeAccess::Puzzles
  d = load_z_riddles
  World.clear_events
  begin
    pz.register($game_map.map_id, d)
    pz.reset_state
    riddle_switches([226, 227, 228, 229, 230, 231])
    $game_variables[118] = 0
    pz.tick
    $game_variables[118] = 1
    SpeakCapture.clear
    pz.tick
    silent "without assist, asking him again is the riddle's own secret"
    PokeAccess::Config.puzzle_assist = true
    $game_variables[118] = 2
    SpeakCapture.clear
    pz.tick
    eq "with assist, each ask is counted", SpeakCapture.lines,
       [PokeAccess::I18n.t(:puzzle_progress, :label => PokeAccess::I18n.t(:riddle_asked), :n => 2, :of => 7)]

    $game_switches[232] = true
    SpeakCapture.clear
    pz.tick
    silent "beating him is his own line to say, and it is not said again over it"
    truthy "the info key still belongs to the island", pz.active?
    pz.stages_read(d)
    eq "the info key says the island is solved", SpeakCapture.lines, [PokeAccess::I18n.t(:riddle_solved)]
  ensure
    PokeAccess::Config.puzzle_assist = false
    $game_variables[118] = 0
    riddle_switches([])
    World.clear_events
    pz.reset_state
  end
end

# After each of the first two riddles the King himself sends the player back to him: the stage that opens
# then is his line, so it is not announced over it; the info key still says it.
Suite.define("z riddle island: going back to the King is his own line, and the info key's") do
  pz = PokeAccess::Puzzles
  d = load_z_riddles
  World.clear_events
  begin
    pz.register($game_map.map_id, d)
    pz.reset_state
    riddle_switches([226])
    pz.tick
    riddle_switches([226, 227])
    SpeakCapture.clear
    pz.tick
    silent "the stage he opens with his own words is not announced"
    pz.stages_read(d)
    eq "and the info key still says where the island stands", SpeakCapture.lines, [PokeAccess::I18n.t(:riddle_back)]
  ensure
    riddle_switches([])
    World.clear_events
    pz.reset_state
  end
end
