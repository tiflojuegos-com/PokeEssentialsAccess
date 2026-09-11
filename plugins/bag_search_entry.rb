# The per-key bag searcher of the Sky forks and Pokemon Z (WindowTextEntryKeyboardPerKey): it subclasses
# the keyboard window but rewrites insert/delete around its @helper without touching the base methods, so
# the echoes core hangs on Window_TextEntry_Keyboard never fire there. Hooked by its own name.
PokeAccess::Hooks.after_hook("WindowTextEntryKeyboardPerKey", :insert, :optional => true) do |_w, _r, args|
  PokeAccess::Keys.typing!
  c = args[0].to_s
  PokeAccess.speak(c == " " ? PokeAccess::I18n.t(:key_space) : c, true) unless c.empty?
end

PokeAccess::Hooks.after_hook("WindowTextEntryKeyboardPerKey", :delete, :optional => true) do |_w, _r, _a|
  PokeAccess::Keys.typing!
  PokeAccess.speak(PokeAccess::I18n.t(:te_deleted), true)
end

# One copy (the Sky fork) also redefines update without super, which hides the per-frame hook core hangs on
# Window_TextEntry: the typing suppression decays in four frames and the caret read lives there, so a typed
# letter that is also a mod key fired the key, and Left/Right inside the term said nothing. Bound only where
# the class owns update; the copies that inherit it (royal, Pokémon Z) are already driven by core's hook.
# hook_container for the same reason as core's: update calls insert and delete, which the hooks above read.
own_update = (PokeAccess.const_at("WindowTextEntryKeyboardPerKey").instance_methods(false).map { |m| m.to_sym }.include?(:update) rescue false)
if own_update
  PokeAccess::Hooks.after_hook("WindowTextEntryKeyboardPerKey", :update, :hook_container => true, :optional => true) do |win, _r, _a|
    if (win.active rescue true)
      PokeAccess::Keys.typing!
      PokeAccess::TextEntry.cursor_read(win)
    end
  end
end
