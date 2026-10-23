module PokeAccess
  # UIHelper's message methods, which bypass pbMessage: each wrapped singleton method takes (helpwindow, msg, ...) and
  # says msg through say_dialogue first. A profile whose fork adds one of that shape, or keeps its own copy of the
  # module under another name, registers it with wrap.
  module UIHelperWrap
    # Wraps the named methods of owner (UIHelper, or a game's copy by its full constant path) once each.
    def self.wrap(names, owner = "UIHelper")
      mod = PokeAccess.const_at(owner)
      return unless mod.is_a?(Module)
      meta = class << mod; self; end
      names.each do |m|
        next unless meta.method_defined?(m) || meta.private_method_defined?(m)
        orig = "#{m}__access_orig"
        next if meta.method_defined?(orig) || meta.private_method_defined?(orig)
        PokeAccess::Hooks.keep_bound(meta, m) do |_again|
          meta.send(:alias_method, orig, m)
          meta.send(:define_method, m) do |helpwindow, msg, *rest, &blk|
            PokeAccess.say_dialogue(msg)
            send(orig, helpwindow, msg, *rest, &blk)
          end
        end
      end
    rescue StandardError => e
      PokeAccess.write_marker("hook_uihelper: #{e.message}\n")
    end
  end
end

PokeAccess::UIHelperWrap.wrap(["pbDisplay", "pbDisplayStatic", "pbConfirm", "pbShowCommands", "pbChooseNumber"])
