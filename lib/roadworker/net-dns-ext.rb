require 'net/dns'
require 'net/dns/rr'

module Net
  module DNS
    module QueryTypes
      SPF = 99
    end # QueryTypes

    class RR
      class Types
        TYPES['SPF'] = 99
      end # Types

      class SPF < TXT
        def spf
          txt
        end

        private
        def set_type
          @type = Net::DNS::RR::Types.new("SPF")
        end
      end # SPF
    end # RR
  end # DNS
end # Net
