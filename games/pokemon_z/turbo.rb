# Pokemon Z's speed key (TurboNuevo: Q or Alt steps $GameSpeed inside Input.update, in any scene). The core says a
# change on the free map and stays silent elsewhere, where other games move the speed by themselves; in Z only the
# key moves it inside Input.update, so a change made there off the map, in a battle, is said too.
module PokeAccess
  module ZTurbo
    # Runs one Input.update (the block) and says the new multiplier when the speed index moved inside it off the free
    # map; the block's value is kept.
    def self.around_update
      before = PokeAccess::Turbo.current_speed
      r = yield
      now = PokeAccess::Turbo.current_speed
      PokeAccess::Turbo.say_speed(now) if !now.nil? && now != before && !PokeAccess::Turbo.free_map?
      r
    end
  end
end

PokeAccess::Hooks.wrap_singleton("Input", :update, "z_turbo_key", :around) do |_args, call_next|
  PokeAccess::ZTurbo.around_update { call_next.call }
end
