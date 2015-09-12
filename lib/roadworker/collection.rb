module Roadworker
  class Collection

    class << self
      def batch(pageable_response, collection_name)
        pageable_response.each do |response|
          response.public_send(collection_name).each do |item|
            yield(item)
          end
        end
      end
    end # of class method

  end # Collection
end # Roadworker
