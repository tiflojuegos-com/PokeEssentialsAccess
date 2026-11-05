# Hacking Minigame (plugins/hacking_minigame.rb), played on stand-ins shaped as its scripts: each node reached with its
# state, wires and what lies along each way out, a puzzle's keys as it opens and the next one as each is played, a Key
# Node's panel, the Antivirus (where it stands, what it takes, a catch that costs a life), the moves left, the timer's
# marks and what the info and row keys say.
module HackingGameSettings
  GRID_SQUARE_SIZE = 32
  NODE_INFO = { :Base => { :name => "Base Node" }, :Locked => { :name => "Locked Node", :needs_id => true },
                :Key => { :name => "Key Node", :linked_type => :Locked }, :Charge => { :name => "Charge Node" },
                :Finish => { :name => "Finish Node" } }
end

class HackingGame_Scene
  class HackingKey
    attr_accessor :dir, :hidden
    attr_reader :state

    def initialize(dir, state, hidden, *_args)
      @dir = dir
      @state = state
      @hidden = hidden
    end

    def state=(val); @state = val; end
  end

  class HackingAntivirus
    attr_accessor :x, :y, :active, :visible

    def initialize(x, y)
      @x = x
      @y = y
      @active = false
      @visible = true
    end

    def activate; @active = true; end
    def deactivate; @active = false; end
  end

  class HackingNode
    attr_accessor :type, :id, :state, :puzzle, :puzzle_hidden, :keys_to_reveal, :visible, :enabled, :charge_target,
                  :disabled_info, :disabled_unlocked

    def initialize(type, id = nil, state = 0)
      @type = type
      @id = id
      @state = state
      @visible = true
      @enabled = true
    end

    def get_data; HackingGameSettings::NODE_INFO[@type]; end

    def get_name
      name = get_data[:name]
      @id ? "#{name} #{@id}" : name
    end

    def can_interact?
      return false if @type == :Base
      return false if @disabled_info && !@disabled_unlocked
      @enabled
    end
  end

  # As the game's: a path that is locked or concealed is not drawn at all.
  class HackingPath
    attr_reader :state
    attr_accessor :visible

    def initialize(name, state = 0)
      @name = name
      self.state = state
    end

    def state=(val)
      @state = val
      @visible = val == 0
    end

    def can_pass; @visible && @state == 0; end
    def get_name; @name; end
  end

  class PlayerSprite
    attr_accessor :x, :y, :charged

    def initialize; @x = 0; @y = 0; @charged = false; end
  end

  attr_accessor :coords, :nodes, :paths, :sprites, :timer, :move_limit, :move_count, :lives, :puzzle_keys, :presses,
                :timer_half_passed, :timer_fourth_passed, :antivirus

  def initialize
    @sprites = { "player" => PlayerSprite.new }
    @paths = {}
    @nodes = {}
    @move_count = 0
    @presses = []
    @timer_inc_per_frame = 1.0
  end

  # The game's loop, here whatever the test plays.
  def pbScenePlay(_id = nil); yield self if block_given?; end

  def update_cursor(startup = false); pbPlayCurrentNode unless startup; end
  def pbPlayCurrentNode(_input_trigger = false); nil; end

  # Runs a node as the game does: a locked node's puzzle, unlocking it when solved; a charge node swaps its charge.
  def pbRunNode(node)
    case node.type
    when :Locked
      node.state = 0 if node.state == 1 && pbPlayPuzzle(node)
    when :Charge
      if node.state == 0 && @sprites["player"].charged
        @sprites["player"].charged = false
        node.state = 1
      elsif node.state == 1 && !@sprites["player"].charged
        @sprites["player"].charged = true
        node.state = 0
      end
    when :Key
      pbRevealKeys(node)
    end
  end

  # Makes the key sprites, then plays @presses: a right one lights the next key, a wrong one ends the puzzle.
  def pbPlayPuzzle(node)
    keys = node.puzzle.map { |k| HackingKey.new(k, 0, false) }
    keys.each_with_index { |k, i| k.hidden = node.puzzle_hidden?(i) if node.respond_to?(:puzzle_hidden?) }
    PokeAccess::HackingMinigame.poll
    index = 0
    @presses.each do |dir|
      if dir == node.puzzle[index]
        keys[index].state = 2
        index += 1
        return true if index >= keys.length
        keys[index].state = 1
      else
        keys[index].state = 4
        return false
      end
    end
    false
  end

  # A touch as pbUpdate plays it: a charged player loses the charge and the Antivirus leaves the board.
  def touch_charged(virus)
    @sprites["player"].charged = false
    virus.visible = false
    virus.active = false
  end

  # A catch as pbUpdate and pbScenePlay play it: a life goes, then every Antivirus goes back to its post, each told to stand
  # down, and the first node is drawn again. The frames between run no Input.update, so no pulse: only a catch during a
  # step's frames (mid_step) has one, at the loop's top, before the restart.
  def catch_and_restart(mid_step = false)
    @lives -= 1
    PokeAccess::HackingMinigame.poll if mid_step
    @antivirus.each_value do |a|
      a.deactivate
      a.visible = true
    end
    update_cursor(true)
  end

  def pbRevealKeys(_node); true; end
  def pbShowCommands(helptext, commands, index = 0, force_choice = false, helptextaddons: nil)
    pbShowCommandsCustom(helptext, commands, index, force_choice, helptextaddons)
  end

  def pbShowCommandsCustom(_helptext, commands, _initcmd = 0, _forced = false, _helptextaddons = nil); commands.length; end
  def pbEndScene; nil; end
