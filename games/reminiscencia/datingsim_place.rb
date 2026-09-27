module PokeAccess
  # Reminiscencia's dating-sim task screen: the date place strip, shown only as icons, with @index (0..11) into
  # DATING_PLACES.keys (the place name is DATING_PLACES[key][2]); the panel drawDataWindow paints for the focused
  # character's place; and the character list, whose levels and mood are numbers and faces beside each name.
  module ReminDatingPlace
    # The display name of the place at the given strip index, via the DATING_PLACES hash, or nil.
    def self.place_name(idx)
      keys = (DATING_PLACES.keys rescue nil)
      return nil unless keys && idx && idx >= 0 && idx < keys.length
      entry = DATING_PLACES[keys[idx]]
      (entry.is_a?(Array) && entry[2]) ? entry[2].to_s : keys[idx].to_s
    rescue StandardError
      nil
    end

    # The panel as painted, top to bottom, arrows as colons and a mood sign set apart from its word; then the
    # island's cleanliness, which only a bar shows, as a number.
    # param pairs the panel's text rows (PaintCapture.take_pairs)
    # param icons the images it drew (PaintCapture.icon_rows)
    def self.panel_text(pairs, icons)
      flags = (icons || []).select { |r| r[0].to_s =~ /flag_objective/ }.map { |r| r[2].to_i }
      rows = (pairs || []).select { |r| r[2].is_a?(Numeric) && r[3].is_a?(Numeric) }
      lines = rows.map { |r| r[3] }.uniq.sort.map do |y|
        t = rows.select { |r| r[3] == y }.sort_by { |r| r[2] }.map { |r| PokeAccess.clean(r[0].to_s) }.join(" ")
        t = t.gsub(/\s*->\s*/, ": ").strip.sub(/([^\s:+-])([+-]\d+)\z/) { "#{$1} #{$2}" }
        next nil if t.empty? || t =~ /\A-+\z/
        flags.any? { |fy| fy - y >= 0 && fy - y <= 8 } ? PokeAccess::I18n.t(:rem_task_needed, :item => t) : t
      end
      PokeAccess.sentences(lines.compact.push(PokeAccess::ReminDatingSim.clean_text))
    end

    # Keeps the panel drawDataWindow just painted on the scene, for the next announce.
    def self.note_panel(scene, pairs, icons)
      scene.instance_variable_set(:@access_task_panel, panel_text(pairs, icons))
    rescue StandardError
      nil
    end

    # Reads the focused place's panel when the strip moves (interrupting) or when a new character brings its own
    # place (queued, behind the character's row); the place's name when no panel was painted.
    def self.announce(scene)
      idx = PokeAccess.ivar(scene, :@index)
      row = (PokeAccess.ivar(scene, :@cmdwindow).index rescue nil)
      moved = PokeAccess::Cursor.changed?(scene, :place_row, row)
      changed = PokeAccess::Cursor.changed?(scene, :place_idx, idx)
      return unless changed || moved
      panel = PokeAccess.ivar(scene, :@access_task_panel)
      t = (panel.nil? || panel.to_s.empty?) ? place_name(idx) : panel
      PokeAccess.speak_clean(t, !moved)
    rescue StandardError
      nil
    end

    # One character row as the list paints it: the name, the work and cleaning levels, and the mood face (0 to 4).
    def self.character_row(name)
      work = (datingGet(name, "worklevel") rescue nil)
      clean = (datingGet(name, "cleanlevel") rescue nil)
      mood = (datingGet(name, "status") rescue nil)
      return name.to_s if work.nil? && clean.nil? && mood.nil?
      PokeAccess::I18n.t(:rem_dating_row, :name => name, :work => work.to_i, :clean => clean.to_i, :mood => mood.to_i)
    end
  end
end

PokeAccess::Game.define("reminiscencia") do
  # hook_container, since inputs drives the character list (@cmdwindow.update) and setGenderPage, whose readers the
  # guard would drop as nested.
  after("DatingSimTaskScreen", :inputs, :hook_container => true) do |scene, _result, _args|
    PokeAccess::ReminDatingPlace.announce(scene)
  end
  around("DatingSimTaskScreen", :drawDataWindow, :optional => true) do |scene, nxt, _a|
    icons = nil
    ret = nil
    pairs = PokeAccess::PaintCapture.sample { icons = PokeAccess::PaintCapture.icon_rows { ret = nxt.call } }
    PokeAccess::ReminDatingPlace.note_panel(scene, pairs, icons)
    ret
  end
end

# The task screen's character list (Window_CommandPokemonDatingSim): each row with its levels and mood.
PokeAccess::Menus.def_extractor("Window_CommandPokemonDatingSim") do |win, i|
  cmds = win.instance_variable_get(:@commands)
  (cmds.is_a?(Array) && cmds[i]) ? PokeAccess::ReminDatingPlace.character_row(cmds[i]) : nil
end
