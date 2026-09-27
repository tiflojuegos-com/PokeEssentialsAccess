# Relict's in-battle Arcy Plate selector, drawn to a bitmap: rewriteArcyPlates(plates, index) runs on open and on
# every move, and the focused plate's name and type are read. Its "[D Key]" prompt, painted beside the command and
# fight menus' prompts while a plate is in the bag, is said once a round as a key hint.
module PokeAccess
  module RelictPlates
    # Says the plate prompt once per round while it shows, with the key the player uses for it now: visible, drawn
    # (opacity 0 with no plate in the bag) and at its place on screen (a battle's first slide-in leaves it off it).
    def self.prompt(scene)
      sp = PokeAccess.sprite(scene, "plate")
      return unless sp && (sp.visible rescue false) && (sp.opacity rescue 0).to_i > 0
      return if (sp.x rescue 0).to_i < 0
      round = (PokeAccess.ivar(scene, :@battle).turnCount rescue nil)
      return if round.nil? || PokeAccess.ivar(scene, :@pa_plate_round) == round
      scene.instance_variable_set(:@pa_plate_round, round)
      return unless PokeAccess::Verbosity.hints?
      PokeAccess.speak(PokeAccess::I18n.t(:rel_plates_hint, :key => PokeAccess::KeyHints.key(:z, "D")), false)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("relict") do
  # The dedup slot lives on the battle-long scene: reset when the picker opens, so the same plate reads again.
  before("Battle::Scene", :pbActivateArcyPlates) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :plate_idx)
  end
  after("Battle::Scene", :rewriteArcyPlates) do |scene, _r, args|
    plates = args[0]; index = args[1]
    next unless plates.is_a?(Array) && index && index >= 0 && index < plates.length
    next unless PokeAccess::Cursor.changed?(scene, :plate_idx, index)
    item = plates[index]
    nm = (GameData::Item.get(item).name rescue item.to_s)
    tsym = (::PLATE_TYPES[item] rescue nil)
    tnm = tsym ? (GameData::Type.get(tsym).name rescue nil) : nil
    txt = tnm ? "#{nm}, #{tnm}" : nm.to_s
    PokeAccess.speak_clean(txt, true)
  end
  # A container: the prompt's first appearance in a round slides in over a loop of pbUpdate.
  after("Battle::Scene", :pbRefreshUIPrompt, :hook_container => true) { |scene, _r, _a| PokeAccess::RelictPlates.prompt(scene) }
end
