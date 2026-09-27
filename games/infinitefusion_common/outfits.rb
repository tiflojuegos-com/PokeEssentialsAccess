module PokeAccess
  # The wardrobe menus: each change says what is on now, the clothes, hat or hairstyle by its outfit-data name
  # and a shifted dye by its hue number, which the player's preview shows only as a colour; so do the preview's
  # other changes (the hat toggled, a dye reset) and the hair shop's hat toggle and colour swap.
  module IFOutfits
    # The colour version a full hair id leads with, captured ("3_afro", getFullHairId in both games).
    HAIR_VERSION = /\A(\d+)_/

    # What the preview shows that a menu may change: [hat, second hat (Hoenn), the hair, hat, second hat and clothes
    # dyes, the full hair id].
    def self.dress
      [:hat, :hat2, :hair_color, :hat_color, :hat2_color, :clothes_color, :hair].map { |k| ($Trainer.send(k) rescue nil) }
    end

    def self.item(kind)
      id = case kind
           when :clothes then $Trainer.clothes
           when :hat then $Trainer.hat
           else $Trainer.hair
           end
      return PokeAccess::I18n.t(:if_outfit_none) if id.nil? || id.to_s.empty?
      data = case kind
             when :clothes then (get_clothes_by_id(id) rescue nil)
             when :hat then (get_hat_by_id(id) rescue nil)
             else (get_hair_by_id(id) rescue nil) || (get_hair_by_id(id.to_s.sub(HAIR_VERSION, "")) rescue nil)
             end
      name = (data.name rescue nil)
      shown = PokeAccess.clean((name.nil? || name.to_s.empty?) ? id.to_s : name.to_s)
      version = (kind == :hair && data && id.to_s =~ HAIR_VERSION) ? $1 : nil
      version ? "#{shown}, #{PokeAccess::I18n.t(:if_hair_version, :n => version)}" : shown
    rescue StandardError
      nil
    end

    def self.say_item(kind)
      remember
      t = item(kind)
      PokeAccess.speak(t, true) if t && !t.empty?
    end

    def self.say_hue(value)
      remember
      PokeAccess.speak(PokeAccess::I18n.t(:if_hue, :n => value.to_i), true)
    end

    # The dye of the hat a shift changed: the second hat's when shiftHatColor's flag says so (Hoenn only).
    def self.hat_hue(secondary)
      secondary ? ($Trainer.hat2_color rescue 0) : ($Trainer.hat_color rescue 0)
    end

    # Takes what the preview shows as heard, so the next repaint says only what changed after it.
    def self.remember
      @dress = dress if @dress
    end

    # Forgets the preview as its menu closes, so the next menu starts from what it first shows; the repaint's own
    # hide_outfit_preview, run inside display_outfit_preview, forgets nothing.
    def self.forget
      @dress = nil unless @previewing
    end

    # Runs one preview repaint and then says what it changed against what was shown before it.
    def self.preview
      was = @dress
      @previewing = true
      begin
        ret = yield
      ensure
        @previewing = false
      end
      previewed(was)
      ret
    end

    # Says what a preview repaint changed that no other reader has said: a hat taken off or put back, a dye reset,
    # the hair's colour version swapped (Hoenn's "Swap base color").
    def self.previewed(was)
      now = dress
      @dress = now
      return if was.nil?
      said = []
      [0, 1].each do |i|
        on = !now[i].nil? && !now[i].to_s.empty?
        off_before = was[i].nil? || was[i].to_s.empty?
        said.push(PokeAccess::I18n.t(on ? :if_hat_on : :if_hat_off)) if on == off_before
      end
      said.push(PokeAccess::I18n.t(:if_dye_off)) if (2..5).any? { |i| now[i].to_i == 0 && was[i].to_i != 0 }
      style = lambda { |h| h.to_s.sub(HAIR_VERSION, "") }
      if now[6] != was[6] && style.call(now[6]) == style.call(was[6]) && now[6].to_s =~ HAIR_VERSION
        said.push(PokeAccess::I18n.t(:if_hair_version, :n => $1))
      end
      PokeAccess.speak(said.uniq.join(", "), true) unless said.empty?
    rescue StandardError
      nil
    end

    # The hair shop's hat toggle: whether the preview now shows the hat.
    def self.say_hat_shown(visible)
      PokeAccess.speak(PokeAccess::I18n.t(visible ? :if_hat_on : :if_hat_off), true)
    end

    # The hair shop's colour swap: the base colour version the preview now wears.
    def self.say_version(version)
      PokeAccess.speak(PokeAccess::I18n.t(:if_hair_version, :n => version.to_i), true) if version
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  after("OutfitSelector", :changeToNextClothes, :optional => true) { |_s, _r, _a| PokeAccess::IFOutfits.say_item(:clothes) }
  after("OutfitSelector", :changeToNextHat, :optional => true) { |_s, _r, _a| PokeAccess::IFOutfits.say_item(:hat) }
  after("OutfitSelector", :changeToNextHairstyle, :optional => true) { |_s, _r, _a| PokeAccess::IFOutfits.say_item(:hair) }
  kernel("shiftHairColor", :after) { |_a, _r| PokeAccess::IFOutfits.say_hue(($Trainer.hair_color rescue 0)) }
  kernel("shiftClothesColor", :after) { |_a, _r| PokeAccess::IFOutfits.say_hue(($Trainer.clothes_color rescue 0)) }
  kernel("shiftHatColor", :after) { |a, _r| PokeAccess::IFOutfits.say_hue(PokeAccess::IFOutfits.hat_hue(a[1])) }
  kernel("display_outfit_preview", :around) { |_a, nxt| PokeAccess::IFOutfits.preview { nxt.call } }
  kernel("hide_outfit_preview", :after) { |_a, _r| PokeAccess::IFOutfits.forget }
  after("HairMartAdapter", :toggleEvent, :optional => true) do |s, _r, _a|
    PokeAccess::IFOutfits.say_hat_shown(PokeAccess.ivar(s, :@hat_visible)) if PokeAccess.ivar(s, :@worn_hat)
  end
  after("HairMartAdapter", :switchVersion, :optional => true) do |s, _r, _a|
    PokeAccess::IFOutfits.say_version(PokeAccess.ivar(s, :@version))
  end
end
