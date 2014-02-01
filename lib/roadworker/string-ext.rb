require 'term/ansicolor'

class String
  @@colorize = false

  class << self
    def colorize=(value)
      @@colorize = value
    end

    def colorize
      @@colorize
    end
  end # of class method

  Term::ANSIColor::Attribute.named_attributes.map do |attribute|
    class_eval(<<-EOS, __FILE__, __LINE__ + 1)
      def #{attribute.name}
        if @@colorize
          Term::ANSIColor.send(#{attribute.name.inspect}, self)
        else
          self
        end
      end
    EOS
  end

end
