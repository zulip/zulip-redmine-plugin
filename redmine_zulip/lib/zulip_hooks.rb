# encoding: utf-8

require 'json'

class NotificationHook < Redmine::Hook::Listener

    # We generate Zulips for creating and updating issues.

    def controller_issues_new_after_save(context = {})
        issue = context[:issue]
        project = issue.project

        if !configured(project)
            # Fail silently: the rest of the app needs to continue working.
             return true
        end

        content = %Q{%s opened [issue %d: %s](%s) in %s

~~~ quote
%s
~~~

**Priority**: %s
**Status**: %s
**Assigned to**: %s} % [User.current.name, issue.id, issue.subject, url(issue),
                        project.name, issue.description, issue.priority.to_s,
                        issue.status.to_s, issue.assigned_to.to_s]

        send_zulip_message(content, project)
    end

    def controller_issues_edit_after_save(context = {})
        issue = context[:issue]
        project = issue.project

        if !configured(project)
            # Fail silently: the rest of the app needs to continue working.
             return true
        end

        content = %Q{%s updated [issue %d: %s](%s) in %s

~~~ quote
%s
~~~} % [User.current.name, issue.id, issue.subject, url(issue),
        project.name, issue.notes]

        send_zulip_message(content, project)
    end

    private

    def configured(project)
        # The plugin can be configured as a system setting or per-project.

        if project.zulip_email.present? &&
             project.zulip_api_key.present? &&
             project.zulip_stream.present? &&
             Setting.plugin_redmine_zulip["projects"] &&
             Setting.plugin_redmine_zulip["zulip_url"].present?
            # We have full per-project settings.
            return true
        end
        if Setting.plugin_redmine_zulip["projects"] &&
             Setting.plugin_redmine_zulip["zulip_email"].present? &&
             Setting.plugin_redmine_zulip["zulip_api_key"].present? &&
             Setting.plugin_redmine_zulip["zulip_stream"].present? &&
             Setting.plugin_redmine_zulip["zulip_url"].present?
            # We have full global settings.
            return true
        end

        Rails.logger.info "Missing config, can't sent to Zulip!"
        false
    end

    def zulip_email(project)
        if project.zulip_email.present?
            return project.zulip_email
        end
        Setting.plugin_redmine_zulip["zulip_email"]
    end

    def zulip_api_key(project)
        if project.zulip_api_key.present?
            return project.zulip_api_key
        end
        Setting.plugin_redmine_zulip["zulip_api_key"]
    end

    def zulip_stream(project)
        if project.zulip_stream.present?
            return project.zulip_stream
        end
        Setting.plugin_redmine_zulip["zulip_stream"]
    end

   def zulip_url()
       Setting.plugin_redmine_zulip["zulip_url"]
   end

   def url(issue)
       "#{Setting[:protocol]}://#{Setting[:host_name]}/issues/#{issue.id}"
   end

   def send_zulip_message(content, project)
       data = {"to" => zulip_stream(project),
               "type" => "stream",
               "subject" => project.name,
               "content" => content}

       Rails.logger.info "Forwarding to Zulip: #{data['content']}"

       uri = URI("#{zulip_url}/v1/messages")

       req = Net::HTTP::Post.new(uri)
       req.basic_auth(zulip_email(project), zulip_api_key(project))
       req["User-Agent"] = "ZulipRedmine/#{RedmineZulip::VERSION}"
       req.set_form_data(data)

       res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
         http.request(req)
       end

       if res.code == "200"
         Rails.logger.info "Zulip message sent!"
       else
         Rails.logger.error "Error while POSTing to Zulip: #{res.body}"
       end
   end
end
