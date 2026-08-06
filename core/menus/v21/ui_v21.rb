module PokeAccess
  # GameData-era Essentials UI screens (the UI:: framework and assorted plugin scenes). Screens using classic
  # Window_DrawableCommand (bag, options, mart, command lists, the pokedex list) are read by the core
  # generic hook/extractors; this adds the rest: in-screen messages, the focused party member, the move
  # reminder, the region-map location and the pokegear option. Per-screen reads dedupe (these games
  # re-assert the selection every frame).
  module UIV21
    # Speaks text only when it changes for a given tag (the GameData-era UI re-selects every frame, so
    # without this the focused item would repeat continuously). Backed by Cursor's module-wide table (no
    # scene instance to hang on here). param tag a symbol naming the source, so different screens do not
    # shadow each other
    def self.speak_changed(tag, text)
      return if text.nil? || text.to_s.empty?
      PokeAccess::Cursor.announce(nil, tag, text) { text }
    rescue StandardError
      nil
    end

    # Clears a dedup tag so the next read for it speaks even if the text is unchanged (used when a screen
    # reopens with the cursor on the same item as last time).
    def self.reset(tag); PokeAccess::Cursor.reset(nil, tag); end

    # Spoken summary of a party member: name, gender, level, hp and fainted state, plus the eligibility
    # annotation ("able"/"not able") when the party is opened to use an item or pick a move target.
    # param annotation the panel's annotation text, or nil/blank when none applies
    def self.party_member(pk, annotation = nil)
      return nil unless pk
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

    # Detail of a single reminder-list entry: a [move_id, "Nv. X"] pair, an id, or a move object.
    def self.move_from_entry(m)
      return nil unless m
      id = m.is_a?(Array) ? m[0] : (m.id rescue m)
      move_by_id(id)
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

# Party screen (classic panels): read the cursor-highlighted member (deduped); also sets the contextual
# info so the info key can read its moves/ability.
PokeAccess::Hooks.after_hook("PokemonPartyPanel", :selected=) do |panel, _r, args|
  if args[0]
    pk = PokeAccess.ivar(panel, :@pokemon)
    if pk
      PokeAccess::Info.set_info(:pokemon, pk)
      ann = PokeAccess.ivar(panel, :@text)
      PokeAccess::UIV21.speak_changed(:party, PokeAccess::UIV21.party_member(pk, ann))
    end
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
# starts on the same place as last time.
#
# Bound under both names, not the modern one alone: gen-6 calls the scene PokemonRegionMapScene, without the
# underscore, so those games never got this reset at all -- reopen the map on the same spot and it stayed
# quiet, because the dedup still held the location from last time. Resetting a dedup slot is the same act in
# either era, so this is scene_classes and not era_scene: era_scene answers "which of these two names does
# the reader for MY data API bind to" and returns nothing when its own era's name is absent, which would
# leave every modern game unbound -- the exact silence this reset exists to prevent.
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
