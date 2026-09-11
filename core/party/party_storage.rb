module PokeAccess
  # Party screen and PC storage navigation.
  module Party
    # PC boxes are laid out 6 wide in Essentials (used to read row and column).
    BOX_COLUMNS = 6

    # The localized sex word for a pokemon (male/female/genderless), or nil when no gender data. The single
    # spot the 0/1/2 gender mapping lives.
    def self.gender_word(pk)
      g = (pk.gender rescue nil)
      return nil unless g == 0 || g == 1 || g == 2
      PokeAccess::I18n.t(g == 0 ? :pk_male : (g == 1 ? :pk_female : :pk_none))
    end

    # The sex word as a " word" suffix (leading space) for the member line, or "" when no gender data.
    def self.gender_phrase(pk)
      w = gender_word(pk)
      w ? " " + w : ""
    end

    # The ", fainted" suffix when a pokemon has no hp left, else "" (the single KO threshold for all readers).
    def self.fainted_suffix(pk)
      ((pk.hp rescue 1).to_i <= 0) ? ", " + PokeAccess::I18n.t(:pk_fainted) : ""
    end

    # What a member carries that only an ICON says: shiny, and pokerus while it is still catching (stage 1,
    # the only stage that spreads). Held item and status are already in the info key's glance, and a line
    # heard six times down the party has to stay short. An EGG says neither: the panel refuses to draw both
    # on one, and announcing them would tell the player what is inside an egg the screen is hiding.
    def self.icon_mark_list(pk)
      return [] if pk.nil? || PokeAccess::Summary.egg?(pk)
      marks = []
      marks.push(PokeAccess::I18n.t(:pk_shiny)) if shiny?(pk)
      marks.push(PokeAccess::I18n.t(:pk_pokerus)) if pokerus?(pk)
      marks
    rescue StandardError
      []
    end

    # The marks as a clause to append to a line that does not end in a stop. "" when there is nothing, so
    # callers append it unconditionally.
    def self.icon_marks(pk)
      m = icon_mark_list(pk)
      m.empty? ? "" : ", " + m.join(", ")
    end

    # Whether a pokemon is shiny, under BOTH spellings of the question: the seven gen-6 games ask isShiny?
    # and the eight modern ones shiny?, so probing only one of them left the mark unspoken in half the
    # games -- and silently, because the probe simply answered false.
    def self.shiny?(pk)
      v = (pk.shiny? rescue nil)
      v = (pk.isShiny? rescue nil) if v.nil?
      v ? true : false
    rescue StandardError
      false
    end

    # Whether a pokemon is carrying pokerus RIGHT NOW. Stage 1 only: 0 is never infected and 2 is cured, and
    # the panel draws its icon for stage 1 alone (Essentials 016_UI/005_UI_Party.rb:244). A cured one is a
    # permanent state that no screen marks and that changes nothing the player can act on.
    #
    # pokerusStage is the question all fifteen games answer; the raw counter is the fallback for a build
    # that lacks it, and there byte/16 is the strain and byte%16 the days left, so a non-zero counter is an
    # infection still running.
    def self.pokerus?(pk)
      v = (pk.pokerusStage rescue nil)
      return v.to_i == 1 unless v.nil?
      v = (pk.pokerus rescue nil)
      v.nil? ? false : v.to_i > 0
    rescue StandardError
      false
    end

    # The spoken line for a party slot (name, sex, level, hp, fainted), or the cancel label for an empty
    # slot/button; also stashes the pokemon for the info key. Shared by the gen-6 scene and the v22 screen.
    def self.party_line(party, idx)
      pk = (party && idx.is_a?(Integer) && idx >= 0 && idx < party.length) ? party[idx] : nil
      return PokeAccess::I18n.t(:pc_cancel) unless pk
      PokeAccess::Info.set_info(:pokemon, pk)
      t = PokeAccess::I18n.t(:pty_member, :name => pk.name, :sex => gender_phrase(pk), :level => pk.level, :hp => pk.hp, :tot => pk.totalhp)
      t + fainted_suffix(pk) + icon_marks(pk)
    end

    # The label for a slot past the last party member. The screen puts a button row there, and WHICH button
    # has to come from the sprite rather than from the index: with multiselect the screen swaps the single
    # CANCEL for a CONFIRM plus a CANCEL, and answering "cancel" for both made the button that commits the
    # selection sound exactly like the one that abandons it -- on the Battle Challenge entry screen, where
    # that is the whole decision. The concrete sprite classes are named for what they are in both eras
    # (PokeSelection*/PokemonParty* + Confirm/Cancel); only the shared base carries both words.
    def self.party_button(scene, idx)
      cn = (PokeAccess.ivar(scene, :@sprites)["pokemon#{idx}"].class.to_s rescue "")
      return nil unless cn.include?("Cancel") || cn.include?("Confirm")
      confirm = cn.include?("Confirm") && !cn.include?("ConfirmCancel")
      PokeAccess::I18n.t(confirm ? :pc_confirm : :pc_cancel)
    end

    # True when this slot holds a Pokemon rather than one of the trailing buttons.
    def self.party_slot?(party, idx)
      party && idx.is_a?(Integer) && idx >= 0 && idx < party.length && party[idx]
    end

    # Speaks the party slot being focused (name, level, hp, fainted), or the button past the last member.
    def self.announce_party(scene, party, idx, oldidx)
      return if idx == oldidx
      t = party_slot?(party, idx) ? party_line(party, idx) : (party_button(scene, idx) || PokeAccess::I18n.t(:pc_cancel))
      PokeAccess.speak(t, true)
    end

    # Speaks the pc storage cursor: held pokemon, controls, or the slot's pokemon. param selection the
    # cursor selection (negative values are controls); param party the party array when navigating the
    # party column, else nil
    def self.announce_pc(scene, selection, party)
      screen  = scene.instance_variable_get(:@screen)
      storage = PokeAccess.expect!("pc.storage", scene.instance_variable_get(:@storage))
      held    = (screen.pbHeldPokemon rescue nil)
      box     = (storage.currentBox rescue -9)
      slot_pk = nil
      if selection.is_a?(Integer) && selection >= 0
        slot_pk = party ? (party[selection] rescue nil) : (storage[box, selection] rescue nil)
      end
      key = [box, selection, (held ? held.object_id : nil), !party.nil?,
             (slot_pk ? slot_pk.object_id : nil)]
      return unless PokeAccess::Cursor.changed?(scene, :pc_key, key)
      case selection
      when -1 then PokeAccess.speak(PokeAccess::I18n.t(:pc_box, :name => (storage[box].name rescue '')), true)
      when -2 then PokeAccess.speak(PokeAccess::I18n.t(:pc_team), true)
      when -3 then PokeAccess.speak(PokeAccess::I18n.t(:pc_close), true)
      when -4 then PokeAccess.speak(PokeAccess::I18n.t(:pc_prev), true)
      when -5 then PokeAccess.speak(PokeAccess::I18n.t(:pc_next), true)
      else
        pkmn = slot_pk
        pos = party ? "" : PokeAccess::I18n.t(:pc_pos, :row => selection / BOX_COLUMNS + 1, :col => selection % BOX_COLUMNS + 1)
        if held
          if pkmn
            PokeAccess.speak(PokeAccess::I18n.t(:pc_swap, :name => pkmn.name, :held => held.name) + pos, true)
          else
            PokeAccess.speak(PokeAccess::I18n.t(:pc_place, :held => held.name) + pos, true)
          end
        elsif pkmn
          PokeAccess::Info.set_info(:pokemon, pkmn)
          t = PokeAccess::I18n.t(:pc_slot, :name => pkmn.name, :level => pkmn.level)
          t += fainted_suffix(pkmn)
          PokeAccess.speak(t + pos, true)
        else
          PokeAccess.speak(PokeAccess::I18n.t(:pc_empty) + pos, true)
        end
      end
    rescue StandardError
      nil
    end
  end
end

# The version-specific scene hooks that drive these helpers live in the version folders, per the
# module-first layout: gen-6 party/storage/pause in party/gen6/party_g6.rb; the modern pause menu in
# party/v21/party_v21_pause.rb.
