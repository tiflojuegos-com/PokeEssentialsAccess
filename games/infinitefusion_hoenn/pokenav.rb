# The PokeNav apps (PokeNavAppScene: @index over @buttons, each PokeNavButton painting its label), read on hover
# for every app that inherits it; PokeChallenges has its own reader, and the launcher is the core's.
module PokeAccess
  module IF2PokeNav
    # A button's label: its own text, or its id when that is a String (a Symbol id is a radar row's species).
    def self.button_text(btn)
      t = PokeAccess.ivar(btn, :@text)
      t = (btn.id rescue nil) if t.nil? || t.to_s.strip.empty?
      return nil unless t.is_a?(String)
      PokeAccess.clean(t)
    rescue StandardError
      nil
    end

    # What the focused button says: a radar row on the radar, else its label.
    def self.entry_text(scene, btn)
      return radar_text(scene, btn) if radar?(scene)
      button_text(btn)
    end

    # Whether the app is the PokeRadar (the one with @seenPokemon).
    def self.radar?(scene)
      PokeAccess.ivar(scene, :@seenPokemon).is_a?(Array)
    end

    @header = nil

    # Runs the radar's repaint of its header labels (its name, the battery and the zone), keeping them for the
    # first row read, which leads with them.
    def self.keep_header(scene)
      @header = []
      yield
    ensure
      scene.instance_variable_set(:@access_if2_header, @header) if @header
      @header = nil
    end

    # A HUD label painted while the radar's header is kept.
    def self.note_header(text)
      t = PokeAccess.clean(text.to_s)
      @header.push(t) if @header && !t.empty?
    end

    # A radar row: the species, and from medium its rarity and scan cost (the scene's own helpers); "unknown" for an
    # unseen species, nothing during a scan.
    def self.radar_text(scene, btn)
      return nil if ($PokemonTemp.pokeradar rescue false)
      sp = (btn.id rescue nil)
      return nil unless sp
      seen = PokeAccess.ivar(scene, :@seenPokemon)
      unless seen.include?(sp)
        unknown = PokeAccess::I18n.t(:if2_radar_unknown)
        PokeAccess::Info.set_info(:text, unknown)
        return unknown
      end
      parts = [[(PokeAccess::Data.species_name(sp) rescue nil) || sp.to_s, :brief]]
      r = (scene.get_rarity_flavor_text(sp) rescue nil)
      parts.push([PokeAccess.clean(r.to_s), :medium]) if r && !r.to_s.strip.empty?
      e = (scene.get_energy_for_scan(sp) rescue nil)
      parts.push([PokeAccess::I18n.t(:if2_radar_battery, :n => e), :medium]) if e
      PokeAccess::Verbosity.info_line(:dex_entry, parts)
    rescue StandardError
      nil
    end

    # Speaks the focused app button once per change, with its position in the grid; the radar's first row leads with
    # the header labels it painted as it opened (its HUD lines, cut by this read, would say the row twice).
    def self.focus(scene)
      idx = PokeAccess.ivar(scene, :@index)
      btns = PokeAccess.ivar(scene, :@buttons)
      return unless idx.is_a?(Integer) && btns.is_a?(Array) && idx >= 0 && idx < btns.length
      return contact(scene, btns, idx) if contacts?(scene)
      label = entry_text(scene, btns[idx])
      return if label.nil? || label.empty?
      head = radar?(scene) && PokeAccess::Cursor.pending?(scene, :list_entry) ? header(scene) : []
      PokeAccess::Cursor.announce(scene, :list_entry, idx, true) do
        PokeAccess.sentences(head + [PokeAccess::Verbosity.list_entry(label, idx + 1, btns.length)])
      end
    rescue StandardError
      nil
    end

    # The header labels the radar kept on its last repaint.
    def self.header(scene)
      h = PokeAccess.ivar(scene, :@access_if2_header)
      h.is_a?(Array) ? h : []
    end

    # Whether the app is the trainers' contacts, whose list mixes zone headers among the trainers.
    def self.contacts?(scene)
      defined?(::ContactsAppScene) && scene.is_a?(::ContactsAppScene) ? true : false
    end

    def self.trainer_button?(btn)
      defined?(::ContactsAppTrainerButton) && btn.is_a?(::ContactsAppTrainerButton) ? true : false
    end

    def self.zone_button?(btn)
      defined?(::ContactsAppLocationButton) && btn.is_a?(::ContactsAppLocationButton) ? true : false
    end

    # The zone header above a row, as [its index, its label], or nil.
    def self.zone_of(btns, idx)
      i = idx
      i -= 1 while i >= 0 && !zone_button?(btns[i])
      i >= 0 ? [i, button_text(btns[i])] : nil
    end

    # The icons a trainer row paints on its right: a trade on offer, and a trainer not seen yet (whose icon is
    # already fading by the time the row is read, as the row's hover clears the flag first).
    def self.contact_marks(btn)
      marks = []
      marks.push(PokeAccess::I18n.t(:if2_nav_trade)) if PokeAccess.ivar(btn, :@is_trade_available)
      fading = PokeAccess.ivar(btn, :@fading_new_icon)
      fresh = PokeAccess.ivar(btn, :@is_new) || (fading && !(fading.disposed? rescue false))
      marks.push(PokeAccess::I18n.t(:if2_nav_new)) if fresh
      marks
    end

    # A contacts row: the zone's header when the cursor enters another zone, then the trainer with its row's icons
    # and its place among the trainers alone, as the cursor skips the headers; a header it lands on (after an empty
    # zone, which it skips only once) by its name.
    def self.contact(scene, btns, idx)
      label = button_text(btns[idx])
      return if label.nil? || label.empty?
      trainers = btns.select { |b| trainer_button?(b) }
      pos = trainers.index(btns[idx])
      PokeAccess::Cursor.announce(scene, :list_entry, idx, true) do
        zone = zone_of(btns, idx)
        entered = zone && zone[1] && PokeAccess::Cursor.changed?(scene, :if2_nav_zone, zone[0])
        if pos.nil?
          label
        else
          row = PokeAccess::Verbosity.list_entry(([label] + contact_marks(btns[idx])).join(", "), pos + 1, trainers.length)
          entered ? "#{zone[1]}. #{row}" : row
        end
      end
    end
  end

  # PokeChallenges (PokemonChallenges_Scene): the active challenges, each a ChallengeButton painted into a bitmap,
  # focused by @index and read from pbUpdate.
  module IF2Challenges
    # The focused challenge and its place, then its reward (in full; from medium only that it can be collected);
    # keyed on the description too, as collecting one shifts the next into its slot; the info key keeps it whole.
    # The first is queued after the title and the completed count the header paints as the app opens.
    def self.focus(scene)
      idx = PokeAccess.ivar(scene, :@index)
      list = PokeAccess.ivar(scene, :@challenges)
      return unless idx.is_a?(Integer) && list.is_a?(Array) && idx >= 0 && idx < list.length
      c = list[idx]
      desc = PokeAccess.clean((c.description rescue "").to_s)
      return if desc.empty?
      PokeAccess::Cursor.announce(scene, :if2_challenge, [idx, desc], true, false) do
        whole = reward(scene, idx, c)
        PokeAccess::Info.set_info(:text, [desc, whole].compact.join(". "))
        head = PokeAccess::Verbosity.list_entry(desc, idx + 1, list.length)
        [head, reward_at_level(scene, idx, c, whole)].compact.join(". ")
      end
    rescue StandardError
      nil
    end

    # The reward at the quest reading's level: whole in full, from medium only that it is ready to collect.
    def self.reward_at_level(scene, idx, c, whole)
      return whole if PokeAccess::Verbosity.keep?(:quest, :full)
      return nil unless PokeAccess::Verbosity.keep?(:quest, :medium) && claimable?(scene, idx, c)
      PokeAccess::I18n.t(:if2_ch_ready)
    end

    # Whether the challenge's reward waits to be collected, as its button says.
    def self.claimable?(scene, idx, c)
      btn = (PokeAccess.ivar(scene, :@buttons)[idx] rescue nil)
      (btn.can_claim_reward rescue (c.completed rescue false)) ? true : false
    end

    # The reward line: claimable or pending, the money, and any items by name.
    def self.reward(scene, idx, c)
      parts = [PokeAccess::I18n.t(claimable?(scene, idx, c) ? :if2_ch_collect : :if2_ch_reward,
                                  :n => (c.money_reward rescue 0).to_i)]
      items = (c.item_reward rescue nil)
      if items.is_a?(Array) && !items.empty?
        names = items.map { |i| (PokeAccess::Data.item_name(i) rescue nil) || i.to_s }
        parts.push(names.join(", "))
      end
      parts.join(". ")
    rescue StandardError
      nil
    end
  end

  # The launcher's own rearrange mode (Hoenn's edited PokemonPokegear_Scene): the apps wobble and one is lifted,
  # which the core's app name reader does not tell.
  module IF2Launcher
    COLUMNS = 4

    # The app at a grid index, as its button holds its name (the core reader's dedup key), or nil.
    def self.raw_name(scene, idx)
      cmds = PokeAccess.ivar(scene, :@commands)
      c = cmds.is_a?(Array) && idx.is_a?(Integer) ? cmds[idx] : nil
      c ? c[1].to_s : nil
    end

    # Marks the app under the cursor as said, so the core reader does not say it again over this line.
    def self.mark_focus(scene)
      name = raw_name(scene, PokeAccess.ivar(scene, :@index))
      PokeAccess::Cursor.changed?(nil, :pokegear, name) if name
      name
    end

    # Says the mode as it changes, from the scene's state each frame, since leaving it happens inside the scene's
    # loop: on, with the focused app the reopened loop would otherwise say over it, or off.
    def self.mode(scene)
      on = PokeAccess.ivar(scene, :@rearranging) ? true : false
      was = PokeAccess.ivar(scene, :@access_if2_rearranging)
      scene.instance_variable_set(:@access_if2_rearranging, on)
      return if was.nil? || was == on
      if on
        name = mark_focus(scene)
        PokeAccess.speak(PokeAccess.sentences([PokeAccess::I18n.t(:if2_nav_rearrange_on), PokeAccess.clean(name.to_s)]),
                         true)
      else
        PokeAccess.speak(PokeAccess::I18n.t(:if2_nav_rearrange_off), true)
      end
    end

    # A pick or a drop: the app lifted, or the one set down at the cursor, with its place on the grid.
    def self.swapped(scene)
      held = PokeAccess.ivar(scene, :@held_index)
      idx = held || PokeAccess.ivar(scene, :@index)
      name = raw_name(scene, idx)
      return unless name
      mark_focus(scene)
      where = PokeAccess::I18n.t(:pc_pos, :row => idx / COLUMNS + 1, :col => idx % COLUMNS + 1)
      PokeAccess.speak(PokeAccess::I18n.t(held ? :if2_nav_picked : :if2_nav_placed, :name => PokeAccess.clean(name)) + where,
                       true)
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  after("PokeNavAppScene", :hover) { |s, _r, _a| PokeAccess::IF2PokeNav.focus(s) }
  around("PokeRadarAppScene", :displayTextElements) { |s, nxt, _a| PokeAccess::IF2PokeNav.keep_header(s) { nxt.call } }
  kernel("pbDisplayText", :after) { |args, _r| PokeAccess::IF2PokeNav.note_header(args[0]) }
  # The opening focus, which hover does not read; an app that overrides pbStartScene moves the cursor after super,
  # so it is read from its own opener below.
  after("PokeNavAppScene", :pbStartScene) do |s, _r, _a|
    own = (s.class.instance_method(:pbStartScene).owner rescue nil)
    next if own && own != PokeNavAppScene
    PokeAccess::IF2PokeNav.focus(s)
  end
  after("ContactsAppScene", :pbStartScene, :optional => true) { |s, _r, _a| PokeAccess::IF2PokeNav.focus(s) }
  # FusionQuizAppScene redefines pbStartScene too, so its own opener is read; the quiz reopens its menu on the same
  # scene after each game, back on its first button, so the slot is reset first.
  after("FusionQuizAppScene", :pbStartScene, :optional => true) do |s, _r, _a|
    PokeAccess::Cursor.reset(s, :list_entry)
    PokeAccess::IF2PokeNav.focus(s)
  end
  after("PokemonChallenges_Scene", :pbUpdate) { |s, _r, _a| PokeAccess::IF2Challenges.focus(s) }
  after("PokemonChallenges_Scene", :pbEndScene, :optional => true) { |_s, _r, _a| PokeAccess::Info.clear_text }
  after("PokeNavAppScene", :pbEndScene, :optional => true) { |_s, _r, _a| PokeAccess::Info.clear_text }
