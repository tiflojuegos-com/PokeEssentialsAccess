module PokeAccess
  # Shared helpers for the v22 UI:: rework (Essentials v22: UI::BaseScreen / UI::BaseVisuals). Each screen
  # drives its list/cursor PASSIVELY -- the windows are created with active = false and the screen reads
  # their index itself -- so the active-only generic command-window reader never sees them. Instead we hook
  # each screen's own "cursor moved" callback (refresh_on_index_changed) to read the focused item, and we
  # read every in-screen message/prompt from UI::BaseScreen's show_* methods (inherited by all screens).
  module V22
    # Announces a v22 screen's focused entry whenever its cursor moves: after_hooks the visuals class's
    # cursor callback (refresh_on_index_changed by default, or set_index on screens whose alternate
    # navigate loops skip refresh_on_index_changed) and speaks reader.call(visuals), deduped per instance
    # by [index, text] so a redraw in place stays silent. No-op unless the class exists, keeping gen-6/v21
    # games quiet.
    # param class_name the UI::*Visuals class as a string
    # param method the cursor-moved method to hook
    # param reader block taking the visuals and returning the line to speak
    def self.on_nav(class_name, method = :refresh_on_index_changed, &reader)
      return unless PokeAccess::Engine.has?(class_name)
      PokeAccess::Hooks.after_hook(class_name, method) do |vis, _ret, _args|
        t = (reader.call(vis) rescue nil)
        key = [(vis.index rescue nil), t]
        unless key == PokeAccess.ivar(vis, :@access_v22_key)
          vis.instance_variable_set(:@access_v22_key, key)
          PokeAccess.speak(t, true) if t && !t.to_s.empty?
        end
      end
    end
  end
end

# In-screen messages, confirmations and choice prompts: every v22 screen inherits these from
# UI::BaseScreen, so one set of hooks reads them all (via say_dialogue, which dedupes a repeat within half a
# second). The Yes/No and choice windows are active Window_CommandPokemons read by the generic reader.
if PokeAccess::Engine.has?("UI::BaseScreen")
  [:show_message, :show_confirm_message, :show_confirm_serious_message, :show_choice_message].each do |meth|
    PokeAccess::Hooks.before_hook("UI::BaseScreen", meth) do |_screen, args|
      PokeAccess.say_dialogue(args[0].to_s) if args[0] && !args[0].to_s.empty?
    end
  end
end
