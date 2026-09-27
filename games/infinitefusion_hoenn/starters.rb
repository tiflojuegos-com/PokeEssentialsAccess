# Hoenn's starter picker (StartersSelectionScene, all sprites), read after each updateStarterSelectionGraphics, which
# paints the starter's name and its category line.
module PokeAccess
  module IF2Starters
    # Speaks the focused starter once per change at the Pokedex entry reading's level: its name, from medium the
    # category line painted under it, in full whether its sprite is shiny, and its place in the row (not in the
    # single variant); the info key keeps it whole.
    def self.focus(scene)
      idx = PokeAccess.ivar(scene, :@index)
      list = PokeAccess.ivar(scene, :@starters_species)
      return unless idx.is_a?(Integer) && list.is_a?(Array) && idx >= 0 && idx < list.length
      name = (PokeAccess::Data.species_name(list[idx]) || list[idx].to_s)
      PokeAccess::Cursor.announce(scene, :if2_starter, idx, true) do
        label = PokeAccess::Verbosity.info_line(:dex_entry, parts(scene, idx, name))
        single?(scene) ? label : PokeAccess::Verbosity.list_entry(label, idx + 1, list.length)
      end
    rescue StandardError
      nil
    end

    # The starter's parts: the name, the category line the screen painted for it, and the shiny mark.
    def self.parts(scene, idx, name)
      painted = PokeAccess.ivar(scene, :@access_if2_painted)
      out = [[name, :brief]]
      out.push([PokeAccess.clean(painted[1].to_s), :medium]) if painted.is_a?(Array) && painted[1]
      pk = (PokeAccess.ivar(scene, :@starter_pokemon)[idx] rescue nil)
      out.push([PokeAccess::I18n.t(:pk_shiny), :full]) if pk && PokeAccess::Party.shiny?(pk)
      out
    end

    # True for the one-starter variant, whose row pads two invisible placeholders (its @index is always 1).
    def self.single?(scene)
      scene.class.to_s == "StartersSelectionSceneSingle"
    rescue StandardError
      false
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  # Also covers StartersSelectionSceneSingle, which inherits updateStarterSelectionGraphics.
  after("StartersSelectionScene", :updateStarterSelectionGraphics) { |s, _r, _a| PokeAccess::IF2Starters.focus(s) }
  # Inside the reader above: keeps the name and category lines the repaint draws, for it to read.
  around("StartersSelectionScene", :updateStarterSelectionGraphics) do |s, nxt, _a|
    r = nil
    rows = PokeAccess::PaintCapture.sample { r = nxt.call }
    s.instance_variable_set(:@access_if2_painted, rows.map { |row| row[0] })
    r
  end
end
