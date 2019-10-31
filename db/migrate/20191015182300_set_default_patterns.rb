class SetDefaultPatterns < ActiveRecord::Migration[5.2]
  def change
    Setting.plugin_redmine_zulip[:zulip_stream_expression] = "${project_name}"
    Setting.plugin_redmine_zulip[:zulip_issue_updates_subject_expression] = "${issue_subject}"
    Setting.plugin_redmine_zulip[:zulip_version_updates_subject_expression] = "Version ${version_name}"
  end
end
