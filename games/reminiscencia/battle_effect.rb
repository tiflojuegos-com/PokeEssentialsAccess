module PokeAccess
  # Reminiscencia's own battle cues: the fight menu's effectiveness icon and the foe's type icons (rewriteType), and
  # the floating text over a hit ("-12.5%", "¡Muy eficaz!"), in place of the effectiveness messages the game drops.
  module ReminBattle
    # The word for each EffectivenessCheck picture, by its file name.
    EFFECT_ICONS = { "x0" => :mv_eff_none, "m4" => :mv_eff_barely, "m2" => :mv_eff_weak,
                     "x1" => :mv_eff_neutral, "x2" => :mv_eff_super, "x4" => :mv_eff_hyper }

    # The foe rewriteType measures the move against: the given index, or in a double or SOS battle the one left
    # standing.
    def self.foe(battle, index)
      bs = battle.battlers
      pk = bs[index]
      if (battle.doublebattle rescue false) || (battle.sosbattle rescue false)
        pk = bs[1] if (bs[3].isFainted? rescue false)
        pk = bs[3] if (bs[1].isFainted? rescue false)
      end
      pk
    end

    # Speaks, queued, the effectiveness icon rewriteType just painted and, from full, the foe's shown types; nothing
    # while the icon is hidden or when the focus and the foe are unchanged.
    # param args rewriteType's (move type, foe index)
    def self.fight_effect(scene, args)
      icon = PokeAccess.sprite(scene, "effectivenessIcon")
      return unless icon && (icon.visible rescue false)
      key = EFFECT_ICONS[File.basename((icon.name rescue "").to_s, ".*")]
      return unless key
      pk = foe(PokeAccess.ivar(scene, :@battle), args[1] || 1)
      types = pk ? PokeAccess::Battle.shown_types(pk) : []
      idx = (PokeAccess.sprite(scene, "fightwindow").index rescue nil)
      return unless PokeAccess::Cursor.changed?(scene, :rem_effect, [idx, key, types, (pk.name rescue nil)])
      parts = [[PokeAccess::I18n.t(key), :brief]]
      unless types.empty?
        parts.push([PokeAccess::I18n.t(:rem_bt_foe_types, :name => (pk.name rescue ""), :t => types.join(" ")), :full])
      end
      PokeAccess.speak(PokeAccess::Verbosity.line(:battle_move, parts, ". "), false, :menu)
    rescue StandardError
      nil
    end

    # Whether the game's HP option shows hit points as a percentage.
    def self.percent?
      ($PokemonSystem.porcentaje == 1 rescue false) ? true : false
    end

    # A change of hit points as the percentage of the total the floating text paints, two decimals at most.
    def self.percent_text(diff, total)
      return "0" if total.to_i <= 0
      v = (diff.abs * 10000.0 / total.to_i).round / 100.0
      PokeAccess::I18n.number(v == v.to_i ? v.to_i : v)
    end

    # Keeps the effectiveness pbDamageAnimation was given for a hit on a battler (1 not very, 2 super), for that
    # battler's next loss alone.
    def self.note_hit(pkmn, effectiveness)
      (@hits ||= {})[(pkmn.index rescue nil)] = effectiveness
    end

    # Forgets the hits no loss followed, as a new turn's fight menu opens.
    def self.forget_hits
      @hits = {}
    end

    # The effectiveness word of the hit behind this loss, taken once; a loss with no hit before it (poison, recoil)
    # has none, though the game leaves its "not very effective" text painted.
    def self.effect_word(pkmn)
      key = { 1 => :mv_eff_weak, 2 => :mv_eff_super }[(@hits ||= {}).delete((pkmn.index rescue nil))]
      key ? PokeAccess::I18n.t(key) : nil
    end

    # The hit points line as the floating text over the target paints it: the change in hit points, or with the
    # percent option its share of the total, a loss led by its effectiveness word; then what is left, as the box.
    def self.hp_change(pkmn, oldhp)
      return unless pkmn && oldhp
      diff = (pkmn.hp - oldhp rescue 0)
      return if diff == 0
      bt = PokeAccess::Battle
      verb = PokeAccess::I18n.t(diff < 0 ? :bt_lose : :bt_gain)
      rest = bt.shown_hp(pkmn, (pkmn.index.odd? rescue false))
      line = if percent?
               PokeAccess::I18n.t(:rem_bt_hp_change_pct, :name => pkmn.name, :verb => verb,
                                  :n => percent_text(diff, pkmn.totalhp), :rest => rest)
             else
               PokeAccess::I18n.t(:bt_hp_change, :name => pkmn.name, :verb => verb, :n => diff.abs, :rest => rest)
             end
      PokeAccess.speak(PokeAccess.sentences([diff < 0 ? effect_word(pkmn) : nil, line]), false)
    end
  end
end

PokeAccess::Game.define("reminiscencia") do
  before("PokeBattle_Scene", :pbFightMenu, :optional => true) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :rem_effect)
    PokeAccess::ReminBattle.forget_hits
  end
  after("PokeBattle_Scene", :pbDamageAnimation, :optional => true) do |_scene, _r, args|
    PokeAccess::ReminBattle.note_hit(args[0], args[1])
  end
  after("PokeBattle_Scene", :rewriteType, :optional => true) do |scene, _r, args|
    PokeAccess::ReminBattle.fight_effect(scene, args)
  end
end

# The hit points line of this game, as its floating text paints it, in place of the core's.
PokeAccess::Game.define("reminiscencia") do
  override("PokeAccess::Battle", :announce_hp_change) do |_mod, _original, args|
    PokeAccess::ReminBattle.hp_change(args[0], args[1])
  end
end
