# The per-key bag searcher (WindowTextEntryKeyboardPerKey), whose insert and delete bypass the keyboard window's,
# so its echoes are hooked by its own name.
PokeAccess::Hooks.after_hook("WindowTextEntryKeyboardPerKey", :insert, :optional => true) do |_w, _r, args|
  PokeAccess::Keys.typing!
  c = args[0].to_s
  PokeAccess.speak(c == " " ? PokeAccess::I18n.t(:key_space) : c, true) unless c.empty?
end

PokeAccess::Hooks.after_hook("WindowTextEntryKeyboardPerKey", :delete, :optional => true) do |_w, _r, _a|
  PokeAccess::Keys.typing!
  PokeAccess.speak(PokeAccess::I18n.t(:te_deleted), true)
end

# A copy that redefines update without super (the Sky fork) gets core's per-frame typing suppression and caret
# read here; hook_container, as update drives the insert and delete hooks above.
own_update = (PokeAccess.const_at("WindowTextEntryKeyboardPerKey").instance_methods(false).map { |m| m.to_sym }.include?(:update) rescue false)
if own_update
  PokeAccess::Hooks.after_hook("WindowTextEntryKeyboardPerKey", :update, :hook_container => true, :optional => true) do |win, _r, _a|
    if (win.active rescue true)
      PokeAccess::Keys.typing!
      PokeAccess::TextEntry.cursor_read(win)
    end
  end
end
