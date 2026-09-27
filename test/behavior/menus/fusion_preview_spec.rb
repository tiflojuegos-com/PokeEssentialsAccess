# Infinite Fusion's fusion chooser: ids are head * NB_POKEMON + body, with the game's own base (Kanto 501, Hoenn 576).
require File.expand_path("../../../games/infinitefusion_common/fusion_preview", File.dirname(__FILE__))

# The engine's top-level Settings (inside the mod a bare Settings:: is PokeAccess::Settings), at Hoenn's 576.
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

  fused =FakeFusedSpecies.new("Charizard/Blastoise", FakeParent.new("Charizard"), FakeParent.new("Blastoise"))
  truthy "a fused entry is a species", ifp.species?(fused)
  falsy "nil is not", ifp.species?(nil)

  eq "the description names the fusion and which parent gives what",
     ifp.describe(fused),
     PokeAccess::I18n.t(:if_fusion_side, :name => "Charizard/Blastoise", :head => "Charizard", :body => "Blastoise")

  scene = Object.new
  scene.instance_variable_set(:@species_left, fused)
  scene.instance_variable_set(:@species_right, fused)
  scene.instance_variable_set(:@selected, 0)

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
