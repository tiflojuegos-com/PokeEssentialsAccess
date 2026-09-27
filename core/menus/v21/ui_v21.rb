module PokeAccess
  # GameData-era screens the command-window readers miss: the focused party member, the move reminder, the region
  # map's location and name, and the pokegear option, each deduped (these games re-assert the selection every frame).
  module UIV21
    # Speaks text when it changes for a tag, on Cursor's module-wide table; true when spoken.
    # param tag a symbol naming the source, so different screens do not shadow each other
    # param key identifies the focus where the text cannot (two eggs read alike); joins the dedup key, unspoken
    def self.speak_changed(tag, text, key = nil, interrupt = true)
      return if text.nil? || text.to_s.empty?
      said = PokeAccess::Cursor.announce(nil, tag, key.nil? ? text : [key, text], interrupt) { text }
      @party_said = true if said && tag == :party
      said
    rescue StandardError
      nil
    end

    # Runs a party screen's opening with its reads queued, so the first member follows the help line set inside it.
    def self.opening_party
      @party_opening = true
      @party_fresh = true
      yield
    ensure
      @party_opening = false
    end

    # Whether a party read interrupts: every cursor move does, the opening's own read does not.
    def self.party_interrupt?; !@party_opening; end

    # The name a region map's bar writes at its top, queued on open; a later change waits for the next frame, so it
    # follows the location the same move speaks.
    def self.region_name(text)
      t = PokeAccess.clean(text.to_s)
      return if t.empty?
      return speak_changed(:regionname, t, nil, false) if PokeAccess::Cursor.current(nil, :regionname).nil?
      @region_name = t if PokeAccess::Cursor.changed?(nil, :regionname, t)
    end

    # From the frame poller: the region name held by region_name.
    def self.flush_region_name
      t = @region_name
      @region_name = nil
      PokeAccess.speak(t, false) if t
    end

    # Clears a dedup tag so the next read speaks even on unchanged text (a screen reopening on the same item).
    def self.reset(tag); PokeAccess::Cursor.reset(nil, tag); end

    # Whether the classic party scene reports cursor moves itself (then the panel hooks keep quiet); resolved once.
    @scene_reports = nil

    def self.scene_reports_party?
      @scene_reports = PokeAccess::Engine.has?("PokemonScreen_Scene#pbChangeSelection") if @scene_reports.nil?
      @scene_reports
    end

    # A party member as its panel shows it (Party.member_line, pokerus in the state slot, its annotation where one
    # applies); an egg as an egg, since Pokemon#name gives an egg's species.
    # param annotation the panel's annotation text, or nil/blank when none applies
    def self.party_member(pk, annotation = nil)
      return nil unless pk
      if (pk.egg? rescue false)
        t = PokeAccess::I18n.t(:pty_egg)
        t += ", " + annotation.to_s if annotation && !annotation.to_s.empty?
        return t
      end
      PokeAccess::Party.member_line(pk, :annotation => annotation, :pokerus_slot => true)
    rescue StandardError
      nil
    end

    # Detail of a move from its id (symbol), via the agnostic MoveInfo.by_id (GameData lookup).
    def self.move_by_id(id)
      PokeAccess::MoveInfo.by_id(id)
    end

    # A reminder entry ([move_id, label] pair, id or move object) at the learn move reading's level: the row label
    # first from medium, the move with pk's display_* values (Hidden Power's own type); the info key keeps it whole.
    # param pk the Pokemon the list is for, or nil for the move's plain data
    def self.move_from_entry(m, pk = nil)
      return nil unless m
      id = m.is_a?(Array) ? m[0] : (m.id rescue m)
      lbl = m.is_a?(Array) ? entry_label(m) : ""
      data = (GameData::Move.get(id) rescue nil)
      return move_by_id(id) unless data
      ty = (GameData::Type.get(shown(data, :display_type, pk) || data.type).name rescue nil)
      pw = shown(data, :display_power, pk)
      pw = PokeAccess.attr_of(data, :power, :base_damage) if pw.nil?
      acc = shown(data, :display_accuracy, pk)
      acc = (data.accuracy rescue 0) if acc.nil?
      cat = shown(data, :display_category, pk)
      cat = (data.category rescue nil) if cat.nil?
      tot = PokeAccess.attr_of(data, :total_pp, :totalpp)
      args = [(data.name rescue "").to_s, ty, pw || 0, acc,
              { :pp => tot, :total_pp => tot, :cat => PokeAccess::MoveInfo.category_word(cat),
                :desc => (data.description rescue "") }]
      full = PokeAccess::MoveInfo.line(*args)
      PokeAccess::Info.set_info(:text, lbl.empty? ? full : "#{lbl}. #{full}")
      line = PokeAccess::MoveInfo.leveled(:learn_move, *args)
      lbl = "" unless PokeAccess::Verbosity.keep?(:learn_move, :medium)
      lbl.empty? ? line : "#{lbl}. #{line}"
    rescue StandardError
      nil
    end

    # A move property as the screen shows it for pk (data.meth(pk)), or nil without pk or such a method.
    def self.shown(data, meth, pk)
      return nil if pk.nil?
      data.respond_to?(meth) ? (data.send(meth, pk) rescue nil) : nil
    end

    # The label a reminder row paints beside its move; a game painting something else overrides this.
    def self.entry_label(m)
      PokeAccess.clean(m[1].to_s)
    end

    # A new choice after a sub-screen or command: says the member under the cursor again, queued; quiet on the
    # opening's own choice or when a member was said since the last choice.
    # param initial pbChoosePokemon's initialsel, where the cursor goes
    def self.retake_party(scene, initial = nil)
      if @party_fresh
        @party_fresh = false
        return
      end
      return if @party_said || scene_reports_party?
      idx = (initial.is_a?(Integer) && initial >= 0) ? initial : PokeAccess.ivar(scene, :@activecmd)
      sprite = PokeAccess.sprite(scene, "pokemon#{idx}")
      return unless sprite
      reset(:party)
      pk = PokeAccess.ivar(sprite, :@pokemon)
      if pk && PokeAccess::Party.party_slot?(PokeAccess.ivar(scene, :@party), idx)
        ann = PokeAccess.ivar(sprite, :@text)
        PokeAccess::Info.set_info(:pokemon, pk, PokeAccess::Verbosity.whole { party_member(pk, ann) })
        speak_changed(:party, party_member(pk, ann), sprite.object_id, false)
      else
        speak_changed(:party, PokeAccess::Party.button_label(sprite), sprite.object_id, false)
      end
    end

    # A choice ended: from here on, a member said is one the next choice need not repeat.
    def self.party_choice_done; @party_said = false; end

    # A party panel the cursor landed on: the member it shows, set for the info key and said once per landing.
    def self.say_panel(panel)
      pk = PokeAccess.ivar(panel, :@pokemon)
      return unless pk
      ann = PokeAccess.ivar(panel, :@text)
      PokeAccess::Info.set_info(:pokemon, pk, PokeAccess::Verbosity.whole { party_member(pk, ann) })
      speak_changed(:party, party_member(pk, ann), panel.object_id, party_interrupt?)
    end

    # The move reminder's opening read: its first move, dedup cleared; a screen replacing main calls it itself.
    def self.reminder_opening(screen)
      UIV21.reset(:reminder)
      moves = PokeAccess.ivar(screen, :@moves)
      first = moves.is_a?(Array) ? moves[0] : nil
      speak_changed(:reminder, move_from_entry(first, PokeAccess.ivar(screen, :@pokemon))) if first
    end

    # The focused move in the move reminder visuals (its list holds [move_id, "Nv. X"] pairs).
    def self.reminder_move(vis)
      moves = PokeAccess.ivar(vis, :@moves)
      idx = (vis.index rescue (vis.instance_variable_get(:@index) rescue 0))
      return nil unless moves && idx && idx >= 0 && idx < moves.length
      move_from_entry(moves[idx], PokeAccess.ivar(vis, :@pokemon))
    rescue StandardError
      nil
    end
  end
