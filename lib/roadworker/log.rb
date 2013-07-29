module Roadworker
  module Log

    def log(level, message, color, log_id = nil)
      log_id = yield if block_given?
      message = "#{message}: #{log_id}" if log_id
      message << ' (dry-run)' if @options.dry_run
      @options.logger.send(level, message.send(color))
    end

  end # Log
end # Roadworker
