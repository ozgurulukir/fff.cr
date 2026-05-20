require "spec"
require "../spec_helper.cr"
require "../../src/fff.cr"

module IntegrationHelper
  include SpecHelper
  extend self

  def create_realistic_test_structure(base_dir)
    files = [
      {name: "document.txt", content: "This is a document file"},
      {name: "report.pdf", content: "PDF report content"},
      {name: "image.png", content: "PNG image content"},
      {name: "script.sh", content: "#!/bin/bash\necho 'hello world'"},
      {name: "data.json", content: %q|{"name": "test", "value": 42}|},
      {name: "README.md", content: "# README\nThis is a readme file"},
    ]

    dirs = ["documents", "images", "scripts", "config"]

    files.each do |fi|
      create_temp_file(base_dir, fi[:name], fi[:content])
    end

    dirs.each do |dir_name|
      dir_path = File.join(base_dir, dir_name)
      Dir.mkdir_p(dir_path)

      case dir_name
      when "documents"
        create_temp_file(dir_path, "internal_doc.txt", "Internal document")
        create_temp_file(dir_path, "notes.txt", "Meeting notes")
      when "images"
        create_temp_file(dir_path, "photo1.jpg", "JPEG image")
        create_temp_file(dir_path, "logo.svg", "SVG logo")
      when "scripts"
        create_temp_file(dir_path, "backup.sh", "#!/bin/bash\necho 'backup script'")
        create_temp_file(dir_path, "deploy.sh", "#!/bin/bash\necho 'deploy script'")
      when "config"
        create_temp_file(dir_path, "settings.conf", "Configuration file")
        create_temp_file(dir_path, "env_vars", "Environment variables")
      end
    end

    create_temp_file(base_dir, ".hidden_file", "Hidden content")
    create_temp_file(base_dir, ".config", "Hidden config")

    source_file = File.join(base_dir, "document.txt")
    symlink_path = File.join(base_dir, "link_to_document")
    if File.exists?(source_file)
      File.symlink("document.txt", symlink_path)
    end

    {base_dir, dirs}
  end

  def wait_for(duration : Time::Span)
    sleep(duration)
  end
end
