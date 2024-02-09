module RedmineZulip
  module IssuePatch
    extend ActiveSupport::Concern

    TWEET_SIZE = 140

    included do
      after_commit :notify_assignment, if: proc { |issue|
        issue.zulip_settings.enabled? &&
          issue.assigned_to_id.present? &&
          issue.assigned_to_id != User.current.id &&
          issue.previous_changes.keys.include?("assigned_to_id")
      }

      after_commit :notify_unassignment, if: proc { |issue|
        issue.zulip_settings.enabled? &&
          issue.previous_changes.keys.include?("assigned_to_id") &&
          issue.previous_changes["assigned_to_id"].first.present? &&
          issue.previous_changes["assigned_to_id"].first != User.current.id
      }

      after_commit :notify_assigned_to_issue_updated, if: proc { |issue|
        issue.zulip_settings.enabled? &&
          !issue.destroyed? &&
          !issue.previous_changes.include?("id") &&
          !issue.previous_changes.include?("assigned_to_id") &&
          issue.assigned_to_id.present? &&
          issue.assigned_to_id != User.current.id
      }

      after_commit :notify_assigned_to_issue_destroyed, if: proc { |issue|
        issue.zulip_settings.enabled? &&
          issue.destroyed? &&
          issue.assigned_to_id.present? &&
          issue.assigned_to_id != User.current.id
      }

      after_commit :init_issue_subject, if: proc { |issue|
        issue.zulip_settings.enabled? &&
          issue.zulip_settings.stream.present? &&
          issue.zulip_settings.issue_updates_subject.present? &&
          issue.previous_changes.include?("id")
      }

      after_commit :update_issue_subject, if: proc { |issue|
        issue.zulip_settings.enabled? &&
          !issue.destroyed? &&
          issue.zulip_settings.stream.present? &&
          issue.zulip_settings.issue_updates_subject.present? &&
          !issue.previous_changes.include?("id")
      }

      after_commit :update_issue_subject_destroyed, if: proc { |issue|
        issue.zulip_settings.enabled? &&
          issue.destroyed? &&
          issue.zulip_settings.stream.present? &&
          issue.zulip_settings.issue_updates_subject.present?
      }

      after_commit :update_version_subject_added, if: proc { |issue|
        issue.zulip_settings.enabled? &&
          issue.zulip_settings.stream.present? &&
          issue.zulip_settings.version_updates_subject.present? &&
          issue.previous_changes.include?("fixed_version_id") &&
          issue.previous_changes["fixed_version_id"].last.present?
      }

      after_commit :update_version_subject_removed, if: proc { |issue|
        issue.zulip_settings.enabled? &&
          issue.zulip_settings.stream.present? &&
          issue.zulip_settings.version_updates_subject.present? &&
          issue.previous_changes.include?("fixed_version_id") &&
          issue.previous_changes["fixed_version_id"].first.present?
      }

      after_commit :update_version_subject_status, if: proc { |issue|
        issue.zulip_settings.enabled? &&
          issue.zulip_settings.stream.present? &&
          issue.zulip_settings.version_updates_subject.present? &&
          issue.previous_changes.include?("status_id") &&
          issue.fixed_version_id.present? &&
          !issue.previous_changes.include?("fixed_version_id")
      }

      after_commit :update_version_subject_destroyed, if: proc { |issue|
        issue.zulip_settings.enabled? &&
          issue.zulip_settings.stream.present? &&
          issue.zulip_settings.version_updates_subject.present? &&
          issue.destroyed? &&
          issue.fixed_version_id.present?
      }
    end

    def subject_without_punctuation
      subject.end_with?(".") ? subject[0..-1] : subject
    end

    def zulip_settings
      @_zulip_settings ||= RedmineZulip::Settings.new(self)
    end

    private

    def zulip_api
      @_zulip_api ||= RedmineZulip::Api.new(
        url: zulip_settings.zulip_url,
        email: zulip_settings.zulip_email,
        key: zulip_settings.zulip_api_key
      )
    end

    def notify_assignment
      locale = assigned_to.language.present? ?
                 assigned_to.language : Setting.default_language
      message = I18n.t("zulip_notify_assignment", **{
        locale: locale,
        user: User.current.name,
        id: id,
        url: url,
        status: status.name,
        project: project.name,
        subject: subject_without_punctuation,
        description: description_truncated,
        status_label: Issue.human_attribute_name(:status, locale: locale)
      })
      if fixed_version.present?
        version_label = Issue.human_attribute_name(:fixed_version, locale: locale)
        message += "* **#{version_label}**: #{fixed_version.name}\n"
      end
      if estimated_hours.present?
        estimated_hours_label = Issue.human_attribute_name(:estimated_hours, locale: locale)
        message += "* **#{estimated_hours_label}**: #{estimated_hours}\n"
      end
      zulip_api.messages.send(
        type: "private",
        content: message,
        to: assigned_to.mail
      )
    end

    def notify_unassignment
      previous_assigned_to = User.find(
        previous_changes["assigned_to_id"].first
      )
      locale = previous_assigned_to.language.present? ?
                 previous_assigned_to.language : Setting.default_language
      message = I18n.t("zulip_notify_unassignment", **{
        user: User.current.name,
        id: id,
        url: url,
        project: project.name,
        subject: subject_without_punctuation,
        locale: locale
      })
      zulip_api.messages.send(
        type: "private",
        content: message,
        to: previous_assigned_to.mail
      )
    end

    def notify_assigned_to_issue_updated
      locale = assigned_to.language.present? ?
                 assigned_to.language : Setting.default_language
      message = I18n.t("zulip_notify_updated", **{
        user: User.current.name,
        id: id,
        url: url,
        project: project.name,
        subject: subject_without_punctuation,
        locale: locale
      })
      if previous_changes.include?("description")
        message += "~~~ quote\n"
        message += description_truncated
        message += "\n~~~\n"
      end
      if notes.present?
        message += "\n**#{Issue.human_attribute_name(:notes, locale: locale)}**\n"
        message += "~~~ quote\n"
        message += notes
        message += "\n~~~\n"
      end
      if previous_changes.include?("status_id")
        message += "\n* **#{Issue.human_attribute_name(:status, locale: locale)}**: "
        previous_status_id = previous_changes["status_id"].first
        if previous_status_id.present?
          previous_status = IssueStatus.find(previous_status_id)
          message += "*~~#{previous_status}~~* " if previous_status.present?
        end
        if status.present?
          message += status.name
        end
      end
      if previous_changes.include?("fixed_version_id")
        message += "\n* **#{Issue.human_attribute_name(:fixed_version, locale: locale)}**: "
        previous_fixed_version_id = previous_changes["fixed_version_id"].first
        if previous_fixed_version_id.present?
          previous_fixed_version = Version.find(previous_fixed_version_id)
          message += "*~~#{previous_fixed_version}~~* " if previous_fixed_version.present?
        end
        if fixed_version.present?
          message += fixed_version.name
        end
      end
      if previous_changes.include?("estimated_hours")
        message += "\n* **#{Issue.human_attribute_name(:estimated_hours, locale: locale)}**: "
        previous_estimated_hours = previous_changes["estimated_hours"].first
        if previous_estimated_hours.present?
          message += "*~~#{previous_estimated_hours}~~* "
        end
        if estimated_hours.present?
          message += "#{estimated_hours}"
        end
      end
      zulip_api.messages.send(
        type: "private",
        content: message,
        to: assigned_to.mail
      )
    end

    def notify_assigned_to_issue_destroyed
      locale = assigned_to.language.present? ?
                 assigned_to.language : Setting.default_language
      message = I18n.t("zulip_notify_destroyed", **{
        user: User.current.name,
        id: id,
        project: project.name,
        subject: subject_without_punctuation,
        locale: locale
      })
      zulip_api.messages.send(
        type: "private",
        content: message,
        to: assigned_to.mail
      )
    end

    def init_issue_subject
      locale = Setting.default_language
      message = I18n.t("zulip_init_issue_subject", **{
        locale: locale,
        user: User.current.name,
        id: id,
        url: url,
        project: project.name,
        subject: subject_without_punctuation,
        description: description_truncated,
        assigned_to_label: Issue.human_attribute_name(:assigned_to, locale: locale),
        assigned_to: assigned_to || "-",
        status_label: Issue.human_attribute_name(:status, locale: locale),
        status: status.nil? ? nil : status.name
      })
      if fixed_version.present?
        version_label = Issue.human_attribute_name(:fixed_version, locale: locale)
        message += "* **#{version_label}**: #{fixed_version.name}\n"
      end
      if estimated_hours.present?
        estimated_hours_label = Issue.human_attribute_name(:estimated_hours, locale: locale)
        message += "* **#{estimated_hours_label}**: #{estimated_hours}\n"
      end
      zulip_api.messages.send(
        type: "stream",
        content: message,
        to: zulip_settings.stream,
        subject: zulip_settings.issue_updates_subject
      )
    end

    def update_issue_subject
      locale = Setting.default_language
      message = I18n.t("zulip_notify_updated", **{
        locale: locale,
        user: User.current.name,
        id: id,
        url: url,
        project: project.name,
        subject: subject_without_punctuation,
      })
      if previous_changes.include?("description")
        message += "~~~ quote\n"
        message += description_truncated
        message += "\n~~~\n"
      end
      if notes.present?
        message += "\n* **#{Issue.human_attribute_name(:notes, locale: locale)}**\n"
        message += "~~~ quote\n"
        message += notes
        message += "\n~~~\n"
      end
      if previous_changes.include?("assigned_to_id")
        message += "\n* **#{Issue.human_attribute_name(:assigned_to, locale: locale)}**: "
        previous_assigned_to_id = previous_changes["assigned_to_id"].first
        if previous_assigned_to_id.present?
          previous_assigned_to = User.find(previous_assigned_to_id)
          message += "*~~#{previous_assigned_to.name}~~* " if previous_assigned_to.present?
        end
        if assigned_to.present?
          message += assigned_to.name
        end
      end
      if previous_changes.include?("status_id")
        message += "\n* **#{Issue.human_attribute_name(:status, locale: locale)}**: "
        previous_status_id = previous_changes["status_id"].first
        if previous_status_id.present?
          previous_status = IssueStatus.find(previous_status_id)
          message += "*~~#{previous_status}~~* " if previous_status.present?
        end
        if status.present?
          message += status.name
        end
      end
      if previous_changes.include?("fixed_version_id")
        message += "\n* **#{Issue.human_attribute_name(:fixed_version, locale: locale)}**: "
        previous_fixed_version_id = previous_changes["fixed_version_id"].first
        if previous_fixed_version_id.present?
          previous_fixed_version = Version.find(previous_fixed_version_id)
          message += "*~~#{previous_fixed_version}~~* " if previous_fixed_version.present?
        end
        if fixed_version.present?
          message += fixed_version.name
        end
      end
      if previous_changes.include?("estimated_hours")
        message += "\n* **#{Issue.human_attribute_name(:estimated_hours, locale: locale)}**: "
        previous_estimated_hours = previous_changes["estimated_hours"].first
        if previous_estimated_hours.present?
          message += "*~~#{previous_estimated_hours}~~* "
        end
        if estimated_hours.present?
          message += "#{estimated_hours}"
        end
      end
      zulip_api.messages.send(
        type: "stream",
        content: message,
        to: zulip_settings.stream,
        subject: zulip_settings.issue_updates_subject
      )
    end

    def update_issue_subject_destroyed
      message = I18n.t("zulip_notify_destroyed", **{
        locale: Setting.default_language,
        user: User.current.name,
        id: id,
        project: project.name,
        subject: subject_without_punctuation
      })
      zulip_api.messages.send(
        type: "stream",
        content: message,
        to: zulip_settings.stream,
        subject: zulip_settings.issue_updates_subject
      )
    end

    def update_version_subject_added
      message = I18n.t("zulip_update_version_subject_added", **{
        locale: Setting.default_language,
        user: User.current.name,
        id: id,
        url: url,
        project: project.name,
        subject: subject_without_punctuation,
        fixed_version: fixed_version
      })
      zulip_api.messages.send(
        type: "stream",
        content: message,
        to: zulip_settings.stream,
        subject: zulip_settings.version_updates_subject
      )
    end

    def update_version_subject_removed
      previous_fixed_version = Version.find(
        previous_changes["fixed_version_id"].first
      )
      message = I18n.t("zulip_update_version_subject_removed", **{
        locale: Setting.default_language,
        user: User.current.name,
        id: id,
        url: url,
        project: project.name,
        subject: subject_without_punctuation,
        fixed_version: previous_fixed_version
      })
      zulip_api.messages.send(
        type: "stream",
        content: message,
        to: zulip_settings.stream,
        subject: zulip_settings.version_updates_subject
      )
    end

    def update_version_subject_status
      previous_status_id = previous_changes["status_id"].first
      message = I18n.t("zulip_update_version_subject_status", **{
        locale: Setting.default_language,
        user: User.current.name,
        id: id,
        url: url,
        project: project.name,
        subject: subject_without_punctuation,
        previous_status: IssueStatus.find(previous_status_id),
        current_status: status
      })
      zulip_api.messages.send(
        type: "stream",
        content: message,
        to: zulip_settings.stream,
        subject: zulip_settings.version_updates_subject
      )
    end

    def update_version_subject_destroyed
      message = I18n.t("zulip_notify_destroyed", **{
        locale: Setting.default_language,
        user: User.current.name,
        id: id,
        project: project.name,
        subject: subject_without_punctuation
      })
      zulip_api.messages.send(
        type: "stream",
        content: message,
        to: zulip_settings.stream,
        subject: zulip_settings.version_updates_subject
      )
    end

    def url
      "#{Setting[:protocol]}://#{Setting[:host_name]}/issues/#{id}"
    end

    def description_truncated
      truncated = description
      if truncated.include?("\n")
        truncated = "#{truncated.split("\n")[0]}..."
      end
      if truncated.size > TWEET_SIZE
        truncated = "#{truncated[0..(TWEET_SIZE - 1)]}..."
      end
      truncated
    end
  end
end
