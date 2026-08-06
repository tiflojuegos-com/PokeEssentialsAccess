# The carriage / fast-travel picker (Teleport_Scene, script 0280). A list of destinations shown as a picture
# plus a description panel, with the focus in @select over @mapnames (and @map_descs alongside). The scene
# already holds both strings, so the reader just voices the focused one; whether the destination is available
# comes from the game's own pbTpUnlocked?, which is what decides if choosing it does anything.
module PokeAccess
  module AwakeningTeleport
    @scene = nil

    def self.watch(scene); @scene = scene; end
    def self.unwatch; @scene = nil; end
    def self.poll; focus(@scene) if @scene; end

    # Voices the focused destination once per change: its name, its description, and that it is still locked.
    def self.focus(scene)
      idx = PokeAccess.ivar(scene, :@select)
      names = PokeAccess.ivar(scene, :@mapnames)
      return unless idx.is_a?(Integer) && names.is_a?(Array) && idx >= 0 && idx < names.length
      # Each MAP_DESCS entry is an ARRAY of text fragments, not a string -- the game's own commented template
      # shows the shape. Ruby 1.8.7 happens to flatten it on to_s, which is why this never misbehaved in the
      # game, but the same line on any newer interpreter would speak the brackets and quotes out loud.
      descs = PokeAccess.ivar(scene, :@map_descs)
      name = PokeAccess.clean(names[idx].to_s).to_s.strip
      return if name.empty?
      PokeAccess::Cursor.announce(scene, :awk_tp, idx, true) do
        parts = [PokeAccess::I18n.t(:list_entry, :name => name, :n => idx + 1, :tot => names.length)]
        d = (descs.is_a?(Array) ? descs[idx] : nil)
        d = d.join(" ") if d.is_a?(Array)
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
  # pbUpdate is not a per-frame update despite the name: it IS the screen's blocking loop, running until the
  # player leaves. Hooking after it meant the destination list was read exactly once, on the way out. So the
  # loop is held and the focus polled per frame instead, the same shape every other blocking picker uses.
  around("Teleport_Scene", :pbUpdate) do |scene, nxt, _a|
    PokeAccess::AwakeningTeleport.watch(scene)
    begin; nxt.call; ensure; PokeAccess::AwakeningTeleport.unwatch; end
  end
  poll_each_frame { PokeAccess::AwakeningTeleport.poll }
end
