module RedmineZulip
  VERSION = "3.1-alpha1"
end

Rails.configuration.to_prepare do
  Issue.send(:include, RedmineZulip::IssuePatch)
  Project.send(:include, RedmineZulip::ProjectPatch)
  ProjectsController.send(:helper, RedmineZulip::ProjectSettingsTabs)
end
