module PokeAccess
  # Uranium's icon pause menu (PokemonMenu_Scene): pbUpdateSelect lights one IconMenu a frame and paints its caption
  # from @textos. The lit icon's caption is said as it changes; once per menu, the map line and the running icon's
  # state; the running toggle (A) as it flips. While the menu is up, the info key has the team preview with its item
  # and mail icons.
  module UraniumMenu
    # The icons in @textos order.
    ICONS = %w[iconPokedex iconPokemon iconBag iconPokepod iconCard iconSave iconOption iconExit]

    # The scene whose selection loop is running, or nil.
    def self.scene; @scene; end

    # Runs a selection loop with its scene marked as the one whose icons are watched.
    def self.selecting(scene)
      prev = @scene
      @scene = scene
      yield
    ensure
      @scene = prev
    end

    # An icon lit or put out inside the selection loop: a lit menu icon says its caption, the running icon its state.
    def self.activated(icon, flag)
      s = @scene
      sprites = s ? PokeAccess.ivar(s, :@sprites) : nil
      return unless sprites.is_a?(Hash)
      if sprites["iconRun"].equal?(icon)
        state = PokeAccess::I18n.t(flag ? :val_on : :val_off)
        PokeAccess.speak(PokeAccess::I18n.t(:ura_run_state, :state => state), true)
        return
      end
      key = flag ? ICONS.find { |k| sprites[k].equal?(icon) } : nil
      return if key.nil?
      idx = ICONS.index(key)
      PokeAccess::Cursor.announce(s, :ura_menu, idx, true, false) { caption(s, idx) }
    end

    # The caption painted for icon idx, the team put back on the info key (a screen opened from the menu may have
    # taken it); the first time in a menu, the map line painted under it and the running icon's state too.
    def self.caption(scene, idx)
      rows = (PokeAccess.ivar(scene, :@textos) || [])[idx]
      return nil unless rows.is_a?(Array) && rows[0].is_a?(Array)
      note_team(scene)
      parts = [rows[0][0].to_s]
      unless PokeAccess.ivar(scene, :@access_ura_map)
        scene.instance_variable_set(:@access_ura_map, true)
        parts.push(rows[1][0].to_s) if rows[1].is_a?(Array)
        parts.push(run_state(scene).to_s)
      end
      PokeAccess.clean(parts.reject { |t| t.empty? }.join(". "))
    end

    # The running icon's state, lit when running is on; nil where the menu has no such icon (no running shoes).
    def self.run_state(scene)
      icon = PokeAccess.sprite(scene, "iconRun")
      return nil unless icon
      state = PokeAccess::I18n.t(PokeAccess.ivar(icon, :@active) ? :val_on : :val_off)
      PokeAccess::I18n.t(:ura_run_state, :state => state)
    end

    # Keeps for the info key the team the preview shows, each member with the item or mail icon it draws.
    def self.note_team(scene)
      preview = PokeAccess.sprite(scene, "teampreview")
      party = (preview ? (preview.party rescue nil) : nil) || ($Trainer.party rescue nil)
      return unless party.is_a?(Array) && !party.empty?
      list = party.map { |pk| [pk.name.to_s, PokeAccess::Party.held_icon(pk)].compact.join(", ") }
      PokeAccess::Info.set_info(:text, PokeAccess::I18n.t(:ura_menu_team, :list => list.join("; ")))
    end
  end
end

PokeAccess::Game.define("uranium") do
  around("PokemonMenu_Scene", :pbUpdateSelect) do |scene, nxt, args|
    r = PokeAccess::UraniumMenu.selecting(scene) { nxt.call }
    PokeAccess::Cursor.reset(scene, :ura_menu) if !args[0] && r.is_a?(Integer) && r >= 0
    r
  end
  after("IconMenu", :setActive) { |icon, _r, args| PokeAccess::UraniumMenu.activated(icon, args[0]) }
  after("PokemonMenu_Scene", :pbEndScene) { |_s, _r, _a| PokeAccess::Info.clear_text }
end
