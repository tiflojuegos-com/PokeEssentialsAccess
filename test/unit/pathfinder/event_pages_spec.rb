# EventPages walks a touch event's page per facing, as the interpreter would, without running it: branches, moves,
# jumps, transfers and the live state its conditions read.
def event_pages_event(list, opts = {})
  World.touch(:id => opts.fetch(:id, 90), :x => 5, :y => 5, :list => list)
end

Suite.define("event pages: every facing branch keeps its own move, the else answers the rest") do
  ep = PokeAccess::EventPages
  ev = event_pages_event([World.if_facing(4), World.move_player([2, 2, 4], 1), World.else_,
                          World.move_player([3, 3, 1], 1), World.end_])
  eq "facing left takes the IF route", ep.outcome(ev, 4).move, [-2, -1]
  eq "facing right takes the ELSE route", ep.outcome(ev, 6).move, [2, 1]
  eq "and so does facing down", ep.outcome(ev, 2).move, [2, 1]
  o = ep.outcome(ev, 4)
  falsy "a plain carry neither talks nor changes anything", o.talks || o.changes
  eq "and its steps are kept, with the facing after each", o.path, [[-1, 0, 4], [-2, 0, 4], [-2, -1, 8]]
  World.clear_events
end

Suite.define("event pages: an unconditional move runs every way, a jump counts its distance") do
  ep = PokeAccess::EventPages
  walk = event_pages_event([World.move_player([1, 1])])
  eq "no condition: the same move facing up", ep.outcome(walk, 8).move, [0, 2]
  eq "and facing left", ep.outcome(walk, 4).move, [0, 2]
  hop = event_pages_event([World.move_player([[14, [0, 2]]])], :id => 91)
  eq "a jump moves by its parameters", ep.outcome(hop, 2).move, [0, 2]
  truthy "and says it was a jump", ep.outcome(hop, 2).jump
  World.clear_events
end

Suite.define("event pages: a forward step follows the facing, turns included") do
  ep = PokeAccess::EventPages
  fwd = event_pages_event([World.move_player([12, 12])])
  eq "forward twice facing right", ep.outcome(fwd, 6).move, [2, 0]
  eq "forward twice facing up", ep.outcome(fwd, 8).move, [0, -2]
  turn = event_pages_event([World.move_player([19, 12])], :id => 92)
  eq "turn up, then forward: up whatever the facing", ep.outcome(turn, 6).move, [0, -1]
  back = event_pages_event([World.move_player([13])], :id => 93)
  eq "backward steps away from the facing", ep.outcome(back, 6).move, [-1, 0]
  World.clear_events
end

Suite.define("event pages: what cannot be known stops the walk") do
  ep = PokeAccess::EventPages
  random = event_pages_event([World.move_player([9])])
  truthy "a random step is unknown", ep.outcome(random, 2).unknown
  choice = event_pages_event([TestCmd.new(102, [["Sí", "No"], 2]), TestCmd.new(201, [0, 7, 3, 4])], :id => 94)
  o = ep.outcome(choice, 2)
  truthy "a choice is unknown", o.unknown
  truthy "and a transfer past it is noted", o.maybe_transfer
  World.clear_events
end

Suite.define("event pages: a cutscene is told apart from a carry") do
  ep = PokeAccess::EventPages
  talk = event_pages_event([TestCmd.new(101, ["¡Espera!"]), World.move_player([4])])
  o = ep.outcome(talk, 2)
  eq "the move is still read", o.move, [0, -1]
  truthy "but the page talks", o.talks
  falsy "and sets nothing that stays", o.changes
  battle = event_pages_event([TestCmd.new(355, ["pbTrainerBattle(:HIKER)"]), World.move_player([1])], :id => 95)
  truthy "a battle started from a script talks too", ep.outcome(battle, 2).talks
  once = event_pages_event([TestCmd.new(101, ["Hola"]), World.move_player([1]), TestCmd.new(123, ["A", 0])], :id => 103)
  truthy "a scene that turns its own self switch changes the game", ep.outcome(once, 2).changes
  World.clear_events
end

