# Independent Hidden Power Type (Soulstones 2): each Pokemon's own Hidden Power type (hptype), which the memo page
# paints as an icon, said after the page's paragraph.
module PokeAccess
  module HiddenPowerType
    def self.text(pk)
      t = (pk.hptype rescue nil)
      name = t ? (GameData::Type.get(t).name rescue nil) : nil
      name ? PokeAccess::I18n.t(:sm_hidden_power, :t => name) : nil
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.override("PokeAccess::SummaryGameData", :memo_extras, :tag => "hidden_power_type", :optional => true) do |_mod, original, args|
  (original.call || []) + [PokeAccess::HiddenPowerType.text(args[0])].compact
end
