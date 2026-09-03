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
