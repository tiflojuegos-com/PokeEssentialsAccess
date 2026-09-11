# The in-battle half of DBK Raid Battles (an "[Edited]" copy, hence the profile): the cheer menu that
# replaces Call in a raid, and the boss's barrier. The menu is a 2x2 grid of icon buttons driven by
# pbChooseCheer's own blocking loop, so its focus is polled; what each button does depends on the cheer
# LEVEL, so the level opens the menu and every button is read with the kit's own description for it.
module PokeAccess
  module SS2Cheer
    MAX_LEVEL = 3

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

    # The shout on the button, then what it does at this level. The kit's :None placeholder has a name and
    # no shout.
    def self.line(cheer, lvl)
      nm = PokeAccess.clean((cheer.cheer_text rescue nil))
      nm = PokeAccess.clean((cheer.name rescue nil)) if nm.empty?
      desc = PokeAccess.clean((cheer.description(lvl) rescue nil))
      desc.empty? ? nm : "#{nm}, #{desc}"
    end

    # The bars left on the boss's barrier, or nil. Zero is the kit's own "barrier disappeared" message.
    def self.shield_text(scene, battler)
      return nil unless (battler.opposes? rescue false)
      hp = (battler.shieldHP rescue nil).to_i
      return nil unless hp > 0
      max = (PokeAccess.ivar(scene, :@battle).raidRules[:shield_hp] rescue nil).to_i
      max > 0 ? PokeAccess::I18n.t(:ss2_raid_shield, :n => hp, :max => max) : nil
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
end

PokeAccess::SceneWatcher.reader("Battle::Scene", :pbChooseCheer, :ss2_cheer, :optional => true) do |scene|
  PokeAccess::SS2Cheer.focus(scene)
end
