# Map events and scenes shaped as the readers inspect them. The event mirrors RMXP: an inner @event with .pages
# (each .trigger, .graphic, .list, .condition), a live @page and a direct .character_name.

# An RMXP event command (code, parameters, indent), e.g. 201 transfer; the indent ties a branch to its else and end.
class TestCmd
  attr_accessor :code, :parameters, :indent
  def initialize(code, parameters = [], indent = 0); @code = code; @parameters = parameters; @indent = indent; end
end

# A Set Move Route's route: its list of move commands.
class TestMoveRoute
  attr_accessor :list
  def initialize(list); @list = list; end
end

# One move command of a route (code + parameters): 1-4 steps, 12/13 forward/backward, 14 jump [x, y]...
class TestMoveCmd
  attr_accessor :code, :parameters
  def initialize(code, parameters = []); @code = code; @parameters = parameters; end
end

# A page's graphic (only character_name and pattern are read by the locator).
class TestGraphic
  attr_accessor :character_name, :pattern
  def initialize(name, pattern = 0); @character_name = name; @pattern = pattern; end
end

# A page's appear condition (switch / self-switch validity flags).
class TestCondition
  attr_accessor :switch1_valid, :self_switch_valid, :variable_valid, :switch1_id, :self_switch_ch
  def initialize(opts = {})
    @switch1_valid = opts.fetch(:switch1_valid, false)
    @self_switch_valid = opts.fetch(:self_switch_valid, false)
    @variable_valid = opts.fetch(:variable_valid, false)
    @switch1_id = opts[:switch1_id]
    @self_switch_ch = opts[:self_switch_ch]
  end
end

# One event page: trigger, graphic, command list and condition.
class TestPage
  attr_accessor :trigger, :graphic, :list, :condition
  def initialize(opts = {})
    @trigger = opts.fetch(:trigger, 0)
    @graphic = TestGraphic.new(opts.fetch(:sprite, ""), opts.fetch(:pattern, 0))
    @list = opts.fetch(:list, [])
    @condition = TestCondition.new(opts.fetch(:condition, {}))
  end
end

# The inner RPG::Event-like object holding the pages.
class TestRpgEvent
  attr_accessor :pages
  def initialize(pages); @pages = pages; end
end

# A Game_Event-like wrapper exposing @event, @page, character_name and tile_id (a tile-drawn page has no sprite
# name) as the locator reads them; blocking makes its tile impassable.
class TestGameEvent
  attr_accessor :id, :name, :x, :y, :character_name, :direction, :blocking, :tile_id, :through
  def initialize(opts = {})
    @id = opts.fetch(:id, 1)
    @tile_id = opts.fetch(:tile_id, 0)
    @name = opts.fetch(:name, "EV#{@id}")
    @x = opts.fetch(:x, 5); @y = opts.fetch(:y, 5)
    @direction = 2
    @blocking = false
    pages = opts.fetch(:pages, [TestPage.new])
    @event = TestRpgEvent.new(pages)
    @active = opts.fetch(:active_page, pages[0])
    @character_name = @active.graphic.character_name
    @list = @active.list
    @trigger = (@active.trigger rescue 0)
  end
  def instance_variable_get(sym)
    return @event if sym == :@event
    return @active if sym == :@page
    return @list if sym == :@list
    return @trigger if sym == :@trigger
    super
  end
end

