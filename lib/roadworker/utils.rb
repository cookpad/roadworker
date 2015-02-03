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
    end # of class methods
  end
end
