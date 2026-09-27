module PokeAccess
  # The multi-save file selector (a cursor sliding over pre-drawn rows, not a command window): the focused save file
  # as the cursor moves, and the first one on open.
  module LoadScreen
    # The spoken label of a save-file row (its display name at savefiles[i][1]).
    def self.savefile_text(files, idx)
      return nil unless files.is_a?(Array) && files[idx].is_a?(Array)
      nm = files[idx][1]
      (nm && !nm.to_s.empty?) ? nm.to_s : nil
    rescue StandardError
      nil
    end
  end
end

# Opening the list: the first row, queued. :optional since single-save titles lack the method, and Hooks.missing
# lists only typos.
PokeAccess::Hooks.after_hook(PokeAccess::Engine.scene_class("PokemonLoad_Scene", "PokemonLoadScene").to_s, :pbDrawSaveCommands, :optional => true) do |_s, _r, args|
  txt = PokeAccess::LoadScreen.savefile_text(args[0], 0)
  PokeAccess.speak_clean(txt, false) if txt
end

# Moving the cursor: announce the now-focused save file, interrupting the previous one.
PokeAccess::Hooks.after_hook(PokeAccess::Engine.scene_class("PokemonLoad_Scene", "PokemonLoadScene").to_s, :pbMoveSaveSel, :optional => true) do |scene, _r, args|
  files = scene.instance_variable_get(:@savefiles)
  txt = PokeAccess::LoadScreen.savefile_text(files, args[0])
  PokeAccess.speak_clean(txt, true) if txt
end

# The per-slot sub-chooser some forks add (Normal Save / Autosave), repainted on entry and every left/right move:
# its five painted strings (slot name, two panel labels, two dates) are captured and replayed per focus.
module PokeAccess
  module LoadScreen
    def self.auto_sub(scene, index, arrayindex)
      rows = PokeAccess::PaintCapture.take(:ls_autosub)
      scene.instance_variable_set(:@access_autosub_rows, rows) if rows.is_a?(Array) && rows.length >= 5
      r = PokeAccess.ivar(scene, :@access_autosub_rows)
      return unless r.is_a?(Array) && r.length >= 5
      PokeAccess::Cursor.announce(scene, :ls_autosub, [arrayindex, index], true, false) do
        index.to_i == 0 ? "#{r[0]}. #{r[1]}, #{r[3]}" : "#{r[2]}, #{r[4]}"
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.before_hook("PokemonLoadScene", :pbChooseAutoSubFile, :optional => true) do |scene, _a|
  PokeAccess::PaintCapture.arm(:ls_autosub) unless PokeAccess.sprite(scene, "autosavefile")
end
PokeAccess::Hooks.after_hook("PokemonLoadScene", :pbChooseAutoSubFile, :optional => true) do |scene, _r, args|
  PokeAccess::LoadScreen.auto_sub(scene, args[0], args[1])
end

# The name of the save on offer, which multi-save titles paint above the panels: taken from the paint, queued.
PokeAccess::Hooks.around_hook(PokeAccess::Engine.scene_class("PokemonLoad_Scene", "PokemonLoadScene").to_s, :pbDrawCurrentSaveFile, :optional => true) do |_s, nxt, _a|
  ret = nil
  rows = PokeAccess::PaintCapture.sample { ret = nxt.call }
  t = PokeAccess::PaintCapture.text(rows.map { |r| r[0] })
  PokeAccess.speak(t, false) unless t.empty?
  ret
end
