module Roadworker
  class Utils
    module Helper
      def matched_zone?(name)
        result = true

        if @options.exclude_zone
          result &&= name !~ @options.exclude_zone
        end

        if @options.target_zone
          result &&= name =~ @options.target_zone
        end

        result
      end
    end

    class << self
      def diff(obj1, obj2, options = {})
        diffy = Diffy::Diff.new(
          obj1.pretty_inspect,
          obj2.pretty_inspect,
          :diff => '-u'
        )

        out = diffy.to_s(options[:color] ? :color : :text).gsub(/\s+\z/m, '')
        out.gsub!(/^/, options[:indent]) if options[:indent]
        out
      end
    end # of class methods
  end
end
