# Infinite Fusion 2's minigames over the map (games/infinitefusion_hoenn/clefairy_board.rb, time_trial.rb,
# bike_color.rb and wild_notice.rb), gamedata pass: each arrow the Clefairy's blackboard takes is said, cutting in, in
# the order the game takes them and never past the sequence; the time trial's start is said, queued, and the info key
# says its time, its bumps and its finish line while it runs; each change of the bike's paint says the hue it leaves,
# cutting in; a wild Pokemon noticing the player says who, its reaction and where, queued. The overworld Safari
# (safari.rb, preventive): its caught panel's rows as it opens, the info key's balls and watchers, a failed throw and,
# there alone, a watcher losing sight. The PC of both games (infinitefusion_common/storage_selection.rb): the
# multi-selection's count on each redraw and a dimmed slot. The stand-ins come before the profile files load.

# The game's blackboard minigame, down to its input loop: each pulse the arrows held are taken in the game's order,
# each with its sound, until the sequence is full.
def clefairy_minigame(length = 4, clefairy_event_id = nil)
  taken = 0
  IfhMiniGdTest.pulses.each do |held|
    IfhMiniGdTest.held = held
    [Input::LEFT, Input::UP, Input::RIGHT, Input::DOWN].each do |key|
      next unless Input.trigger?(key)
      taken += 1
      pbSEPlay("GUI save choice", 80, 100)
    end
    PokeAccess::Frame.instance_variable_set(:@pulses, PokeAccess::Frame.pulses + 1)
    break if taken >= length
  end
  true
end

SWITCH_TIME_TRIAL = 2196 unless defined?(SWITCH_TIME_TRIAL)
VAR_TIME_TRIAL_START = 1051 unless defined?(VAR_TIME_TRIAL_START)

# The game's trial start, down to the clock it keeps in a variable.
def timeTrialStart; $game_variables[VAR_TIME_TRIAL_START] = Time.now; end

# The bumps the game counts on $game_temp during a trial.
class Game_Temp; attr_accessor :time_trial_bumps; end

# The trial's finish line: a row of three tiles with no graphic.
IfhFinishLine = Struct.new(:id, :name, :x, :y)

# The repaint of the player's sprite and the paint menu's changes, down to the hue they leave on the bike.
def refreshPlayerOutfit; end

def shiftBikeColor(incr)
  $Trainer.bike_color = 0 if !$Trainer.bike_color
  $Trainer.bike_color += incr
  refreshPlayerOutfit
end

def select_bike_color
  IfhMiniGdTest.paint.each do |change|
    if change == :default
      $Trainer.bike_color = 0
      refreshPlayerOutfit
    else
      shiftBikeColor(change)
    end
  end
  true
end

# A visible wild Pokemon, down to where it stands, what it shows and how it behaves on noticing; its state as the game
# sets it, a fleeing behaviour fleeing as it notices, and its flight, which a shiny one never takes.
class OverworldPokemonEvent
  attr_accessor :x, :y, :character_name, :species, :behavior_noticed, :opacity, :shiny

  def update_state(new_state)
    @current_state = new_state
    flee if new_state == :NOTICED_PLAYER && @behavior_noticed == :flee
  end

  def flee(_behavior = nil)
    @current_state = :FLEEING unless @shiny
  end
end

# The Safari's state as the readers ask it: nil outside a Safari, as core's field key expects.
def pbSafariState; IfhMiniGdTest.safari; end

# The Safari's caught panel, down to the sprite keys it builds: an icon "<SPECIES>_<n>" per catch, in the order each
# species was first caught, and its background, none for an empty list.
class SafariCaughtIcons_UI
  def initialize(caught_pokemon = [])
    counts = Hash.new(0)
    caught_pokemon.each { |pk| counts[pk.species] += 1 }
    @sprites = {}
    return if counts.empty?
    counts.to_a.each { |species, n| n.times { |i| @sprites["#{species}_#{i}"] = :icon } }
    @sprites["bg"] = :window
  end
end

# A throw that reaches a Pokemon, down to the catch it records when it lands.
def try_catch_safari_pokemon(pokemon_event)
  pbSafariState.caught_pokemon << pokemon_event if IfhMiniGdTest.lands
end

