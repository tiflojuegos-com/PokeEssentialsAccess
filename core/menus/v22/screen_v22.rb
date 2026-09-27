module PokeAccess
  # Shared v22 UI:: helpers: screens drive inactive windows the generic reader skips, so each screen's cursor
  # callback is hooked (on_nav), and UI::BaseScreen's show_* messages are read for all of them.
  module V22
    # Speaks reader.call(visuals) after a visuals class's cursor callback, deduped per instance on [index, text];
    # binds nothing where the class is absent.
    # param method the cursor-moved method (set_index where a navigate loop skips refresh_on_index_changed)
    def self.on_nav(class_name, method = :refresh_on_index_changed, &reader)
      return unless PokeAccess::Engine.has?(class_name)
      PokeAccess::Hooks.after_hook(class_name, method) do |vis, _ret, _args|
        t = (reader.call(vis) rescue nil)
        key = [(vis.index rescue nil), t]
        unless key == PokeAccess.ivar(vis, :@access_v22_key)
          vis.instance_variable_set(:@access_v22_key, key)
          PokeAccess.speak(t, true, :menu)
        end
      end
    end
  end
end

# The in-screen messages, confirmations and choice prompts every v22 screen inherits from UI::BaseScreen.
if PokeAccess::Engine.has?("UI::BaseScreen")
  [:show_message, :show_confirm_message, :show_confirm_serious_message, :show_choice_message].each do |meth|
    PokeAccess::Hooks.before_hook("UI::BaseScreen", meth) do |_screen, args|
      PokeAccess.say_screen_message(args)
    end
  end
end
