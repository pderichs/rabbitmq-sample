class CalcResultsWorker
  include Sneakers::Worker

  from_queue 'app.calc.results', env: nil

  def work(raw_post)
    # RecentPosts.push(raw_post)
    Rails.logger.info "new post #{raw_post}"

    ack! # we need to let queue know that message was received
  end
end
