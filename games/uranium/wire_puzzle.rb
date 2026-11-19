module PokeAccess
  # Read Uranium's active wire controls and its existing connection state.
  module UraniumWire
    MAPS = [250, 268, 269, 270].freeze
    RESETS = { 268 => [15, 29], 269 => [20, 36], 270 => [1] }.freeze
    NODE = /(?:\A|;)Wire(Start|End)([A-D])(?::|;|\z)/
    CIRCUITS = %w[A B C D].freeze

    MEMORY_SCREENS = {
      268 => { 1 => 1, 2 => 2, 7 => 4, 8 => 3 }.freeze,
      269 => { 1 => 8, 4 => 5, 5 => 7, 6 => 6 }.freeze,
      270 => { 2 => 9, 3 => 10 }.freeze
    }.freeze

    # The original Bank's action screens share graphics even when their memory numbers differ.
    def self.screen_number(event)
      screens = MEMORY_SCREENS[($game_map.map_id rescue nil)]
      return nil unless screens && event.character_name.to_s =~ /\Amemory[1-4]\z/
      number = screens[event.id]
      return nil unless number && PokeAccess.ivar(event, :@trigger) == 0
      list = PokeAccess.ivar(event, :@list)
      number if list.is_a?(Array) && list.any? { |command| (command.code rescue 0) == 101 }
    end

    def self.screen_name(event)
      number = screen_number(event)
      PokeAccess::I18n.t(:ura_memory_screen, :n => number) if number
    end

    def self.active_scripts(event)
      return [] unless PokeAccess.ivar(event, :@trigger) == 0
      list = PokeAccess.ivar(event, :@list)
      return [] unless list.is_a?(Array)
      list.map { |command| PokeAccess::Routes::Effects.script_of(command) }.compact
    end

    def self.node(event)
      match = NODE.match(event.name.to_s)
      return nil unless match
      circuit = match[2]
      script = /\A\s*WirePuzzle\.setColor\(\s*:#{circuit}\s*\)\s*;?\s*\z/
      return nil unless active_scripts(event).any? { |line| line =~ script }
      [match[1] == "Start" ? :ura_wire_start : :ura_wire_end, { :circuit => circuit }]
    end

    def self.reset(event)
      script = /\A\s*WirePuzzle\.resetWires\(\s*\)\s*;?\s*\z/
      active_scripts(event).any? { |line| line =~ script } ? :ura_wire_reset : nil
    end

    def self.endpoints
      return nil unless defined?(::WirePuzzle) && $game_map && MAPS.include?($game_map.map_id)
      values = ::WirePuzzle.send(:class_variable_get, :@@endPointStates)
      values.is_a?(Hash) && !values.empty? ? values : nil
    end

    # The game stops its shared switch check at the first incomplete endpoint.
    # Check the current wire geometry to report each endpoint independently.
    def self.connected?(color, x, y)
      target = [x, y]
      starts = ::WirePuzzle.send(:class_variable_get, :@@startPoints)
      (starts[color] || []).any? do |point|
        point != target && ::WirePuzzle.checkConnection(point, target, color)
      end
    end

    def self.status
      values = endpoints
      return nil unless values
      color = ::WirePuzzle.send(:class_variable_get, :@@currentColor)
      drawing = color.is_a?(Integer) && color.between?(1, 4) ? CIRCUITS[color - 1] : nil
      connected = values.keys.select { |node| connected?(*node) }.length
      count = PokeAccess::I18n.t(:ura_wire_connections, :connected => connected, :total => values.length)
      return count unless drawing
      PokeAccess.sentences([PokeAccess::I18n.t(:ura_wire_drawing, :circuit => drawing), count])
    end
  end
end

PokeAccess::Game.define("uranium") do
  event_category(:objects) { |ev| PokeAccess::UraniumWire.screen_number(ev) }
  event_name { |ev| PokeAccess::UraniumWire.screen_name(ev) }
  PokeAccess::UraniumWire::MAPS.each do |map|
    reset_ids = PokeAccess::UraniumWire::RESETS[map]
    screens = PokeAccess::UraniumWire::MEMORY_SCREENS[map]
    mechanic(:state, map, :part => :wire) do
      auto
      if screens
        name(screens.keys, lambda { |ev| PokeAccess::UraniumWire.screen_name(ev) },
             :when => lambda { |ev| PokeAccess::UraniumWire.screen_number(ev) }, :assist => true)
      end
      name(PokeAccess::UraniumWire::NODE, lambda { |ev| PokeAccess::UraniumWire.node(ev) },
           :when => lambda { |ev| PokeAccess::UraniumWire.node(ev) }, :assist => true)
      if reset_ids
        name(reset_ids, lambda { |ev| PokeAccess::UraniumWire.reset(ev) },
             :when => lambda { |ev| PokeAccess::UraniumWire.reset(ev) }, :assist => true)
      end
      active { PokeAccess::UraniumWire.endpoints }
      info { PokeAccess::UraniumWire.status }
    end
  end
end
