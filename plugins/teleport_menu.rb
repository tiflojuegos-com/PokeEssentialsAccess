module PokeAccess
  # PokéLiberty's teleport menu (Teleport_Scene, its loop in pbUpdate): one destination at a time under @select, its
  # name and description lines, or "???" while locked; read as the cursor moves, with its place in the list.
  module TeleportMenu
    # The destination under the cursor as the screen writes it: the name and the description's lines, or unknown
    # for one still locked; then "n of total" while positions are said.
    def self.text(scene, sel)
      names = PokeAccess.ivar(scene, :@mapnames)
      return nil unless names.is_a?(Array) && sel.is_a?(Integer) && names[sel]
      parts = unlocked?(scene, sel) ? destination(scene, names, sel) : [PokeAccess::DexEntry.unknown_marks("???")]
      parts.push(PokeAccess::Verbosity.position(sel + 1, names.length))
      PokeAccess.sentences(parts.compact)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The name and the non-empty description lines of an unlocked destination.
    def self.destination(scene, names, sel)
      descs = PokeAccess.ivar(scene, :@map_descs)
      lines = descs.is_a?(Array) && descs[sel].is_a?(Array) ? descs[sel] : []
      [names[sel].to_s].concat(lines.map { |l| l.to_s }).map { |l| PokeAccess.clean(l) }.reject { |l| l.strip.empty? }
    end

    # Whether the screen shows the destination (its own pbTpUnlocked?), false when it cannot tell.
    def self.unlocked?(scene, sel)
      scene.respond_to?(:pbTpUnlocked?) ? (scene.pbTpUnlocked?(sel) ? true : false) : true
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end
  end
end

# pbUpdate is the menu's loop: the destination is polled each frame and said when @select changes.
PokeAccess::TeleportMenu::READER = PokeAccess::SceneWatcher.reader("Teleport_Scene", :pbUpdate, :teleport_dest,
                                                                   :optional => true) do |scene|
  sel = PokeAccess.ivar(scene, :@select)
  sel.is_a?(Integer) ? [sel, lambda { PokeAccess::TeleportMenu.text(scene, sel) }] : nil
end
