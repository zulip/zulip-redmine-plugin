# encoding: utf-8

require 'json'

class NotificationHook < Redmine::Hook::Listener

    # We generate Zulips for creating and updating issues.

    def controller_issues_new_after_save(context = {})
        extract_and_send(context, "new")
    end

    def controller_issues_edit_after_save(context = {})
        extract_and_send(context, "edit")
    end

    private

    def configured(project)
        # The plugin can be configured as a system setting or per-project.

        if !project.zulip_email.empty? && !project.zulip_api_key.empty? &&
           !project.zulip_stream.empty?
            # We have full per-project settings.
            return true
        elsif Setting.plugin_redmine_zulip[:projects] &&
            Setting.plugin_redmine_zulip[:zulip_email] &&
            Setting.plugin_redmine_zulip[:zulip_api_key] &&
            Setting.plugin_redmine_zulip[:zulip_stream]
            # We have full global settings.
            return true
        end

        Rails.logger.info "Missing config, can't sent to Zulip!"
        return false
    end

    def zulip_email(project)
        if !project.zulip_email.empty?
            return project.zulip_email
        end
        return Setting.plugin_redmine_zulip[:zulip_email]
    end

    def zulip_api_key(project)
        if !project.zulip_api_key.empty?
            return project.zulip_api_key
        end
        return Setting.plugin_redmine_zulip[:zulip_api_key]
    end

    def zulip_stream(project)
        if !project.zulip_stream.empty?
            return project.zulip_stream
        end
        return Setting.plugin_redmine_zulip[:zulip_stream]
    end

    def send_message(data)
        Rails.logger.info "Forwarding to Zulip: #{data[:payload]}"

        http = Net::HTTP.new("api.zulip.com", 443)
        http.use_ssl = true

        req = Net::HTTP::Post.new("/api/v1/external/redmine")
        req.set_form_data({
            "email" => data[:zulip_email],
            "api-key" => data[:zulip_api_key],
            "stream" => data[:zulip_stream],
            "payload" => data[:payload]
        })

        begin
            http.request(req)
        rescue Net::HTTPBadResponse => e
            Rails.logger.error "Error while POSTing to Zulip: #{e}"
        end
    end

    def extract_and_send(context, type)
        issue = context[:issue]
        project = issue.project

        if !configured(project)
            # Fail silently: the rest of the app needs to continue working.
             return true
        end

        author = CGI::escapeHTML(User.current.name)
        subject = CGI::escapeHTML(issue.subject)
        url = "#{Setting[:protocol]}://#{Setting[:host_name]}/issues/#{issue.id}"

        payload = {:type => type,
                   :project => project.name,
                   :issue_id => issue.id,
                   :issue_subject => subject,
                   :issue_description => issue.description,
                   :priority => issue.priority.to_s,
                   :status => issue.status.to_s,
                   :assignee => issue.assigned_to.to_s,
                   :notes => issue.notes,
                   :author => author,
                   :url => "#{url}##{issue.id}"}.to_json

        data = {:payload => payload,
                :zulip_email => zulip_email(project),
                :zulip_api_key => zulip_api_key(project),
                :zulip_stream => zulip_stream(project)}

        send_message(data)
    end
end