Suite.define("event pages: transfers and bridge ramps") do
  ep = PokeAccess::EventPages
  door = event_pages_event([TestCmd.new(201, [0, 12, 3, 4])])
  eq "a literal transfer", ep.outcome(door, 2).transfer, [12, 3, 4]
  $game_variables[31] = 8; $game_variables[32] = 2; $game_variables[33] = 6
  byvar = event_pages_event([TestCmd.new(201, [1, 31, 32, 33])], :id => 96)
  eq "a transfer by variables is read from them", ep.outcome(byvar, 2).transfer, [8, 2, 6]
  on = event_pages_event([TestCmd.new(355, ["pbBridgeOn"])], :id => 97)
  eq "pbBridgeOn raises the bridge to 2", ep.outcome(on, 2).bridge, 2
  on3 = event_pages_event([TestCmd.new(355, ["pbBridgeOn(3)"])], :id => 98)
  eq "with its height when given", ep.outcome(on3, 2).bridge, 3
  off = event_pages_event([TestCmd.new(355, ["pbBridgeOff"])], :id => 99)
  eq "pbBridgeOff lowers it", ep.outcome(off, 2).bridge, 0
  World.clear_events
end

Suite.define("event pages: conditions read the game's live state") do
  ep = PokeAccess::EventPages
  gated = event_pages_event([TestCmd.new(111, [0, 41, 0]), World.move_player([1], 1), World.end_])
  $game_switches[41] = false
  truthy "switch off: the move does not run", ep.outcome(gated, 2).move.nil?
  $game_switches[41] = true
  eq "switch on: it does", ep.outcome(gated, 2).move, [0, 1]
  $game_variables[42] = 3
  cmp = event_pages_event([TestCmd.new(111, [1, 42, 0, 2, 1]), World.move_player([3], 1), World.end_], :id => 100)
  eq "variable 42 >= 2", ep.outcome(cmp, 2).move, [1, 0]
  bike = event_pages_event([TestCmd.new(111, [12, "$PokemonGlobal.bicycle"]), World.move_player([2], 1), World.end_], :id => 101)
  $PokemonGlobal.bicycle = false
  truthy "on foot the bike-only slope does nothing", ep.outcome(bike, 2).move.nil?
  $PokemonGlobal.bicycle = true
  eq "on the bike it carries", ep.outcome(bike, 2).move, [-1, 0]
  $PokemonGlobal.bicycle = false
  unknown = event_pages_event([TestCmd.new(111, [12, "pbSomethingOdd"]), World.move_player([2], 1), World.end_], :id => 102)
  truthy "a script it cannot read is unknown, not guessed", ep.outcome(unknown, 2).unknown
  World.clear_events
end

Suite.define("event pages: a common event the page calls is walked in place") do
  ep = PokeAccess::EventPages
  had = $data_common_events
  ce = Struct.new(:list)
  $data_common_events = [nil, ce.new([World.move_player([5]), TestCmd.new(115, []), World.move_player([1]), TestCmd.new(0, [])])]
  begin
    stair = event_pages_event([TestCmd.new(117, [1]), World.move_player([3])])
    eq "the common event's move and the page's after it", ep.outcome(stair, 2).move, [0, 1]
    missing = event_pages_event([TestCmd.new(117, [9])], :id => 104)
    truthy "a common event the game does not have is unknown", ep.outcome(missing, 2).unknown
  ensure
    $data_common_events = had
    World.clear_events
  end
end

Suite.define("event pages: waiting for the move, and transfers written as scripts") do
  ep = PokeAccess::EventPages
  wait = event_pages_event([World.move_player([2]), TestCmd.new(210, [])])
  truthy "a page that waits for the move to end says so", ep.outcome(wait, 2).waits
  free = event_pages_event([World.move_player([2])], :id => 105)
  falsy "one that does not, does not", ep.outcome(free, 2).waits
  script = event_pages_event([TestCmd.new(355, ["pbTransferWithTransition(12,7,9,nil)"])], :id => 106)
  eq "a transfer function with coordinates lands on them", ep.outcome(script, 2).transfer, [12, 7, 9]
  ids = event_pages_event([TestCmd.new(355, ["$game_temp.player_new_map_id = 4"]),
                          TestCmd.new(655, ["$game_temp.player_new_x = 3"]), TestCmd.new(655, ["$game_temp.player_new_y = 8"])], :id => 107)
  eq "and so does a new position written out", ep.outcome(ids, 2).transfer, [4, 3, 8]
  World.clear_events
end

Suite.define("event pages: a condition on where the player stands reads the tile the page fires from") do
  ep = PokeAccess::EventPages
  block = event_pages_event([TestCmd.new(111, [12, "$game_player.x == 12"]), World.move_player([2, 2, 1], 1), World.end_,
                             TestCmd.new(111, [12, "$game_player.x == 13"]), World.move_player([1, 2, 2, 2], 1), World.end_])
  eq "from x 12, that tile's move", ep.outcome(block, 8, [12, 8]).move, [-2, 1]
  eq "from x 13, the other one", ep.outcome(block, 8, [13, 8]).move, [-3, 1]
  truthy "not told where, it is unknown rather than guessed", ep.outcome(block, 8).unknown
  truthy "and the page is walked tile by tile", ep.varies_by_tile?(PokeAccess.ivar(block, :@list))
  falsy "a page with no script condition is walked once", ep.varies_by_tile?([World.move_player([1])])
  later = event_pages_event([World.move_player([1]), TestCmd.new(111, [12, "$game_player.y == 9"]),
                             World.move_player([3], 1), World.end_], :id => 108)
  eq "a move before the test counts: down from 8, the test sees 9", ep.outcome(later, 2, [5, 8]).move, [1, 1]
  World.clear_events
