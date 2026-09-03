# The fusion chooser (FusionPreviewScreen < DoublePreviewScreen, 048_Fusion/). The game's signature screen
# -- the splicers show the two possible fusions (A head + B body, and the reverse) and you pick one -- and
# the least accessible: it draws two sprites, paints the types as images and the level into a bitmap, and
# NEVER writes the resulting fusion's name anywhere, encoding even "a custom sprite exists" as a colour
# tint. Left/Right choose, Down moves to cancel (-1), Up returns.
#
# Only initialize/getBackgroundPicture are overridden by the subclass, so hooking the parent's
# updateSelectionGraphics -- which the loop calls whenever the choice changes -- covers both. That call is
# the ONLY one, and startSelection enters its loop on @selected = 0, so the opening hook alongside it
# shares the dedup.
#
# @species_left/@species_right are filled with the two PARENT Pokemon, since FusionPreviewScreen#initialize
# calls super(poke1, poke2) and DoublePreviewScreen stores them as-is. So an ivar is used only when it
# really holds a species, and otherwise the fused id is rebuilt from the parents: GameData::Species.get is
# patched by the game to resolve a fused id into a FusedSpecies, so the combined name and the head/body
# split come out right, with .name still nil where the game has no split name, hence the fallback.
module PokeAccess
  module IFFusionPreview
    # The base the saga packs a fusion id with (head * nb + body). It has to come from the game and never
    # from a literal: Kanto's Settings::NB_POKEMON is 501, but Hoenn's 002_BattleSettings reassigns it to
    # 576 after 001_Settings sets 501. A hardcoded 501 there decoded to a DIFFERENT fusion and named it
    # with confidence -- and this file being a byte-identical twin is exactly how Kanto's number got there.
    #
    # The leading :: is load-bearing. The mod owns a PokeAccess::Settings, so inside this module a bare
    # Settings:: resolves to OURS by lexical scope, raises NameError and lands on the fallback -- silently
    # reintroducing the very literal this method exists to avoid.
    def self.nb
      (::Settings::NB_POKEMON rescue 501)
    end

    # True only for a species entry. DoublePreviewScreen stores Pokemon objects in the same ivars, and a
    # Pokemon answers to name -- which is exactly why "not nil" was never a good enough test.
    def self.species?(v)
      return false if v.nil?
      return false if defined?(::Pokemon) && v.is_a?(::Pokemon)
      return true if defined?(GameData::Species) && v.is_a?(GameData::Species)
      v.respond_to?(:head_pokemon)
    rescue StandardError
      false
    end

    # The fused species on one side, or nil. side 0 = left (poke1 head), 1 = right (the reverse).
    def self.side_species(scene, side)
      direct = PokeAccess.ivar(scene, side == 0 ? :@species_left : :@species_right)
      return direct if species?(direct)
      p1 = PokeAccess.ivar(scene, :@poke1)
      p2 = PokeAccess.ivar(scene, :@poke2)
      return nil unless p1 && p2
      a = (p1.species_data.id_number rescue nil)
      b = (p2.species_data.id_number rescue nil)
      return nil if a.nil? || b.nil?
      base = nb
      id = (side == 0) ? (a * base + b) : (b * base + a)
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
          d = describe(side_species(scene, sel.to_i))
          d || (PokeAccess.ivar(scene, :@poke1) ? PokeAccess::I18n.t(:if_fusion_unknown) : nil)
        end
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  before("DoublePreviewScreen", :startSelection) { |s, _a| PokeAccess::IFFusionPreview.focus(s) }
  after("DoublePreviewScreen", :updateSelectionGraphics) { |s, _r, _a| PokeAccess::IFFusionPreview.focus(s) }
end
