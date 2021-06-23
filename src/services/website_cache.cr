require "redis"

class WebsiteCache
  @@redis = Redis::PooledClient.new

  def self.store(key : String, value)
    @@redis.set(key, value)
  end

  def self.retrieve(key : String)
    @@redis.get(key)
  end

  def self.clear!
    @@redis.flushdb
  end
end
