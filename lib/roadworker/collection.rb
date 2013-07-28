module Roadworker
  class Collection

    class << self
      def batch(collection)
        AWS.memoize {
          collection.each_batch do |batch|
            batch.each do |item|
              yield(item)
            end
          end
        }
      end
    end # of class method

  end # Collection
end # Roadworker
