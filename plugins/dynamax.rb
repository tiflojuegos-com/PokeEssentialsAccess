module PokeAccess
  # Dynamax plugins (ZUD, the Deluxe Battle Kit's): the G-Max Factor mark on every summary page, the Dynamax meter
  # on the stats page, the PC panel's factor mark where STORAGE_GMAX_FACTOR is set, and ZUD's databox icons; both
  # method spellings are asked.
  module Dynamax
    # Whether the G-Max Factor mark is drawn for this Pokemon.
    def self.factor?(pk)
      v = (pk.gmax_factor? rescue nil)
      v = (pk.gmaxFactor? rescue nil) if v.nil?
      v ? true : false
    end

    # The Dynamax level as the stats page's meter shows it, or nil where none is drawn: only for a Pokemon that can
    # Dynamax, and under the kit only while its no-Dynamax switch is off (ZUD draws it regardless).
    def self.meter(pk)
      kit = pk.respond_to?(:dynamax_able?)
      able = kit ? (pk.dynamax_able? rescue nil) : (pk.dynamaxAble? rescue nil)
      return nil unless able
      return nil if kit && switched_off?
      PokeAccess::I18n.t(:dmax_level, :n => (pk.dynamax_lvl rescue 0).to_i)
    end

    # Whether the kit's switch against Dynamax is on.
    def self.switched_off?
      off = (::Settings::NO_DYNAMAX rescue nil)
      off ? ($game_switches[off] rescue false) : false
    end
  end
end

PokeAccess::Hooks.override(PokeAccess::Summary, :header_icons, :tag => "dynamax") do |_m, original, args|
  icons = original.call
  PokeAccess::Dynamax.factor?(args[0]) ? [icons, PokeAccess::I18n.t(:dmax_factor)].reject { |s| s.to_s.empty? }.join(", ") : icons
end

PokeAccess::Hooks.override(PokeAccess::SummaryGameData, :stats_extras, :tag => "dynamax") do |_m, original, args|
  original.call + [PokeAccess::Dynamax.meter(args[0])].compact
end

PokeAccess::Hooks.override(PokeAccess::Party, :pc_details, :tag => "dynamax") do |_m, original, args|
  shows = (::Settings::STORAGE_GMAX_FACTOR rescue false)
  (shows && PokeAccess::Dynamax.factor?(args[0])) ? original.call + [PokeAccess::I18n.t(:dmax_factor)] : original.call
end

# The icons ZUD's databox draws beside a Dynamaxed or Ultra Burst battler's name.
PokeAccess::Battle.icon_mark(/\Aicon_dynamax\z/i, :bt_m_dynamax)
PokeAccess::Battle.icon_mark(/\Aicon_ultra\z/i, :bt_m_ultra)
