# Drimer's Trainer Sensor as Sky's base ships it ("Barras entrenadores": Anil, Royal, Revival), and as World Frontier
# edits it, its bars fading in by closeness: two dark bars come in while a trainer not yet beaten is in range and go out
# when none is, with no text. Their coming in is said once, as soon as they can be seen; their leaving is silent.
module PokeAccess
  module SkyTrainerBars
    @said = false

    # Whether the bars can be seen: their top row holds some colour (World Frontier's fade in starts clear).
    def self.opaque?(sensor)
      top = PokeAccess.ivar(sensor, :@top)
      (top.bitmap.get_pixel(0, 0).alpha > 0 rescue true)
    end

    # One frame of the bars: says their coming in once while they are in, the first frame they can be seen.
    def self.tick(sensor)
      on = (sensor.triggered? rescue false) ? true : false
      if on && !@said && opaque?(sensor)
        PokeAccess.speak(PokeAccess::I18n.t(:trainer_near), false)
        @said = true
      end
      @said = false unless on
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.wrap_singleton("TrainerSensor", :update, "skyflyer_common_trainer_sensor", :after) do |_args, _r|
  PokeAccess::SkyTrainerBars.tick(PokeAccess.const_at("TrainerSensor"))
end
