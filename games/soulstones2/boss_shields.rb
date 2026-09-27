# Soulstones 2's shielded bosses: a knockout blow breaks a shield instead, said with the shields left, ahead of
# the shield's effects or, for one with none, as the counter drops, before the HP refill.
module PokeAccess
  module SS2BossShields
    @breaking = nil
    @said = false

    # Runs one shielded hit. The battler is remembered so the effects hook can tell this break from the
    # entry and delayed effects that run the same method.
    def self.around_damage(battler)
      @breaking = battler
      @said = false
      yield
    ensure
      @breaking = nil
    end

    # The break's effects are about to run: the break is said first, counting the shield it takes.
    def self.before_effects(battler)
      return unless @breaking && battler.equal?(@breaking) && !@said
      say((battler.shieldCount rescue 1).to_i - 1)
    end

    # The counter has just dropped, before the bar is refilled: a break the effects did not announce is said
    # here, with what is left.
    def self.counted(battler)
      return unless @breaking && battler.equal?(@breaking) && !@said
      say((battler.shieldCount rescue 0).to_i)
    end

    def self.say(left)
      @said = true
      PokeAccess.speak(PokeAccess::I18n.t(:ss2_shield_broken, :n => [left, 0].max), false)
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  around("Battle", :pbShieldDamage, :optional => true) do |_b, nxt, args|
    PokeAccess::SS2BossShields.around_damage(args[0]) { nxt.call }
  end

  before("Battle", :pbShieldEffects, :optional => true) do |_b, args|
    PokeAccess::SS2BossShields.before_effects(args[0])
  end

  after("Battle::Battler", :shieldCount=, :optional => true) do |battler, _r, _a|
    PokeAccess::SS2BossShields.counted(battler)
  end
end
