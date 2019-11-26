module Roadworker
  module Log

    def log(level, message, color, log_id = nil, dry_run: @dry_run || (@options && @options.dry_run), logger: @logger || @options.logger)
      log_id = yield if block_given?
      message = "#{message}: #{log_id}" if log_id
      message << ' (dry-run)' if dry_run
      message = message.send(color) if color
      logger.send(level, message)
    end

  end # Log
end # Roadworker
