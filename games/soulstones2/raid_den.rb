# The overworld half of Soulstones 2's edited DBK Raid Battles: the den, read as painted with its option told by
# the cursor sprite's height, and the rewards page's outcome line and item description (core reads the list).
module PokeAccess
  module SS2RaidDen
    # Where the cursor sprite sits for each option (Raid Den - Scene.rb:280).
    CURSOR_TOP = 132
    CURSOR_STEP = 34
    OPTIONS = 3
    # The party icon sprites the entry screen can hold, partyicon_0 onwards.
    PARTY_ICONS = 6

    # Speaks the entry screen as painted and keeps its option labels for the cursor: the positions batch is
    # the den's name and then Begin/Leave/Change, and the raid's rules go out through drawTextEx.
    def self.open(scene)
      rows = PokeAccess::PaintCapture.take_by_source(:ss2_den)
      pos = rows[:positions] || []
      @options = pos[1, OPTIONS] || []
      PokeAccess::Cursor.store(scene, :ss2_den_party, party_key(scene))
      parts = [pos[0], boss_line(scene)] + icon_parts(scene) + (rows[:dtex] || []) + [party_line(scene)]
      PokeAccess.speak(PokeAccess::PaintCapture.text(parts.compact), false)
    end

    # The boss inside as the screen shows it: a silhouette, its types and its rank. Its species stays unsaid
    # until the rewards page names it.
    def self.boss_line(scene)
      pk = PokeAccess.ivar(scene, :@pkmn)
      return nil unless pk
      parts = [PokeAccess::I18n.t(:ss2_raid_hidden)]
      types = PokeAccess::Data.pokemon_types(pk)
      parts.push(PokeAccess::I18n.t(:pc_types, :t => types.join(" "))) unless types.empty?
      rank = (PokeAccess.ivar(scene, :@rules)[:rank] rescue nil)
      parts.push(PokeAccess::I18n.t(:ss2_raid_rank, :n => rank)) if rank
      parts.join(", ")
    end

    # The entry screen's other icons: the bonus loot and online marks, and the field conditions.
    def self.icon_parts(scene)
      rules = PokeAccess.ivar(scene, :@rules)
      rules = {} unless rules.is_a?(Hash)
      out = []
      out.push(PokeAccess::I18n.t(:ss2_raid_bonus)) if rules[:loot]
      out.push(PokeAccess::I18n.t(:ss2_raid_online)) if rules[:online]
      field = field_line(scene, rules)
      out.push(field) if field
      out
    end

    # The weather, terrain and environment icons, painted only when they are not none, none and the den style's
    # own environment; a none among them is a blank icon and is left out.
    def self.field_line(scene, rules)
      conds = [PokeAccess.ivar(scene, :@weather), PokeAccess.ivar(scene, :@terrain), PokeAccess.ivar(scene, :@environ)]
      base = (GameData::RaidType.get(rules[:style]).battle_environ rescue nil)
      return nil if conds == [:None, :None, base]
      names = [weather_name(conds[0]), terrain_name(conds[1]), environ_name(conds[2])].compact
      names.empty? ? nil : PokeAccess::I18n.t(:ss2_raid_field, :list => names.join(", "))
    end

    def self.weather_name(w)
      PokeAccess::Battle.weather_name(w) || PokeAccess::Battle.overworld_weather_name(w)
    end

    def self.terrain_name(t)
      key = PokeAccess::Battle::TERRAIN_SYMS[t]
      key ? PokeAccess::I18n.t(key) : nil
    end

    # The game's own name for a battle environment, or its id where the data has none.
    def self.environ_name(e)
      return nil if e.nil? || e == :None
      n = (GameData::Environment.get(e).name rescue nil)
      (n.nil? || n.to_s.empty?) ? e.to_s : n.to_s
    end

    # The Pokemon whose icons the entry screen shows, the partner's included in a partner raid; none once the battle
    # has disposed of them, without raising on the way, since the party poll runs through the whole battle.
    def self.party(scene)
      (0...PARTY_ICONS).map { |i| PokeAccess.attr_of(PokeAccess.sprite(scene, "partyicon_#{i}"), :pokemon) }.compact
    end

    def self.party_key(scene)
      party(scene).map { |pk| pk.object_id }
    end

    # Who enters, by name, or nil with no party icon on screen.
    def self.party_line(scene)
      names = party(scene).map { |pk| PokeAccess.clean((pk.name rescue "").to_s) }.reject { |n| n.empty? }
      names.empty? ? nil : PokeAccess::I18n.t(:ss2_raid_party, :list => names.join(", "))
    end

    # Holds the entry screen while its loop runs, so the party poll can reach it.
    def self.hold(scene); @entry = scene; end

    def self.release(scene)
      @entry = nil
      PokeAccess::Cursor.reset(scene, :ss2_den_party)
    end

    # From the frame poll: the party line again once Change Party has put other Pokemon on the icons.
    def self.poll_party
      scene = @entry
      return unless scene
      key = party_key(scene)
      return if key.empty? || !PokeAccess::Cursor.changed?(scene, :ss2_den_party, key)
      PokeAccess.speak(party_line(scene), true)
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

    # Speaks the rewards page once painted: the positions batch only (the first description goes to a hidden
    # box), keeping sex-sign rows and dropping other rows with no letter or digit, then the page's icons.
    def self.say_rewards
      scene = @rewards_scene
      return unless scene && PokeAccess::PaintCapture.pending?(:ss2_den_rewards)
      @rewards_scene = nil
      rows = PokeAccess::PaintCapture.take_by_source(:ss2_den_rewards)[:positions] || []
      kept = rows.select { |r| r.to_s =~ /[A-Za-z0-9]/ || PokeAccess::Party::SIGNS.include?(r.to_s.strip) }
      PokeAccess.speak(PokeAccess::PaintCapture.text(kept + reward_icons(scene)), false)
    end

    # The rewards page's icons: the shiny mark of a shiny boss and the rank stars.
    def self.reward_icons(scene)
      out = []
      pk = PokeAccess.ivar(scene, :@pkmn)
      out.push(PokeAccess::I18n.t(:pk_shiny)) if pk && PokeAccess::Party.shiny?(pk)
      rank = (PokeAccess.ivar(scene, :@rules)[:rank] rescue nil)
      out.push(PokeAccess::I18n.t(:ss2_raid_rank, :n => rank)) if rank
      out
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

  # The entry loop: the screen said on the way in, and held while it runs for the party poll.
  around("RaidScene", :pbRaidEntry, :optional => true) do |scene, nxt, _a|
    PokeAccess::SS2RaidDen.open(scene)
    PokeAccess::SS2RaidDen.hold(scene)
    begin
      nxt.call
    ensure
      PokeAccess::SS2RaidDen.release(scene)
    end
  end

  before("RaidScene", :pbRaidRewardsScreen, :optional => true) do |scene, _a|
    PokeAccess::SS2RaidDen.arm_rewards(scene)
  end

  # The rewards page paints and then blocks, so its paint is spoken from the frame poll.
  poll_each_frame { PokeAccess::SS2RaidDen.say_rewards }
  poll_each_frame { PokeAccess::SS2RaidDen.poll_party }
end

PokeAccess::SceneWatcher.reader("RaidScene", :pbRaidEntry, :ss2_den_opt, :optional => true) do |scene|
  PokeAccess::SS2RaidDen.option(scene)
end

# Queued, since with the box shown the list names each reward first, and an interrupting description would cut it.
PokeAccess::SceneWatcher.reader("RaidScene", :pbRaidRewardsScreen, :ss2_den_desc, :optional => true,
                                :queued => true) do |scene|
  PokeAccess::SS2RaidDen.reward_desc(scene)
end
