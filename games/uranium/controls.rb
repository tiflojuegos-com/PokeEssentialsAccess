module PokeAccess
  # Uranium's key binding screen (ControlBindingScene over Window_ControlBinding): each action with the keys it
  # paints, the two commands after them, the title on opening and the prompt shown while a new key is awaited.
  module UraniumControls
    # A row as painted: the action and its keys ("None" when it has none), marked required where the screen paints
    # an action it cannot save unbound in red; after the actions, Restore Defaults and Save.
    def self.row(win, i)
      opts = PokeAccess.ivar(win, :@options) || []
      return (i == opts.length ? _INTL("Restore Defaults") : _INTL("Save")) if i >= opts.length
      o = opts[i]
      text = "#{o.name}: #{o.text}"
      return text unless (o.keyboard.empty? && o.required rescue false)
      "#{text}, #{PokeAccess::I18n.t(:ura_ctrl_required)}"
    end

    # Says the focused row once per change of row or of the keys it shows (a key added or cleared), the first
    # read queued; the list is claimed from the generic reader, which has no words for it.
    def self.update(win)
      PokeAccess.dedicate(win)
      return unless win.active
      idx = win.index
      return if idx.nil? || idx < 0
      text = row(win, idx)
      PokeAccess::Cursor.announce(win, :ura_ctrl, [idx, text], true, false) { text }
    end

    # The screen's title as its window paints it, for the opening read; the screen is kept for the key prompt.
    def self.opened(scene)
      @scene = scene
      box = PokeAccess.sprite(scene, "title")
      box ? (box.text rescue nil) : nil
    end

    # Forgets the screen as it closes.
    def self.closed
      @scene = nil
    end

    # Says the prompt the screen shows while it waits for a new key.
    def self.awaiting
      box = PokeAccess.sprite(@scene, "textbox")
      t = box ? PokeAccess.clean((box.text rescue "").to_s) : ""
      PokeAccess.speak(t, true) unless t.empty?
    end
  end
end

PokeAccess::Game.define("uranium") do
  after("Window_ControlBinding", :update) { |win, _r, _a| PokeAccess::UraniumControls.update(win) }
  read_on_open("ControlBindingScene", :pbStartScene) { |scene| PokeAccess::UraniumControls.opened(scene) }
  after("ControlBindingScene", :pbEndScene) { |_s, _r, _a| PokeAccess::UraniumControls.closed }
end

PokeAccess::Hooks.wrap_singleton("KeyBindings", :detectInput, "hook_ura_detect_input", :before) do |_args, _r|
  PokeAccess::UraniumControls.awaiting
end
