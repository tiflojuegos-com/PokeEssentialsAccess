module PokeAccess
  # v22 title load screen (Essentials v22: UI::LoadVisuals) and in-game save screen (UI::SaveVisuals). Both
  # show save-slot panels from save_data ([filename, hash], hash has :player and :stats). Reads the focused
  # title command / save slot and, for a slot, a summary (trainer, play time, dex seen) via the load_* strings.
  module LoadSaveV22
    # A one-line summary of a save data hash, or the empty-slot label.
    def self.slot_summary(hash)
      return PokeAccess::I18n.t(:pc_empty) unless hash.is_a?(Hash)
      pl = hash[:player]
      st = hash[:stats]
      parts = []
      parts.push(PokeAccess::I18n.t(:load_save, :name => pl.name)) if pl && (pl.name rescue nil)
      hm = PokeAccess::Util.playtime_parts((st.play_time.to_i rescue nil))
      parts.push(PokeAccess::I18n.t(:load_play, :h => hm[0], :m => hm[1])) if hm
      seen = (pl.pokedex.seen_count rescue nil)
      parts.push(PokeAccess::I18n.t(:load_dex, :n => seen)) if seen
      parts.empty? ? PokeAccess::I18n.t(:pc_empty) : parts.join(". ")
    rescue StandardError
      nil
    end
  end
end

# In-game save: the focused slot's summary as the cursor moves.
if PokeAccess::Engine.has?("UI::SaveVisuals")
  PokeAccess::Hooks.after_hook("UI::SaveVisuals", :set_index) do |vis, _ret, _args|
    sd = PokeAccess.ivar(vis, :@save_data)
    i  = (vis.index rescue nil)
    next unless sd && i
    hash = (sd[i] ? sd[i][1] : nil)
    PokeAccess.speak(PokeAccess::LoadSaveV22.slot_summary(hash), true)
  end
end

# Title screen: the focused command (Continue/New Game/Options...), plus the save summary on Continue.
if PokeAccess::Engine.has?("UI::LoadVisuals")
  PokeAccess::Hooks.after_hook("UI::LoadVisuals", :set_index) do |vis, _ret, _args|
    cmds = PokeAccess.ivar(vis, :@commands)
    idx  = PokeAccess.ivar(vis, :@index)
    next unless cmds && idx
    parts = [cmds[idx]]
    if idx == :continue
      sd   = PokeAccess.ivar(vis, :@save_data)
      slot = (vis.slot_index rescue nil)
      hash = (sd && slot && sd[slot] ? sd[slot][1] : nil)
      parts.push(PokeAccess::LoadSaveV22.slot_summary(hash)) if hash
    end
    t = parts.compact.reject { |s| s.to_s.empty? }.join(". ")
    PokeAccess.speak(t, true) unless t.empty?
  end

  # On Continue with several saves, LEFT/RIGHT cycle the slot via set_slot_index (not set_index), so the
  # chosen save would otherwise stay silent on a destructive pick. Announce the slot number and its summary.
  PokeAccess::Hooks.after_hook("UI::LoadVisuals", :set_slot_index) do |vis, _ret, _args|
    sd   = PokeAccess.ivar(vis, :@save_data)
    slot = (vis.slot_index rescue nil)
    next unless sd && slot
    hash = (sd[slot] ? sd[slot][1] : nil)
    pre  = PokeAccess::I18n.t(:load_slot, :n => slot + 1, :tot => sd.length)
    PokeAccess.speak("#{pre}. #{PokeAccess::LoadSaveV22.slot_summary(hash)}", true)
  end
end
