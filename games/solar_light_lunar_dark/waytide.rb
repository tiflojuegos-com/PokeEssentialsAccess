# These Waytide floor switches set a flag on contact. Their next page transfers
# the player, so the active page has no dialogue or direct transfer to detect.
module PokeAccess
  module Waytide
    FLAGS = { 288 => 545, 289 => 546, 290 => 547, 291 => 548,
              293 => 549, 294 => 550, 295 => 551 }.freeze

    def self.activation(event)
      return nil unless PokeAccess::Config.scene_guidance && $game_map && $game_switches
      flag = FLAGS[$game_map.map_id]
      return nil unless flag && event.id == 1 && !$game_switches[flag]

      record = PokeAccess::World::Events.record_of(event)
      return nil unless record && record.page && record.trigger == 1 && record.tile == 2331 && record.char.to_s.empty?
      list = PokeAccess.ivar(event, :@list)
      return nil unless list.is_a?(Array)
      commands = list.reject { |command| [0, 108, 408].include?(command.code) }
      return nil unless commands.length == 1 && commands[0].code == 121 && commands[0].parameters == [flag, flag, 0]
      :onto if PokeAccess::Routes::Effects.fires_on_arrival?(event)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

# Scene guidance is an optional shared Access feature.
if defined?(PokeAccess::SceneTriggers)
  PokeAccess::Game.define("solar_light_lunar_dark") do
    override("PokeAccess::SceneTriggers", :activation) do |_reader, original, args|
      original.call || PokeAccess::Waytide.activation(args[0])
    end
  end
end
