# Infinite Fusion 2's Pokedex search by name (games/infinitefusion_hoenn/dex_search.rb): the stock keyboard naming
# screen under its own name, read as that screen is, its question and the text the box starts with.

# The search box's opener, down to its arguments; the rest of the screen is the stock one's.
class PokedexTextEntry
  def pbStartScene(_helptext, _minlength, _maxlength, _initialText, _subject = 0, _pokemon = nil); :started; end
end

class IfhDexSearchGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "dex_search.rb")

  # Evaluates the profile file once, as boot does, its hook bound to the stand-in above.
  def self.load_profile
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  ensure
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  test "the search box says its question as it opens, queued" do
    assert_equal :started, PokedexTextEntry.new.pbStartScene("Search Pokémon by name.", 0, 12, "")
    assert_equal [["Search Pokémon by name.", false]], SpeakCapture.log
  end

  test "the search box says the text it starts with after its question" do
    PokedexTextEntry.new.pbStartScene("Search Pokémon by name.", 0, 12, "Pika")
    assert_equal ["Search Pokémon by name. #{PokeAccess::I18n.t(:nm_current, :t => 'Pika')}"], SpeakCapture.lines
  end
end
