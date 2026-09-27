module PokeAccess
  # v22 load screen (UI::LoadVisuals) and save screen (UI::SaveVisuals): the focused command or save slot, with a
  # slot's summary from save_data ([filename, hash], the hash holding :player and :stats).
  module LoadSaveV22
    # A one-line summary of a save data hash, with the saved team as its icons show it, or the empty-slot label.
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
      team = (PokeAccess::LoadPanel.team(pl) if pl)
      parts.push(team) if team
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
    t = PokeAccess::Util.join_parts(parts)
    PokeAccess.speak(t, true)
  end

  # Left/right on Continue cycle the slot (set_slot_index): its number (and total from medium) and its summary.
  PokeAccess::Hooks.after_hook("UI::LoadVisuals", :set_slot_index) do |vis, _ret, _args|
    sd   = PokeAccess.ivar(vis, :@save_data)
    slot = (vis.slot_index rescue nil)
    next unless sd && slot
    hash = (sd[slot] ? sd[slot][1] : nil)
    pre = if PokeAccess::Verbosity.keep?(:positions, :medium)
            PokeAccess::I18n.t(:load_slot, :n => slot + 1, :tot => sd.length)
          else
            PokeAccess::I18n.t(:load_slot_bare, :n => slot + 1)
          end
    PokeAccess.speak("#{pre}. #{PokeAccess::LoadSaveV22.slot_summary(hash)}", true)
  end
end
