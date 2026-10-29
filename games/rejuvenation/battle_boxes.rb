# The crest a databox paints beside a crested battler's name, said as a mark: on Rejuvenation's stock box
# (Rejuv/Battle/Battle_Scene.rb), which core reads, and on the box of an ally a boss calls in (SosPokemonDataBox), read
# below; battleApplyCrest where a trainer lent the crest's effect.
PokeAccess::Battle.icon_mark(/\AbattleCrest\z/i, :rj_mark_crest)
PokeAccess::Battle.icon_mark(/\AbattleApplyCrest\z/i, :rj_mark_applied_crest)

module PokeAccess
  # Rejuvenation's boss boxes (PokemonBossBattle.rb): a boss's box (BossPokemonDataBox) paints its shields as icons,
  # said as the box comes up and each time their count changes, listed with the boss's marks for the info key, and
  # kept on the HP key at every level, as a count.
  module RejuvBossBoxes
    # The shields a boss's box paints, or nil for any other box.
    def self.shields(box)
      box && box.respond_to?(:shieldCount) ? [PokeAccess.ivar_i(box, :@shieldCount), 0].max : nil
    end

    # Follows a boss's box while it shows: a boss seen for the first time is said with its shields, a drop as a broken
    # shield with those left, a rise as the new count.
    def self.track(box)
      return unless (box.visible rescue false)
      b = PokeAccess.ivar(box, :@battler)
      pk = b ? (b.pokemon rescue nil) : nil
      n = shields(box)
      return unless pk && n
      last = PokeAccess.ivar(b, :@pa_shields)
      b.instance_variable_set(:@pa_shields, [pk, n])
      line = if last.nil? || !last[0].equal?(pk) || n > last[1]
               "#{b.name}, #{PokeAccess::I18n.t(:ss2_shields, :n => n)}"
             elsif n < last[1]
               PokeAccess::I18n.t(:ss2_shield_broken, :n => n)
             end
      PokeAccess.speak(line, false) if line
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The shields a battler's boss box paints, or nil for a battler with none.
    def self.battler_shields(b)
      scene = (b.battle.scene rescue nil)
      scene ? shields(PokeAccess.sprite(scene, "battlebox#{b.index}")) : nil
    end

    # A battler's marks with the shields its boss box paints after them.
    def self.marks(b, marks)
      n = battler_shields(b)
      n ? marks + [PokeAccess::I18n.t(:ss2_shields, :n => n)] : marks
    end

    # A battler's HP line with its boss box's shields at its end where the marks that carry them are left out.
    def self.state(b, line)
      return line if line.nil? || PokeAccess::Verbosity.keep?(:battle_marks, :medium)
      n = battler_shields(b)
      n ? "#{line}, #{PokeAccess::I18n.t(:ss2_shields, :n => n)}" : line
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  after("BossPokemonDataBox", :refresh) { |box, _r, _a| PokeAccess::RejuvBossBoxes.track(box) }

  after("BossPokemonDataBox", :appear) { |box, _r, _a| PokeAccess::RejuvBossBoxes.track(box) }

  around("SosPokemonDataBox", :refresh) do |box, nxt, _a|
    PokeAccess::Battle.marks_around(box) { nxt.call }
  end

  override("PokeAccess::Battle", :shown_marks) do |_mod, original, args|
    PokeAccess::RejuvBossBoxes.marks(args[0], original.call)
  end

  override("PokeAccess::Battle", :battler_state) do |_mod, original, args|
    PokeAccess::RejuvBossBoxes.state(args[0], original.call)
  end
end
