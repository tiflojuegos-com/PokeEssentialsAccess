# royal's curry berry picker ([ROYAL] TDW Berry Core and Dex -> Window_ChooseBerryMultiple): a
# Window_DrawableCommand whose entries live in @bag.pockets[5] indexed through @filterlist (not a standard
# list ivar), so the generic command reader skips it. Read the focused berry name and quantity, the label
# column the screen paints for its mode (the dominant flavour for the curry pot, the colour for the
# composter and the planter) and how many berries are chosen of the maximum; the index past the list is
# the close button. The berry's description goes to the info key.
module PokeAccess
  module RoyalCurry
    # The label column as the picker paints it for its @label mode, or nil.
    def self.berry_label(item, label)
      data = (GameData::BerryData.get(item) rescue nil)
      return nil unless data
      case label
      when :Flavor
        f = (data.flavor.max_by { |_k, v| v } rescue nil)
        f ? f[0].to_s : nil
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
    next "Cerrar bolsa" if !fl.is_a?(Array) || i >= fl.length
    bag   = win.instance_variable_get(:@bag)
    entry = (bag.pockets[5][fl[i]] rescue nil)
    next nil unless entry
    item = entry[0]
    nm = (GameData::Item.get(item).name rescue nil)
    next nil if nm.nil? || nm.to_s.empty?
    scene = win.instance_variable_get(:@scene)
    PokeAccess::Info.set_info(:item, item)
    qty = entry[1]
    qty -= (scene.selectedBerries.count(GameData::Item.get(item)) rescue 0) if qty
    parts = [qty ? "#{nm}, #{qty}" : nm]
    lbl = PokeAccess::RoyalCurry.berry_label(item, (scene.instance_variable_get(:@label) rescue nil))
    parts.push(lbl) if lbl && !lbl.empty?
    chosen = (scene.selectedBerries.length rescue nil)
    max = (scene.instance_variable_get(:@count) rescue nil)
    parts.push("elegidas #{chosen} de #{max}") if chosen && max
    parts.join(", ")
  end
end
