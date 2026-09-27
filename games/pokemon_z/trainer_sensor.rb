# Drimer's Trainer Sensor as Pokemon Z edits it: two dark bars slide in while a trainer not yet beaten is in range and out
# when none is, with no text; their coming in is said, their leaving is silent.
module PokeAccess
  module ZTrainerBars
    @shown = false

    # Whether the bars can be seen: Pokemon Z fills them clear when its switch 411 was on as they were first made.
    def self.opaque?(sensor)
      top = PokeAccess.ivar(sensor, :@top)
      (top.bitmap.get_pixel(0, 0).alpha > 0 rescue true)
    end

    # One frame of the bars: says their coming in, once, while they can be seen.
    def self.tick(sensor)
      on = (sensor.triggered? rescue false) ? true : false
      PokeAccess.speak(PokeAccess::I18n.t(:trainer_near), false) if on && !@shown && opaque?(sensor)
      @shown = on
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.wrap_singleton("TrainerSensor", :update, "pokemon_z_trainer_sensor", :after) do |_args, _r|
  PokeAccess::ZTrainerBars.tick(PokeAccess.const_at("TrainerSensor"))
end
