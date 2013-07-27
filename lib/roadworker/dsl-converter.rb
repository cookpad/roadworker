module Roadworker
  class DSL
    class Converter

      class << self
        def convert(hosted_zones)
          hosted_zones.map {|i| output_zone(i) }.join("\n")
        end

        private

        def output_rrset(recrod)
          name = recrod.delete(:name).inspect
          type = recrod.delete(:type).inspect

          attrs = recrod.map {|key, value|
            if value.kind_of?(Array)
              if value.empty?
                nil
              else
                value = value.map {|i| i.inspect }.join(",\n      ")
                "#{key}(\n      #{value}\n    )"
              end
            else
              "#{key} #{value.inspect}"
            end
          }.select {|i| i }.join("\n    ")

          return(<<-EOS)
  rrset #{name}, #{type} do
    #{attrs}
  end
          EOS
        end

        def output_zone(zone)
          name = zone[:name].inspect
          rrsets = zone[:rrsets]

          return(<<-EOS)
hosted_zone #{name} do
#{rrsets.map {|i| output_rrset(i) }.join("\n").chomp}
end
          EOS
        end
      end # of class method

    end # Converter
  end # DSL
end # Roadworker
