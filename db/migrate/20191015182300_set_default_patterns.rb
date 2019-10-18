class SetDefaultPatterns < ActiveRecord::Migration
  def change
    Setting.plugin_redmine_zulip[:zulip_stream_pattern] = "${project_name}"
    Setting.plugin_redmine_zulip[:zulip_issue_updates_subject_pattern] = "${issue_subject}"
    Setting.plugin_redmine_zulip[:zulip_version_updates_subject_pattern] = "Version ${version_name}"
  end
end
