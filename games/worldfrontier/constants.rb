# Pokemon World Frontier profile (Essentials v21.1 on La Base de Sky, Ruby 3.1), built on Pokemon Royal's code: what it
# shares with Royal is read by royal_common, its Deluxe Battle Kit by the dbk plugin readers its manifest declares, and
# its own screens (the Battle Frontier's facilities, the trainer album, the battle history...) by this profile.
PokeAccess::Game.define("worldfrontier")

# World Frontier's controls picture (bg_controles), which paints Alt alone for the speed, as wf_controls transcribes it.
PokeAccess::RoyalControls.key = :wf_controls

module PokeAccess
  # Species named as World Frontier's team icons show them.
  module WfSpecies
    # A species as World Frontier's team icons show it: its name, with its form's in brackets where the form has one.
    def self.name(species, form)
      name = PokeAccess::Data.species_name(species).to_s
      fname = form.to_i > 0 ? (GameData::Species.get_species_form(species, form.to_i).form_name rescue nil) : nil
      (fname && !fname.to_s.empty?) ? "#{name} (#{fname})" : name
    end
  end

  # The key hints World Frontier's screens paint, said with the keys the player has now while hints are said.
  module WfHint
    # A painted hint as said, or nil while hints are left out.
    # param verbs true for a hint that asks with a verb ("Pulsa C para continuar")
    def self.text(hint, verbs = false)
      return nil unless hint && PokeAccess::Verbosity.hints?
      PokeAccess::KeyHints.localize(PokeAccess.clean(hint), nil, verbs)
    end

    # A line with its painted hint after it as a sentence of its own.
    def self.after(line, hint, verbs = false)
      PokeAccess.sentences([line, text(hint, verbs)])
    end

    # Says a painted hint on its own, queued after the screen's first line.
    def self.say(hint)
      t = text(hint)
      PokeAccess.speak(t, false) if t
    end
  end
end
