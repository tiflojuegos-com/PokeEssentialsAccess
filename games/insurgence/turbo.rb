module PokeAccess
  # Insurgence's Speed-Up (Input::I, M by default; Input.update in 147_PokemonSystem.rb) steps
  # $PokemonSystem.turbospeed through 1, 2, 3 and back to 0, asking 100, 160 and 220 frames a second of the normal 40;
  # the core's speed line says each step's multiplier.
  module InsurgenceTurbo
    RATES = [40, 100, 160, 220]

    # Each step's multiplier over the normal rate, indexed by turbospeed.
    def self.stages
      RATES.map { |r| r / RATES[0].to_f }
    end

    # The step the game is on, nil before the first press.
    def self.step
      ($PokemonSystem.turbospeed rescue nil)
    end
  end
end

PokeAccess::Game.define("insurgence") do
  override("PokeAccess::Turbo", :current_speed) { |_m, _original, _a| PokeAccess::InsurgenceTurbo.step }
  override("PokeAccess::Turbo", :stage_table) { |_m, _original, _a| PokeAccess::InsurgenceTurbo.stages }
end
