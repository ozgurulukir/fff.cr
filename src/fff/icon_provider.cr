module FFF
  # IconProvider — Nerd Font file-type icons for TUI display.
  # Enabled via FFF_ICONS=1 env or config.json "icons": true.
  # Falls back to empty strings when disabled (zero-cost).
  module IconProvider
    # Default icons
    DIR_ICON      = " "
    DIR_OPEN_ICON = " "
    FILE_ICON     = " "
    SYMLINK_ICON  = " "
    EXEC_ICON     = " "

    # Extension → Nerd Font icon mapping
    EXTENSION_ICONS = {
      # Crystal / Ruby
      ".cr" => " ", ".rb" => " ",
      # Python
      ".py" => " ", ".pyi" => " ", ".pyc" => " ",
      # JavaScript / TypeScript
      ".js" => " ", ".mjs" => " ", ".cjs" => " ",
      ".ts" => " ", ".tsx" => " ", ".jsx" => " ",
      # Web
      ".html" => " ", ".htm" => " ",
      ".css" => " ", ".scss" => " ", ".sass" => " ", ".less" => " ",
      ".vue" => " ", ".svelte" => " ",
      # Data / Config
      ".json" => " ", ".yaml" => " ", ".yml" => " ", ".toml" => " ",
      ".xml" => " ", ".csv" => " ",
      # Markdown / Docs
      ".md" => " ", ".mdx" => " ", ".rst" => " ", ".txt" => " ",
      ".pdf" => " ", ".doc" => " ", ".docx" => " ",
      # Shell
      ".sh" => " ", ".bash" => " ", ".zsh" => " ", ".fish" => " ",
      ".ps1" => " ", ".psm1" => " ", ".bat" => " ", ".cmd" => " ",
      # C / C++
      ".c" => " ", ".h" => " ",
      ".cpp" => " ", ".hpp" => " ", ".cc" => " ", ".hh" => " ",
      # Go
      ".go" => " ",
      # Rust
      ".rs" => " ",
      # Java / Kotlin
      ".java" => " ", ".kt" => " ", ".kts" => " ",
      ".gradle" => " ",
      # Swift
      ".swift" => " ",
      # PHP
      ".php" => " ",
      # Lua
      ".lua" => " ",
      # Elixir / Erlang
      ".ex" => " ", ".exs" => " ", ".erl" => " ",
      # Haskell
      ".hs" => " ",
      # Images
      ".png" => " ", ".jpg" => " ", ".jpeg" => " ", ".gif" => " ",
      ".svg" => " ", ".ico" => " ", ".bmp" => " ", ".webp" => " ",
      # Video
      ".mp4" => " ", ".mkv" => " ", ".avi" => " ", ".mov" => " ",
      ".webm" => " ",
      # Audio
      ".mp3" => " ", ".wav" => " ", ".flac" => " ", ".ogg" => " ",
      ".m4a" => " ",
      # Archives
      ".zip" => " ", ".tar" => " ", ".gz" => " ", ".bz2" => " ",
      ".xz" => " ", ".7z" => " ", ".rar" => " ", ".zst" => " ",
      # Docker
      ".dockerfile" => " ",
      # Git
      ".gitignore" => " ", ".gitmodules" => " ",
      # Database
      ".sql" => " ", ".db" => " ", ".sqlite" => " ",
      # Binary / Compiled
      ".exe" => " ", ".dll" => " ", ".so" => " ", ".dylib" => " ",
      ".o" => " ", ".a" => " ",
      # Lock files
      ".lock" => " ",
      # Environment
      ".env" => " ",
      # Log
      ".log" => " ",
    }

    # Exact filename → icon mapping (overrides extension)
    SPECIAL_NAMES = {
      "Makefile"            => " ",
      "makefile"            => " ",
      "CMakeLists.txt"      => " ",
      "Dockerfile"          => " ",
      "docker-compose.yml"  => " ",
      "docker-compose.yaml" => " ",
      ".gitignore"          => " ",
      ".gitmodules"         => " ",
      ".gitattributes"      => " ",
      "LICENSE"             => " ",
      "LICENSE.md"          => " ",
      "LICENSE.txt"         => " ",
      "README.md"           => " ",
      "README"              => " ",
      "Gemfile"             => " ",
      "Rakefile"            => " ",
      "Cargo.toml"          => " ",
      "Cargo.lock"          => " ",
      "go.mod"              => " ",
      "go.sum"              => " ",
      "package.json"        => " ",
      "package-lock.json"   => " ",
      "tsconfig.json"       => " ",
      "webpack.config.js"   => " ",
      "vite.config.ts"      => " ",
      "vite.config.js"      => " ",
      ".eslintrc"           => " ",
      ".eslintrc.json"      => " ",
      ".prettierrc"         => " ",
      "shard.yml"           => " ",
      "shard.lock"          => " ",
      ".editorconfig"       => " ",
      ".env"                => " ",
      ".env.local"          => " ",
      "Procfile"            => " ",
      "Vagrantfile"         => " ",
    }

    # Get the appropriate icon for a file path
    def self.icon_for(path : String, info : File::Info?, linfo : File::Info?) : String
      name = File.basename(path)

      if icon = SPECIAL_NAMES[name]?
        return icon
      end

      if info && info.directory?
        return DIR_ICON
      end

      if linfo && linfo.symlink?
        return SYMLINK_ICON
      end

      # Executable check
      if info && !info.directory?
        {% unless flag?(:windows) %}
          if info.permissions.includes?(::File::Permissions::OtherExecute)
            return EXEC_ICON
          end
        {% end %}
      end

      # Extension-based lookup
      ext = File.extname(name).downcase
      EXTENSION_ICONS[ext]? || FILE_ICON
    end
  end
end