end

Suite.define("event pages: the script grammar answers only what it can read") do
  sc = PokeAccess::EventPages::ScriptCondition
  $game_switches[43] = true; $game_switches[44] = false
  truthy "a switch", sc.evaluate("$game_switches[43]", :face => 2)
  falsy "negation", sc.evaluate("!$game_switches[43]", :face => 2)
  truthy "or and parentheses", sc.evaluate("$game_switches[44] || ($game_switches[43] && true)", :face => 2)
  truthy "the key being held is the facing walked", sc.evaluate("Input.press?(Input::UP)", :face => 8)
  falsy "any other key is not held", sc.evaluate("Input.press?(Input::UP)", :face => 2)
  truthy "a comparison of numbers", sc.evaluate("3 >= 2", :face => 2)
  truthy "an unknown call is nil", sc.evaluate("pbCallSomething(1)", :face => 2).nil?
  truthy "a stray token is nil", sc.evaluate("$game_switches[43] &&", :face => 2).nil?
  eq "a known false settles an && whatever the call after it", sc.evaluate("$game_switches[44] && !$game_player.bike_hops", :face => 2), false
  truthy "a known true does not", sc.evaluate("$game_switches[43] && !$game_player.bike_hops", :face => 2).nil?
  eq "a known true settles an ||", sc.evaluate("$game_switches[43] || pbSomething(2)", :face => 2), true
  truthy "and nothing else is guessed", sc.evaluate("$player.difficulty_mode >= 1", :face => 2).nil?
  $game_variables[45] = 3
  truthy "pbGet reads the variable, as the engine defines it", sc.evaluate("pbGet(45) == 3", :face => 2)
  truthy "the player's column, when the walk knows it", sc.evaluate("$game_player.x == 4 && $game_player.y > 6", :face => 2, :pos => [4, 7])
  truthy "and unknown when it does not", sc.evaluate("$game_player.x == 4", :face => 2).nil?
  truthy "a longer name that only starts like it is another call", sc.evaluate("$game_player.x_offset == 4", :face => 2, :pos => [4, 7]).nil?
  truthy "the event's own place, as the interpreter's get_character(0) gives it",
         sc.evaluate("get_character(0).x == 5 && get_character(0).y == 3", :face => 2, :self => [5, 3])
  truthy "and the player's, as get_character(-1)", sc.evaluate("get_character(-1).y == 7", :face => 2, :pos => [4, 7])
  truthy "another character is not known", sc.evaluate("get_character(4).x == 5", :face => 2, :self => [5, 3]).nil?
  truthy "the map the walk is on", sc.evaluate("$game_map.map_id == #{$game_map.map_id}", :face => 2)
  class << $PokemonGlobal; def visitedMaps; { 12 => true }; end; end
  begin
    truthy "a map the player has been to", sc.evaluate("$PokemonGlobal.visitedMaps[12]", :face => 2)
    falsy "and one they have not", sc.evaluate("$PokemonGlobal.visitedMaps[13]", :face => 2)
  ensure
    class << $PokemonGlobal; remove_method :visitedMaps; end
  end
end

Suite.define("event pages: a branch a held direction key opens marks the walk as held") do
  ep = PokeAccess::EventPages
  floor = event_pages_event(World.cracked_floor(999), :id => 120)
  was = $PokemonGlobal.bicycle
  begin
    $PokemonGlobal.bicycle = true
    o = ep.outcome(floor, 6)
    truthy "on the bike the floor bears the player while the key walked is held", o.held
    truthy "and drops no one", o.transfer.nil?
    $PokemonGlobal.bicycle = false
    o = ep.outcome(floor, 6)
    falsy "on foot no key helps", o.held
    eq "and the floor gives way", o.transfer && o.transfer[0], 999
    falsy "a key that only reads as held, where the page does not go that way, marks nothing",
          ep.outcome(event_pages_event([TestCmd.new(111, [12, "Input.press?(Input::UP) && false"]),
                                        World.move_player([2], 1), World.end_], :id => 121), 8).held
  ensure
    $PokemonGlobal.bicycle = was
    World.clear_events
  end
end

