# The options screen's per-option help. @sprites["textbox"] is a help box in some games and the dialogue frame
# sample in most gen-6 ones: OptionHelp offers it once its text changes while the option's value stays.
module OptHelpRig
  class Box
    attr_accessor :text
    def initialize(t); @text = t; end
  end

  # Each option's value, kept on the window itself and indexed by option, as these scenes do.
  class Opt
    attr_accessor :index
    def initialize(i); @index = i; @vals = Hash.new(0); end
    def [](k); @vals[k]; end
    def []=(k, v); @vals[k] = v; end
  end

  class Scene
    def initialize(text, idx)
      @sprites = { "textbox" => Box.new(text), "option" => Opt.new(idx) }
    end

    def at(text, idx, val = nil)
      @sprites["textbox"].text = text
      @sprites["option"].index = idx
      @sprites["option"][idx] = val unless val.nil?
      self
    end
  end
end

Suite.define("menus: la muestra del marco de dialogo no se ofrece como ayuda") do
  PokeAccess::Info.set_info(:text, nil)
  s = OptHelpRig::Scene.new("Marco de dialogo 1.", 0)

  PokeAccess::OptionHelp.read(s)
  falsy("nada guardado con una sola muestra", PokeAccess::Info.info_text.to_s.include?("Marco"))

  PokeAccess::OptionHelp.read(s.at("Marco de dialogo 1.", 1))
  PokeAccess::OptionHelp.read(s.at("Marco de dialogo 1.", 2))
  falsy("un texto constante nunca se ofrece", PokeAccess::Info.info_text.to_s.include?("Marco"))
end

Suite.define("menus: cambiar el marco de dialogo tampoco lo acredita") do
  PokeAccess::Info.set_info(:text, nil)
  s = OptHelpRig::Scene.new("Marco de dialogo 1.", 3)
  s.at("Marco de dialogo 1.", 3, 0)

  PokeAccess::OptionHelp.read(s)
  PokeAccess::OptionHelp.read(s.at("Marco de dialogo 2.", 3, 1))
  falsy("el texto cambia porque cambio el valor, no porque sea ayuda",
        PokeAccess::Info.info_text.to_s.include?("Marco"))
end

Suite.define("menus: una ayuda de verdad si llega a la tecla de info") do
  PokeAccess::Info.set_info(:text, nil)
  s = OptHelpRig::Scene.new("Velocidad del texto del juego.", 0)

  PokeAccess::OptionHelp.read(s)
  PokeAccess::OptionHelp.read(s.at("Activa o desactiva el sonido.", 1))
  truthy("dos opciones con textos distintos lo acreditan",
         PokeAccess::Info.info_text.to_s.include?("sonido"))

  PokeAccess::OptionHelp.read(s.at("Marco de dialogo 1.", 2))
  truthy("y a partir de ahi se ofrece siempre", PokeAccess::Info.info_text.to_s.include?("Marco"))
end

Suite.define("menus: la ayuda de la PRIMERA opcion tambien se lee") do
  PokeAccess::Info.set_info(:text, nil)
  s = OptHelpRig::Scene.new("Marco de dialogo 1.", 0)
  s.at("Marco de dialogo 1.", 0, 0)
  PokeAccess::OptionHelp.read(s)
  PokeAccess::OptionHelp.read(s.at("Ajusta el volumen de la musica del juego", 0, 0))
  truthy("mismo indice y mismo valor, texto distinto: es ayuda",
         PokeAccess::Info.info_text.to_s.include?("volumen"))
end
