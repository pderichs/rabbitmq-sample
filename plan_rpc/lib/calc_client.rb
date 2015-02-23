 # Stolen from http://www.rabbitmq.com/tutorials/tutorial-six-ruby.html

require 'thread'

require_relative './bunny_rpc_client'

class CalcClient < BunnyRpcClient
end
