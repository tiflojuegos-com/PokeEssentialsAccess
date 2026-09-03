module PokeAccess
  # GameData-era Essentials UI screens (the UI:: framework and assorted plugin scenes). Screens using classic
  # Window_DrawableCommand (bag, options, mart, command lists, the pokedex list) are read by the core
  # generic hook/extractors; this adds the rest: in-screen messages, the focused party member, the move
  # reminder, the region-map location and the pokegear option. Per-screen reads dedupe (these games
  # re-assert the selection every frame).
  module UIV21
    # Speaks text only when it changes for a given tag (the GameData-era UI re-selects every frame, so
    # without this the focused item would repeat continuously). Backed by Cursor's module-wide table (no
    # scene instance to hang on here).
    # param tag a symbol naming the source, so different screens do not shadow each other
    # param key what identifies the FOCUS, when the text alone cannot: two party slots holding an egg
    #   produce the same line, and on the text alone moving between them is silent. It joins the dedup key
    #   and is never spoken.
    def self.speak_changed(tag, text, key = nil)
      return if text.nil? || text.to_s.empty?
      PokeAccess::Cursor.announce(nil, tag, key.nil? ? text : [key, text]) { text }
    rescue StandardError
      nil
    end

    # Clears a dedup tag so the next read for it speaks even if the text is unchanged (used when a screen
    # reopens with the cursor on the same item as last time).
    def self.reset(tag); PokeAccess::Cursor.reset(nil, tag); end

    # Whether the classic party scene reports cursor moves itself, in which case the panel hook must keep
    # quiet. Resolved once: it is a property of the game, not of the screen.
    @scene_reports = nil

    def self.scene_reports_party?
      @scene_reports = PokeAccess::Engine.has?("PokemonScreen_Scene#pbChangeSelection") if @scene_reports.nil?
      @scene_reports
    end

    # Spoken summary of a party member: name, gender, level, hp and fainted state, plus the eligibility
    # annotation ("able"/"not able") when the party is opened to use an item or pick a move target. An egg
    # gets its own line, because the panel hides its HP bar, HP numbers and level, and Pokemon#name answers
    # with the species for an unnicknamed one, so the usual line would hand all of that over.
    # param annotation the panel's annotation text, or nil/blank when none applies
    def self.party_member(pk, annotation = nil)
      return nil unless pk
      if (pk.egg? rescue false)
        t = PokeAccess::I18n.t(:pty_egg)
        t += ", " + annotation.to_s if annotation && !annotation.to_s.empty?
        return t
      end
      sex = PokeAccess::Party.gender_phrase(pk)
      t = PokeAccess::I18n.t(:pty_member, :name => pk.name, :sex => sex, :level => pk.level, :hp => pk.hp, :tot => pk.totalhp)
      t += PokeAccess::Party.fainted_suffix(pk)
      t += ", " + annotation.to_s if annotation && !annotation.to_s.empty?
      t
    rescue StandardError
      nil
    end

    # Detail of a move from its id (symbol), via the agnostic MoveInfo.by_id (GameData lookup).
    def self.move_by_id(id)
      PokeAccess::MoveInfo.by_id(id)
    end

    # Detail of a single reminder-list entry: a [move_id, label] pair, an id, or a move object. The row
    # label leads the line ("Nv. 12" relearns free, "MT" spends the machine: the label is where the cost
    # lives). PP and the icon-only damage category join through MoveInfo.line.
    def self.move_from_entry(m)
      return nil unless m
      id = m.is_a?(Array) ? m[0] : (m.id rescue m)
      lbl = m.is_a?(Array) ? PokeAccess.clean(m[1].to_s).to_s.strip : ""
      data = (GameData::Move.get(id) rescue nil)
      return move_by_id(id) unless data
      ty = (GameData::Type.get(data.type).name rescue nil)
      pw = PokeAccess.attr_of(data, :power, :base_damage)
      tot = PokeAccess.attr_of(data, :total_pp, :totalpp)
      ci = (data.category rescue nil)
      ck = [:cat_physical, :cat_special, :cat_status][ci] if ci.is_a?(Integer)
      line = PokeAccess::MoveInfo.line((data.name rescue "").to_s, ty, pw || 0,
                                       (data.accuracy rescue 0),
                                       :pp => tot, :total_pp => tot,
                                       :cat => (ck ? PokeAccess::I18n.t(ck) : nil),
                                       :desc => (data.description rescue ""))
      lbl.empty? ? line : "#{lbl}. #{line}"
    rescue StandardError
      nil
    end

    # The focused move in the move reminder visuals (its list holds [move_id, "Nv. X"] pairs).
    def self.reminder_move(vis)
      moves = PokeAccess.ivar(vis, :@moves)
      idx = (vis.index rescue (vis.instance_variable_get(:@index) rescue 0))
      return nil unless moves && idx && idx >= 0 && idx < moves.length
      move_from_entry(moves[idx])
    rescue StandardError
      nil
    end
  end
end

# NOTE: UI::BaseScreen#show_message is voiced by menus/v22/screen_v22 via say_dialogue (which also feeds
# the repeat key). A second hook here that called speak() directly would be deduped away by say_dialogue,
# leaving the repeat key stale on v21 -- so it lives only in screen_v22.

