module PokeAccess
  # FL's Family Tree, a Modular UI summary page (:page_family, drawPageFamily): each parent as the page writes it, its
  # name, species and sex sign, and the two grandparents its icons stand for.
  module FamilyTree
    # The page as spoken: the father, then the mother, each with their parents; from @pokemon.family, the data the
    # page draws.
    def self.page_text(pk)
      fam = (pk.family rescue nil)
      PokeAccess.sentences([parent_line(fam, 0, :ftree_father), parent_line(fam, 1, :ftree_mother)])
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # One parent's line (index 0 the father, 1 the mother), with their parents when either is known.
    def self.parent_line(fam, i, key)
      parent = fam ? (fam[i] rescue nil) : nil
      line = PokeAccess::I18n.t(key, :who => who(parent))
      grands = [0, 1].map { |j| parent ? (parent[j] rescue nil) : nil }
      return line if grands.compact.empty?
      "#{line}; #{PokeAccess::I18n.t(:ftree_grandparents, :list => grands.map { |g| species(g) }.join(', '))}"
    end

    # A parent as the page writes it: the name, the species when it differs (the page writes it below, after a "/"),
    # and the sex sign; unknown when the tree has no one there (the page writes "???").
    def self.who(parent)
      return PokeAccess::I18n.t(:ftree_unknown) unless parent
      name = (parent.name rescue nil).to_s
      sp = species(parent)
      base = (name.empty? || name == sp) ? sp : "#{name}, #{sp}"
      "#{base}#{PokeAccess::Party.sign_phrase(parent)}"
    end

    # A family member's species name without a trailing sex sign (as the page trims it), or unknown.
    def self.species(member)
      return PokeAccess::I18n.t(:ftree_unknown) unless member
      sp = PokeAccess::Data.species_name((member.species rescue nil)).to_s
      sp = sp.sub(/(?:#{PokeAccess::Party::SIGNS.join('|')})\z/, "")
      sp.empty? ? PokeAccess::I18n.t(:ftree_unknown) : sp
    end
  end
end

PokeAccess::Hooks.override(PokeAccess::SummaryGameData, :page_text, :tag => "fl_family_tree") do |_m, original, args|
  scene = args[0]
  pk = PokeAccess.ivar(scene, :@pokemon)
  if PokeAccess.ivar(scene, :@page_id) == :page_family && scene.respond_to?(:drawPageFamily) && pk
    PokeAccess::FamilyTree.page_text(pk) || original.call
  else
    original.call
  end
end
