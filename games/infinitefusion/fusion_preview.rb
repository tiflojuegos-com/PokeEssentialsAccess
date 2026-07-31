# The fusion chooser (FusionPreviewScreen < DoublePreviewScreen, 048_Fusion/). This is the game's signature
# screen -- the splicers show the two possible fusions (A head + B body, and the reverse) and you pick one --
# and it is the least accessible: it draws two sprites, paints the types as images and the level into a
# bitmap, and NEVER writes the resulting fusion's name anywhere. It even encodes whether a custom sprite
# exists as a colour tint. Left/Right choose, Down moves to cancel (-1), Up returns.
#
# Only initialize/getBackgroundPicture are overridden by the subclass, so hooking the parent's
# updateSelectionGraphics -- which the loop calls whenever the choice actually changes -- covers both.
# FusionPreviewScreen does not fill @species_left/@species_right (it keeps @poke1/@poke2 and rebuilds the
# fused ids), so the reader recomputes them the same way the constructor does. GameData::Species.get is
# patched by the game to resolve a fused id into a FusedSpecies, so the combined name and types come out
# right; .name can still be nil on species the game has no split name for, hence the head/body fallback.
module PokeAccess
  module IFFusionPreview
    NB = 501

    # The fused species on one side, or nil. side 0 = left (poke1 head), 1 = right (the reverse).
    def self.side_species(scene, side)
      direct = PokeAccess.ivar(scene, side == 0 ? :@species_left : :@species_right)
      return direct unless direct.nil?
      p1 = PokeAccess.ivar(scene, :@poke1)
      p2 = PokeAccess.ivar(scene, :@poke2)
      return nil unless p1 && p2
      a = (p1.species_data.id_number rescue nil)
      b = (p2.species_data.id_number rescue nil)
      return nil if a.nil? || b.nil?
      id = (side == 0) ? (a * NB + b) : (b * NB + a)
      (GameData::Species.get(id) rescue nil)
    rescue StandardError
      nil
    end

    # The spoken description of a fusion: its combined name plus which Pokemon gives the head and the body,
    # which is the part that actually tells the two options apart.
    def self.describe(sp)
      return nil if sp.nil?
      name = (sp.name rescue nil)
      head = (sp.head_pokemon.name rescue nil)
      body = (sp.body_pokemon.name rescue nil)
      return nil if name.nil? && head.nil? && body.nil?
      if head && body
        PokeAccess::I18n.t(:if_fusion_side, :name => (name || "#{head} #{body}"), :head => head, :body => body)
      else
        name.to_s
      end
    rescue StandardError
      nil
    end

    # Voices the focused option once per change: the two fusions, or the cancel button.
    def self.focus(scene)
      sel = PokeAccess.ivar(scene, :@selected)
      return if sel.nil?
      PokeAccess::Cursor.announce(scene, :if_fusion, sel, true) do
        if sel.to_i < 0
          PokeAccess::I18n.t(:if_fusion_cancel)
        else
          describe(side_species(scene, sel.to_i)) || PokeAccess::I18n.t(:if_fusion_unknown)
        end
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion") do
  after("DoublePreviewScreen", :updateSelectionGraphics) { |s, _r, _a| PokeAccess::IFFusionPreview.focus(s) }
end
