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
    # The label of a button: its own text when it carries one, else its id, which is a readable symbol.
    def self.button_text(btn)
      t = PokeAccess.ivar(btn, :@text)
      t = (btn.id rescue nil) if t.nil? || t.to_s.strip.empty?
      PokeAccess.clean(t.to_s).to_s.strip
    rescue StandardError
      nil
    end

    # Speaks the focused app button once per change, with its position in the grid.
    def self.focus(scene)
      idx = PokeAccess.ivar(scene, :@index)
      btns = PokeAccess.ivar(scene, :@buttons)
      return unless idx.is_a?(Integer) && btns.is_a?(Array) && idx >= 0 && idx < btns.length
      label = button_text(btns[idx])
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
  # hover only fires on MOVEMENT, and pbStartScene does not call it, so entering an app landed on a focused
  # button that was never announced. PokeRadar hid the gap by calling hover from its own start; Contacts and
  # FusionQuiz opened in silence.
  after("PokeNavAppScene", :pbStartScene) { |s, _r, _a| PokeAccess::IF2PokeNav.focus(s) }
  after("PokemonChallenges_Scene", :pbUpdate) { |s, _r, _a| PokeAccess::IF2Challenges.focus(s) }
end
