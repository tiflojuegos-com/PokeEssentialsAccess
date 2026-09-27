# Royal's new-game screens, gamedata pass: the controls picture said from its transcription (its module evaluated on
# its own, as Anil's hook on the same ButtonEventScene runs in this pass) and the selectors' options by what their
# pictures show. The selector stand-ins come before the profile file loads: a hook on a missing class binds nothing.
class MenuSelector2OpcionesScene
  def selectOpc1; :normal; end
  def selectOpc2; :challenge; end
  def pbEndScene; :closed; end
end

class TonoPielSelectorScene
  (1..4).each { |n| define_method("selectTono#{n}") { n } }
end

load File.expand_path("../../../games/royal/selectors.rb", File.dirname(__FILE__))
royal_controls_path = File.expand_path("../../../games/royal/controles.rb", File.dirname(__FILE__))
eval(File.read(royal_controls_path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, royal_controls_path)

Suite.define("royal controls: the one picture is said from its transcription, its keys as the player has them") do
  t = PokeAccess::I18n
  scene = ButtonEventScene.new
  SpeakCapture.clear
  PokeAccess::RoyalControls.say(scene)
  eq "the transcribed picture, interrupting", SpeakCapture.log, [[t.t(:royal_controls), true]]
  truthy "Royal's own list, not Anil's", t.t(:royal_controls) != t.t(:anil_controls)
  begin
    PokeAccess::Config.rebinds = { :c => 0x4B, :l => 0x4A }
    SpeakCapture.clear
    PokeAccess::RoyalControls.say(scene)
    line = SpeakCapture.last.to_s
    truthy "a key rebound with the mod is said as the one in use", line.include?("K: aceptar e interactuar")
    truthy "the second key of a line as well", line.include?("Alt o J: aumentar la velocidad")
  ensure
    PokeAccess::Config.rebinds = {}
  end
  scene.instance_variable_set(:@access_labels, { 1 => ["Pulsa C para hablar."] })
  SpeakCapture.clear
  PokeAccess::RoyalControls.say(scene)
  silent "a copy that registered paragraphs of its own is left to core"
end

Suite.define("royal selectors: each option by what its picture shows") do
  t = PokeAccess::I18n
  normal = PokeAccess.sentences([t.t(:rsel_normal), t.t(:rsel_normal_desc)])
  challenge = PokeAccess.sentences([t.t(:rsel_challenge), t.t(:rsel_challenge_desc)])
  diff = MenuSelector2OpcionesScene.new
  SpeakCapture.clear
  eq "the hook keeps the selector's own value", diff.selectOpc1, :normal
  eq "full: the mode and the sentence under it", SpeakCapture.lines, [normal]
  eq "which the info key keeps", PokeAccess::Info.info_text, normal
  PokeAccess::Config.verbosity = :brief
  SpeakCapture.clear
  diff.selectOpc2
  eq "brief: the mode alone", SpeakCapture.lines, [t.t(:rsel_challenge)]
  eq "the info key says its sentence all the same", PokeAccess::Info.info_text, challenge
  PokeAccess::Config.verbosity = :full
  diff.pbEndScene
  eq "closing the selector takes it off the info key", PokeAccess::Info.info_text, nil

  skin = TonoPielSelectorScene.new
  SpeakCapture.clear
  (1..4).each { |n| skin.send("selectTono#{n}") }
  eq "each portrait by what it shows, and its place among the four", SpeakCapture.lines,
     (1..4).map { |n| t.t(:list_entry, :name => t.t("rsel_skin_#{n}".to_sym), :n => n, :tot => 4) }
  truthy "four different portraits", (1..4).map { |n| t.t("rsel_skin_#{n}".to_sym) }.uniq.length == 4
  PokeAccess::Config.verbosity = :brief
  SpeakCapture.clear
  skin.selectTono2
  eq "brief: the portrait alone", SpeakCapture.lines, [t.t(:rsel_skin_2)]
  PokeAccess::Config.verbosity = :full
end
