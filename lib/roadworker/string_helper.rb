require 'term/ansicolor'

module Roadworker
  module StringHelper
    @colorize = false

    class << self
      def colorize=(value)
        @colorize = value
      end

      def colorize
        @colorize
      end

      Term::ANSIColor::Attribute.named_attributes.map do |attribute|
        define_method(attribute.name) do |str|
          if colorize
            Term::ANSIColor.public_send(attribute.name, str)
          else
            str
          end
        end
      end
    end
  end
end
