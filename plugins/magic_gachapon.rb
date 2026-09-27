# Magic Gachapon (Kyu and Clara's GachaScene; royal, awakening): @banner_sel picks the banner and @sel the button,
# read on refresh with the banner's name and featured rewards, its counters and each pull's reward.
module PokeAccess
  module MagicGachapon
    # Button labels as each copy's source writes them, before its _INTL, in cursor order: Royal's five (sprites
    # numbered 1, 2, 4, 5, 3), Awakening's three; the copy is told by its fifth button sprite.
    BUTTONS_FIVE  = ["Info.", "Tirar x1", "Tirar x10", "Ticket ULTRA", "Salir"]
    BUTTONS_THREE = ["Información", "Tirar", "Salir"]

    # The three-button copy's cursor on the banner itself (Up), where left and right change banner.
    BANNER_SEL = 3

    def self.buttons(scn)
      sprites = PokeAccess.ivar(scn, :@sprites)
      (sprites && sprites["button5"]) ? BUTTONS_FIVE : BUTTONS_THREE
    end

    # A button's label as refresh paints it, through the game's _INTL (Royal's English build translates it).
    def self.button_label(text)
      (_INTL(text) rescue text).to_s
    end

    # The focused banner (by name and place in the strip, and the rewards it features, when it changed or when the
    # cursor moves up onto it), the focused button, and the counters beside the banner when they changed (on opening
    # and after each pull). The info key repeats the featured rewards.
    def self.refresh(scn)
      sel  = PokeAccess.ivar(scn, :@sel)
      bsel = PokeAccess.ivar(scn, :@banner_sel)
      return unless sel
      banners = PokeAccess.ivar(scn, :@banners)
      counts = counters(scn, banners, bsel)
      banner_changed = PokeAccess::Cursor.changed?(scn, :gacha_banner, bsel)
      counts_changed = PokeAccess::Cursor.changed?(scn, :gacha_counts, counts)
      return unless PokeAccess::Cursor.changed?(scn, :gacha, [sel, bsel, counts])
      parts = []
      btn = buttons(scn)[sel.to_i]
      on_banner = btn.nil? && sel.to_i == BANNER_SEL
      if (banner_changed || on_banner) && banners.is_a?(Array) && bsel.is_a?(Integer) && banners[bsel]
        name = PokeAccess.clean((banners[bsel].name rescue "").to_s)
        parts.push(PokeAccess::Verbosity.list_entry(name, bsel + 1, banners.length)) unless name.empty?
        feat = featured(banners[bsel])
        parts.push(feat) if feat
        feat ? PokeAccess::Info.set_info(:text, feat) : PokeAccess::Info.clear_text
      end
      parts.push(button_label(btn)) if btn
      parts.concat(counts) if counts_changed
      PokeAccess.speak_clean(parts.join(". "), true) unless parts.empty?
    rescue StandardError
      nil
    end

    # The three rewards a banner features (a BannerReward each: its picture and its row of stars), named from the
    # pictures; nil when one of them has a picture that names nothing (Awakening's blank ones).
    def self.featured(banner)
      rewards = (banner.rewards rescue nil)
      stars = (banner.stars rescue nil)
      return nil unless rewards.is_a?(Array) && stars.is_a?(Array) && !rewards.empty?
      names = []
      rewards.each_with_index do |path, i|
        n = reward_name(path)
        return nil if n.nil?
        names.push(PokeAccess::I18n.t(:gacha_prize, :name => n, :n => stars[i].to_i))
      end
      PokeAccess::I18n.t(:gacha_featured, :list => names.join("; "))
    end

    # What a reward picture shows, by its folder and file: Graphics/Pokemon/Eggs/X an egg of that species, another
    # Graphics/Pokemon folder the species itself (a form's id included), Graphics/Items/X the item; else nil.
    def self.reward_name(path)
      dirs = path.to_s.tr("\\", "/").split("/")
      id = dirs.pop.to_s.sub(/\.png\z/i, "")
      return nil if id.empty?
      if dirs.include?("Items")
        (GameData::Item.try_get(id.to_sym).name rescue nil)
      elsif dirs.include?("Pokemon")
        sp = (GameData::Species.try_get(id.to_sym).name rescue nil)
        (sp && dirs.include?("Eggs")) ? PokeAccess::I18n.t(:gacha_egg, :name => sp) : sp
      end
    end

    # The counts painted beside the banner, each an "x N" by its icon: Awakening's copy the coins it
    # spends, Royal's the pulls made on the banner and the two kinds of ticket it holds.
    def self.counters(scn, banners, bsel)
      if buttons(scn).equal?(BUTTONS_FIVE)
        name = (banners[bsel].name rescue nil)
        [PokeAccess::I18n.t(:gacha_pulls, :n => ($PokemonGlobal.get_tiradas_banner(name) rescue 0).to_i),
         PokeAccess::I18n.t(:gacha_tickets, :n => ($bag.quantity(:TICKETGACHA) rescue 0).to_i),
         PokeAccess::I18n.t(:gacha_ultra, :n => ($bag.quantity(:TICKETGACHAULTRA) rescue 0).to_i)]
      else
        [PokeAccess::I18n.t(:gacha_coins, :n => ($PokemonGlobal.gachaCoins rescue 0).to_i)]
      end
    end

    # A reward as its picture shows it, with the tier its stars and colour give it.
    # param qty the amount of an item or a decoration, where the copy passes one
    def self.reward(name, stars, qty = nil)
      n = PokeAccess.clean(name.to_s)
      return if n.empty?
      key = (qty && qty.to_i > 1) ? :gacha_prize_qty : :gacha_prize
      PokeAccess.speak(PokeAccess::I18n.t(key, :name => n, :q => qty.to_i, :n => stars.to_i), true)
    rescue StandardError
      nil
    end

    # The tier alone of a reward the game names right after in its own message.
    def self.tier(stars)
      PokeAccess.speak(PokeAccess::I18n.t(:gacha_stars, :n => stars.to_i), true)
    rescue StandardError
      nil
    end

    # Marks that an item reward has just been said, so the reveal it runs next (rewardAnim) says nothing more.
    def self.reward_said; @reward_said = true; end

    # A reveal (rewardAnim): the tier of its reward, unless the item reward that runs it has just been said.
    def self.reveal(stars)
      said = @reward_said
      @reward_said = false
      tier(stars) unless said
    end

    # An item prize as the copy hands it over: Royal's carries an amount before the stars and is named by
    # its message afterwards, Awakening's goes into the bag in silence and is named here.
    def self.item_prize(args)
      args.length > 2 ? tier(args[-1]) : reward(item_name(args[0]), args[-1])
    end

    # An item prize's name. Awakening hands over the item's symbol (:HEALTHWING) on a gen-6 base, whose
    # table answers numbers only, so a symbol is looked up by name first.
    def self.item_name(id)
      id.is_a?(Symbol) ? (PokeAccess::Data.item_id(id) || [])[1] : PokeAccess::Data.item_name(id)
    end

    # The Info button's panel: the banner description, painted as a bitmap in its own loop, spoken as it opens.
    def self.info(scn)
      sel = PokeAccess.ivar(scn, :@banner_sel).to_i
      b = (PokeAccess.ivar(scn, :@banners) || [])[sel]
      d = (b.description rescue nil)
      PokeAccess.speak_clean(d.to_s, true)
    rescue StandardError
      nil
    end
  end