# Party screen (classic panels): reads the cursor-highlighted member (deduped) and sets the contextual info
# so the info key can read its moves and ability.
#
# Stands down where the classic scene reports the move too. party_g6 splits the eras by WHICH object
# reports, since a game with panels is read by this hook whatever its scene is called -- true in twelve
# games, false in awakening, the one v17.2 fork with both shapes: its loop calls pbChangeSelection AND sets
# selected= on every panel, so both readers speak the same line and cut each other on every cursor move.
# The classic reader wins because it also names the Cancel and Confirm buttons, which a panel never sees.
PokeAccess::Hooks.after_hook("PokemonPartyPanel", :selected=) do |panel, _r, args|
  if args[0] && !PokeAccess::UIV21.scene_reports_party?
    pk = PokeAccess.ivar(panel, :@pokemon)
    if pk
      PokeAccess::Info.set_info(:pokemon, pk)
      ann = PokeAccess.ivar(panel, :@text)
      PokeAccess::UIV21.speak_changed(:party, PokeAccess::UIV21.party_member(pk, ann), panel.object_id)
    end
  end
end

# The trailing button row. It is NOT a PokemonPartyPanel: Cancel and Confirm are PokemonPartyConfirmCancelSprite
# subclasses, so the panel hook above never saw them and the screen went silent the moment the cursor left the
# last member -- with nothing to say the cursor had left the list at all. pbSelect is the one call that knows
# the new index, and it marks every sprite, so gating on "this slot is not a Pokemon" keeps the two apart:
# the panel hook still voices the members and this one only the buttons.
PokeAccess::Hooks.after_hook("PokemonParty_Scene", :pbSelect, :optional => true) do |scene, _r, args|
  idx = args[0]
  party = PokeAccess.ivar(scene, :@party)
  unless PokeAccess::Party.party_slot?(party, idx)
    PokeAccess::UIV21.speak_changed(:party, PokeAccess::Party.party_button(scene, idx), idx)
  end
end

# Clear the party dedup when the party screen opens, so reopening reads the first member even when it is
# the same one focused last time.
PokeAccess::Hooks.before_hook("PokemonParty_Scene", :pbStartScene) do |_s, _a|
  PokeAccess::UIV21.reset(:party)
end

# Move reminder / relearner (BetterMoveRelearner, UI::MoveReminder -> UI::MoveReminderVisuals): read the
# focused move on each cursor move. refresh_on_index_changed fires only on index change, so the first
# move is read separately on open (below), both deduped.
PokeAccess::Hooks.after_hook("UI::MoveReminderVisuals", :refresh_on_index_changed) do |vis, _r, _a|
  PokeAccess::UIV21.speak_changed(:reminder, PokeAccess::UIV21.reminder_move(vis))
end

# Read the first move on open (the visuals and move list already exist when main is entered), after
# clearing the dedup so reopening the relearner reads it again.
PokeAccess::Hooks.before_hook("UI::MoveReminder", :main) do |screen, _a|
  PokeAccess::UIV21.reset(:reminder)
  moves = PokeAccess.ivar(screen, :@moves)
  first = moves.is_a?(Array) ? moves[0] : nil
  PokeAccess::UIV21.speak_changed(:reminder, PokeAccess::UIV21.move_from_entry(first)) if first
end

# Region map: the bottom bar's location text changes as the cursor moves over the map (deduped).
PokeAccess::Hooks.after_hook("MapBottomSprite", :maplocation=) do |_s, _r, args|
  PokeAccess::UIV21.speak_changed(:regionmap, PokeAccess.clean(args[0].to_s))
end

# Clear the region-map dedup when the map screen opens, so reopening reads the location even when the cursor
# starts where it did last time. Bound under both names, since gen-6 calls the scene PokemonRegionMapScene
# without the underscore.
#
# scene_classes and not era_scene: resetting a dedup slot is the same act in either era, while era_scene
# answers "which name does the reader for MY data API bind to" and returns nothing when its own era's name
# is absent, which would leave every modern game unbound.
PokeAccess::Engine.scene_classes("PokemonRegionMapScene", "PokemonRegionMap_Scene").each do |cn|
  PokeAccess::Hooks.before_hook(cn, :pbStartScene) do |_s, _a|
    PokeAccess::UIV21.reset(:regionmap)
  end
end

# Pokegear: each option button is (re)selected every frame; read the focused one's name (deduped).
PokeAccess::Hooks.after_hook("PokegearButton", :selected=) do |btn, _r, args|
  PokeAccess::UIV21.speak_changed(:pokegear, (btn.name rescue nil).to_s) if args[0]
end

# Clear the pokegear dedup when the pokegear opens, so reopening reads the focused option even when it is
# the same one focused last time.
PokeAccess::Hooks.before_hook("PokemonPokegear_Scene", :pbStartScene) do |_s, _a|
  PokeAccess::UIV21.reset(:pokegear)
end
PokeAccess::Hooks.before_hook("Scene_Pokegear", :main, :optional => true) do |_s, _a|
  PokeAccess::UIV21.reset(:pokegear)
end

# Scene_Pokegear (the RMXP-style copy) keeps a HIDDEN but active Window_CommandPokemon underneath its
# sprite buttons, and the generic command hook read it in step with the button hook above: every option
# arrived twice. Claiming the window leaves the buttons as the single voice; dedicate is idempotent, so
# per-frame is fine.
PokeAccess::Hooks.after_hook("Scene_Pokegear", :update, :optional => true) do |scene, _r, _a|
  PokeAccess.dedicate(PokeAccess.sprite(scene, "command_window"))
end
