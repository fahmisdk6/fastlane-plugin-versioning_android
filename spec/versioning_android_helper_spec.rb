require 'spec_helper'

describe Fastlane::Helper::VersioningAndroidHelper do
  describe "Versioning Android Helper" do
    it "should return path to build.gradle" do
      result = Fastlane::Helper::VersioningAndroidHelper.get_gradle_file(nil)
      expect(result).to eq(Fastlane::Helper::VersioningAndroidHelper::GRADLE_FILE_TEST)
    end

    it "should return absolute path to build.gradle" do
      xcodeproj = Fastlane::Helper::VersioningAndroidHelper::GRADLE_FILE_TEST
      result = Fastlane::Helper::VersioningAndroidHelper.get_gradle_file_path(xcodeproj)
      expect(result).to eq("/tmp/fastlane/tests/versioning/app/build.gradle")
    end
  end

  describe "Kotlin DSL (build.gradle.kts) support" do
    let(:tmp_dir) { File.expand_path("../tmp_kts_test", __FILE__) }
    let(:kts_path) { File.join(tmp_dir, "build.gradle.kts") }
    let(:groovy_path) { File.join(tmp_dir, "build.gradle") }

    before do
      FileUtils.mkdir_p(tmp_dir)
    end

    after do
      FileUtils.rm_rf(tmp_dir)
    end

    it "reads versionCode from Kotlin DSL assignment syntax" do
      File.write(kts_path, "android {\n  defaultConfig {\n    versionCode = 42\n    versionName = \"2.0.0\"\n  }\n}\n")
      expect(Fastlane::Helper::VersioningAndroidHelper.read_key_from_gradle_file(kts_path, "versionCode")).to eq("42")
      expect(Fastlane::Helper::VersioningAndroidHelper.read_key_from_gradle_file(kts_path, "versionName")).to eq("2.0.0")
    end

    it "reads versionCode from Groovy syntax (backward compatible)" do
      File.write(groovy_path, "android {\n  defaultConfig {\n    versionCode 7\n    versionName \"1.2.3\"\n  }\n}\n")
      expect(Fastlane::Helper::VersioningAndroidHelper.read_key_from_gradle_file(groovy_path, "versionCode")).to eq("7")
      expect(Fastlane::Helper::VersioningAndroidHelper.read_key_from_gradle_file(groovy_path, "versionName")).to eq("1.2.3")
    end

    it "writes versionCode preserving Kotlin DSL assignment syntax" do
      File.write(kts_path, "android {\n  defaultConfig {\n    versionCode = 42\n    versionName = \"2.0.0\"\n  }\n}\n")
      Fastlane::Helper::VersioningAndroidHelper.save_key_to_gradle_file(kts_path, "versionCode", 99)
      expect(File.read(kts_path)).to include("versionCode = 99")
      expect(Fastlane::Helper::VersioningAndroidHelper.read_key_from_gradle_file(kts_path, "versionCode")).to eq("99")
    end

    it "does not match keys that share a prefix" do
      File.write(kts_path, "    versionCodeOverride = 100\n    versionCode = 5\n")
      expect(Fastlane::Helper::VersioningAndroidHelper.read_key_from_gradle_file(kts_path, "versionCode")).to eq("5")
    end

    it "auto-detects build.gradle.kts when build.gradle does not exist" do
      File.write(kts_path, "versionCode = 1\n")
      resolved = Fastlane::Helper::VersioningAndroidHelper.get_gradle_file(groovy_path)
      # In test mode, get_gradle_file short-circuits to GRADLE_FILE_TEST, so test the
      # resolver indirectly via gradle_file_exists?
      expect(Fastlane::Helper::VersioningAndroidHelper.gradle_file_exists?(groovy_path)).to eq(true)
    end
  end
end
