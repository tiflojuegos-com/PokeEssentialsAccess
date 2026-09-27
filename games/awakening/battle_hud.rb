# Awakening's battle HUD: the impulse meters beside the databoxes, the fight menu's impulse button (F) and route D's
# cursed-energy gem, which the command menu paints under switch 650.
module PokeAccess
  module AwakeningBattleHud
    IMPULSE_MAX = 5
    FOE_METER_VAR = 150
    GEM_SWITCH = 650
    ENERGY_VAR = 399

    # The trainers whose meter the scene draws on a side: the player's (the first of a pair), or each foe's while
    # variable 150 is above 0.
    def self.meter_trainers(battle, foe)
      if foe
        return [] unless ($game_variables[FOE_METER_VAR] rescue 0).to_i > 0
        opp = (battle.opponent rescue nil)
        return opp.is_a?(Array) ? opp : [opp].compact
      end
      pl = (battle.player rescue nil)
      [pl.is_a?(Array) ? pl[0] : pl].compact
    end

    # The meters of a side as "impulses: n of 5", or nil where the scene draws none.
    def self.meter_text(battle, foe)
      vals = meter_trainers(battle, foe).map { |t| (t.impulses rescue nil) }.select { |v| v.is_a?(Integer) }
      return nil if vals.empty?
      key = foe ? :awk_impulses_foe : :awk_impulses
      vals.map { |v| PokeAccess::I18n.t(key, :n => v, :max => IMPULSE_MAX) }.join(", ")
    end

    # The player's impulse count, or nil.
    def self.player_impulses(battle)
      pl = (battle.player rescue nil)
      pl = pl[0] if pl.is_a?(Array)
      v = (pl.impulses rescue nil)
      v.is_a?(Integer) ? v : nil
    end

    # Said as the fight menu sets its impulse button (0 hidden, 1 shown, 2 on): that the impulse is ready as the
    # button comes up with a full meter, and on or off as F toggles it.
    def self.button(disp, v, battle)
      last = disp.instance_variable_get(:@access_impulse)
      disp.instance_variable_set(:@access_impulse, v) if v.is_a?(Integer)
      if v == 1 && (last.nil? || last == 0)
        return unless (player_impulses(battle) || 0) >= IMPULSE_MAX
        ready = PokeAccess::I18n.t(:awk_impulse_ready)
        PokeAccess.speak(PokeAccess::Verbosity.with_hint(ready, PokeAccess::I18n.t(:awk_impulse_key)), false)
      elsif v == 2 && last == 1
        PokeAccess.speak(PokeAccess::I18n.t(:awk_impulse_on), true)
      elsif v == 1 && last == 2
        PokeAccess.speak(PokeAccess::I18n.t(:awk_impulse_off), true)
      end
    rescue StandardError
      nil
    end

    # The battle behind a fight menu: its battler's, else the one the battle hooks hold.
    def self.battle_of(disp)
      (disp.battler.battle rescue nil) || PokeAccess::Battle.battle
    end

    # The gem the command menu paints for the cursed energy: 0 (emaldita) at none, then emaldita1 to emaldita5 for
    # 1-25, 26-50, 51-70, 71-99 and anything else.
    def self.gem_level(energy)
      case energy.to_i
      when 0 then 0
      when 1..25 then 1
      when 26..50 then 2
      when 51..70 then 3
      when 71..99 then 4
      else 5
      end
    end

    # Said as the command menu opens under switch 650, each battle and whenever the gem changes picture: the
    # energy, and with the full gem that a talisman is ready, with its key.
    def self.gem(scene)
      return unless ($game_switches[GEM_SWITCH] rescue false)
      energy = ($game_variables[ENERGY_VAR] || 0).to_i
      level = gem_level(energy)
      battle = PokeAccess.ivar(scene, :@battle)
      PokeAccess::Cursor.announce(nil, :awk_gem, [battle.__id__, level], false) do
        t = PokeAccess::I18n.t(:awk_energy, :n => energy)
        next t if level < 5
        ready = "#{t}. #{PokeAccess::I18n.t(:awk_gem_ready)}"
        PokeAccess::Verbosity.with_hint(ready, PokeAccess::KeyHints.localize(PokeAccess::I18n.t(:awk_gem_key)))
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("awakening") do
  # The HP key's side, then that side's impulse meters, queued after it.
  override("PokeAccess::Battle", :announce_hp) do |mod, original, args|
    original.call
    battle = mod.battle
    t = battle ? PokeAccess::AwakeningBattleHud.meter_text(battle, args[0] ? true : false) : nil
    PokeAccess.speak(t, false) if t
  end
  after("FightMenuDisplay", :impulseButton=, :optional => true) do |disp, _r, args|
    PokeAccess::AwakeningBattleHud.button(disp, args[0], PokeAccess::AwakeningBattleHud.battle_of(disp))
  end
  before("PokeBattle_Scene", :pbCommandMenuEx, :optional => true) { |s, _a| PokeAccess::AwakeningBattleHud.gem(s) }
end
