# Clara's Character Profiles (BES v16): the list's heading, and each profile page as drawPage paints it (the name, the
# short facts, then the paragraphs) with its place among the pages, read as the scene opens and on every page change.
module PokeAccess
  module CharacterProfiles
    # The list's heading, said as the list opens, ahead of its first name, which the command window reads.
    def self.list_title(scene)
      win = PokeAccess.sprite(scene, "header")
      PokeAccess.speak_clean(win ? win.text : nil, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The page's place among the pages, while positions are said and the scene keeps a count of its pages.
    def self.place(n)
      total = PokeAccess.const_at("CharacterPageDisplayScene::PAGES")
      return unless total.is_a?(Integer) && PokeAccess::Verbosity.keep?(:positions, :medium)
      PokeAccess::I18n.t(:chp_page, :n => n, :tot => total)
    end

    # A page's text from what drawPage painted: the name at the top, the page's place, the facts painted as
    # positioned text (ally, age, sex), then the formatted paragraphs (origin, partner, description, or the three data
    # blocks of the second page).
    def self.page_text(pairs, n)
      paragraphs = PokeAccess::PaintCapture.lines(pairs) { |r| r[1] == :formatted }
      facts = PokeAccess::PaintCapture.lines(pairs) { |r| r[1] == :positions }
      parts = [paragraphs.shift, place(n)]
      parts.concat(facts)
      parts.concat(paragraphs)
      PokeAccess.sentences(parts)
    end

    # Speaks the page just drawn unless it is the one already said (the first page is redrawn when LEFT is pressed on
    # it): queued as the scene opens, interrupting on a change.
    # param id the page's index as drawPage was given it, 0-based
    def self.page(scene, id, pairs)
      n = id.to_i + 1
      said = PokeAccess.ivar(scene, :@access_chp_page)
      return if said == n
      scene.instance_variable_set(:@access_chp_page, n)
      PokeAccess.speak(page_text(pairs, n), !said.nil?)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.before_hook("CharacterProfileListScene", :start, :optional => true) do |scene, _a|
  PokeAccess::CharacterProfiles.list_title(scene)
end
PokeAccess::Hooks.around_hook("CharacterPageDisplayScene", :drawPage, :optional => true) do |scene, nxt, args|
  ret = nil
  pairs = PokeAccess::PaintCapture.sample { ret = nxt.call }
  PokeAccess::CharacterProfiles.page(scene, args[0], pairs)
  ret
end
