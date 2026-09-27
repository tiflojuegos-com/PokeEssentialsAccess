module PokeAccess
  # UIHelper's message methods, which bypass pbMessage: each wrapped singleton method takes (helpwindow, msg, ...) and
  # says msg through say_dialogue first. A profile whose fork adds one of that shape registers it with wrap.
  module UIHelperWrap
    def self.wrap(names)
      return unless defined?(::UIHelper)
      meta = class << ::UIHelper; self; end
      names.each do |m|
        next unless meta.method_defined?(m) || meta.private_method_defined?(m)
        orig = "#{m}__access_orig"
        next if meta.method_defined?(orig) || meta.private_method_defined?(orig)
        meta.send(:alias_method, orig, m)
        meta.send(:define_method, m) do |helpwindow, msg, *rest, &blk|
          PokeAccess.say_dialogue(msg)
          send(orig, helpwindow, msg, *rest, &blk)
        end
      end
    rescue StandardError => e
      PokeAccess.write_marker("hook_uihelper: #{e.message}\n")
    end
  end
end

PokeAccess::UIHelperWrap.wrap(["pbDisplay", "pbDisplayStatic", "pbConfirm", "pbShowCommands", "pbChooseNumber"])
