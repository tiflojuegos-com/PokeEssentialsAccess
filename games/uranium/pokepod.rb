module PokeAccess
  # Uranium's PokePod (Scene_Pokegear): the command list the core reads sits off screen, and the box beside its
  # pictures describes the focused option; the description is kept for the info key and said while descriptions are.
  module UraniumPod
    # Takes the box's text after each update, whose update_info rewrites it, once per change: its lines as sentences.
    def self.info(scene)
      box = PokeAccess.ivar(scene, :@info)
      raw = box ? (box.text rescue "").to_s : ""
      t = PokeAccess.sentences(raw.split(/\r?\n/).map { |l| PokeAccess.clean(l) })
      return if t.empty? || !PokeAccess::Cursor.changed?(scene, :ura_pod_info, t)
      PokeAccess::Info.set_info(:text, t)
      PokeAccess.speak(t, false) if PokeAccess::Verbosity.descriptions?
    end
  end
end

PokeAccess::Game.define("uranium") do
  after("Scene_Pokegear", :update, :hook_container => true) { |scene, _r, _a| PokeAccess::UraniumPod.info(scene) }
  around("Scene_Pokegear", :main) do |_s, nxt, _a|
    begin
      nxt.call
    ensure
      PokeAccess::Info.clear_text
    end
  end
end
