# PokeNav app framework (PokeNavAppScene, 053_PIF_Hoenn/PokeNav/.../PokeNavAppScene.rb). Hoenn replaces the
# Pokegear with a grid of app buttons driven by the game's own loop: no Essentials window is involved, the
# focus is just @index over @buttons and each PokeNavButton paints its own label. One hook on the scene's
# hover -- which the loop calls whenever the focus moves -- covers every APP that INHERITS from it (Contacts,
# its info page, FusionQuiz and PokeRadar). PokeChallenges does not: PokemonChallenges_Scene is written from
# scratch, has no hover and shares nothing but the idea, so it needs its own reader below. NOT the launcher
# either: that is PokemonPokegear_Scene (016_UI/PokeNav/008_UI_Pokegear.rb), which does not inherit from here
# and is read by the core through PokegearButton#selected=.
module PokeAccess
  module IF2PokeNav
    # The label of a button: its own text, or its id when the id IS a label.
    #
    # A Symbol id is data, not writing: the radar rows carry the species there and the panel deliberately
    # does not print it for anything unseen, so a symbol never stands in for a missing label.
    def self.button_text(btn)
      t = PokeAccess.ivar(btn, :@text)
      t = (btn.id rescue nil) if t.nil? || t.to_s.strip.empty?
      return nil unless t.is_a?(String)
      PokeAccess.clean(t).to_s.strip
    rescue StandardError
      nil
    end

    # What the focused button says on this app. Only the radar keeps a @seenPokemon list, and only its rows
    # are species rather than labels.
    def self.entry_text(scene, btn)
      return radar_text(scene, btn) if PokeAccess.ivar(scene, :@seenPokemon).is_a?(Array)
      button_text(btn)
    end

    # A radar row as the panel writes it: for a species the player has seen, its name plus the rarity and
    # scan cost the panel prints beside it; for one they have not, the same "unknown" and nothing else.
    #
    # The rarity and the cost come from the scene's own two helpers, so the reader cannot disagree with the
    # line under the icon. A scan in progress paints nothing at all, and neither does this.
    def self.radar_text(scene, btn)
      return nil if ($PokemonTemp.pokeradar rescue false)
      sp = (btn.id rescue nil)
      return nil unless sp
      seen = PokeAccess.ivar(scene, :@seenPokemon)
      return PokeAccess::I18n.t(:if2_radar_unknown) unless seen.include?(sp)
      parts = [(PokeAccess::Data.species_name(sp) rescue nil) || sp.to_s]
      r = (scene.get_rarity_flavor_text(sp) rescue nil)
      parts.push(PokeAccess.clean(r.to_s).to_s.strip) if r && !r.to_s.strip.empty?
      e = (scene.get_energy_for_scan(sp) rescue nil)
      parts.push(PokeAccess::I18n.t(:if2_radar_battery, :n => e)) if e
      parts.join(", ")
    rescue StandardError
      nil
    end

    # Speaks the focused app button once per change, with its position in the grid.
    def self.focus(scene)
      idx = PokeAccess.ivar(scene, :@index)
      btns = PokeAccess.ivar(scene, :@buttons)
      return unless idx.is_a?(Integer) && btns.is_a?(Array) && idx >= 0 && idx < btns.length
      label = entry_text(scene, btns[idx])
      return if label.nil? || label.empty?
      PokeAccess::Cursor.announce(scene, :list_entry, idx, true) do
        PokeAccess::I18n.t(:list_entry, :name => label, :n => idx + 1, :tot => btns.length)
      end
    rescue StandardError
      nil
    end
  end

  # PokeChallenges (PokemonChallenges_Scene). A list of active challenges, each a ChallengeButton painting its
  # own description and reward into a bitmap -- nothing an Essentials reader can see, and the app was silent
  # except for its title, which arrives through pbDisplayText. The scene's own pbUpdate marks the focused
  # button every frame, so the index it uses is the focus.
  module IF2Challenges
    # The focused challenge: what it asks for, where it sits in the list, and what it pays -- with the reward
    # labelled the way the button labels it, since a completed one says "collect" and is the whole reason to
    # open the app.
    #
    # The description is in the dedup key and not just the index. Collecting a reward REMOVES that challenge
    # and shifts the rest up with the cursor where it was, so the same slot then holds a different one --
    # keyed on the index alone that is the one moment this would stay silent, right after the player acted.
    def self.focus(scene)
      idx = PokeAccess.ivar(scene, :@index)
      list = PokeAccess.ivar(scene, :@challenges)
      return unless idx.is_a?(Integer) && list.is_a?(Array) && idx >= 0 && idx < list.length
      c = list[idx]
      desc = PokeAccess.clean((c.description rescue "").to_s).to_s.strip
      return if desc.empty?
      PokeAccess::Cursor.announce(scene, :if2_challenge, [idx, desc], true) do
        head = PokeAccess::I18n.t(:list_entry, :name => desc, :n => idx + 1, :tot => list.length)
        [head, reward(scene, idx, c)].compact.join(". ")
      end
    rescue StandardError
      nil
    end

    # The reward line: claimable or pending, the money, and any items by name.
    def self.reward(scene, idx, c)
      btn = (PokeAccess.ivar(scene, :@buttons)[idx] rescue nil)
      claim = (btn.can_claim_reward rescue (c.completed rescue false))
      parts = [PokeAccess::I18n.t(claim ? :if2_ch_collect : :if2_ch_reward,
                                  :n => (c.money_reward rescue 0).to_i)]
      items = (c.item_reward rescue nil)
      if items.is_a?(Array) && !items.empty?
        names = items.map { |i| (PokeAccess::Data.item_name(i) rescue nil) || i.to_s }
        parts.push(names.join(", "))
      end
      parts.join(". ")
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  after("PokeNavAppScene", :hover) { |s, _r, _a| PokeAccess::IF2PokeNav.focus(s) }
  # hover only fires on MOVEMENT, and the base opener does not call it, so entering an app landed on a
  # focused button that was never announced.
  #
  # The base opener is skipped for an app that overrides it: the override calls super FIRST -- which is
  # where this hook lands, with the cursor still on row zero -- and only then places the cursor where the
  # app wants it. Those apps are read from their own opener, below.
  after("PokeNavAppScene", :pbStartScene) do |s, _r, _a|
    own = (s.class.instance_method(:pbStartScene).owner rescue nil)
    next if own && own != PokeNavAppScene
    PokeAccess::IF2PokeNav.focus(s)
  end
  after("ContactsAppScene", :pbStartScene, :optional => true) { |s, _r, _a| PokeAccess::IF2PokeNav.focus(s) }
  # FusionQuizAppScene tambien redefine pbStartScene, asi que la guarda de arriba apaga el lector base y sin
  # esta linea la app no decia nada al abrirse ni al volver de una ronda: su propio opener es el que sabe
  # donde ha quedado el cursor.
  after("FusionQuizAppScene", :pbStartScene, :optional => true) { |s, _r, _a| PokeAccess::IF2PokeNav.focus(s) }
  after("PokemonChallenges_Scene", :pbUpdate) { |s, _r, _a| PokeAccess::IF2Challenges.focus(s) }
end
