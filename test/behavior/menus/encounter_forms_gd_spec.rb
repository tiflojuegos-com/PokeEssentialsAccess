# The encounter list names a species as its icon shows it: with its form's name for a form other than the first (a
# regional form) or for any form while the list shows the species in several (Flabébé's five flowers), gamedata pass.
EncounterFormsScene = Struct.new(:table) do
  private

  def getEncData; table; end
end

Suite.define("encounter list: a species in one of its forms is named with that form") do
  el = PokeAccess::EncounterList
  forms = { :FLABEBE => ["Flabébé", :FLABEBE, 0, "Forma Flor Roja"],
            :FLABEBE_1 => ["Flabébé", :FLABEBE, 1, "Forma Flor Amarilla"],
            :ZIGZAGOON_1 => ["Zigzagoon", :ZIGZAGOON, 1, "Forma Galar"],
            :EXEGGCUTE_1 => ["Exeggcute", :EXEGGCUTE, 1, ""],
            :PIKACHU => ["Pikachu", :PIKACHU, 0, ""],
            :PUMPKABOO => ["Pumpkaboo", :PUMPKABOO, 0, "Tamaño Pequeño"],
            :VULPIX_1 => ["Vulpix", :VULPIX, 1, "Vulpix de Alola"] }
  meta = class << GameData::Species; self; end
  meta.send(:alias_method, :enc_forms_spec_get, :get)
  meta.send(:define_method, :get) do |i|
    d = enc_forms_spec_get(i)
    row = forms[i]
    if row
      d.define_singleton_method(:name) { row[0] }
      d.define_singleton_method(:species) { row[1] }
      d.define_singleton_method(:form) { row[2] }
      d.define_singleton_method(:form_name) { row[3] }
    end
    d
  end
  begin
    scene = EncounterFormsScene.new([[:FLABEBE, :FLABEBE_1, :ZIGZAGOON_1, :EXEGGCUTE_1, :PIKACHU, :PUMPKABOO], :Land])
    shown = ["Flabébé Forma Flor Roja", "Flabébé Forma Flor Amarilla", "Zigzagoon Forma Galar", "Exeggcute",
             "Pikachu", "Pumpkaboo"]
    whole = el.summary("Land", shown.map { |n| [n, :dex_caught] }, true)
    PokeAccess::EncounterListUI.text_for(scene)
    eq "each flower by its own name, a regional form with its region, the rest as they are",
       PokeAccess::Info.info_text, whole
    eq "a species alone keeps its first form's name out", el.entry(:PUMPKABOO)[0], "Pumpkaboo"
    eq "and a form the data leaves unnamed keeps the name alone", el.entry(:EXEGGCUTE_1)[0], "Exeggcute"
    eq "a lone form above the first is still named", el.entry_text(:ZIGZAGOON_1, true),
       el.phrase("Zigzagoon Forma Galar", :dex_caught, true)
    eq "a form whose name already holds the species' is said by it alone", el.entry(:VULPIX_1)[0], "Vulpix de Alola"
    placeholder = EncounterFormsScene.new([[:PIKACHU, :ZIGZAGOON_1], :Land])
    placeholder.instance_variable_set(:@sprites, { "icon_1" => Struct.new(:species).new(0) })
    PokeAccess::EncounterListUI.text_for(placeholder)
    eq "an icon drawn as the ? placeholder is said as unknown, whatever the Pokedex holds of the species",
       PokeAccess::Info.info_text, el.summary("Land", [["Pikachu", :dex_caught], ["Zigzagoon Forma Galar", :dex_unknown]], true)
  ensure
    meta.send(:alias_method, :get, :enc_forms_spec_get)
    meta.send(:remove_method, :enc_forms_spec_get)
  end
end

# Every copy of the plugin paints the Pokedex state on the icon: an unseen species as the "?" placeholder or a black
# shadow, a seen one greyed out, a caught one in colour; the icon is what is said where it and the Pokedex disagree.
Suite.define("encounter list: each species is said in the state its icon paints") do
  el = PokeAccess::EncounterList
  ui = PokeAccess::EncounterListUI
  icon = Struct.new(:species, :color, :tone)
  color = Struct.new(:red, :green, :blue, :alpha)
  tone = Struct.new(:red, :green, :blue, :gray)
  clear = color.new(0, 0, 0, 0)
  flat = tone.new(0, 0, 0, 0)
  eq "the ? placeholder is unknown", ui.icon_state(icon.new(0, clear, flat)), :dex_unknown
  eq "a black shadow is unknown", ui.icon_state(icon.new(25, color.new(0, 0, 0, 255), flat)), :dex_unknown
  eq "a greyed icon is seen", ui.icon_state(icon.new(25, clear, tone.new(0, 0, 0, 255))), :dex_seen
  eq "a coloured one is caught", ui.icon_state(icon.new(25, clear, flat)), :dex_caught
  eq "with no icon the Pokedex decides", ui.icon_state(nil), nil
  shadow = EncounterFormsScene.new([[:PIKACHU], :Land])
  shadow.instance_variable_set(:@sprites, { "icon_0" => icon.new(25, color.new(0, 0, 0, 255), flat) })
  ui.text_for(shadow)
  eq "the list says the shadow as unknown, whatever the Pokedex holds", PokeAccess::Info.info_text,
     el.summary("Land", [["Pikachu", :dex_unknown]], true)
end
