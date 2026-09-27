# Multi Save's slot submenu (slotSelectCommands, the same in every copy): the question it opens its message window
# with is said ahead of the slot list, and only that window. The screen and the layout function are reduced to what
# they do, defined before the plugin file is bound to them here.
class MultiSaveSpecWindow
  attr_reader :text
  def initialize(text); @text = text; end
end

def pbBottomLeftLines(window, _lines, _width = nil); window; end

class PokemonSaveScreen
  def initialize; @scene = Object.new; end
  def slotSelectCommands(_choices, _info, _default = 0)
    pbBottomLeftLines(MultiSaveSpecWindow.new("Which slot to save in?"), 2)
    pbBottomLeftLines(MultiSaveSpecWindow.new("Overwrite the save?"), 2)
    0
  end
end

Suite.define("multi save: the slot submenu's question is said as its window is laid out") do
  load File.expand_path("../../../plugins/multi_save.rb", File.dirname(__FILE__)) unless $multi_save_question_loaded
  $multi_save_question_loaded = true
  SpeakCapture.clear
  eq "the submenu still answers the slot chosen", PokemonSaveScreen.new.slotSelectCommands([], []), 0
  eq "its question, once and queued, and no later window", SpeakCapture.log, [["Which slot to save in?", false]]
  SpeakCapture.clear
  pbBottomLeftLines(MultiSaveSpecWindow.new("Hola."), 2)
  silent "outside the submenu a window's layout says nothing"
end
