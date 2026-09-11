# The overworld half of DBK Raid Battles (an "[Edited]" copy, hence the profile): the den the portal opens
# and its rewards page. The den's three options live in a local of pbRaidEntry's loop and the only trace of
# the choice is where the loop put the cursor sprite, so that is what is read; its words are read off the
# paint, which is also where the option labels come from. The rewards list is a command window the mod
# already reads; what is added is the outcome line and the item description, the latter only while shown.
module PokeAccess
  module SS2RaidDen
    # Where the cursor sprite sits for each option (Raid Den - Scene.rb:280).
    CURSOR_TOP = 132
    CURSOR_STEP = 34
    OPTIONS = 3

    # Speaks the entry screen as painted and keeps its option labels for the cursor: the positions batch is
    # the den's name and then Begin/Leave/Change, and the raid's rules go out through drawTextEx.
    def self.open(scene)
      rows = PokeAccess::PaintCapture.take_by_source(:ss2_den)
      pos = rows[:positions] || []
      @options = pos[1, OPTIONS] || []
      PokeAccess.speak(PokeAccess::PaintCapture.text(([pos[0], boss_line(scene)] + (rows[:dtex] || [])).compact), false)
    end

    # The boss inside: species, types and rank, which the screen shows as icons and a row of stars.
    def self.boss_line(scene)
      pk = PokeAccess.ivar(scene, :@pkmn)
      return nil unless pk
      parts = [PokeAccess::Data.species_name(pk.species) || (pk.name rescue nil)]
      types = PokeAccess::Data.pokemon_types(pk)
      parts.push(PokeAccess::I18n.t(:sum_type, :t => types.join(" "))) unless types.empty?
      rank = (PokeAccess.ivar(scene, :@rules)[:rank] rescue nil)
      parts.push(PokeAccess::I18n.t(:ss2_raid_rank, :n => rank)) if rank
      parts.compact.join(", ")
    end

    # The focused option as [index, label], read off the cursor sprite.
    def self.option(scene)
      y = (PokeAccess.sprite(scene, "cursor").y rescue nil)
      return nil unless y
      i = (y.to_i - CURSOR_TOP) / CURSOR_STEP
      return nil unless i >= 0 && i < @options.to_a.length
      t = PokeAccess.clean(@options[i])
      t.empty? ? nil : [i, t]
    end

    def self.arm_rewards(scene)
      @rewards_scene = scene
      PokeAccess::PaintCapture.arm(:ss2_den_rewards)
    end

    # Speaks the rewards page once its paint has landed: the positions batch only, since the first reward's
    # description is painted at the same time into a box the page keeps hidden. A caught boss's sex is a bare
    # glyph row, replaced by the mod's own word.
    def self.say_rewards
      scene = @rewards_scene
      return unless scene && PokeAccess::PaintCapture.pending?(:ss2_den_rewards)
      @rewards_scene = nil
      rows = PokeAccess::PaintCapture.take_by_source(:ss2_den_rewards)[:positions] || []
      sex = PokeAccess::Party.gender_word(PokeAccess.ivar(scene, :@pkmn))
      PokeAccess.speak(PokeAccess::PaintCapture.text(rows.map { |r| (r.to_s =~ /[A-Za-z0-9]/) ? r : sex }.compact), false)
    end

    # The focused reward's description while its box is shown. The key carries the visibility, so asking for
    # the box again on the same item speaks again.
    def self.reward_desc(scene)
      win = PokeAccess.sprite(scene, "itemtext")
      return nil unless win
      shown = (win.visible rescue false) ? true : false
      t = PokeAccess.clean((win.text rescue nil))
      return nil if t.empty?
      [[t, shown], shown ? t : nil]
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  # The den paints between the saving prompt and its loop, so the capture is armed when the prompt answers
  # yes. hook_container: the prompt delegates its words to the message hooks it drives.
  after("RaidScene", :pbSavingPrompt, :optional => true, :hook_container => true) do |_s, ret, _a|
    PokeAccess::PaintCapture.arm(:ss2_den) if ret
  end

  before("RaidScene", :pbRaidEntry, :optional => true) do |scene, _a|
    PokeAccess::SS2RaidDen.open(scene)
  end

  before("RaidScene", :pbRaidRewardsScreen, :optional => true) do |scene, _a|
    PokeAccess::SS2RaidDen.arm_rewards(scene)
  end

  # The rewards page paints and then blocks, so its paint is spoken from the frame poll.
  poll_each_frame { PokeAccess::SS2RaidDen.say_rewards }
end

PokeAccess::SceneWatcher.reader("RaidScene", :pbRaidEntry, :ss2_den_opt, :optional => true) do |scene|
  PokeAccess::SS2RaidDen.option(scene)
end

PokeAccess::SceneWatcher.reader("RaidScene", :pbRaidRewardsScreen, :ss2_den_desc, :optional => true) do |scene|
  PokeAccess::SS2RaidDen.reward_desc(scene)
end
