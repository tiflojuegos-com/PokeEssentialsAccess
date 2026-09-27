# Royal's berry picker (Window_ChooseBerryMultiple, entries in @bag.pockets[5] through @filterlist): the berry and
# how many are left, and from medium the label column for its mode and how many are chosen; past the list, close.
module PokeAccess
  module RoyalCurry
    # The label column as the picker paints it for its @label mode, or nil; the flavour through the game's _INTL, as
    # the English build paints it translated.
    def self.berry_label(item, label)
      data = (GameData::BerryData.get(item) rescue nil)
      return nil unless data
      case label
      when :Flavor
        f = (data.flavor.max_by { |_k, v| v } rescue nil)
        f ? (_INTL(f[0].to_s) rescue f[0].to_s).to_s : nil
      when :Firm, :Firmness then (data.firmness.to_s rescue nil)
      when :Size then (data.size ? "#{data.size} cm" : nil rescue nil)
      when :Type, :TypeText, :TypeIcon then (GameData::Type.get(pbBerryGetNaturalGift(item)[0]).name rescue nil)
      else (GameData::BerryColor.get(data.color).name rescue nil)
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("royal") do
  screen_reader("Window_ChooseBerryMultiple") do |win, i|
    fl = win.instance_variable_get(:@filterlist)
    next PokeAccess.clean((_INTL("CERRAR BOLSA") rescue "CERRAR BOLSA").to_s) if !fl.is_a?(Array) || i >= fl.length
    bag   = win.instance_variable_get(:@bag)
    entry = (bag.pockets[5][fl[i]] rescue nil)
    next nil unless entry
    item = entry[0]
    nm = (GameData::Item.get(item).name rescue nil)
    next nil if nm.nil? || nm.to_s.empty?
    scene = win.instance_variable_get(:@scene)
    qty = entry[1]
    qty -= (scene.selectedBerries.count(GameData::Item.get(item)) rescue 0) if qty
    parts = [[qty ? "#{nm}, #{qty}" : nm, :brief]]
    lbl = PokeAccess::RoyalCurry.berry_label(item, (scene.instance_variable_get(:@label) rescue nil))
    parts.push([lbl, :medium]) if lbl && !lbl.empty?
    chosen = (scene.selectedBerries.length rescue nil)
    max = (scene.instance_variable_get(:@count) rescue nil)
    parts.push([PokeAccess::I18n.t(:rcy_chosen, :n => chosen, :tot => max), :medium]) if chosen && max
    PokeAccess::Info.set_info(:item, item, PokeAccess::Verbosity.full_line(parts))
    PokeAccess::Verbosity.line(:bag_item, parts)
  end
end
