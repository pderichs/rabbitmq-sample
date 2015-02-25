class JobsController < ApplicationController
  def create
    Rails.logger.info "CREATE!"
    id = SecureRandom.uuid
    render json: '{ "id": "' + id + '", "from": "2012-02-01", "to": "2012-02-05", "duration": "0", "status": "Waiting for result", "text": "CREATE" }'
  end

  def index
    render json: '{ "text": "GET" }'
  end

  def show
    render json: '{ "text": "SHOW" }'
  end
end
