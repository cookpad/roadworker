module Roadworker
  class Utils
    module Helper
      def matched_zone?(name)
        if @options.target_zone
          name =~ @options.target_zone
        else
          true
        end
      end
    end # of class methods
  end
end
