# GameData-era Essentials routes many plugin screen messages through the UIHelper module (UIHelper.
# pbDisplay / pbDisplayStatic / pbConfirm) instead of pbMessage, so those lines (egg-move learner prompts,
# plugin notices, yes/no questions) were never voiced. Wrap the module's singleton methods to read the
# message first, then run the original (via say_dialogue, so an identical line within half a second is
# voiced once and stays repeatable). UIHelper is a module method, out of reach of the class-hook helper,
# so it is aliased on the module's singleton class. Guarded to where UIHelper exists.
begin
  if defined?(UIHelper)
    class << UIHelper
      ["pbDisplay", "pbDisplayStatic", "pbConfirm"].each do |m|
        next unless method_defined?(m) || private_method_defined?(m)
        orig = "#{m}__access_orig"
        next if method_defined?(orig) || private_method_defined?(orig)
        alias_method(orig, m)
        define_method(m) do |helpwindow, msg, *rest, &blk|
          PokeAccess.say_dialogue(msg)
          send(orig, helpwindow, msg, *rest, &blk)
        end
      end
    end
  end
rescue StandardError => e
  PokeAccess.write_marker("hook_uihelper: #{e.message}\n")
end
