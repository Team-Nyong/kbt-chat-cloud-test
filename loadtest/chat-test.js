const io = require('socket.io-client');
const axios = require('axios');
const https = require('https');
const http = require('http');

// C 리전 IP로 강제 연결
const C_REGION_IP = '3.39.133.100';
const HOST = 'chat.goorm-ktb-006.goorm.team';

// HTTPS Agent with custom lookup
const httpsAgent = new https.Agent({
  lookup: (hostname, options, callback) => {
    if (hostname === HOST) {
      console.log(`[HTTPS] ${hostname} -> ${C_REGION_IP} (C 리전)`);
      callback(null, C_REGION_IP, 4);
    } else {
      require('dns').lookup(hostname, options, callback);
    }
  }
});

const API_URL = `https://${HOST}`;
const SOCKET_URL = `https://${HOST}`;

// Axios instance with custom agent
const api = axios.create({
  httpsAgent,
  timeout: 10000
});

async function main() {
  console.log('========================================');
  console.log('  C 리전 (3.39.133.100) 직접 연결 테스트');
  console.log('========================================\n');

  const timestamp = Date.now();
  const email = `claude_bot_c_${timestamp}@test.com`;
  const password = 'Test1234!';
  const name = 'Claude Bot (C리전)';

  console.log('=== 1. 회원가입 시도 ===');
  try {
    const registerRes = await api.post(`${API_URL}/api/auth/register`, {
      email, password, name
    });
    console.log('회원가입 성공:', registerRes.data.message);
  } catch (err) {
    console.log('회원가입:', err.response?.data?.message || err.message);
  }

  // 로그인
  console.log('\n=== 2. 로그인 시도 ===');
  let authData;
  try {
    const loginRes = await api.post(`${API_URL}/api/auth/login`, {
      email, password
    });
    authData = loginRes.data;
    console.log('로그인 성공!');
  } catch (loginErr) {
    console.log('로그인 실패:', loginErr.response?.data || loginErr.message);
    process.exit(1);
  }

  const { token, sessionId, user } = authData;
  console.log('토큰:', token?.substring(0, 50) + '...');
  console.log('세션ID:', sessionId);
  console.log('사용자:', user?.name);

  // HTTP API로 채팅방 목록 조회
  console.log('\n=== 3. 채팅방 목록 조회 (HTTP API) ===');
  let roomId;
  try {
    const roomsRes = await api.get(`${API_URL}/api/rooms`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    const rooms = roomsRes.data.data || [];
    console.log('채팅방 수:', rooms.length);

    if (rooms.length > 0) {
      roomId = rooms[0]._id;
      console.log('첫 번째 채팅방:', rooms[0].name, '(' + roomId + ')');
    } else {
      console.log('\n채팅방이 없어서 생성합니다...');
      const createRes = await api.post(`${API_URL}/api/rooms`, {
        name: 'Claude Test Room (C리전)',
        description: 'Claude Bot이 C 리전에서 만든 테스트 채팅방'
      }, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      roomId = createRes.data.data._id;
      console.log('채팅방 생성됨:', roomId);
    }
  } catch (err) {
    console.log('채팅방 조회 실패:', err.response?.data || err.message);
    process.exit(1);
  }

  // Socket.IO 연결 (C 리전으로)
  console.log('\n=== 4. Socket.IO 연결 (C 리전) ===');

  // Socket.IO에도 custom agent 적용
  const socketHttpsAgent = new https.Agent({
    lookup: (hostname, options, callback) => {
      if (hostname === HOST) {
        console.log(`[Socket.IO] ${hostname} -> ${C_REGION_IP} (C 리전)`);
        callback(null, C_REGION_IP, 4);
      } else {
        require('dns').lookup(hostname, options, callback);
      }
    }
  });

  const socket = io(SOCKET_URL, {
    auth: { token, sessionId },
    transports: ['websocket', 'polling'],
    reconnection: false,
    timeout: 10000,
    agent: socketHttpsAgent
  });

  socket.on('connect', () => {
    console.log('Socket.IO 연결 성공! ID:', socket.id);
    console.log('연결된 서버: C 리전 (3.39.133.100)');

    // 채팅방 입장
    console.log('\n=== 5. 채팅방 입장 ===');
    socket.emit('joinRoom', roomId);
    console.log('joinRoom 이벤트 전송:', roomId);

    // 메시지 전송
    setTimeout(() => {
      console.log('\n=== 6. 메시지 전송 ===');
      const message = `[C리전 테스트] 안녕하세요! Claude Bot입니다. (${new Date().toLocaleTimeString('ko-KR')})`;
      socket.emit('chatMessage', {
        roomId,
        content: message
      });
      console.log('보낸 메시지:', message);

      setTimeout(() => {
        console.log('\n========================================');
        console.log('  C 리전 테스트 완료!');
        console.log('========================================');
        socket.disconnect();
        process.exit(0);
      }, 3000);
    }, 1000);
  });

  socket.on('connect_error', (err) => {
    console.log('연결 에러:', err.message);
    process.exit(1);
  });

  socket.on('newMessage', (data) => {
    console.log('새 메시지 수신:', data.content);
  });

  socket.on('roomJoined', (data) => {
    console.log('채팅방 입장 확인:', data);
  });

  // 타임아웃
  setTimeout(() => {
    console.log('타임아웃!');
    socket.disconnect();
    process.exit(1);
  }, 30000);
}

main().catch(console.error);
