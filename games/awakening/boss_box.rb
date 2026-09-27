# Awakening's boss battles (switch 200): no sex sign, and no level for a foe, as the databox draws them; a boss's life
# icons (variable 189) said with its hit points, and the life it loses as its bar breaks.
module PokeAccess
  module AwakeningBossBox
    SWITCH = 200

    def self.on?
      ($game_switches[SWITCH] rescue false) ? true : false
    end

    # The life icons a battler's box draws: one per life past the current bar (lives - 1), or 0.
    def self.spare_lives(b)
      n = (b.lives rescue 1).to_i
      n > 1 ? n - 1 : 0
    end

    # The hit points as the box shows them, with its life icons after them when it draws any.
    def self.with_lives(b, hp)
      n = spare_lives(b)
      n > 0 ? "#{hp}, #{PokeAccess::I18n.t(:awk_lives, :n => n)}" : hp
    end

    # Said as the bar breaks (pbBreakBar, after the life is taken): the life lost and the icons left, or that this is
    # the last life.
    def self.life_lost(b)
      n = spare_lives(b)
      rest = n > 0 ? PokeAccess::I18n.t(:awk_lives_left, :n => n) : PokeAccess::I18n.t(:awk_lives_last)
      PokeAccess.speak(PokeAccess::I18n.t(:awk_life_lost, :name => b.name, :rest => rest), false)
    rescue StandardError
      nil
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
  override("PokeAccess::Battle", :shown_hp) do |_mod, original, args|
    PokeAccess::AwakeningBossBox.with_lives(args[0], original.call)
  end
  before("PokeBattle_Scene", :pbBreakBar, :optional => true) do |_s, args|
    PokeAccess::AwakeningBossBox.life_lost(args[0])
  end
end
