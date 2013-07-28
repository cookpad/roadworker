module Roadworker
  class Collection

    class << self
      def batch(collection)
        if collection.respond_to?(:each_batch)
          collection.each_batch do |batch|
            batch.each do |item|
              yield(item)
            end
          end
        else
          collection.each do |item|
            yield(item)
          end
        end
      end
    end # of class method

  end # Collection
end # Roadworker
