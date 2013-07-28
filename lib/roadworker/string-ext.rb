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

  Term::ANSIColor::Attribute.named_attributes.map do |attr|
    class_eval(<<-EOS, __FILE__, __LINE__ + 1)
      def #{attr.name}
        if @@colorize
          Term::ANSIColor.send(#{attr.name.inspect}, self)
        else
          self
        end
      end
    EOS
  end

end
