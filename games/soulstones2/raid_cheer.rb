# The in-battle half of Soulstones 2's edited DBK Raid Battles: the boss's barrier, the turn and knock out counters
# its databox paints (also on the boss's HP key line), and the cheer menu, whose polled 2x2 buttons are read with their
# description at the cheer level said as it opens.
module PokeAccess
  module SS2Cheer
    MAX_LEVEL = 3
    # The raid rules the boss's databox paints as counters ("TURN:n", "KO:n"), in its order, each with its line's key.
    COUNTERS = [[:turn_count, :ss2_raid_turns], [:ko_count, :ss2_raid_kos]]

    # The player's side's cheer level, read from the battle because the window is filled after it opens.
    def self.level(scene)
      b = PokeAccess.ivar(scene, :@battle)
      (b.cheerLevel[0][0] rescue nil)
    end

    def self.level_text(scene)
      lvl = level(scene)
      lvl ? PokeAccess::I18n.t(:ss2_cheer_lvl, :n => lvl, :max => MAX_LEVEL) : nil
    end

    # The focused button as [index, text], or nil while the window is not readable yet.
    def self.focus(scene)
      win = PokeAccess.sprite(scene, "cheerWindow")
      idx = (win.index rescue nil)
      cheer = (win.cheers[idx] rescue nil)
      return nil unless cheer
      [idx, lambda { line(cheer, (win.cheerLvl rescue 0).to_i) }]
    end

    # The shout on the button, then what it does at this level while descriptions are said; the info key keeps
    # both. The kit's :None placeholder has a name and no shout.
    def self.line(cheer, lvl)
      nm = PokeAccess.clean((cheer.cheer_text rescue nil))
      nm = PokeAccess.clean((cheer.name rescue nil)) if nm.empty?
      desc = PokeAccess.clean((cheer.description(lvl) rescue nil))
      PokeAccess::Verbosity.info_line(:descriptions, [[nm, :brief], [desc, :full]])
    end

    # The bars left on the boss's barrier, or nil. Zero is the kit's own "barrier disappeared" message.
    def self.shield_text(scene, battler)
      return nil unless (battler.opposes? rescue false)
      hp = (battler.shieldHP rescue nil).to_i
      return nil unless hp > 0
      max = (PokeAccess.ivar(scene, :@battle).raidRules[:shield_hp] rescue nil).to_i
      max > 0 ? PokeAccess::I18n.t(:ss2_raid_shield, :n => hp, :max => max) : nil
    end

    # The counters a raid boss's databox paints (draw_plugin_elements) as [key, count, line], each while its rule
    # counts, from 0 up; none for any other battler.
    def self.counters(battler)
      return [] unless (battler.isRaidBoss? rescue false)
      rules = (battler.battle.raidRules rescue nil)
      return [] unless rules.is_a?(Hash)
      COUNTERS.map do |rule, key|
        n = rules[rule]
        n.is_a?(Integer) && n >= 0 ? [key, n, PokeAccess::I18n.t(key, :n => n)] : nil
      end.compact
    end

    # The counters as the HP key adds them to a raid boss's line, or nil.
    def self.counters_text(battler)
      lines = counters(battler).map { |c| c[2] }
      lines.empty? ? nil : lines.join(", ")
    end

    # A battler's HP line with the counters its raid box paints, ahead of the stat changes that close the line; any
    # other battler's line as it is.
    def self.state(battler, line)
      raid = counters_text(battler)
      return line if line.nil? || raid.nil?
      changes = PokeAccess::Battle.stat_changes(battler)
      cut = (!changes.empty? && line.end_with?(changes)) ? line.length - changes.length : line.length
      "#{line[0, cut]}, #{raid}#{line[cut..-1]}"
    end

    # A repaint of a databox: says, queued, the counters that changed since the battle's last paint, every one on its
    # first; the battle holds what was said, so a box made again for the same battle says nothing new.
    def self.box_painted(box)
      b = PokeAccess.ivar(box, :@battler)
      battle = (b.battle rescue nil)
      return unless battle
      fresh = counters(b).select { |key, n, _line| PokeAccess::Cursor.changed?(battle, key, n) }
      PokeAccess.speak(fresh.map { |c| c[2] }.join(", "), false) unless fresh.empty?
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  # Before: the original is the bar animation and blocks. The kit calls it only when a bar changed.
  before("Battle::Scene", :pbAnimateRaidShield, :optional => true) do |scene, args|
    PokeAccess.speak(PokeAccess::SS2Cheer.shield_text(scene, args[0]), false)
  end

  # Before and queued: pbChooseCheer blocks in its own loop, and the level is what the buttons mean.
  read_on_open("Battle::Scene", :pbChooseCheer, :optional => true, :timing => :before) do |scene|
    PokeAccess::SS2Cheer.level_text(scene)
  end

  # The kit repaints the boss's box (pbRefreshOne) each time it changes a counter, so the change is said as it is drawn.
  after("Battle::Scene::RaidPokemonDataBox", :draw_plugin_elements) do |box, _r, _a|
    PokeAccess::SS2Cheer.box_painted(box)
  end

  # The HP key keeps the counters at every level, as counts.
  override("PokeAccess::Battle", :battler_state) do |_mod, original, args|
    PokeAccess::SS2Cheer.state(args[0], original.call)
  end
end

PokeAccess::SceneWatcher.reader("Battle::Scene", :pbChooseCheer, :ss2_cheer, :optional => true) do |scene|
  PokeAccess::SS2Cheer.focus(scene)
end
