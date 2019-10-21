require "redmine_zulip/issue_patch"

module RedmineZulip
  VERSION = "3.1-alpha1"

  def self.api
    RedmineZulip::Api.new
  end
end


Rails.configuration.to_prepare do
  Issue.send(:include, RedmineZulip::IssuePatch)
  Project.send(:include, RedmineZulip::ProjectPatch)
  ProjectsController.send(:helper, RedmineZulip::ProjectSettingsTabs)
end
