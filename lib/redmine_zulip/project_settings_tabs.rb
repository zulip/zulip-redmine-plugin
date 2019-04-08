module RedmineZulip
  module ProjectSettingsTabs
    def project_settings_tabs
      super.tap do |tabs|
        tabs.push({
          name: 'redmine_zulip',
          partial: 'projects/settings/redmine_zulip',
          label: :label_redmine_zulip
        })
      end
    end
  end
end
