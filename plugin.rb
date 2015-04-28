# name: discourse-akismet
# about: supports submitting posts to akismet for review
# version: 0.1.0
# authors: Michael Verdi, Robin Ward
# url: https://github.com/discourse/discourse-akismet
# required version: 1.3.0.beta6

# install dependencies
gem "akismet", "1.0.2"

# load the engine
load File.expand_path('../lib/discourse_akismet.rb', __FILE__)

register_asset "stylesheets/akismet.scss"

after_initialize do
  require_dependency File.expand_path('../jobs/check_for_spam_posts.rb', __FILE__)
  require_dependency File.expand_path('../jobs/post_was_spam.rb', __FILE__)
  require_dependency File.expand_path('../jobs/reviewed_akismet_post.rb', __FILE__)

  QueuedPost.visible_queues << 'akismet_to_review'

  # When staff agrees a flagged post is spam, send it to akismet
  on(:confirmed_spam_post) do |post|
    if SiteSetting.akismet_enabled?
      Jobs.enqueue(:post_was_spam, post_id: post.id)
    end
  end

  on(:approved_post) do |queued_post|
    if queued_post.queue == 'akismet_to_review'
      Jobs.enqueue(:reviewed_akismet_post, queued_post_id: queued_post.id)
    end
  end

  on(:rejected_post) do |queued_post|
    if queued_post.queue == 'akismet_to_review'
      Jobs.enqueue(:reviewed_akismet_post, queued_post_id: queued_post.id)
    end
  end

  begin
    require_dependency 'new_post_manager'
    require_dependency 'queued_post'

    ::NewPostManager.add_handler(100) do |manager|
      result = nil
      if SiteSetting.akismet_enabled?

        # We only run it on certain trust levels
        next if manager.user.has_trust_level?(TrustLevel[SiteSetting.skip_akismet_trust_level.to_i])

        # We don't run akismet on private messages
        topic_id = manager.args["topic_id"].to_i
        if topic_id != 0
          topic = Topic.find(topic_id)
          next if topic.private_message?
        end

        # We only check posts over 20 chars
        stripped = manager.args['raw'].strip
        next if stripped.size < 20

        # If the entire post is a URI we skip it. This might seem counter intuitive but
        # Discourse already has settings for max links and images for new users. If they
        # pass it means the administrator specifically allowed them.
        uri = URI(stripped) rescue nil
        next if uri

        result = manager.enqueue('akismet_to_check', 'akismet')
      end
      result
    end
  end

end

add_admin_route 'akismet.title', 'akismet'

# And mount the engine
Discourse::Application.routes.append do
  mount ::DiscourseAkismet::Engine, at: '/admin/plugins/akismet'
end