# Builds a typed map event. :kind picks the data shape the locator keys on:
#   :sign    one action page, a Show-Text command, no sprite
#   :door    one player-touch page with a transfer (cmd 201), no sprite
#   :lever   two action pages, same sprite, different pattern, page 2 switch-gated, no battle/transfer
#   :trainer two action pages, same sprite, page 2 self-switch-gated, with a pbTrainerBattle script
#   :npc     one action page with a sprite (a plain person)
module World
  def self.event(opts = {})
    kind = opts.fetch(:kind, :npc)
    base = { :id => opts.fetch(:id, 1), :x => opts.fetch(:x, 5), :y => opts.fetch(:y, 5),
             :name => opts.fetch(:name, "EV#{opts.fetch(:id, 1)}") }
    pages = case kind
            when :sign
              [TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(101, ["Hi"])])]
            when :door
              [TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(201, [0, 5, 1, 1])])]
            when :lever
              [TestPage.new(:trigger => 0, :sprite => "lever", :pattern => 0),
               TestPage.new(:trigger => 0, :sprite => "lever", :pattern => 1,
                            :condition => { :switch1_valid => true, :switch1_id => 50 })]
            when :trainer
              [TestPage.new(:trigger => 0, :sprite => "hiker", :pattern => 0,
                            :list => [TestCmd.new(355, ["pbTrainerBattle(:HIKER)"])]),
               TestPage.new(:trigger => 0, :sprite => "hiker", :pattern => 1,
                            :condition => { :self_switch_valid => true, :self_switch_ch => "A" })]
            else
              [TestPage.new(:trigger => 0, :sprite => opts.fetch(:sprite, "npc"))]
            end
    ev = TestGameEvent.new(base.merge(:pages => pages, :active_page => pages[opts.fetch(:active, 0)]))
    ($game_map.events[ev.id] = ev) if $game_map.respond_to?(:events) && $game_map.events.is_a?(Hash)
    ev
  end

  # A touch event (player touch by default, no sprite) running the given command list, placed on the map.
  def self.touch(opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 1), :sprite => opts.fetch(:sprite, ""),
                        :list => opts.fetch(:list, []) + [TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => opts.fetch(:id, 1), :x => opts.fetch(:x, 5), :y => opts.fetch(:y, 5),
                           :name => opts.fetch(:name, "EV#{opts.fetch(:id, 1)}"), :pages => [page])
    ($game_map.events[ev.id] = ev) if $game_map.respond_to?(:events) && $game_map.events.is_a?(Hash)
    ev
  end

  # A Set Move Route on the player (209, target -1) walking the given move codes, at an indent.
  def self.move_player(codes, indent = 0)
    TestCmd.new(209, [-1, TestMoveRoute.new(codes.map { |c| c.is_a?(Array) ? TestMoveCmd.new(c[0], c[1]) : TestMoveCmd.new(c) })], indent)
  end

  # The command list of Emerald's cracked floor (Sky Pillar, Mirage Tower): it bears the player riding the
  # bike while a direction key is held, and drops anyone else to map below.
  def self.cracked_floor(below)
    held = "$PokemonGlobal.bicycle && (Input.press?(Input::UP) || Input.press?(Input::LEFT) || " \
           "Input.press?(Input::RIGHT) || Input.press?(Input::DOWN))"
    [TestCmd.new(123, ["A", 0]), TestCmd.new(111, [12, held]), TestCmd.new(0, [], 1), TestCmd.new(411, []),
     TestCmd.new(201, [0, below, 3, 10], 1), TestCmd.new(0, [], 1), TestCmd.new(412, [])]
  end

  # "If the player is facing <dir>" (111, character -1).
  def self.if_facing(dir, indent = 0); TestCmd.new(111, [6, -1, dir], indent); end

  # The else and the end of a conditional branch.
  def self.else_(indent = 0); TestCmd.new(411, [], indent); end
  def self.end_(indent = 0); TestCmd.new(412, [], indent); end

  # Clears the test map's events (call between event specs so per-map caches rebuild cleanly).
  def self.clear_events
    $game_map.events.clear if $game_map.respond_to?(:events) && $game_map.events.is_a?(Hash)
  end

  # A gen-6 summary scene (the real stubbed PokemonSummaryScene the hooks wrap); set @pokemon and call
  # pbUpdate to drive the per-frame reader.
  def self.summary_scene(opts = {})
    PokemonSummaryScene.new(opts.fetch(:pokemon, Poke.build))
  end

  # A bare scene stub carrying the given ivars (keys :@page or :page), for readers that only inspect ivars.
  def self.stub_scene(ivars = {})
    s = Object.new
    ivars.each do |k, v|
      name = k.to_s
      name = "@#{name}" unless name[0, 1] == "@"
      s.instance_variable_set(name.to_sym, v)
    end
    s
  end
end
