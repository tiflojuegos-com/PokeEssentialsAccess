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

    # The spoken line for a party slot (name, sex, level, hp, fainted), or the cancel label for an empty
    # slot/button; also stashes the pokemon for the info key. Shared by the gen-6 scene and the v22 screen.
    def self.party_line(party, idx)
      pk = (party && idx.is_a?(Integer) && idx >= 0 && idx < party.length) ? party[idx] : nil
      return PokeAccess::I18n.t(:pc_cancel) unless pk
      PokeAccess::Info.set_info(:pokemon, pk)
      t = PokeAccess::I18n.t(:pty_member, :name => pk.name, :sex => gender_phrase(pk), :level => pk.level, :hp => pk.hp, :tot => pk.totalhp)
      t + fainted_suffix(pk)
    end

    # Speaks the party slot being focused (name, level, hp, fainted).
    def self.announce_party(party, idx, oldidx)
      return if idx == oldidx
      PokeAccess.speak(party_line(party, idx), true)
    end

    # Speaks the pc storage cursor: held pokemon, controls, or the slot's pokemon. param selection the
    # cursor selection (negative values are controls); param party the party array when navigating the
    # party column, else nil
    def self.announce_pc(scene, selection, party)
      screen  = scene.instance_variable_get(:@screen)
      storage = PokeAccess.expect!("pc.storage", scene.instance_variable_get(:@storage))
      held    = (screen.pbHeldPokemon rescue nil)
      box     = (storage.currentBox rescue -9)
      key     = [box, selection, (held ? held.object_id : nil), !party.nil?]
      return if key == PokeAccess.ivar(scene, :@access_pc_key)
      scene.instance_variable_set(:@access_pc_key, key)
      case selection
      when -1 then PokeAccess.speak(PokeAccess::I18n.t(:pc_box, :name => (storage[box].name rescue '')), true)
      when -2 then PokeAccess.speak(PokeAccess::I18n.t(:pc_team), true)
      when -3 then PokeAccess.speak(PokeAccess::I18n.t(:pc_close), true)
      when -4 then PokeAccess.speak(PokeAccess::I18n.t(:pc_prev), true)
      when -5 then PokeAccess.speak(PokeAccess::I18n.t(:pc_next), true)
      else
        pkmn = party ? (party[selection] rescue nil) : (storage[box, selection] rescue nil)
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