end

# UI::BaseScreen#show_message is read only in menus/v22/screen_v22, through say_dialogue (the repeat key's feed).

# Party panels: the member the cursor lands on, also set for the info key; stands down where the classic scene
# reports cursor moves itself (pbChangeSelection), since both would speak.
PokeAccess::Hooks.after_hook("PokemonPartyPanel", :selected=) do |panel, _r, args|
  PokeAccess::UIV21.say_panel(panel) if args[0] && !PokeAccess::UIV21.scene_reports_party?
end

# A focused panel's annotation changing (the Battle Tower's entry order), said through the same landing and dedup.
PokeAccess::Hooks.after_hook("PokemonPartyPanel", :text=, :optional => true) do |panel, _r, _a|
  PokeAccess::UIV21.say_panel(panel) if (panel.selected rescue false) && !PokeAccess::UIV21.scene_reports_party?
end

# The Cancel and Confirm buttons (PokemonPartyConfirmCancelSprite, not panels), keyed by sprite like the panels.
PokeAccess::Hooks.after_hook("PokemonPartyConfirmCancelSprite", :selected=, :optional => true) do |sprite, _r, args|
  if args[0] && !PokeAccess::UIV21.scene_reports_party?
    PokeAccess::UIV21.speak_changed(:party, PokeAccess::Party.button_label(sprite), sprite.object_id,
                                    PokeAccess::UIV21.party_interrupt?)
  end
end

# pbSelect's jumps (the cursor restored on open or after a move), said here under the same sprite key, since its
# guard mutes the sprite hooks; stands down where the classic scene reports the cursor.
PokeAccess::Hooks.after_hook("PokemonParty_Scene", :pbSelect, :optional => true) do |scene, _r, args|
  next if PokeAccess::UIV21.scene_reports_party?
  idx = args[0]
  sprite = (PokeAccess.ivar(scene, :@sprites)["pokemon#{idx}"] rescue nil)
  if PokeAccess::Party.party_slot?(PokeAccess.ivar(scene, :@party), idx)
    PokeAccess::UIV21.say_panel(sprite) if sprite
  else
    PokeAccess::UIV21.speak_changed(:party, PokeAccess::Party.button_label(sprite), sprite ? sprite.object_id : idx,
                                    PokeAccess::UIV21.party_interrupt?)
  end
