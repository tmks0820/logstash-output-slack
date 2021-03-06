# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"
require "openssl"
require "net/http"
require "json"

class LogStash::Outputs::Slack < LogStash::Outputs::Base
  config_name "slack"
  milestone 1

  # The incoming webhook URI needed to post a message
  config :url, :validate => :string, :required => true

  # The text to post in slack
  config :format, :validate => :string, :default => "%{message}"

  # The channel to post to
  config :channel, :validate => :string

  # The username to use for posting
  config :username, :validate => :string

  # Emoji icon to use
  config :icon_emoji, :validate => :string

  # Icon URL to use
  config :icon_url, :validate => :string

  # Attachments array as described https://api.slack.com/docs/attachments
  config :attachments, :validate => :array

  # Proxy host
  config :proxy, :validate => :string

  public
  def register
    require 'rest-client'
    require 'cgi'
    require 'json'

    @content_type = "application/x-www-form-urlencoded"
  end # def register

  public

  def notify_alert_on_slack(payload_json)
    uri = URI.parse(@url)
    https = Net::HTTP::Proxy(@proxy, 8888).new(uri.host, 443)
    https.use_ssl = true
    https.verify_mode = OpenSSL::SSL::VERIFY_PEER

    post_data = URI.encode_www_form({"payload" => JSON.dump(payload_json)})
    https.request_post(uri.path, post_data)
  end


  def receive(event)
    return unless output?(event)

    payload_json = Hash.new
    payload_json['text'] = event.sprintf(@format)

    if not @channel.nil?
      payload_json['channel'] = event.sprintf(@channel)
    end

    if not @username.nil?
      payload_json['username'] = event.sprintf(@username)
    end

    if not @icon_emoji.nil?
      payload_json['icon_emoji'] = @icon_emoji
    end

    if not @icon_url.nil?
      payload_json['icon_url'] = @icon_url
    end

    if @attachments and @attachments.any?
      payload_json['attachments'] = @attachments
    end
    if event.include?('attachments') and event['attachments'].is_a?(Array)
      if event['attachments'].any?
        # need to convert possibly from Java objects to Ruby Array, because
        # JSON dumps does not work well with Java ArrayLists, etc.
        rubified = JSON.parse(event.to_json())
        payload_json['attachments'] = rubified['attachments']
      else
        payload_json.delete('attachments')
      end
    end

    begin
      notify_alert_on_slack(payload_json)
    rescue Exception => e
      @logger.warn("Unhandled exception", :exception => e,
                   :stacktrace => e.backtrace)
    end
  end # def receive
end # class LogStash::Outputs::Slack
