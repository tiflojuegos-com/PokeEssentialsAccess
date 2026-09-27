module PokeAccess
  # Pokegear phone contacts: "ready for rematch" after a contact whose icon says so, read off the live phone scene.
  module Phone
    @scene = nil

    # Holds / releases the active phone scene around its run.
    def self.watch(s); @scene = s; end
    def self.unwatch; @scene = nil; end

    # True if the contact at list index i is ready for a rematch (dual-engine).
    def self.rematch_ready?(i)
      sc = @scene
      return false unless sc
      cts = PokeAccess.ivar(sc, :@contacts)
      return (cts[i].can_rematch? rescue false) if cts && cts[i]
      trs = PokeAccess.ivar(sc, :@trainers)
      t = (trs ? trs[i] : nil)
      (t.is_a?(Array) && t.length > 3) ? !!t[3] : false
    rescue StandardError
      false
    end
  end
end

# Holds the live phone scene: modern between pbStartScene and pbEndScene, gen-6 around its single start.
PokeAccess::Hooks.after_hook("PokemonPhone_Scene", :pbStartScene) { |scene, _r, _a| PokeAccess::Phone.watch(scene) }
PokeAccess::Hooks.after_hook("PokemonPhone_Scene", :pbEndScene) { |_s, _r, _a| PokeAccess::Phone.unwatch }
PokeAccess::Hooks.around_hook("PokemonPhoneScene", :start) do |scene, call_next, _a|
  PokeAccess::Phone.watch(scene)
  begin
    call_next.call
  ensure
    PokeAccess::Phone.unwatch
  end
end

# Contact list (Window_PhoneList): the generic reader gives the name; append the rematch-ready status.
PokeAccess::Menus.def_extractor("Window_PhoneList") do |win, i|
  cmds = win.instance_variable_get(:@commands)
  name = (cmds && cmds[i]) ? cmds[i].to_s : ""
  PokeAccess::Phone.rematch_ready?(i) ? "#{name}, #{PokeAccess::I18n.t(:phone_rematch)}" : name
end
