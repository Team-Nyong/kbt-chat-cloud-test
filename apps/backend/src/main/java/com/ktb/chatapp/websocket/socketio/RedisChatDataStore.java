package com.ktb.chatapp.websocket.socketio;

import java.util.Optional;
import org.redisson.api.RBucket;
import org.redisson.api.RedissonClient;

/**
 * Redis 기반의 ChatDataStore 구현체.
 * Socket.IO 멀티 인스턴스 환경에서도 동일한 사용자/방 데이터를
 * 공유할 수 있도록 레디스를 사용한다.
 */
public class RedisChatDataStore implements ChatDataStore {

    private final RedissonClient redissonClient;

    public RedisChatDataStore(RedissonClient redissonClient) {
        this.redissonClient = redissonClient;
    }

    @Override
    @SuppressWarnings("unchecked")
    public <T> Optional<T> get(String key, Class<T> type) {
        RBucket<Object> bucket = redissonClient.getBucket(key);
        Object value = bucket.get();
        if (value == null) {
            return Optional.empty();
        }

        try {
            return Optional.of((T) value);
        } catch (ClassCastException e) {
            return Optional.empty();
        }
    }

    @Override
    public void set(String key, Object value) {
        redissonClient.getBucket(key).set(value);
    }

    @Override
    public void delete(String key) {
        redissonClient.getBucket(key).delete();
    }

    @Override
    public int size() {
        long count = redissonClient.getKeys().count();
        return count > Integer.MAX_VALUE ? Integer.MAX_VALUE : (int) count;
    }
}
