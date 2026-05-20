module Fastlane
  module Helper
    class VersioningAndroidHelper
      require "shellwords"
      require "tempfile"
      require "fileutils"

      GRADLE_FILE_TEST = "/tmp/fastlane/tests/versioning/app/build.gradle"

      def self.get_gradle_file(gradle_file)
        return GRADLE_FILE_TEST if Helper.test?
        return gradle_file if File.exist?(gradle_file)

        # Auto-detect the Kotlin DSL variant (build.gradle.kts) used by newer Flutter/Android setups
        kts_variant = "#{gradle_file}.kts"
        return kts_variant if File.exist?(kts_variant)

        if gradle_file.end_with?(".kts")
          groovy_variant = gradle_file.sub(/\.kts\z/, "")
          return groovy_variant if File.exist?(groovy_variant)
        end

        gradle_file
      end

      def self.gradle_file_exists?(gradle_file)
        return true if File.exist?(gradle_file)
        return true if File.exist?("#{gradle_file}.kts")
        return true if gradle_file.end_with?(".kts") && File.exist?(gradle_file.sub(/\.kts\z/, ""))
        false
      end

      def self.get_gradle_file_path(gradle_file)
        gradle_file = self.get_gradle_file(gradle_file)
        return File.expand_path(gradle_file)
      end

      def self.get_new_version_code(gradle_file, new_version_code)
        if new_version_code.nil?
          current_version_code = self.read_key_from_gradle_file(gradle_file, "versionCode")
          new_version_code = current_version_code.to_i + 1
        end

        return new_version_code.to_i
      end

      def self.get_new_version_name(gradle_file, new_version_name, bump_type = nil)
        if new_version_name.nil?
          new_version_name = self.read_key_from_gradle_file(gradle_file, "versionName")
        end

        current_version_parts = new_version_name.split(/[.]/)
        major = current_version_parts[0].to_i
        minor = current_version_parts[1].to_i
        patch = current_version_parts[2].to_i

        if bump_type == "major"
          new_version_name = "#{major + 1}.0.0"
        elsif bump_type == "minor"
          new_version_name = "#{major}.#{minor + 1}.0"
        elsif bump_type == "patch"
          new_version_name = "#{major}.#{minor}.#{patch + 1}"
        end

        return new_version_name.to_s
      end

      # Matches both Groovy (`versionCode 1`) and Kotlin DSL (`versionCode = 1`) assignments
      def self.key_line_regex(key)
        /\A#{Regexp.escape(key)}\b\s*=?\s*(.+)\z/
      end

      def self.read_key_from_gradle_file(gradle_file, key)
        value = false
        begin
          file = File.new(gradle_file, "r")
          regex = self.key_line_regex(key)
          while (line = file.gets)
            match = line.strip.match(regex)
            next unless match
            value = match[1].strip.tr("\"", "")
            break
          end
          file.close
        rescue => err
          UI.error("An exception occured while reading gradle file: #{err}")
          err
        end
        return value
      end

      def self.save_key_to_gradle_file(gradle_file, key, value)
        current_value = self.read_key_from_gradle_file(gradle_file, key)

        begin
          found = false
          regex = self.key_line_regex(key)
          temp_file = Tempfile.new("flSave_#{key}_ToGradleFile")
          File.open(gradle_file, "r") do |file|
            file.each_line do |line|
              if !found && line.strip.match?(regex)
                found = true
                line.replace line.sub(current_value.to_s, value.to_s)
              end
              temp_file.puts line
            end
            file.close
          end
          temp_file.rewind
          temp_file.close
          FileUtils.mv(temp_file.path, gradle_file)
          temp_file.unlink
        end

        return found == true ? value : -1
      end
    end
  end
end
