# Infinite Fusion's fusion chooser. The two profiles ship this reader as byte-identical twins, and that is
# how a Kanto-only literal reached Hoenn: fusion ids are packed as head * NB_POKEMON + body, Kanto sets 501
# and Hoenn's 002_BattleSettings reassigns the same constant to 576. Decoding with the wrong base names a
# DIFFERENT fusion, confidently, on the one screen whose whole job is telling the two options apart -- so
# the base has to be read from the game.
require File.expand_path("../../../games/infinitefusion/fusion_preview", File.dirname(__FILE__))

# The engine's own Settings, at top level -- the reader must reach THIS one and not PokeAccess::Settings,
# which is what a bare Settings:: resolves to from inside the mod's namespace. 576 is Hoenn's real value,
# the one a hardcoded 501 got wrong.
module Settings; end
Settings.const_set(:NB_POKEMON, 576) unless Settings.const_defined?(:NB_POKEMON)

class FakeFusedSpecies
  attr_reader :name, :head_pokemon, :body_pokemon
  def initialize(name, head, body); @name = name; @head_pokemon = head; @body_pokemon = body; end
end
class FakeParent
  attr_reader :name
  def initialize(name); @name = name; end
end

Suite.define("infinite fusion preview: the packing base comes from the game, and the screen opens speaking") do
  ifp = PokeAccess::IFFusionPreview

  eq "the base is the game's own constant, never a literal", ifp.nb, Settings::NB_POKEMON

  # DoublePreviewScreen keeps the two PARENTS in the same ivars a fused species would use, and a Pokemon
  # answers to name -- which is why "not nil" was never a good enough test.
  fused = FakeFusedSpecies.new("Charizard/Blastoise", FakeParent.new("Charizard"), FakeParent.new("Blastoise"))
  truthy "a fused entry is a species", ifp.species?(fused)
  falsy "nil is not", ifp.species?(nil)

  eq "the description names the fusion and which parent gives what",
     ifp.describe(fused),
     PokeAccess::I18n.t(:if_fusion_side, :name => "Charizard/Blastoise", :head => "Charizard", :body => "Blastoise")

  scene = Object.new
  scene.instance_variable_set(:@species_left, fused)
  scene.instance_variable_set(:@species_right, fused)
  scene.instance_variable_set(:@selected, 0)

  # startSelection enters its loop already on @selected = 0 and only calls updateSelectionGraphics when the
  # choice CHANGES, so the opening hook is the only thing that reads the default option.
  SpeakCapture.clear
  ifp.focus(scene)
  spoke "opening on the left fusion speaks it", /Charizard/
  SpeakCapture.clear
  ifp.focus(scene)
  silent "and the first cursor move does not repeat it"

  SpeakCapture.clear
  scene.instance_variable_set(:@selected, -1)
  ifp.focus(scene)
  spoke "moving down to cancel says so", /#{PokeAccess::I18n.t(:if_fusion_cancel)}/
end
