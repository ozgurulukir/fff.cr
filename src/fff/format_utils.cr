module FFF
  module FormatUtils
    def self.human_size(bytes : Int) : String
      case bytes
      when .<(1024)
        "#{bytes}B"
      when .<(1024 * 1024)
        "#{(bytes / 1024.0).round(1).to_s.rstrip('0').rstrip('.')}K"
      when .<(1024 * 1024 * 1024)
        "#{(bytes / (1024.0 * 1024.0)).round(1).to_s.rstrip('0').rstrip('.')}M"
      else
        "#{(bytes / (1024.0 * 1024.0 * 1024.0)).round(1).to_s.rstrip('0').rstrip('.')}G"
      end
    end
  end
end
