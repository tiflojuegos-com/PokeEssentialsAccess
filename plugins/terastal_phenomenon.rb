# Terastal Phenomenon by Lucidious89: the Tera Type icon it paints on the summary's first page and in the PC's panel, each
# where its settings turn it on. ZUD's and the kit's Terastallization have no such page of their own.
module PokeAccess
  module TerastalPhenomenon
    # The Pokemon's Tera Type in words, or nil where it has none to say.
    def self.mark(pk)
      type = (pk.tera_type rescue nil)
      name = type ? PokeAccess::Data.type_name(type) : nil
      name && !name.to_s.empty? ? PokeAccess::I18n.t(:ss2_adv_tera, :t => name) : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.override(PokeAccess::Summary, :header_icons, :tag => "terastal_phenomenon") do |_m, original, args|
  icons = original.call
  shows = (::Settings::SUMMARY_TERA_TYPES rescue false)
  mark = shows ? PokeAccess::TerastalPhenomenon.mark(args[0]) : nil
  mark ? [icons, mark].reject { |s| s.to_s.empty? }.join(", ") : icons
end

PokeAccess::Hooks.override(PokeAccess::Party, :pc_details, :tag => "terastal_phenomenon") do |_m, original, args|
  shows = (::Settings::STORAGE_TERA_TYPES rescue false)
  mark = shows ? PokeAccess::TerastalPhenomenon.mark(args[0]) : nil
  mark ? original.call + [mark] : original.call
end
