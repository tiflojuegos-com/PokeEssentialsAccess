# Royal's PC messages go through pbDisplayBorde, which the shared message net does not know. The stand-in is made
# before the profile file is loaded over it, so its hook binds here.
class PokemonStorageScene; end unless defined?(PokemonStorageScene)
class PokemonStorageScene
  def pbDisplayBorde(message); message; end
end
load File.expand_path("../../../games/royal/borde_messages.rb", File.dirname(__FILE__))

Suite.define("royal: the PC's bordered messages are read") do
  SpeakCapture.clear
  eq "the PC message keeps its return value", PokemonStorageScene.new.pbDisplayBorde("¡Adiós, Pikachu!"), "¡Adiós, Pikachu!"
  truthy "and is read", SpeakCapture.lines.join(" ").include?("¡Adiós, Pikachu!")
end
