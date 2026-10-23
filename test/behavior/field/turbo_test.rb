# The turbo announcer under the gen-6 stubs; the cases live in turbo_cases.rb, shared with the gamedata pass.
require File.expand_path("turbo_cases", File.dirname(__FILE__))

class TurboTest < PokeAccessTest
  TurboCases.define(self)
end
