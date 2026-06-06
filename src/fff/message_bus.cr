require "time"

module FFF
  # MessageType — Categorizes TUI notification messages for appropriate styling.
  enum MessageType
    Error
    Success
    Warning
    Info
  end

  # Message — A single notification with text, type, and auto-expiry.
  struct Message
    getter text : String
    getter type : MessageType
    getter expires_at : Time

    def initialize(@text : String, @type : MessageType, duration : Time::Span = 2.seconds)
      @expires_at = Time.utc + duration
    end

    def expired? : Bool
      Time.utc > @expires_at
    end

    # Icon prefix for display
    def icon : String
      case @type
      when .error?   then "❌ "
      when .success? then "✓ "
      when .warning? then "⚠ "
      when .info?    then "ℹ "
      else                ""
      end
    end
  end

  # MessageBus — A message queue that manages TUI notifications.
  # Supports multiple concurrent messages with auto-expiry.
  # Replaces the old @error_msg / @error_expires pattern.
  class MessageBus
    getter messages : Array(Message)

    def initialize
      @messages = [] of Message
    end

    # Push a new message onto the queue
    def push(text : String, type : MessageType, duration : Time::Span = 2.seconds)
      return if text.empty?
      @messages << Message.new(text, type, duration)
    end

    # Convenience methods
    def error(text : String, duration : Time::Span = 3.seconds)
      push(text, MessageType::Error, duration)
    end

    def success(text : String, duration : Time::Span = 2.seconds)
      push(text, MessageType::Success, duration)
    end

    def warning(text : String, duration : Time::Span = 3.seconds)
      push(text, MessageType::Warning, duration)
    end

    def info(text : String, duration : Time::Span = 2.seconds)
      push(text, MessageType::Info, duration)
    end

    # Get the most recent non-expired message (displayed in the TUI)
    def current : Message?
      tick!
      @messages.last?
    end

    # Remove expired messages
    def tick!
      @messages.reject!(&.expired?)
    end

    # Clear all messages
    def clear
      @messages.clear
    end
  end
end
