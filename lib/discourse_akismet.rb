require_dependency File.expand_path('../discourse_akismet/engine.rb', __FILE__)

module DiscourseAkismet

  def self.with_client
    Akismet::Client.open(SiteSetting.akismet_api_key,
      Discourse.base_url,
      :app_name => 'Discourse',
      :app_version => Discourse::VERSION::STRING ) do |client|
        yield client
    end
  end

  def self.args_for_post(post)
    extra_args = {
      content_type: 'forum-post',
      permalink: "#{Discourse.base_url}#{post.url}",
      comment_author: post.user.try(:username),
      comment_content: post.raw
    }

    # Sending the email to akismet is optional
    if SiteSetting.akismet_transmit_email?
      extra_args[:comment_author_email] = post.user.try(:email)
    end

    extra_args
  end

  def self.args_for_queued_post(qp)
    extra_args = {
      content_type: 'forum-post',
      referrer: qp.post_options['referrer'],
      comment_author: qp.user.try(:username),
      comment_content: qp.raw
    }

    # Sending the email to akismet is optional
    if SiteSetting.akismet_transmit_email?
      extra_args[:comment_author_email] = qp.user.try(:email)
    end

    [qp.post_options['ip_address'], qp.post_options['user_agent'], extra_args]
  end

  def self.to_check
    QueuedPost.where(queue: 'akismet_to_check', state: QueuedPost.states[:new])
  end

  def self.check_for_spam(to_check)
    return if to_check.blank?

    spam_count = 0
    to_review = []
    DiscourseAkismet.with_client do |client|
      [to_check].flatten.each do |qp|

        if client.comment_check(*DiscourseAkismet.args_for_queued_post(qp))
          spam_count += 1
          to_review << qp.id
        else
          if NewPostManager.user_needs_approval?(qp.user)
            to_review << qp.id
          else
            qp.approve!(Discourse.system_user)
          end
        end
      end
    end

    QueuedPost.where(id: to_review).update_all(queue: 'akismet_to_review')
    QueuedPost.broadcast_new!

    # Trigger an event that akismet found spam. This allows people to
    # notify chat rooms or whatnot
    DiscourseEvent.trigger(:akismet_found_spam, to_review.size) if spam_count > 0
  end

  def self.stats
    sql = <<-SQL
      SELECT
        SUM(CASE WHEN queue = :review_queue AND state = :new THEN 1 ELSE 0 END) AS needs_review,
        SUM(CASE WHEN queue = :review_queue AND state = :approved THEN 1 ELSE 0 END) AS confirmed_ham,
        SUM(CASE WHEN queue = :review_queue AND state = :rejected THEN 1 ELSE 0 END) AS confirmed_spam,
        SUM(CASE WHEN queue = :check_queue AND state = :approved THEN 1 ELSE 0 END) as checked
      FROM queued_posts
      WHERE queue IN (:review_queue, :check_queue)
    SQL

    result = QueuedPost.exec_sql(sql,
                                 new: QueuedPost.states[:new],
                                 approved: QueuedPost.states[:approved],
                                 rejected: QueuedPost.states[:rejected],
                                 review_queue: 'akismet_to_review',
                                 check_queue: 'akismet_to_check')[0].symbolize_keys!

    result.each_key {|k| result[k] = result[k].to_i}
    result[:confirmed_spam] ||= 0
    result[:confirmed_ham] ||= 0
    result[:needs_review] ||= 0
    result[:checked] ||= 0
    result[:scanned] = result[:checked] + result[:needs_review] + result[:confirmed_spam] + result[:confirmed_ham]
    result
  end

end
