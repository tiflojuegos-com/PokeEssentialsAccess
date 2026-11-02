# Awakening's boss battles (switch 200): no sex sign, and no level for a foe, as the databox draws them. Its lives are
# plugins/battle_lives.rb's.
module PokeAccess
  module AwakeningBossBox
    SWITCH = 200

    def self.on?
      ($game_switches[SWITCH] rescue false) ? true : false
    end
  end
end

PokeAccess::Game.define("awakening") do
  override("PokeAccess::Battle", :shown_sex) do |_mod, original, _args|
    PokeAccess::AwakeningBossBox.on? ? "" : original.call
  end
  override("PokeAccess::Battle", :shown_level) do |_mod, original, args|
    PokeAccess::AwakeningBossBox.on? && (args[0].index.odd? rescue false) ? nil : original.call
  end
end
