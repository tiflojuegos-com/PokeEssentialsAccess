module PokeAccess
  # FL's Set the Controls as a module (SetControls, Decades and Hero Legacy), the pause menu's key rebinding screen: a row
  # per action with its keys, then Default and Exit, and a text box describing the focused row. Choosing a row offers its
  # options through the game's messages; the game then writes a prompt in the box and waits for the next key pressed,
  # taking it away from any other row that had it.
  module FlSetControlsV2
    @save_tries = 0
    @choosing = false

    # The row as painted: the action and its keys (ActionData#name, #keys_text), then the Default and Exit captions
    # through the game's translation, as drawItem paints them.
    def self.row(win, i)
      handler = PokeAccess.ivar(win, :@action_handler)
      if i < handler.size
        return PokeAccess::I18n.t(:chr_value, :name => handler[i].name.to_s, :value => key_words(handler[i].keys_text.to_s))
      end
      caption = i == handler.size ? "Default" : "Exit"
      (_INTL(caption) rescue caption).to_s
    end

    # A list of keys as painted, a key named by signs alone said sign by sign (";:" as both) by the remap's names, which a
    # screen reader would otherwise drop; any other name stays as painted.
    def self.key_words(names)
      names.split(", ").map do |name|
        next name unless name =~ /\A[!-\/:-@\[-`{-~]+\z/
        name.unpack("U*").map { |c| PokeAccess::ConfigMenu.char_name(c) || [c].pack("U") }.join(", ")
      end.join(", ")
    end

    # The keys of every row, in order.
    def self.keys(win)
      handler = PokeAccess.ivar(win, :@action_handler)
      (0...handler.size).map { |j| handler[j].keys_text.to_s }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end

    # Says the row just given a new key, cutting in on the prompt, then each other row whose keys that changed.
    # param before the rows' keys before set_new_input
    def self.rebound(win, before)
      now = keys(win)
      others = (0...now.length).select { |j| j != win.index && now[j] != before[j] }
      t = PokeAccess.sentences(([win.index] + others).map { |j| row(win, j) })
      PokeAccess.speak(t, true, :menu)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says every key went back to its default when an update swapped the window's whole list (the Default row, which
    # repaints each row under a still cursor and writes no message).
    # param before the list the window held as the update began
    def self.reset_check(win, before)
      now = PokeAccess.ivar(win, :@action_handler)
      PokeAccess.speak(PokeAccess::I18n.t(:rmp_all_reset), true, :menu) unless now.equal?(before)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The scene's text box as a watcher pair: the focused row's description keyed on itself, so each change is said once
    # and blanks stay quiet, and any other line keyed on the tries at saving too, as a second refusal of "Keep changes?"
    # writes "Fill all fields!" over itself. While the game waits for a key, the mod's own keys give way.
    def self.box_line(scene)
      box = PokeAccess.sprite(scene, "textbox")
      win = PokeAccess.sprite(scene, "controlwindow")
      PokeAccess::Keys.typing! if win && win.reading_input?
      t = box ? PokeAccess.clean((box.text rescue "").to_s) : ""
      [description?(win, t) ? t : [t, @save_tries], t]
    end

    # True if the line is the focused row's description.
    def self.description?(win, line)
      win ? PokeAccess.clean((win.item_description rescue "").to_s) == line : false
    end

    # Counts a try at saving (see box_line).
    def self.save_tried; @save_tries += 1; end

    # Runs the block as the game's list of a row's keys, whose rows are said as key_words says them.
    def self.choosing
      @choosing = true
      yield
    ensure
      @choosing = false
    end

    # True while the game lists a row's keys.
    def self.choosing?; @choosing; end
  end
end

PokeAccess::Menus.def_extractor("SetControls::Window_Controls") { |win, i| PokeAccess::FlSetControlsV2.row(win, i) }

# A key named by signs alone would be said as an empty row, or not at all, in the game's list of a row's keys.
PokeAccess::Hooks.override(PokeAccess::Menus, :unknown_row, :tag => "fl_set_controls_v2") do |_m, original, args|
  next original.call unless PokeAccess::FlSetControlsV2.choosing? && args[0].is_a?(String)
  PokeAccess::FlSetControlsV2.key_words(args[0])
end

PokeAccess::Hooks.around_hook("SetControls::Window_Controls", :set_new_input, :optional => true) do |win, nxt, _a|
  before = PokeAccess::FlSetControlsV2.keys(win)
  r = nxt.call
  PokeAccess::FlSetControlsV2.rebound(win, before)
  r
end

# Remove key takes a key off the row within the game's own menu, which then answers true: no prompt and no key to wait for.
PokeAccess::Hooks.around_hook("SetControls::Window_Controls", :open_action_menu, :optional => true) do |win, nxt, _a|
  before = PokeAccess::FlSetControlsV2.keys(win)
  r = nxt.call
  PokeAccess::FlSetControlsV2.rebound(win, before) if r
  r
end

PokeAccess::Hooks.around_hook("SetControls::Window_Controls", :choose_control_key, :optional => true) do |_win, nxt, _a|
  PokeAccess::FlSetControlsV2.choosing { nxt.call }
end

# Default swaps the list inside update: around, not after, so the window's own per-frame reads stay unguarded.
PokeAccess::Hooks.around_hook("SetControls::Window_Controls", :update, :optional => true) do |win, nxt, _a|
  before = PokeAccess.ivar(win, :@action_handler)
  r = nxt.call
  PokeAccess::FlSetControlsV2.reset_check(win, before)
  r
end

# The text box, polled each frame of main rather than hooked on the message window class it is built from: the key prompt
# is written right before the game blocks waiting for the key, whose loop still runs the frame pollers. Queued, as each
# line comes a frame after the row the window or a new key has just said.
PokeAccess::SceneWatcher.reader("SetControls::Scene", :main, :fl_set_controls_v2, :optional => true, :queued => true) do |s|
  PokeAccess::FlSetControlsV2.box_line(s)
end

# Only "Keep changes?" answered yes asks for the list to save.
PokeAccess::Hooks.after_hook("SetControls::Window_Controls", :controls, :optional => true) do |_win, _r, _a|
  PokeAccess::FlSetControlsV2.save_tried
end
