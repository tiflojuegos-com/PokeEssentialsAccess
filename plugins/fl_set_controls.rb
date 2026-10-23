module PokeAccess
  # FL's Set the Controls (the v16/v17 script), the key rebinding screen: a row per action and its key, then Default and
  # Exit; choosing a row makes the game write a prompt in its text box and wait for the next key pressed. Insurgence's
  # copy takes the new key away from any other row that had it (setNewInput), Soulstones' keeps it on both.
  module FlSetControls
    # The row as painted: the action and its key (ControlConfig#controlAction, #keyName), then the Default and Exit
    # captions through the game's translation, as drawItem paints them.
    def self.row(win, i)
      controls = PokeAccess.ivar(win, :@controls) || []
      if i < controls.length
        c = controls[i]
        return PokeAccess::I18n.t(:chr_value, :name => c.controlAction.to_s, :value => key_words(c.keyName.to_s))
      end
      caption = (i == controls.length) ? "Default" : "Exit"
      (_INTL(caption) rescue caption).to_s
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A key's name as painted, a name of signs alone said sign by sign (";:" as both) by the remap's names, which a
    # screen reader would otherwise drop; a name with a letter or digit stays as painted.
    def self.key_words(name)
      return name if name =~ /[A-Za-z0-9]/ || name.strip.empty?
      name.unpack("U*").map { |c| PokeAccess::ConfigMenu.char_name(c) || [c].pack("U") }.join(", ")
    end

    # The scene's text box as a watcher pair: its line, keyed on itself, so each change is said once and blanks stay
    # quiet.
    def self.box_line(scene)
      box = PokeAccess.sprite(scene, "textbox")
      t = box ? PokeAccess.clean((box.text rescue "").to_s) : ""
      [t, t]
    end

    # The text box's reader (SceneWatcher.reader), kept so a confirmation's return can make it forget its line.
    def self.box_reader=(reader); @box_reader = reader; end

    # Forgets the text box's line, so the next poll says it even unchanged.
    def self.forget_box
      PokeAccess::Cursor.reset(@box_reader, :fl_set_controls) if @box_reader
    end

    # The rows' key codes, in order.
    def self.codes(win)
      (PokeAccess.ivar(win, :@controls) || []).map { |c| (c.keyCode rescue nil) }
    end

    # The rows besides the focused one whose key setNewInput took away (0, painted "None").
    # param before the rows' key codes before the call
    def self.emptied(win, before)
      return [] unless before.is_a?(Array)
      now = codes(win)
      (0...now.length).select { |j| j != win.index && now[j] == 0 && before[j].to_i != 0 }
    end

    # Says the row just given a new key, interrupting the prompt, then each row left without one.
    # param before the rows' key codes before setNewInput
    def self.rebound(win, before = nil)
      parts = [row(win, win.index)]
      emptied(win, before).each { |j| parts.push(row(win, j)) }
      t = PokeAccess.sentences(parts)
      PokeAccess.speak(t, true, :menu) unless t.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says every key went back to its default when an update swapped the window's whole list (the Default row, which
    # repaints each row under a still cursor and writes no message).
    # param before the list the window held as the update began
    def self.reset_check(win, before)
      now = PokeAccess.ivar(win, :@controls)
      return if before.nil? || now.nil? || now.equal?(before)
      PokeAccess.speak(PokeAccess::I18n.t(:rmp_all_reset), true, :menu)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Menus.def_extractor("Window_PokemonControls") { |win, i| PokeAccess::FlSetControls.row(win, i) }

PokeAccess::Hooks.around_hook("Window_PokemonControls", :setNewInput, :optional => true) do |win, nxt, _a|
  before = PokeAccess::FlSetControls.codes(win)
  r = nxt.call
  PokeAccess::FlSetControls.rebound(win, before)
  r
end

# Default swaps the list inside update: around, not after, so the window's own per-frame reads stay unguarded.
PokeAccess::Hooks.around_hook("Window_PokemonControls", :update, :optional => true) do |win, nxt, _a|
  before = PokeAccess.ivar(win, :@controls)
  r = nxt.call
  PokeAccess::FlSetControls.reset_check(win, before)
  r
end

# The text box, polled each frame of pbMain rather than hooked on the message window class it is built from: the key
# prompt is written right before the game blocks waiting for the key, whose loop still runs the frame pollers.
PokeAccess::FlSetControls.box_reader =
  PokeAccess::SceneWatcher.reader("PokemonControlsScene", :pbMain, :fl_set_controls, :optional => true) do |s|
    PokeAccess::FlSetControls.box_line(s)
  end

# Yes to "Save changes?" with a key missing empties the box and writes "Fill all fields!" again within one frame, which
# the poll never sees: the line is forgotten as the confirmation returns, so the second refusal is said too.
PokeAccess::Hooks.wrap_kernel("pbConfirmMessage", "plugin_fl_set_controls_confirm", :after) do |_args, _r|
  PokeAccess::FlSetControls.forget_box
end
