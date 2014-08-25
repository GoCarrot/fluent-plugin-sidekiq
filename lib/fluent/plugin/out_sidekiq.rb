require "redis"

class Fluent::SidekiqOutput < Fluent::BufferedOutput
  class Batch
    attr_accessor :queue, :klass, :payload

    def initialize(q, k)
      self.queue = q
      self.klass = k
      self.payload = {:class => k, :retry => true, :jid => "", :enqueued_at => 0, :args => [[]] }
    end

    def acceptable_batch(q, c, p, max_size)
      q == queue && c == klass && (payload[:args][0].length + p.length) <= max_size
    end

    def add_to_batch(p)
      payload[:retry] = p['retry']
      payload[:jid] = p['jid']
      payload[:enqueued_at] = p['enqueued_at']
      payload[:args][0] += p['args'][0]
    end

    def enqueue(client)
      client.sadd("queues", queue)
      client.lpush("queue:#{queue}", JSON.generate(payload))
    end
  end

  VERSION = "0.0.3"
  Fluent::Plugin.register_output("sidekiq", self)

  config_param :redis_url, :string, :default => 'redis://localhost:6379'
  config_param :redis_namespace, :string, :default => nil
  config_param :max_batch_size, :integer, :default => 5

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
    opts = {url: @redis_url, driver: :hiredis}
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
    scheduled_jobs = []
    batches = []
    manually_queue = []

    chunk.msgpack_each do |tag, time, data|
      at = data.delete('at')
      if at
        scheduled_jobs << [at, data['payload']]
      else
        payload = JSON.parse(data['payload'])
        if payload['args'][0].kind_of?(Array) && payload['args'][0].all? { |a| a.kind_of?(Hash) }
          queue = data.delete('queue')
          klass = payload['class']

          batch = batches.find { |b| b.acceptable_batch(queue, klass, payload['args'][0], max_batch_size) }
          if !batch
            batch = Batch.new(queue, klass)
            batches << batch
          end

          batch.add_to_batch(payload)
        else
          # Manual queuing
          manually_queue << data
        end
      end
    end

    if scheduled_jobs.length > 0
      client.zadd('schedule', scheduled_jobs)
    end
    batches.each do |batch|
      batch.enqueue(client)
    end
    manually_queue.each do |data|
      queue = data.delete('queue')
      client.sadd('queues', queue)
      client.lpush("queue:#{queue}", data['payload'])
    end
  end
end
