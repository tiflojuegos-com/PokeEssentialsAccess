# The list of the screens checked by hand: the report refuses a malformed or repeated line, and nothing else runs it.
require File.expand_path("../../tools/silent_screens", File.dirname(__FILE__))

class SilentScreensTriagedTest < PokeAccessTest
  test "the report can read the list of screens checked by hand" do
    assert SilentScreens.triaged.length > 100
  end
end
