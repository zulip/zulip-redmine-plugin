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

        if !project.zulip_email.empty? && !project.zulip_api_key.empty? &&
           !project.zulip_stream.empty? && Setting.plugin_redmine_zulip[:projects] &&
            Setting.plugin_redmine_zulip[:zulip_server]
            # We have full per-project settings.
            return true
        elsif Setting.plugin_redmine_zulip[:projects] &&
            Setting.plugin_redmine_zulip[:zulip_email] &&
            Setting.plugin_redmine_zulip[:zulip_api_key] &&
            Setting.plugin_redmine_zulip[:zulip_stream] &&
            Setting.plugin_redmine_zulip[:zulip_server]
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

   def zulip_server()
       return Setting.plugin_redmine_zulip[:zulip_server]
   end

   def zulip_port()
      if Setting.plugin_redmine_zulip[:zulip_port]
        return Setting.plugin_redmine_zulip[:zulip_port]
      end
      return 443
   end

   def zulip_api_basename()
     basename = Setting.plugin_redmine_zulip[:zulip_server].sub %r{^https?:(//|\\\\)}i, ''
     if not basename.end_with? "/api"
         basename = basename.concat "/api"
     end
     return basename
   end

    def url(issue)
        return "#{Setting[:protocol]}://#{Setting[:host_name]}/issues/#{issue.id}"
    end

    def send_zulip_message(content, project)

        data = {"to" => zulip_stream(project),
                "type" => "stream",
                "subject" => project.name,
                "content" => content}

        Rails.logger.info "Forwarding to Zulip: #{data['content']}"

        http = Net::HTTP.new(zulip_server(), zulip_port())
        http.use_ssl = true

        req = Net::HTTP::Post.new(zulip_api_basename() + "/v1/messages")
        req.basic_auth zulip_email(project), zulip_api_key(project)
        req.add_field('User-Agent', "ZulipRedmine/#{RedmineZulip::VERSION}")
        req.set_form_data(data)

        res = http.request(req)
        unless res.code == "200"
          Rails.logger.error "Error while POSTing to Zulip: #{res.body}"
        end
    end
end
