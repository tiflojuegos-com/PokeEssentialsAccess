# The words said are the ones painted: the party's and the PC's buttons, a lent Pokemon's trainer and number, no
# item as "none", and no experience for a Shadow Pokemon, whose page writes its heart instead.
class PokeSelectionCancelSprite3; end
Suite.define("painted words: buttons, PC buttons, the loaned trainer, no item") do
  t = PokeAccess::I18n
  pa = PokeAccess::Party
  btn = PokeSelectionCancelSprite3.new
  btn.instance_variable_set(:@access_label, "SALIR")
  eq "the party button says the word it paints", pa.button_label(btn), "SALIR"
  eq "and without one, what its class says", pa.button_label(PokeSelectionCancelSprite3.new), t.t(:pc_cancel)

  painted = [["Party: 3", :positions, 270, 334], ["Exit", :positions, 446, 334], ["Pika", :positions, 10, 14],
             ["Static", :positions, 86, 312]]
  eq "the PC's two written buttons, party then exit, apart from the panel", pa.pc_buttons(painted), ["Party: 3", "Exit"]
  eq "none where they are pictures", pa.pc_buttons([["Pika", :positions, 10, 14]]), []
  royal = [["Equipo: 3", :positions, 292, 390], ["[W]: Buscar", :positions, 436, 390], ["Salir", :positions, 586, 390]]
  eq "a key hint painted between them is no button (Royal's exit read as the search key)", pa.pc_buttons(royal),
     ["Equipo: 3", "Salir"]
  eq "it is a hint of that row", pa.pc_hints(royal), ["[W]: Buscar"]

  lent = Poke.build(:name => "Pika")
  lent.define_singleton_method(:ot) { "" }
  lent.define_singleton_method(:publicID) { 12345 }
  facts = PokeAccess::Summary.trainer_facts(lent)
  eq "a lent Pokemon's trainer and number as the page writes them", facts[0, 2],
     [t.t(:sum_ot, :name => t.t(:sum_loaned)), t.t(:sum_id, :id => t.t(:pdx_unknown_short))]
  eq "no item is written as none", PokeAccess::Summary.item_fact(Poke.build(:item => 0)),
     t.t(:sum_item, :i => t.t(:sum_none))
  shadow = Poke.build(:name => "Oscuro")
  shadow.define_singleton_method(:isShadow?) { true }
  shadow.define_singleton_method(:exp) { 4321 }
  plain = Poke.build(:name => "Claro")
  plain.define_singleton_method(:exp) { 4321 }
  truthy "an ordinary Pokemon's facts say the experience", PokeAccess::Summary.trainer_facts(plain).any? { |f| f.include?("4321") }
  falsy "a Shadow Pokemon's leave it to the heart the page writes",
        PokeAccess::Summary.trainer_facts(shadow).any? { |f| f.include?("4321") }
end

# Reminiscencia's party panel (no level) and its member menu's limits box. The profile is loaded once; its level
# override is taken back after each suite, its menu hook stays and speaks only where a scene paints the box.
module RemiPartySpec
  def self.with_profile
    meta = (class << PokeAccess::Party; self; end)
    meta.send(:alias_method, :remi_spec_panel_level?, :panel_level?)
    unless @profile
      load File.expand_path("../../../games/reminiscencia/party_panel.rb", File.dirname(__FILE__))
      @profile = PokeAccess::Party.method(:panel_level?)
    end
    PokeAccess::Party.define_singleton_method(:panel_level?, @profile)
    yield
  ensure
    meta.send(:alias_method, :panel_level?, :remi_spec_panel_level?)
    meta.send(:remove_method, :remi_spec_panel_level?)
  end
end

Suite.define("reminiscencia: the party line without the level its panel leaves out, and the limits box") do
  t = PokeAccess::I18n
  RemiPartySpec.with_profile do
    pk = Poke.build(:name => "Chispa", :level => 12, :hp => 30, :totalhp => 30)
    eq "name, sign and HP, no level", PokeAccess::Party.member_line(pk),
       t.t(:pty_member_nolv, :name => "Chispa", :sex => " \xE2\x99\x82", :hp => 30, :tot => 30)

    scene = PokemonScreen_Scene.new
    box = Struct.new(:text).new("Max. EV total: 510\nEscamas: 3/10")
    scene.sprites["infowindow"] = box
    SpeakCapture.clear
    scene.pbShowCommands(nil, ["Datos", "Salir"])
    truthy "a member's menu says the limits box", SpeakCapture.lines.include?("Max. EV total: 510. Escamas: 3/10")
    SpeakCapture.clear
    scene.pbShowCommands(nil, ["Dar", "Quitar"])
    falsy "a submenu over the same box does not say it again", SpeakCapture.lines.any? { |l| l.include?("Escamas") }
    box.text = "Max. EV total: 510\nEscamas: 2/10"
    scene.pbShowCommands(nil, ["Datos", "Salir"])
    truthy "and it is said again once it changes", SpeakCapture.lines.include?("Max. EV total: 510. Escamas: 2/10")
    SpeakCapture.clear
    box.text = "Max. EV total: 510\nEscamas: 1/10"
    scene.pbShowCommands(nil, ["Datos"], 0, false)
    falsy "a menu that hides the box says nothing of it", SpeakCapture.lines.any? { |l| l.include?("Escamas") }
  end
end
