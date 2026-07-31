# The carriage / fast-travel picker (Teleport_Scene, script 0280). A list of destinations shown as a picture
# plus a description panel, with the focus in @select over @mapnames (and @map_descs alongside). The scene
# already holds both strings, so the reader just voices the focused one; whether the destination is available
# comes from the game's own pbTpUnlocked?, which is what decides if choosing it does anything.
module PokeAccess
  module AwakeningTeleport
    # Voices the focused destination once per change: its name, its description, and that it is still locked.
    def self.focus(scene)
      idx = PokeAccess.ivar(scene, :@select)
      names = PokeAccess.ivar(scene, :@mapnames)
      return unless idx.is_a?(Integer) && names.is_a?(Array) && idx >= 0 && idx < names.length
      descs = PokeAccess.ivar(scene, :@map_descs)
      name = PokeAccess.clean(names[idx].to_s).to_s.strip
      return if name.empty?
      PokeAccess::Cursor.announce(scene, :awk_tp, idx, true) do
        parts = [PokeAccess::I18n.t(:if2_pokenav, :name => name, :n => idx + 1, :tot => names.length)]
        d = (descs.is_a?(Array) ? descs[idx] : nil)
        parts.push(PokeAccess.clean(d.to_s)) if d && !d.to_s.strip.empty?
        parts.push(PokeAccess::I18n.t(:awk_tp_locked)) unless (scene.pbTpUnlocked?(idx) rescue true)
        parts.join(". ")
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("awakening") do
  after("Teleport_Scene", :pbUpdate) { |s, _r, _a| PokeAccess::AwakeningTeleport.focus(s) }
end