end

# The trainer sheet's friendship level exists on screen only as a row of heart icons; spoken as a number, once per
# trainer, since up and down redraw the next trainer's sheet on the same scene.
PokeAccess::Game.define("infinitefusion_hoenn") do
  after("ContactsAppInfoPageScene", :showFriendshipIcons, :optional => true) do |scene, _r, _a|
    trainer = PokeAccess.ivar(scene, :@trainer)
    n = (trainer.friendship_level rescue nil)
    if n
      PokeAccess::Cursor.announce(scene, :pnav_hearts, [(trainer.id rescue nil), n.to_i], false) do
        PokeAccess::I18n.t(:pnav_friendship, :n => n.to_i)
      end
    end
  end
end

# The launcher's rearrange mode, watched before each frame's repaint (whose button reads the core owns), and each
# pick and drop.
PokeAccess::Game.define("infinitefusion_hoenn") do
  before("PokemonPokegear_Scene", :pbUpdate) { |s, _a| PokeAccess::IF2Launcher.mode(s) }
  after("PokemonPokegear_Scene", :swap_apps) { |s, _r, _a| PokeAccess::IF2Launcher.swapped(s) }
end

# pbEndScene repaints the PokeNav header after the screen is gone: hushed, so it is not spoken.
PokeAccess::Game.define("infinitefusion_hoenn") do
  around("ContactsAppInfoPageScene", :pbEndScene, :optional => true) do |_s, nxt, _a|
    PokeAccess::HudText.hushed { nxt.call }
  end
end

PokeAccess::Verbosity.define_reading(:quest, :vb_quest, :vbh_quest)
