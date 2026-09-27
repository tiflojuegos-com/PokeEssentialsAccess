# The fusion chooser's family row (DoublePreviewScreen#drawEvolutionIcons, shown while Up is held): a dot for each
# fusion of the two Pokemon's evolution lines, drawn as having a custom sprite or not, the current one marked. Said as
# it comes up: how many there are, how many have a custom sprite and which one is the current fusion.
module PokeAccess
  module IFHFusionFamily
    # Runs drawEvolutionIcons for one side (the block) keeping, in the row's order, each fusion it checks for a custom
    # sprite, and the current one.
    def self.recording(scene, dex_number, side)
      @rows = []
      yield
    ensure
      rows = @rows || []
      @rows = nil
      fam = PokeAccess.ivar(scene, :@access_if_family)
      fam = scene.instance_variable_set(:@access_if_family, {}) unless fam.is_a?(Hash)
      fam[side] = [rows, (GameData::Species.get(dex_number).species rescue nil)]
    end

    # One fusion of the row as drawEvolutionIcons checks it, while a row is being drawn.
    def self.note(species, custom)
      @rows.push([species, custom ? true : false]) if @rows
    end

    # The row of the side under the arrow as its line, or nil where none was drawn.
    def self.line(scene)
      fam = (PokeAccess.ivar(scene, :@access_if_family) || {})[PokeAccess.ivar(scene, :@selected).to_i]
      return nil unless fam && !fam[0].empty?
      rows, current = fam
      at = rows.index { |sp, _c| sp == current } || 0
      PokeAccess::I18n.t(:if2_family, :n => rows.length, :m => rows.select { |_s, c| c }.length, :k => at + 1)
    end
  end
end

PokeAccess::Hooks.wrap_global("customSpriteExistsSpecies", "if2_family", :after) do |args, ret|
  PokeAccess::IFHFusionFamily.note(args[0], ret)
end

# The row comes up once Up has been held a few frames; showAllEvoIcons runs every frame after that, the first time
# with the row still hidden.
PokeAccess::Game.define("infinitefusion_hoenn") do
  around("DoublePreviewScreen", :drawEvolutionIcons, :optional => true) do |s, nxt, args|
    PokeAccess::IFHFusionFamily.recording(s, args[0], args[4]) { nxt.call }
  end
  before("DoublePreviewScreen", :showAllEvoIcons, :optional => true) do |s, _a|
    t = PokeAccess.ivar(s, :@evo_icons_visible) ? nil : PokeAccess::IFHFusionFamily.line(s)
    PokeAccess.speak(t, true) if t
  end
end