end

# On refresh, not update: GachaScene#update is the screen's blocking loop, so an after hook there runs only on exit.
PokeAccess::Hooks.after_hook("GachaScene", :refresh, :optional => true) { |s, _r, _a| PokeAccess::MagicGachapon.refresh(s) }
PokeAccess::Hooks.after_hook("GachaScene", :dispose, :optional => true) { |_s, _r, _a| PokeAccess::Info.clear_text }
PokeAccess::Hooks.before_hook("GachaScene", :summaryWindow, :optional => true) { |s, _a| PokeAccess::MagicGachapon.info(s) }

# An item reward (Royal adds an amount before the stars): Awakening's goes into the bag unnamed, so it is named here,
# and the reveal it runs next says nothing more.
PokeAccess::Hooks.before_hook("GachaScene", :itemReward, :optional => true) do |_s, args|
  PokeAccess::MagicGachapon.item_prize(args)
  PokeAccess::MagicGachapon.reward_said
end
# The reveal every reward runs (a Pokemon, Royal's decorations, a banner's direct prize), stars second in both copies:
# its tier, the name left to the game's own message.
PokeAccess::Hooks.before_hook("GachaScene", :rewardAnim, :optional => true) do |_s, args|
  PokeAccess::MagicGachapon.reveal(args[1])
end