# The PC's multi-selection redraw, which the game runs after each move while a rectangle is open.
class PokemonStorageScene
  def pbUpdateSelectionRect(box, selected); end
end

class IfhMiniGdTest < PokeAccessTest
  DIR = File.join(Harness::ROOT, "games", "infinitefusion_hoenn")
  ZIG = "SpeciesZIGZAGOON"
  COMMON = File.join(Harness::ROOT, "games", "infinitefusion_common", "storage_selection.rb")
  Bike = Struct.new(:bike_color)
  Safari = Struct.new(:ballcount, :caught_pokemon, :running) do
    def inProgress?; running; end
  end
  SafariTemp = Struct.new(:overworld_safari)
  Caught = Struct.new(:species)
  # The PC's multi-selection screen: its rectangle open or not, and the slots it covers.
  MultiScreen = Struct.new(:multiSelectRange, :slots) do
    def getMultiSelection(_box, _selected); slots; end
  end
  # A box icon and the sprite holding a box's icons, as the filter leaves them.
  class Icon; def initialize(enabled); @enabled = enabled; end; end
  class IconHolder; def initialize(icons); @pokemonsprites = icons; end; end

  class << self
    # The arrows held at each pulse of the blackboard's loop, those of the pulse running now, the paint menu's changes
    # in order (a hue shift, or :default), the Safari running and whether a thrown ball catches.
    attr_accessor :pulses, :held, :paint, :safari, :lands
  end
  self.pulses = []
  self.held = []
  self.paint = []

  # Evaluates the profile files once, as boot does, their hooks bound to the stand-ins above; the visible Pokemon's
  # names come from overworld.rb, evaluated only if no other test has.
  def self.load_profile
    profiles = PokeAccess::Game.profiles.dup
    files = %w[clefairy_board time_trial bike_color wild_notice safari]
    files.unshift("overworld") unless defined?(PokeAccess::IF2Overworld)
    (files.map { |f| File.join(DIR, "#{f}.rb") } + [COMMON]).each do |path|
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
    end
  ensure
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  def setup
    super
    @pulses_were = PokeAccess::Frame.pulses
    @trainer_was = $Trainer
    @temp_was = $PokemonTemp
    $Trainer = Bike.new(nil)
  end

  # Puts back the pulses, the player, the trial's bumps, the map's events and the Safari.
  def teardown
    PokeAccess::Frame.instance_variable_set(:@pulses, @pulses_were)
    $Trainer = @trainer_was
    $game_temp.time_trial_bumps = nil
    $game_map.events.clear
    $PokemonTemp = @temp_was
    self.class.pulses = []
    self.class.held = []
    self.class.paint = []
    self.class.safari = nil
    self.class.lands = nil
    super
  end

  test "each arrow the blackboard takes is said, cutting in, by its direction" do
    self.class.pulses = [[Input::LEFT], [], [Input::DOWN], [Input::RIGHT]]
    with_keys { clefairy_minigame(3, 31) }
    assert_equal [[t(:dir_left), true], [t(:dir_down), true], [t(:dir_right), true]], SpeakCapture.log
  end

  test "two arrows taken in one pulse are said in the order the game takes them" do
    self.class.pulses = [[Input::DOWN, Input::LEFT], [Input::UP]]
    with_keys { clefairy_minigame(3) }
    assert_equal [t(:dir_left), t(:dir_down), t(:dir_up)], SpeakCapture.log.map { |l| l[0] }
  end

  test "an arrow taken past the sequence's length is not said" do
    self.class.pulses = [[Input::LEFT], [Input::UP, Input::RIGHT]]
    with_keys { clefairy_minigame(2) }
    assert_equal [t(:dir_left), t(:dir_up)], SpeakCapture.log.map { |l| l[0] }
  end

  test "the arrow sound outside the blackboard and other sounds in it say nothing" do
    self.class.held = [Input::LEFT]
    with_keys do
      pbSEPlay("GUI save choice", 80, 100)
      PokeAccess::IF2Clefairy.run(4) { pbSEPlay("GUI sel buzzer", 80, 100) }
    end
    assert_nothing_spoken
  end

  test "the time trial's start is said, queued, with what the info key tells" do
    timeTrialStart
    assert_equal [["#{t(:if2_trial_start)}. #{t(:if2_trial_hint)}", false]], SpeakCapture.log
  end

  test "the hint is left out of the start while key hints are not said" do
    PokeAccess::Config.verbosity = :brief
    timeTrialStart
    assert_equal [[t(:if2_trial_start), false]], SpeakCapture.log
  end

  test "while the trial runs the info key on the map says the time, the bumps and where the finish line lies" do
    run_trial(7.4, 2)
    $game_player.x = 31
    $game_player.y = 40
    clock = "#{t(:if2_trial_time, :n => 7)}, #{t(:if2_trial_bumps, :n => 2)}"
    goal = t(:if2_trial_goal, :dir => PokeAccess::Locator.dir_phrase(2, 43))
    assert_equal PokeAccess.sentences([clock, goal]), info_text
  end

  test "a trial with no bumps leaves them out, and the finish line's nearest tile is the one said" do
    run_trial(3.2, 0)
    $game_player.x = 36
    $game_player.y = 60
    goal = t(:if2_trial_goal, :dir => PokeAccess::Locator.dir_phrase(-1, 23))
    assert_equal PokeAccess.sentences([t(:if2_trial_time, :n => 3), goal]), info_text
  end

  test "with no trial running the info key on the map is not the trial's" do
    run_trial(5.0, 1)
    $game_switches[SWITCH_TIME_TRIAL] = false
    assert_nil PokeAccess::IF2TimeTrial.line
    refute_includes info_text.to_s, t(:if2_trial_time, :n => 5)
  end

  test "each shift of the bike's paint says the hue it leaves, cutting in, and the default says no dye" do
    self.class.paint = [10, 10, -10, :default]
    assert select_bike_color
    assert_equal [[t(:if_hue, :n => 10), true], [t(:if_hue, :n => 20), true], [t(:if_hue, :n => 10), true],
                  [t(:if_dye_off), true]], SpeakCapture.log
  end

  test "the default on an unpainted bike changes nothing and says nothing" do
    self.class.paint = [:default]
    select_bike_color
    assert_nothing_spoken
  end

  test "a repaint of the player outside the paint menu says nothing" do
    shiftBikeColor(10)
    assert_nothing_spoken
  end

  test "a wild Pokemon noticing the player says who, its reaction and where, queued" do
    notice(:aggressive)
    assert_equal [[seen(:if2_wild_seen_angry, t(:loc_wild, :name => ZIG)), false]], SpeakCapture.log
  end

  test "each behaviour on noticing says the reaction its animation shows" do
    { :semi_aggressive => :if2_wild_seen_angry, :curious => :if2_wild_seen_curious,
      :excited => :if2_wild_seen_excited, :skittish => :if2_wild_seen_surprised,
      :shy => :if2_wild_seen_surprised }.each do |behavior, key|
      SpeakCapture.clear
      notice(behavior)
      assert_equal [seen(key, t(:loc_wild, :name => ZIG))], SpeakCapture.lines, behavior.inspect
    end
  end

  test "a fusion is said by its silhouette" do
    notice(:curious, "Followers/Fusions/ZIGZAGOON_notice")
    assert_equal [seen(:if2_wild_seen_curious, t(:if2_ow_fusion, :name => ZIG))], SpeakCapture.lines
  end

  test "one with no behaviour on noticing, and any other state, say nothing" do
    notice(nil)
    ev = wild(:aggressive)
    ev.update_state(:ROAMING)
    ev.update_state(:FLEEING)
    assert_nothing_spoken
  end

  test "in the Safari a watcher going back to roaming says it lost sight of the player, queued" do
    in_safari
    ev = wild(:curious)
    ev.update_state(:NOTICED_PLAYER)
    SpeakCapture.clear
    ev.update_state(:ROAMING)
    assert_equal [[t(:if2_wild_unseen, :name => t(:loc_wild, :name => ZIG)), false]], SpeakCapture.log
  end

  test "out of the Safari a watcher going back to roaming says nothing" do
    ev = wild(:curious)
    ev.update_state(:NOTICED_PLAYER)
    SpeakCapture.clear
    ev.update_state(:ROAMING)
    assert_nothing_spoken
  end

  test "the Safari's caught panel says its rows as it opens, queued, in the order first caught" do
    SafariCaughtIcons_UI.new([Caught.new(:ZIGZAGOON), Caught.new(:WINGULL), Caught.new(:ZIGZAGOON)])
    rows = [t(:if2_safari_row, :n => 2, :name => ZIG), t(:if2_safari_row, :n => 1, :name => "SpeciesWINGULL")]
    assert_equal [[t(:if2_safari_caught, :list => rows.join(", ")), false]], SpeakCapture.log
  end

  test "an empty caught panel draws nothing and says nothing" do
    SafariCaughtIcons_UI.new([])
    assert_nothing_spoken
  end

  test "in the Safari the info key on the map says the balls left and the Pokemon whose notice icon is up" do
    in_safari(12)
    watcher = wild(:aggressive)
    watcher.update_state(:NOTICED_PLAYER)
    roamer = wild(:aggressive)
    hidden = wild(:aggressive)
    hidden.update_state(:NOTICED_PLAYER)
    hidden.instance_variable_set(:@notice_icon_hidden, true)
    [watcher, roamer, hidden].each_with_index { |ev, i| $game_map.events[40 + i] = ev }
    seen = t(:if2_safari_seen, :list => "#{t(:loc_wild, :name => ZIG)}, #{PokeAccess::Locator.dir_phrase(-2, -3)}")
    assert_equal PokeAccess.sentences([t(:safari_balls, :n => 12), seen]), info_text
  end

  test "out of the Safari the info key on the map is not the Safari's" do
    assert_nil PokeAccess::IF2Safari.line
  end

  test "a throw the Pokemon breaks free of says so, queued, and a catch leaves the game's message alone" do
    in_safari
    try_catch_safari_pokemon(wild(:shy))
    self.class.lands = true
    try_catch_safari_pokemon(wild(:shy))
    assert_equal [[t(:if2_safari_escaped, :name => t(:loc_wild, :name => ZIG)), false]], SpeakCapture.log
  end

  test "each redraw of the PC's multi-selection says, queued, how many Pokemon it covers and how many are dimmed" do
    scene = pc_scene([true, false, true, nil], MultiScreen.new([0, nil], [0, 1, 3]))
    scene.pbUpdateSelectionRect(0, 3)
    line = "#{t(:if_pc_sel, :n => 2)}, #{t(:if_pc_sel_dim, :n => 1)}"
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "a fleeing behaviour says the notice and then the flight, queued" do
    notice(:flee)
    assert_equal [[seen(:if2_wild_seen_surprised, t(:loc_wild, :name => ZIG)), false],
                  [t(:if2_wild_flees, :name => t(:loc_wild, :name => ZIG)), false]], SpeakCapture.log
  end

  test "a watcher fleeing from the player says so once, and a shiny one that stays says nothing" do
    ev = wild(:curious)
    ev.update_state(:NOTICED_PLAYER)
    SpeakCapture.clear
    2.times { ev.flee }
    shiny = wild(:curious)
    shiny.shiny = true
    shiny.flee
    assert_equal [t(:if2_wild_flees, :name => t(:loc_wild, :name => ZIG))], SpeakCapture.lines
  end

  test "after the Safari ends, with its mark still set, the info key and a watcher roaming again say nothing of it" do
    in_safari
    self.class.safari.running = false
    ev = wild(:curious)
    ev.update_state(:NOTICED_PLAYER)
    SpeakCapture.clear
    ev.update_state(:ROAMING)
    assert_nil PokeAccess::IF2Safari.line
    assert_nothing_spoken
  end

  test "a redraw over the box name or a button, a negative selection, says nothing" do
    scene = pc_scene([true, true, true], MultiScreen.new([0, nil], [0, 1, 2]))
    [-1, -2, -3].each { |sel| scene.pbUpdateSelectionRect(0, sel) }
    assert_nothing_spoken
  end

  test "a redraw over the party column counts the party's Pokemon and its dimmed ones" do
    scene = pc_scene([], MultiScreen.new([0, nil], [0, 1, 2]), [false, true, nil])
    scene.pbUpdateSelectionRect(-1, 2)
    assert_equal ["#{t(:if_pc_sel, :n => 2)}, #{t(:if_pc_sel_dim, :n => 1)}"], SpeakCapture.lines
  end

  test "a dimmed Pokemon in the party column says it is unavailable" do
    pk = TestPoke.build
    party = [pk]
    plain = PokeAccess::Party.slot_line(pc_scene([], MultiScreen.new(nil, []), [true]), 0, party, pk, nil, "")
    dimmed = PokeAccess::Party.slot_line(pc_scene([], MultiScreen.new(nil, []), [false]), 0, party, pk, nil, "")
    refute_includes plain, t(:if_pc_dim)
    assert_equal "#{plain}, #{t(:if_pc_dim)}", dimmed
  end

  test "a redraw with no rectangle open says nothing" do
    pc_scene([true], MultiScreen.new(nil, [0])).pbUpdateSelectionRect(0, 0)
    assert_nothing_spoken
  end

  test "a dimmed Pokemon's slot says it is unavailable, and an undimmed one is left as it was" do
    pk = TestPoke.build
    plain = PokeAccess::Party.slot_line(pc_scene([true], MultiScreen.new(nil, [])), 0, nil, pk, nil, "")
    dimmed = PokeAccess::Party.slot_line(pc_scene([false], MultiScreen.new(nil, [])), 0, nil, pk, nil, "")
    refute_includes plain, t(:if_pc_dim)
    assert_equal "#{plain}, #{t(:if_pc_dim)}", dimmed
  end

  private

  # The overworld Safari running, with balls left and nothing caught yet.
  def in_safari(balls = 18)
    $PokemonTemp = SafariTemp.new(true)
    self.class.safari = Safari.new(balls, [], true)
  end

  # A PC scene over one box and the party column, whose slots hold a Pokemon where enabled is given (true or false,
  # as the filter left its icon) and none where it is nil, with screen as its multi-selection.
  def pc_scene(enabled, screen, party = [])
    mons = lambda { |list| list.map { |e| e.nil? ? nil : TestPoke.build } }
    icons = lambda { |list| IconHolder.new(list.map { |e| e.nil? ? nil : Icon.new(e) }) }
    scene = PokemonStorageScene.new(TestStorage.new([mons.call(enabled)], mons.call(party)))
    scene.instance_variable_set(:@screen, screen)
    scene.instance_variable_set(:@sprites, "box" => icons.call(enabled), "boxparty" => icons.call(party))
    scene
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # Runs block with Input.trigger? answering the arrows the class holds now, as the game's keyboard would.
  def with_keys
    sc = class << Input; self; end
    sc.send(:alias_method, :ifh_mini_trigger?, :trigger?)
    sc.send(:define_method, :trigger?) { |*k| IfhMiniGdTest.held.include?(k[0]) }
    yield
  ensure
    sc.send(:alias_method, :trigger?, :ifh_mini_trigger?)
    sc.send(:remove_method, :ifh_mini_trigger?)
  end

  # A trial started seconds ago with bumps so far, its finish line at (33..35, 83).
  def run_trial(seconds, bumps)
    $game_switches[SWITCH_TIME_TRIAL] = true
    $game_variables[VAR_TIME_TRIAL_START] = Time.now - seconds
    $game_temp.time_trial_bumps = bumps
    $game_map.events[25] = IfhFinishLine.new(25, "timeTrialStop size(3,1)", 33, 83)
  end

  # What the info key says on the map.
  def info_text
    PokeAccess::Info.set_info(:map, nil)
    PokeAccess::Info.info_text
  end

  # A visible wild Zigzagoon, 2 left and 3 up of the player, behaving so on noticing and drawn with sprite.
  def wild(behavior, sprite = "Followers/ZIGZAGOON_notice")
    ev = OverworldPokemonEvent.allocate
    ev.x = 3
    ev.y = 2
    ev.character_name = sprite
    ev.species = :ZIGZAGOON
    ev.behavior_noticed = behavior
    ev.opacity = 255
    ev
  end

  def notice(behavior, sprite = "Followers/ZIGZAGOON_notice")
    wild(behavior, sprite).update_state(:NOTICED_PLAYER)
  end

  # The line said for one named name noticing the player with the reaction key, where wild puts it.
  def seen(key, name)
    t(key, :name => name, :dir => PokeAccess::Locator.dir_phrase(-2, -3))
  end
end