Suite.define("event pages: the bag is read through whichever bag and count the engine keeps") do
  sc = PokeAccess::EventPages::ScriptCondition
  had_bag = $bag; had_pb = $PokemonBag
  modern = Object.new
  def modern.quantity(item); item == :POTION ? 2 : 0; end
  old = Object.new
  def old.pbQuantity(item); item == :POTION ? 3 : 0; end
  begin
    $bag = nil; $PokemonBag = nil
    truthy "with no bag the count is not guessed", PokeAccess::Engine.bag_quantity(:POTION).nil?
    truthy "so a condition resting on it is no answer", sc.evaluate("$bag.has?(:POTION)", :face => 2).nil?
    eq "unless the rest settles it", sc.evaluate("$game_switches[44] && $bag.has?(:POTION)", :face => 2), false
    $bag = modern
    eq "a modern bag answers with quantity", PokeAccess::Engine.bag_quantity(:POTION), 2
    truthy "an item it holds", sc.evaluate("$bag.has?(:POTION)", :face => 2)
    falsy "one it holds none of", sc.evaluate("$bag.has?(:ETHER)", :face => 2)
    truthy "and a count compared", sc.evaluate("$bag.quantity(:POTION) >= 2", :face => 2)
    $bag = nil; $PokemonBag = old
    eq "a gen-6 bag answers with pbQuantity", PokeAccess::Engine.bag_quantity(:POTION), 3
    truthy "through the gen-6 spelling of the question too", sc.evaluate("$PokemonBag.pbQuantity(PBItems::POTION) > 2", :face => 2)
  ensure
    $bag = had_bag; $PokemonBag = had_pb
  end
end

Suite.define("event pages: a page started with the action button is walked answering yes") do
  ep = PokeAccess::EventPages
  climb = event_pages_event([TestCmd.new(101, ["¿Quieres escalar?"]), TestCmd.new(102, [["Sí", "No"], 2]),
                             TestCmd.new(402, [0, "Sí"]), World.move_player([37, 4, 4, 4, 38], 1),
                             TestCmd.new(402, [1, "No"]), TestCmd.new(404, [])], :id => 109)
  truthy "walked as a touch, the question stops the walk", ep.outcome(climb, 8).unknown
  o = ep.outcome(climb, 8, nil, true)
  eq "answered yes, it climbs", o.move, [0, -3]
  truthy "with Through on", o.through
  truthy "the question talks, but nothing is changed", o.talks && !o.changes
  asked = event_pages_event([TestCmd.new(355, ['$game_variables[5] = pbMessageBlack(_INTL("¿Trepar?"),[_INTL("Sí"),_INTL("No")],2)']),
                             TestCmd.new(111, [1, 5, 0, 0, 0]), World.move_player([4, 4], 1), World.end_], :id => 110)
  oa = ep.outcome(asked, 8, nil, true)
  eq "an answer kept in a variable is the first option", oa.move, [0, -2]
  falsy "and keeping it is not a change that stays", oa.changes
  confirm = event_pages_event([TestCmd.new(111, [12, 'pbConfirmMessage(_INTL("¿Seguro? (sí)"))']),
                               World.move_player([1], 1), World.end_], :id => 111)
  eq "a confirmation is accepted", ep.outcome(confirm, 2, nil, true).move, [0, 1]
  truthy "but only by a walk that answers", ep.outcome(confirm, 2).unknown
  fight = event_pages_event([TestCmd.new(355, ["pbTrainerBattle(:HIKER)"])], :id => 112)
  truthy "a battle is told as one", ep.outcome(fight, 2).battle
  World.clear_events
end

# Royal's profile file is loaded here once; eval reads the mod's own committed file, as the loader does.
Suite.define("event pages: a game's own staircase test, read with where the event and the player stand") do
  unless $event_pages_royal_loaded
    path = File.join(Harness::ROOT, "games", "royal", "stairs.rb")
    eval(File.read(path), TOPLEVEL_BINDING, path)
    $event_pages_royal_loaded = true
  end
  ep = PokeAccess::EventPages
  step = event_pages_event([TestCmd.new(111, [12, "escalera_pos_arriba(2)"]), World.move_player([6], 1), World.end_], :id => 113)
  eq "one column right of the stair and a row above it, the diagonal runs", ep.outcome(step, 6, [6, 4]).move, [1, 1]
  truthy "two rows above, too", !ep.outcome(step, 6, [6, 3]).move.nil?
  truthy "three rows above counts only on a stair of size 3", ep.outcome(step, 6, [6, 2]).move.nil?
  truthy "and anywhere else it does not", ep.outcome(step, 6, [5, 4]).move.nil?
  World.clear_events
end
