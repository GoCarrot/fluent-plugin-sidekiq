require "redis"

class Fluent::SidekiqOutput < Fluent::BufferedOutput
  VERSION = "0.0.2"
  Fluent::Plugin.register_output("sidekiq", self)

  config_param :redis_url, :string, :default => 'redis://localhost:6379'
  config_param :redis_namespace, :string, :default => nil

  def start
    super
  end

  def shutdown
    super
  end

  def format(tag, time, record)
    [tag, time, record].to_msgpack
  end

  def redis_client
    opts = {url: @redis_url}
    client = Redis.new(opts)
    if @redis_namespace
      require "redis/namespace"
      Redis::Namespace.new(@redis_namespace, client)
    else
      client
    end
  end

  def write(chunk)
    client = redis_client
    client.pipelined do
      chunk.msgpack_each do |tag, time, data|
        at = data.delete('at')
        if at
          client.zadd('schedule', [at, data['payload']])
        else
          queue = data.delete('queue')
          client.sadd('queues', queue)
          client.lpush("queue:#{queue}", data['payload'])
        end
      end
    end
  end
end
