# Golden Crown's summary, its edited stock copy: beside the shiny star the header paints an Alpha symbol for an Alpha
# Pokemon, a Noble one for the Noble forms and a Totem one for the Totem forms, each by the game's own check.
module PokeAccess
  module GoldenCrownMarks
    # The forms the summary paints the Noble and the Totem symbol for, as its isSpecies? checks list them.
    NOBLE = [:KLEAVOR_1, :AVALUGG_2, :ARCANINE_2, :LILLIGANT_2, :ELECTRODE_2]
    TOTEM = [:MIMIKYU_2, :ARAQUANID_1, :RATICATE_2, :GUMSHOOS_1, :WISHIWASHI_2, :SALAZZLE_1, :MAROWAK_3, :LURANTIS_1,
             :TOGEDEARU_1, :VIKAVOLT_1, :KOMMOO_1, :RIBOMBEE_1]

    # The words for the symbols the header paints for pk, in the order it paints them.
    def self.words(pk)
      out = []
      out.push(PokeAccess::I18n.t(:bt_m_alpha)) if (pk.alpha? rescue false)
      out.push(PokeAccess::I18n.t(:bt_m_noble)) if form_of?(pk, NOBLE)
      out.push(PokeAccess::I18n.t(:bt_m_totem)) if form_of?(pk, TOTEM)
      out
    end

    def self.form_of?(pk, forms)
      forms.any? { |f| (pk.isSpecies?(f) rescue false) }
    end
  end
end

PokeAccess::Game.define("goldencrown") do
  override("PokeAccess::Summary", :header_icons) do |_mod, original, args|
    ([original.call] + PokeAccess::GoldenCrownMarks.words(args[0])).reject { |s| s.to_s.empty? }.join(", ")
  end
end
