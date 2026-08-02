# Fabricates map events and scenes shaped exactly as the readers inspect them, so behaviour specs can feed
# a typed event to the locator (target_name) or drive a summary scene's hook. The event shape mirrors RMXP:
# an inner @event with .pages (each .trigger/.graphic.character_name/.graphic.pattern/.list/.condition), a
# live @page (active page) and a direct .character_name.

# A single RMXP-style event command (code + parameters), e.g. 201 transfer, 355 script.
class TestCmd
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

# A Game_Event-like wrapper: exposes @event (raw, with pages), @page (active page) and a direct
# character_name, which is what the locator's predicates read. A test may set @blocking to make the tile it
# stands on impassable, mirroring a solid event in the real engine.
class TestGameEvent
  attr_accessor :id, :name, :x, :y, :character_name, :direction, :blocking
  def initialize(opts = {})
    @id = opts.fetch(:id, 1)
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
              [TestPage.new(:trigger => 0, :sprite => "npc")]
            end
    ev = TestGameEvent.new(base.merge(:pages => pages, :active_page => pages[opts.fetch(:active, 0)]))
    ($game_map.events[ev.id] = ev) if $game_map.respond_to?(:events) && $game_map.events.is_a?(Hash)
    ev
  end

  # Clears the test map's events (call between event specs so per-map caches rebuild cleanly).
  def self.clear_events
    $game_map.events.clear if $game_map.respond_to?(:events) && $game_map.events.is_a?(Hash)
  end

  # A gen-6 summary scene (the real stubbed PokemonSummaryScene the hooks wrap); set @pokemon and call
  # pbUpdate to drive the per-frame reader.
  def self.summary_scene(opts = {})
    PokemonSummaryScene.new(opts.fetch(:pokemon, Poke.build))
  end

  # A bare scene stub carrying the given ivars, for readers that only inspect instance variables
  # (the SceneWatcher/read_on_open shape). Keys may be :@page or :page -- the @ is added if missing.
  #   scene = World.stub_scene(:@select => 2, :@commands => ["A", "B"])
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