end

PokeAccess::Hooks.around_hook("PokemonParty_Scene", :pbChoosePokemon, :optional => true) do |scene, nxt, args|
  PokeAccess::UIV21.retake_party(scene, args[1])
  begin; nxt.call; ensure; PokeAccess::UIV21.party_choice_done; end
end

# Opening the party screen: resets its dedup, queues the opening read behind the help line, then says the Box Link
# key line ("[D]: Cajas del PC") while key hints are said.
PokeAccess::Hooks.around_hook("PokemonParty_Scene", :pbStartScene) do |scene, nxt, _a|
  PokeAccess::UIV21.reset(:party)
  r = PokeAccess::UIV21.opening_party { nxt.call }
  hint = PokeAccess::KeyHints.localize(PokeAccess.clean((PokeAccess.sprite(scene, "storagetext").text rescue "").to_s))
  PokeAccess.speak(hint, false) if PokeAccess::Verbosity.hints? && !hint.empty?
  r
end

# Move reminder (UI::MoveReminderVisuals): the focused move on each index change; the first is read on open (below).
PokeAccess::Hooks.after_hook("UI::MoveReminderVisuals", :refresh_on_index_changed) do |vis, _r, _a|
  PokeAccess::UIV21.speak_changed(:reminder, PokeAccess::UIV21.reminder_move(vis))
end

# Read the first move on open (the visuals and move list already exist when main is entered).
PokeAccess::Hooks.before_hook("UI::MoveReminder", :main) do |screen, _a|
  PokeAccess::UIV21.reminder_opening(screen)
end

# Region map: the bottom bar's location text changes as the cursor moves over the map (deduped).
PokeAccess::Hooks.after_hook("MapBottomSprite", :maplocation=) do |_s, _r, args|
  PokeAccess::UIV21.speak_changed(:regionmap, PokeAccess.clean(args[0].to_s)) unless PokeAccess::RegionMap.building?
end

# The region's name, written at the bar's top on open and when a multi-region map switches.
PokeAccess::Hooks.after_hook("MapBottomSprite", :mapname=) do |_s, _r, args|
  PokeAccess::UIV21.region_name(args[0])
end
PokeAccess::Keys.on_frame { PokeAccess::UIV21.flush_region_name }

# Opening the region map resets its dedup, under both scene spellings; scene_classes, not era_scene, since the reset
# is the same in either era.
PokeAccess::Engine.scene_classes("PokemonRegionMapScene", "PokemonRegionMap_Scene").each do |cn|
  PokeAccess::Hooks.before_hook(cn, :pbStartScene) do |_s, _a|
    PokeAccess::UIV21.reset(:regionmap)
    PokeAccess::UIV21.reset(:regionname)
  end
end

# Pokegear: each option button is (re)selected every frame; read the focused one's name (deduped).
PokeAccess::Hooks.after_hook("PokegearButton", :selected=) do |btn, _r, args|
  PokeAccess::UIV21.speak_changed(:pokegear, (btn.name rescue nil).to_s) if args[0]
end

# Opening the pokegear resets its dedup; :optional, as an RMXP-style copy has only Scene_Pokegear#main (below).
PokeAccess::Hooks.before_hook("PokemonPokegear_Scene", :pbStartScene, :optional => true) do |_s, _a|
  PokeAccess::UIV21.reset(:pokegear)
end
PokeAccess::Hooks.before_hook("Scene_Pokegear", :main, :optional => true) do |_s, _a|
  PokeAccess::UIV21.reset(:pokegear)
end

# Back on an RMXP-style Scene_Pokegear from an app it opened in place (the map, the phone, a quest log), the buttons
# are reselected as they were: the dedup is reset so the focused one is said again.
PokeAccess::MenuReturn.on_return do
  gear = PokeAccess.const_at("Scene_Pokegear")
  PokeAccess::UIV21.reset(:pokegear) if gear && $scene.is_a?(gear)
end

# Back from an app, pbScene runs again on the same buttons and cursor: every call after the first resets the dedup.
PokeAccess::Hooks.before_hook("PokemonPokegear_Scene", :pbScene, :optional => true) do |scene, _a|
  PokeAccess::UIV21.reset(:pokegear) if PokeAccess.ivar(scene, :@access_scene_seen)
  scene.instance_variable_set(:@access_scene_seen, true)
end

# Scene_Pokegear hides an active command window under its buttons: claimed every frame (dedicate is idempotent).
PokeAccess::Hooks.after_hook("Scene_Pokegear", :update, :optional => true) do |scene, _r, _a|
  PokeAccess.dedicate(PokeAccess.sprite(scene, "command_window"))
end
