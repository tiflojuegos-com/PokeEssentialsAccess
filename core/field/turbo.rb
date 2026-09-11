module PokeAccess
  # The speed toggle, which every fangame ships (BES-T and Delta "Speed Up", Royal's own, the gen-6 frame-rate
  # switch) and none of them voices. A poller watches what those scripts move -- $GameSpeed or
  # Graphics.frame_rate, the rate the game ASKS for, never the frames it draws -- and speaks the multiplier,
  # or fast/normal against the rate the map first showed, only when the answer flips and only on the map:
  # battles move the speed by themselves, and coming back re-syncs silently.
  module Turbo
    @speed = nil
    @rate = nil
    @base_rate = nil
    @fast = false
    @on_map = false

    # One frame: notices a speed index or frame-rate change on the map and says it.
    def self.tick
      on_map = free_map?
      speed = current_speed
      rate = (Graphics.frame_rate rescue nil)
      unless on_map && @on_map
        @on_map = on_map
        @speed = speed
        @rate = rate
        @base_rate ||= rate if on_map
        @fast = fast?(rate)
        return
      end
      if speed != @speed
        @speed = speed
        @rate = rate
        @fast = fast?(rate)
        say_speed(speed) unless speed.nil?
      elsif rate != @rate
        @rate = rate
        was = @fast
        @fast = fast?(rate)
        say_rate(@fast) if @fast != was
      end
    rescue StandardError
      nil
    end

    # True on the map with no battle running, in either era's terms.
    def self.free_map?
      return false unless $game_player && $scene.is_a?(Scene_Map)
      return false if (PokeAccess::Battle.in_battle? rescue false)
      return false if ($game_temp && $game_temp.in_battle rescue false)
      true
    end

    # Whether a frame rate is above the one the map first showed.
    def self.fast?(rate)
      !!(@base_rate && rate && rate.to_i > @base_rate.to_i)
    end

    # The speed index the game's script keeps, nil where the game has none.
    def self.current_speed
      defined?($GameSpeed) ? $GameSpeed : nil
    end

    # The multiplier for a speed index: the script's table when it has one (SPEEDUP_STAGES in the Speed Up
    # and Delta scripts, TurboConfig::SPEED_STAGES in Royal's own), else the index counted from 1; a whole
    # number says itself without a decimal.
    def self.multiplier(speed)
      table = stage_table
      n = table ? table[speed.to_i] : nil
      n = speed.to_i + 1 if n.nil?
      n == n.to_i ? n.to_i : n
    end

    # The speed table the running game declares, or nil.
    def self.stage_table
      return SPEEDUP_STAGES if defined?(SPEEDUP_STAGES) && SPEEDUP_STAGES.is_a?(Array)
      royal = (TurboConfig::SPEED_STAGES rescue nil)
      royal.is_a?(Array) ? royal : nil
    end

    def self.say_speed(speed)
      PokeAccess.speak(PokeAccess::I18n.t(:turbo_speed, :n => multiplier(speed)), true)
    end

    def self.say_rate(fast)
      PokeAccess.speak(PokeAccess::I18n.t(fast ? :turbo_on : :turbo_off), true)
    end
  end
end

PokeAccess::Keys.on_frame { PokeAccess::Turbo.tick }