end

eval(Harness.source(File.join(Harness::ROOT, "plugins", "hacking_minigame.rb")), TOPLEVEL_BINDING,
     File.join(Harness::ROOT, "plugins", "hacking_minigame.rb"))

class HackingMinigameGdTest < PokeAccessTest
  T = PokeAccess::I18n
  HM = PokeAccess::HackingMinigame
  Scene = HackingGame_Scene

  # A circuit: the player at (1,1), a Base Node; a Locked Node up by an open path, a Base Node right behind a locked path,
  # which is not drawn; the Finish Node three to the right and one up, joined to nothing.
  def circuit
    s = Scene.new
    s.coords = [1, 1]
    s.nodes = { [1, 1] => Scene::HackingNode.new(:Base), [1, 0] => Scene::HackingNode.new(:Locked, 2, 1),
                [2, 1] => Scene::HackingNode.new(:Base), [4, 0] => Scene::HackingNode.new(:Finish) }
    s.nodes[[1, 0]].puzzle = [8, 4]
    s.paths = { [1, 0, 1, 1] => Scene::HackingPath.new("Base Path"), [1, 1, 2, 1] => Scene::HackingPath.new("Locked Path Linked to 2", 1) }
    s
  end

  def up; T.t(:dir_up); end
  def right; T.t(:dir_right); end

  # The way up to the circuit's Locked Node, as said while it is locked.
  def up_to_locked
    T.t(:hack_way, :dir => up, :what => "Locked Node 2, #{T.t(:hack_locked)}")
  end

  # A corridor of plain nodes running right from (x,y), one to a square, ending in the node given.
  def corridor(s, x, y, length, last = nil)
    length.times do |i|
      s.paths[[x + i, y, x + i + 1, y]] = Scene::HackingPath.new("Base Path")
      s.nodes[[x + i + 1, y]] = i == length - 1 && last ? last : Scene::HackingNode.new(:Base)
    end
  end

  # The fog of war, up or lifted, of the plugin's small or large size.
  def fog(s, up, size = :small)
    s.sprites["fog"] = Struct.new(:visible).new(up)
    s.instance_variable_set(:@game_info, { :fog => size })
  end

  test "a plain node is said by what lies along its ways out, interrupting; a locked path, not drawn, goes unsaid" do
    s = circuit
    s.pbPlayCurrentNode
    assert_equal [[up_to_locked, true]], SpeakCapture.log
  end

  test "a way is told as far as a node worth naming, with the steps to it, past plain nodes and round their bends" do
    s = circuit
    key = Scene::HackingNode.new(:Key, 1)
    corridor(s, 1, 1, 2)
    s.paths[[3, 1, 3, 2]] = Scene::HackingPath.new("Base Path")
    s.nodes[[3, 2]] = key
    s.paths[[1, 1, 2, 1]].state = 0
    assert_includes HM.node_line(s), T.t(:hack_way_far, :dir => right, :what => "Key Node 1", :n => 3)
  end

  test "a way is told as far as a crossing or a dead end" do
    s = circuit
    corridor(s, 1, 1, 2)
    assert_includes HM.node_line(s), T.t(:hack_way_far, :dir => right, :what => T.t(:hack_no_way), :n => 2)
    s.paths[[3, 0, 3, 1]] = Scene::HackingPath.new("Base Path")
    s.nodes[[3, 0]] = Scene::HackingNode.new(:Base)
    s.paths[[3, 1, 3, 2]] = Scene::HackingPath.new("Base Path")
    s.nodes[[3, 2]] = Scene::HackingNode.new(:Base)
    assert_includes HM.node_line(s), T.t(:hack_way_far, :dir => right, :what => T.t(:hack_cross), :n => 2)
    s.paths[[1, 1, 2, 1]].state = 0
    s.paths[[2, 1, 3, 1]].state = 1
    assert_includes HM.node_line(s), T.t(:hack_way, :dir => right, :what => T.t(:hack_no_way))
  end

  test "an Antivirus standing along a way is where the way's telling stops" do
    s = circuit
    corridor(s, 1, 1, 3)
    s.antivirus = { 0 => Scene::HackingAntivirus.new(64, 0) }
    assert_includes HM.node_line(s), T.t(:hack_way_far, :dir => right, :what => T.t(:hack_virus_here), :n => 2)
  end

  test "a loop of plain nodes that comes back to itself tells only its direction" do
    s = Scene.new
    s.coords = [0, 0]
    [[0, 0], [1, 0], [1, 1], [0, 1]].each { |at| s.nodes[at] = Scene::HackingNode.new(:Base) }
    s.paths[[0, 0, 1, 0]] = Scene::HackingPath.new("Base Path")
    s.paths[[1, 0, 1, 1]] = Scene::HackingPath.new("Base Path")
    s.paths[[0, 1, 1, 1]] = Scene::HackingPath.new("Base Path")
    s.paths[[0, 0, 0, 1]] = Scene::HackingPath.new("Base Path")
    assert_equal PokeAccess.sentences([T.t(:dir_down), right]), HM.node_line(s)
    s.nodes[[0, 0]] = Scene::HackingNode.new(:Key, 1)
    assert_equal [nil, 4], HM.far_end(s, 0, 0, HM::WAYS.find { |w| w[2] == 1 }), "not its own node, by name"
  end

  test "under the small fog only the next node is told, and only when it is worth naming" do
    s = circuit
    corridor(s, 1, 1, 2, Scene::HackingNode.new(:Key, 1))
    fog(s, true)
    line = HM.node_line(s)
    assert_includes line, up_to_locked
    assert_includes line, right
    refute_includes line, "Key Node"
    fog(s, false)
    assert_includes HM.node_line(s), "Key Node 1", "with the fog lifted"
  end

  test "under the large fog a way is told two squares out, what lies a third goes unsaid" do
    s = circuit
    corridor(s, 1, 1, 2, Scene::HackingNode.new(:Key, 1))
    fog(s, true, :large)
    assert_includes HM.node_line(s), T.t(:hack_way_far, :dir => right, :what => "Key Node 1", :n => 2)
    far = circuit
    corridor(far, 1, 1, 3, Scene::HackingNode.new(:Key, 1))
    fog(far, true, :large)
    refute_includes HM.node_line(far), "Key Node"
  end

  test "under fog a bend is walked round as far as its hole shows, the corner counting: one square across and down under the small" do
    s = circuit
    corridor(s, 1, 1, 1)
    s.paths[[2, 1, 2, 2]] = Scene::HackingPath.new("Base Path")
    s.nodes[[2, 2]] = Scene::HackingNode.new(:Key, 1)
    [:small, :large].each do |size|
      fog(s, true, size)
      assert_includes HM.node_line(s), T.t(:hack_way_far, :dir => right, :what => "Key Node 1", :n => 2), size.to_s
    end
  end

  test "under the large fog a node two across and one down shows, two across and two down does not" do
    s = circuit
    corridor(s, 1, 1, 2)
    s.paths[[3, 1, 3, 2]] = Scene::HackingPath.new("Base Path")
    s.nodes[[3, 2]] = Scene::HackingNode.new(:Key, 1)
    fog(s, true, :large)
    assert_includes HM.node_line(s), "Key Node 1"
    s.paths.delete([3, 1, 3, 2])
    s.nodes.delete([3, 2])
    s.paths[[3, 1, 3, 2]] = Scene::HackingPath.new("Base Path")
    s.nodes[[3, 2]] = Scene::HackingNode.new(:Base)
    s.paths[[3, 2, 3, 3]] = Scene::HackingPath.new("Base Path")
    s.nodes[[3, 3]] = Scene::HackingNode.new(:Key, 1)
    refute_includes HM.node_line(s), "Key Node"
    assert HM.in_hole?(s, 2, 1)
    refute HM.in_hole?(s, 2, 2)
    fog(s, true, :small)
    assert HM.in_hole?(s, 1, 1)
    refute HM.in_hole?(s, 2, 0)
  end

  test "under fog a dead end or a crossing right ahead is told, its node showing" do
    s = circuit
    corridor(s, 1, 1, 1)
    fog(s, true)
    assert_includes HM.node_line(s), T.t(:hack_way, :dir => right, :what => T.t(:hack_no_way))
    s.paths[[2, 0, 2, 1]] = Scene::HackingPath.new("Base Path")
    s.nodes[[2, 0]] = Scene::HackingNode.new(:Base)
    s.paths[[2, 1, 2, 2]] = Scene::HackingPath.new("Base Path")
    s.nodes[[2, 2]] = Scene::HackingNode.new(:Base)
    assert_includes HM.node_line(s), T.t(:hack_way, :dir => right, :what => T.t(:hack_cross))
  end

  test "a goal the circuit keeps hidden is not told" do
    s = circuit
    assert HM.goal_line(s)
    s.nodes.values.compact.find { |n| n.type == :Finish }.visible = false
    assert_nil HM.goal_line(s)
  end

  test "a path that is drawn but leads to a node that is not says so, by the name the plugin gives it" do
    s = circuit
    s.paths[[1, 1, 2, 1]].state = 0
    s.paths[[1, 1, 2, 1]] = Scene::HackingPath.new("Base Path")
    s.nodes[[2, 1]].visible = false
    assert_equal PokeAccess.sentences([up_to_locked, T.t(:hack_closed, :dir => right, :name => "Base Path")]), HM.node_line(s)
  end

  test "a Charge Node says where its wire runs, and a node shut off by a drained one where that wire comes from" do
    s = circuit
    feed = Scene::HackingNode.new(:Charge, nil, 0)
    feed.charge_target = [1, 0]
    s.nodes[[2, 1]] = feed
    s.coords = [2, 1]
    assert_includes HM.node_line(s), T.t(:hack_wire_to, :where => HM.where(-1, -1))
    s.coords = [1, 0]
    s.nodes[[1, 0]].enabled = false
    line = HM.node_line(s)
    assert_includes line, T.t(:hack_disabled)
    assert_includes line, T.t(:hack_wire_from, :where => HM.where(1, 1))
    feed.state = 1
    refute_includes HM.node_line(s), T.t(:hack_wire_from, :where => HM.where(1, 1)), "a wire with power is no cause"
  end

  test "a wire is said from where the player stands, on either axis, and the info key has it" do
    s = circuit
    feed = Scene::HackingNode.new(:Charge, nil, 0)
    feed.charge_target = [3, 3]
    s.nodes[[4, 5]] = feed
    s.nodes[[3, 3]] = Scene::HackingNode.new(:Locked, 1, 1)
    s.coords = [3, 3]
    assert_includes HM.node_line(s), T.t(:hack_wire_from, :where => HM.where(1, 2))
    s.coords = [4, 5]
    assert_includes HM.node_line(s), T.t(:hack_wire_to, :where => HM.where(-1, -2))
    HM.playing(s) do
      HM.poll
      assert_includes info_data, T.t(:hack_wire_to, :where => HM.where(-1, -2))
      assert_includes info_data, "Charge Node"
    end
  end

  test "a charge node's own line says whether it holds the charge" do
    s = circuit
    s.nodes[[1, 1]] = Scene::HackingNode.new(:Charge, nil, 1)
    assert_includes HM.node_line(s), PokeAccess.sentences(["Charge Node", T.t(:hack_charged)])
    s.nodes[[1, 1]].state = 0
    assert_includes HM.node_line(s), PokeAccess.sentences(["Charge Node", T.t(:hack_drained)])
  end

  test "carrying the charge to a wire's node says what the wire now does, and neither the node nor its ways twice" do
    s = circuit
    feed = Scene::HackingNode.new(:Charge, nil, 0)
    feed.charge_target = [1, 0]
    s.nodes[[1, 1]] = feed
    s.sprites["player"].charged = true
    s.pbRunNode(feed)
    want = PokeAccess.sentences([T.t(:hack_player_empty), T.t(:hack_wire_on, :name => "Locked Node 2, #{T.t(:hack_locked)}"), up_to_locked])
    assert_equal [[want, true]], SpeakCapture.log, "cutting the arrival it has just made stale"
    s.sprites["player"].charged = false
    feed.state = 1
    SpeakCapture.clear
    s.pbRunNode(feed)
    assert_includes SpeakCapture.log[0][0], T.t(:hack_wire_off, :name => "Locked Node 2, #{T.t(:hack_locked)}")
  end

  test "a shut node says how many of what it still needs, and so does the goal" do
    s = circuit
    finish = s.nodes[[4, 0]]
    finish.disabled_info = { :type => :Locked, :id => 2 }
    need = T.t(:hack_needs, :name => "Locked Node 2", :n => 1)
    assert_includes HM.goal_line(s), T.t(:tilt_goal, :where => HM.where(3, -1))
    assert_includes HM.goal_line(s), need
    s.coords = [4, 0]
    assert_includes HM.node_line(s), need
    s.coords = [1, 1]
    s.nodes[[1, 0]].state = 0
    refute_includes HM.goal_line(s), need, "none left of them"
    s.nodes[[1, 0]].state = 1
    finish.disabled_unlocked = true
    refute_includes HM.goal_line(s), need, "unlocked"
  end

  test "a need of any id counts every node of its kind" do
    s = circuit
    s.nodes[[9, 9]] = Scene::HackingNode.new(:Locked, 7, 1)
    finish = s.nodes[[4, 0]]
    finish.disabled_info = { :type => :Locked, :id => nil }
    assert_includes HM.needs_word(s, finish), ": 2"
    finish.disabled_info = { :type => :Locked, :id => 7 }
    assert_includes HM.needs_word(s, finish), ": 1"
  end

  test "the row key adds the board, nearest first, the player's own node and plain ones aside; under fog what its hole shows" do
    s = circuit
    s.nodes[[2, 1]] = Scene::HackingNode.new(:Key, 1)
    HM.playing(s) do
      HM.poll
      locked = T.t(:hack_on_board, :what => "Locked Node 2, #{T.t(:hack_locked)}", :where => HM.where(0, -1))
      key = T.t(:hack_on_board, :what => "Key Node 1", :where => HM.where(1, 0))
      goal = T.t(:hack_on_board, :what => "Finish Node", :where => HM.where(3, -1))
      assert_includes info_data, HM.goal_line(s)
      refute_includes info_data, key, "the info key stays short"
      assert_equal PokeAccess.sentences([info_data, locked, key, goal]), info_row
      fog(s, true)
      s.move_count = 1
      HM.poll
      assert_equal PokeAccess.sentences([info_data, locked, key]), info_row, "the goal, three squares off, does not show"
      s.nodes.delete([1, 0])
      s.nodes.delete([2, 1])
      s.move_count = 2
      HM.poll
      assert_equal info_data, info_row
    end
  end

  test "a locked node is named, with its state; unlocked, it says so" do
    s = circuit
    s.coords = [1, 0]
    assert_includes HM.node_line(s), "Locked Node 2"
    assert_includes HM.node_line(s), T.t(:hack_locked)
    s.nodes[[1, 0]].state = 0
    assert_includes HM.node_line(s), T.t(:hack_unlocked)
  end

  test "a node that cannot be used yet says it is inactive" do
    s = circuit
    s.coords = [1, 0]
    s.nodes[[1, 0]].enabled = false
    assert_includes HM.node_line(s), T.t(:hack_disabled)
    refute_includes HM.node_line(s), T.t(:hack_locked)
  end

  test "the board is nearest first by steps on the grid, a node not drawn and the player's own left out" do
    s = Scene.new
    s.coords = [5, 5]
    s.nodes[[5, 5]] = Scene::HackingNode.new(:Key, 9)
    { [6, 5] => 1, [2, 5] => 2, [5, 7] => 3, [5, 1] => 4 }.each { |at, id| s.nodes[at] = Scene::HackingNode.new(:Key, id) }
    s.nodes[[6, 6]] = Scene::HackingNode.new(:Key, 5)
    s.nodes[[6, 6]].visible = false
    want = [[1, [1, 0]], [3, [0, 2]], [2, [-3, 0]], [4, [0, -4]]].map do |id, off|
      T.t(:hack_on_board, :what => "Key Node #{id}", :where => HM.where(off[0], off[1]))
    end
    assert_equal want, HM.board_words(s)
  end

  test "a node with no way out says that" do
    s = circuit
    s.paths[[1, 0, 1, 1]].state = 1
    assert_equal T.t(:hack_no_way), HM.node_line(s)
  end

  test "a path that opens is said the moment it is drawn" do
    s = circuit
    s.paths[[1, 1, 2, 1]].state = 0
    assert_includes HM.node_line(s), T.t(:hack_way, :dir => right, :what => T.t(:hack_no_way))
  end

  test "the circuit opens with its limits, the goal and the first node, queued; a later step says only the node" do
    s = circuit
    s.timer = 25 * Graphics.frame_rate
    s.move_limit = 63
    s.move_count = 3
    s.lives = 2
    with_hints(false) { s.update_cursor(true) }
    assert_equal 1, SpeakCapture.log.length
    line, interrupt = SpeakCapture.log[0]
    assert_equal false, interrupt
    [T.t(:hack_time, :n => 25, :secs => T.t(:secs, :n => 25)), "Moves Remaining: 60", T.t(:hack_lives, :n => 2),
     T.t(:tilt_goal, :where => HM.where(3, -1)), up].each { |part| assert_includes line, part }
    refute_includes line, "Antivirus"
  end

  test "the keys hint goes only where hints are said" do
    s = circuit
    with_hints(true) { s.update_cursor(true) }
    assert_includes SpeakCapture.log[0][0], T.t(:hack_hint, :key => PokeAccess::KeyHints.key(:b, T.t(:key_escape)))
    SpeakCapture.clear
    with_hints(false) { s.update_cursor(true) }
    refute_includes SpeakCapture.log[0][0], T.t(:hack_hint, :key => PokeAccess::KeyHints.key(:b, T.t(:key_escape)))
  end

  test "a step's update_cursor adds no opening" do
    s = circuit
    s.update_cursor(false)
    assert_equal 1, SpeakCapture.log.length
    assert_equal true, SpeakCapture.log[0][1], "only the node, cutting what was being said"
  end

  test "the goal is left out of the line when the player stands on it or the circuit has none" do
    s = circuit
    s.coords = [4, 0]
    assert_nil HM.goal_line(s)
    s.nodes.delete([4, 0])
    assert_nil HM.goal_line(s)
  end

  test "a puzzle says its keys on its first frame, once, the next as each is played and how it ended" do
    s = circuit
    s.coords = [1, 0]
    s.presses = [8, 4]
    HM.playing(s) { s.pbRunNode(s.nodes[[1, 0]]) }
    lines = SpeakCapture.log
    seq = T.t(:hack_seq, :list => "#{up}, #{T.t(:dir_left)}")
    assert_equal [seq, true], lines[0], "cutting the node's line, whose ways come back after it"
    assert_equal [T.t(:dir_left), true], lines[1]
    assert_equal 3, lines.length
    assert_includes lines[2][0], T.t(:hack_solved)
    assert_includes lines[2][0], T.t(:hack_unlocked), "the node again, as it now stands"
    assert_equal false, lines[2][1]
  end

  test "a wrong key says so, and the node stays locked" do
    s = circuit
    s.coords = [1, 0]
    s.presses = [2]
    HM.playing(s) { s.pbRunNode(s.nodes[[1, 0]]) }
    assert_includes SpeakCapture.log, [T.t(:hack_key_wrong), true]
    assert_includes SpeakCapture.log[-1][0], T.t(:hack_failed)
    assert_includes SpeakCapture.log[-1][0], T.t(:hack_locked)
  end

  test "a hidden key is said as hidden until guessed" do
    key = Scene::HackingKey.new(8, 0, true)
    assert_equal T.t(:hack_key_hidden), HM.key_word(key)
    key.hidden = false
    assert_equal up, HM.key_word(key)
  end

  test "a key's state outside a puzzle says nothing" do
    Scene::HackingKey.new(8, 0, false).state = 1
    assert_equal [], SpeakCapture.log
  end

  test "a node that changes nothing when run is not said again" do
    s = circuit
    s.coords = [1, 0]
    s.nodes[[1, 0]].state = 0
    s.pbRunNode(s.nodes[[1, 0]])
    assert_equal [], SpeakCapture.log
  end

  test "a charge node that changes hands says what the player now holds and the ways, both ways; one that does not, nothing" do
    s = circuit
    node = Scene::HackingNode.new(:Charge, nil, 1)
    s.nodes[[1, 1]] = node
    s.pbRunNode(node)
    assert_equal [[PokeAccess.sentences([T.t(:hack_player_charged), up_to_locked]), true]], SpeakCapture.log
    SpeakCapture.clear
    s.pbRunNode(node)
    assert_equal [[PokeAccess.sentences([T.t(:hack_player_empty), up_to_locked]), true]], SpeakCapture.log
    SpeakCapture.clear
    s.sprites["player"].charged = false
    node.state = 0
    s.pbRunNode(node)
    assert_equal [], SpeakCapture.log
  end

  test "a node that changes with no puzzle says itself again, queued" do
    s = circuit
    s.coords = [1, 0]
    node = s.nodes[[1, 0]]
    HM.before_run(s, node)
    node.state = 0
    HM.after_run(s, node)
    assert_equal [[HM.node_line(s), false]], SpeakCapture.log
  end

  # A Key Node at the player's square, for the Locked Node's hidden puzzle.
  def key_circuit
    s = circuit
    key = Scene::HackingNode.new(:Key, 2)
    key.keys_to_reveal = [true, false, true]
    s.nodes[[1, 0]].puzzle = [8, 4, 6]
    s.nodes[[1, 0]].puzzle_hidden = true
    s.nodes[[1, 1]] = key
    [s, key]
  end

  def panel_line
    PokeAccess.sentences(["Key Node 2", "Read-Only", "#{T.t(:hack_reveal, :n => 1, :dir => up)}, #{T.t(:hack_reveal, :n => 3, :dir => right)}"])
  end

  test "a Key Node's panel says its keys, each at its place, and what closes it while hints are said; closing says the node" do
    s, key = key_circuit
    close = T.t(:hack_reveal_close, :ok => PokeAccess::KeyHints.key(:c, T.t(:key_enter)),
                                    :back => PokeAccess::KeyHints.key(:b, T.t(:key_escape)))
    with_hints(true) { s.pbRunNode(key) }
    assert_equal [[PokeAccess.sentences([panel_line, close]), true], [PokeAccess.sentences(["Key Node 2", up_to_locked]), true]],
                 SpeakCapture.log
    SpeakCapture.clear
    with_hints(false) { s.pbRunNode(key) }
    assert_equal panel_line, SpeakCapture.log[0][0], "no key words with hints off"
  end

  test "the info key has a Key Node's keys while its panel is open, and the node once it shuts" do
    s, key = key_circuit
    HM.playing(s) do
      HM.revealed(s, key)
      HM.poll
      assert_equal 0, info_row.index(panel_line)
      HM.after_run(s, key)
      HM.poll
      refute_includes info_row, "Read-Only"
      assert_includes info_row, "Key Node 2"
    end
  end

  test "a warning goes behind a Key Node's keys, not over them" do
    s, key = key_circuit
    a = Scene::HackingAntivirus.new(64, 0)
    s.antivirus = { 0 => a }
    HM.playing(s) do
      HM.revealed(s, key)
      SpeakCapture.clear
      a.activate
      assert_equal false, SpeakCapture.log[0][1]
    end
  end

  test "a Key Node opens no panel for a puzzle with no hidden keys, or none to show" do
    s, key = key_circuit
    s.nodes[[1, 0]].puzzle_hidden = nil
    s.pbRunNode(key)
    assert_equal [], SpeakCapture.log
    s.nodes[[1, 0]].puzzle_hidden = true
    key.keys_to_reveal = [false, false, false]
    s.pbRunNode(key)
    assert_equal [], SpeakCapture.log
  end

  test "an alert while a puzzle's keys are read goes behind them, and the info key has the keys left" do
    s = circuit
    s.coords = [1, 0]
    a = Scene::HackingAntivirus.new(64, 0)
    s.antivirus = { 0 => a }
    node = s.nodes[[1, 0]]
    node.puzzle = [8, 4]
    s.presses = [8]
    played = nil
    s.define_singleton_method(:pbPlayPuzzle) do |n|
      keys = n.puzzle.each_with_index.map { |k, i| Scene::HackingKey.new(k, i == 0 ? 1 : 0, false) }
      PokeAccess::HackingMinigame.poll
      a.activate
      played = [SpeakCapture.log.dup, PokeAccess::Info.instance_variable_get(:@row)]
      keys[0].state = 2
      keys[1].state = 1
      PokeAccess::HackingMinigame.poll
      played.push(PokeAccess::Info.instance_variable_get(:@row))
      played.push(SpeakCapture.log.count { |l| l[0] =~ /#{T.t(:hack_seq, :list => "")}/ })
      false
    end
    HM.playing(s) { HM.puzzle { s.pbPlayPuzzle(node) } }
    log, row, later, sequences = played
    assert_equal 1, sequences, "the keys are said once"
    assert_equal [T.t(:hack_seq, :list => "#{up}, #{T.t(:dir_left)}"), true], log[0]
    assert_equal [T.t(:hack_alert, :where => HM.where(2, 0)), false], log[1]
    assert_equal 0, row.index(T.t(:hack_seq, :list => "#{up}, #{T.t(:dir_left)}"))
    assert_equal 0, later.index(T.t(:hack_seq, :list => T.t(:dir_left))), "the key played is gone from it"
  end

  test "an alert with no keys being read cuts what was being said" do
    s = circuit
    a = Scene::HackingAntivirus.new(64, 0)
    HM.playing(s) do
      a.activate
      assert_equal true, SpeakCapture.log[0][1]
    end
  end

  test "the moves left are said as they fall to half, a quarter, ten and five, queued, and at no other count" do
    s = circuit
    s.move_limit = 63
    s.move_count = 0
    said = []
    HM.playing(s) do
      HM.poll
      assert_equal [], SpeakCapture.log, "not as the circuit opens, which says them"
      s.move_count = 32
      HM.poll
      assert_equal [["Moves Remaining: 31", false]], SpeakCapture.log, "on the frame they fall to it"
      SpeakCapture.clear
      (33..60).each do |moved|
        s.move_count = moved
        2.times { HM.poll }
      end
      said = SpeakCapture.log.dup
    end
    assert_equal [15, 10, 5].map { |n| ["Moves Remaining: #{n}", false] }, said
  end

  test "a circuit with no limit on moves says none" do
    s = circuit
    s.move_count = 3
    HM.playing(s) { 2.times { HM.poll } }
    assert_equal [], SpeakCapture.log
  end

  test "the question on giving up is said before its modal loop" do
    assert_equal 2, circuit.pbShowCommands("Give up?", ["Yes", "No"])
    assert_includes SpeakCapture.log.map { |l| l[0] }, "Give up?"
  end

  test "the Antivirus says where it stands when it sees the player, and only one that was on the hunt says it lost them" do
    s = circuit
    a = Scene::HackingAntivirus.new(64, -32)
    b = Scene::HackingAntivirus.new(0, 0)
    HM.playing(s) do
      a.activate
      assert_equal [[T.t(:hack_alert, :where => HM.where(2, -1)), true]], SpeakCapture.log
      SpeakCapture.clear
      b.deactivate
      assert_equal [], SpeakCapture.log, "an idle one has nothing to lose"
      a.deactivate
      assert_equal [[T.t(:hack_alert_off), false]], SpeakCapture.log
    end
  end

  test "a place on the grid is said across then down, each by its own way" do
    leg = lambda { |dir, n| T.t(:tilt_leg, :dir => T.t(dir), :n => n) }
    assert_equal "#{leg.call(:dir_right, 2)}, #{leg.call(:dir_up, 1)}", HM.where(2, -1)
    assert_equal "#{leg.call(:dir_left, 3)}, #{leg.call(:dir_down, 4)}", HM.where(-3, 4)
    assert_equal "#{leg.call(:dir_right, 1)}, #{leg.call(:dir_down, 1)}", HM.where(1, 1)
    assert_equal "", HM.where(0, 0)
  end

  test "each step says where the Antivirus on the hunt now stands, and no idle one" do
    s = circuit
    hunter = Scene::HackingAntivirus.new(64, -32)
    hunter.active = true
    idle = Scene::HackingAntivirus.new(-32, 0)
    s.antivirus = { 0 => hunter, 1 => idle }
    assert_includes HM.node_line(s), T.t(:hack_virus, :where => HM.where(2, -1))
    hunter.x = 32
    hunter.y = 0
    assert_includes HM.node_line(s), T.t(:hack_virus, :where => HM.where(1, 0)), "it moved since the alert"
    refute_includes HM.node_line(s), HM.where(-1, 0), "an idle one is not said on each step"
    s.sprites["player"].x = 64
    s.sprites["player"].y = -32
    assert_includes HM.node_line(s), T.t(:hack_virus, :where => HM.where(-1, 1)), "measured from the player's sprite"
  end

  test "the info key says every Antivirus on the board, the one on the hunt as on alert, as it moves" do
    s = circuit
    hunter = Scene::HackingAntivirus.new(64, -32)
    hunter.active = true
    idle = Scene::HackingAntivirus.new(-32, 0)
    s.antivirus = { 0 => hunter, 1 => idle }
    HM.playing(s) do
      HM.poll
      assert_includes info_row, T.t(:hack_alert, :where => HM.where(2, -1))
      assert_includes info_row, T.t(:hack_virus, :where => HM.where(-1, 0))
      hunter.x = 32
      hunter.y = 0
      HM.poll
      assert_includes info_row, T.t(:hack_alert, :where => HM.where(1, 0)), "kept current with no move of the player's"
    end
  end

  test "an Antivirus that takes the charge is said as it goes, and the info key follows" do
    s = circuit
    s.nodes[[4, 1]] = Scene::HackingNode.new(:Charge, nil, 1)
    virus = Scene::HackingAntivirus.new(32, 0)
    virus.active = true
    s.antivirus = { 0 => virus }
    s.sprites["player"].charged = true
    HM.playing(s) do
      HM.poll
      assert_includes info_row, T.t(:hack_player_charged)
      SpeakCapture.clear
      s.touch_charged(virus)
      2.times { HM.poll }
      assert_equal [[T.t(:hack_virus_gone), true]], SpeakCapture.log, "once, cutting what was being said"
      assert_includes info_row, T.t(:hack_player_empty)
      refute_includes info_row, "Antivirus", "gone from the board"
    end
  end

  test "the circuit's end clears the board without a word about a charge" do
    s = circuit
    s.antivirus = { 0 => Scene::HackingAntivirus.new(32, 0) }
    HM.playing(s) do
      HM.poll
      s.antivirus = {}
      HM.poll
    end
    assert_equal [], SpeakCapture.log
  end

  test "the info key leaves the charge out of a circuit with no Charge Node" do
    s = circuit
    HM.playing(s) { HM.poll }
    refute_includes info_row, T.t(:hack_player_empty)
  end

  test "a catch that costs a life is said as such, not as being lost, and the restart gives no hint again" do
    [false, true].each do |mid_step|
      SpeakCapture.clear
      s = circuit
      s.lives = 3
      a = Scene::HackingAntivirus.new(32, 0)
      a.active = true
      idle = Scene::HackingAntivirus.new(64, 0)
      s.antivirus = { 0 => a, 1 => idle }
      hint = T.t(:hack_hint, :key => PokeAccess::KeyHints.key(:b, T.t(:key_escape)))
      HM.playing(s) do
        with_hints(true) do
          s.update_cursor(true)
          assert_includes SpeakCapture.log[0][0], hint
          refute_includes SpeakCapture.log[0][0], T.t(:hack_restart)
          HM.poll
          SpeakCapture.clear
          s.catch_and_restart(mid_step)
          HM.poll
        end
      end
      lines = SpeakCapture.log
      assert_equal [T.t(:hack_caught), true], lines[0], "mid_step: #{mid_step}"
      assert_equal 2, lines.length, lines.inspect
      assert_equal false, lines[1][1], "the restart queued behind the catch"
      assert_equal 0, lines[1][0].index(T.t(:hack_restart))
      assert_includes lines[1][0], T.t(:hack_lives, :n => 2)
      refute_includes lines[1][0], hint
      refute_includes lines.map { |l| l[0] }, T.t(:hack_alert_off)
    end
  end

  test "the last life goes with the game's own message, and nothing of the mod's over it" do
    s = circuit
    s.lives = 1
    HM.playing(s) do
      HM.poll
      s.lives = 0
      HM.poll
    end
    assert_equal [], SpeakCapture.log
  end

  test "an Antivirus that stands down in play still says it, also after a restart" do
    s = circuit
    s.lives = 2
    a = Scene::HackingAntivirus.new(32, 0)
    s.antivirus = { 0 => a }
    HM.playing(s) do
      s.update_cursor(true)
      HM.poll
      s.catch_and_restart
      HM.poll
      assert_includes SpeakCapture.log, [T.t(:hack_caught), true], "with one life left, still a catch"
      SpeakCapture.clear
      a.active = true
      a.deactivate
      assert_equal [[T.t(:hack_alert_off), false]], SpeakCapture.log
    end
  end

  test "the timer's marks are said once each, as its flags come up" do
    s = circuit
    HM.playing(s) do
      HM.poll
      assert_equal [], SpeakCapture.log
      s.timer_half_passed = true
      2.times { HM.poll }
      assert_equal [[T.t(:hack_time_half), false]], SpeakCapture.log
      s.timer_fourth_passed = true
      HM.poll
      assert_equal [T.t(:hack_time_quarter), false], SpeakCapture.log[-1]
    end
  end

  test "Essentials 20's timer counts frames, and the info key's line keeps up with it" do
    s = circuit
    s.timer = 30 * Graphics.frame_rate
    HM.playing(s) do
      HM.poll
      assert_includes info_row, T.t(:hack_time, :n => 30, :secs => T.t(:secs, :n => 30))
      s.timer = 12 * Graphics.frame_rate
      HM.poll
      assert_includes info_row, T.t(:hack_time, :n => 12, :secs => T.t(:secs, :n => 12))
      assert_includes info_row, up_to_locked
      assert_includes info_row, T.t(:tilt_goal, :where => HM.where(3, -1))
    end
  end

  test "Essentials 21's timer counts down the play time" do
    s = circuit
    s.instance_variable_set(:@timer_inc_per_frame, nil)
    s.instance_variable_set(:@timer_start, 100)
    s.timer = 30
    kept = $stats
    $stats = Struct.new(:play_time).new(110)
    assert_equal 20, HM.seconds(s)
    $stats = Struct.new(:play_time).new(140)
    assert_equal 0, HM.seconds(s), "never below nothing"
    $stats = kept
  end

  test "closing the scene forgets the info key's line" do
    s = circuit
    PokeAccess::Info.set_info(:text, "x", "x")
    s.pbEndScene
    assert_nil info_row
  end

  private

  # What the row key says, and what the info key does.
  def info_row; PokeAccess::Info.instance_variable_get(:@row); end
  def info_data; PokeAccess::Info.instance_variable_get(:@data); end

  def with_hints(on)
    meta = (class << PokeAccess::Verbosity; self; end)
    meta.send(:alias_method, :hack_spec_hints, :hints?)
    PokeAccess::Verbosity.define_singleton_method(:hints?) { on }
    yield
  ensure
    meta.send(:alias_method, :hints?, :hack_spec_hints)
    meta.send(:remove_method, :hack_spec_hints)
  end
end
