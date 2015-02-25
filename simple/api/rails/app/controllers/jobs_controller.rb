class JobsController < ApplicationController
  def create
    Rails.logger.info "CREATE!"
    render json: '{ "id": "foobar", "from": "2012-02-01", "to": "2012-02-05", "text": "CREATE" }'
  end

  def index
    render json: '{ "text": "GET" }'
  end

  def show
    render json: '{ "text": "SHOW" }'
  end
end
