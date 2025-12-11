import React from 'react';
import { useRouter } from 'next/router';
import { ThemeProvider } from '@vapor-ui/core';
import '@vapor-ui/core/styles.css';
import '../styles/globals.css';
import ChatHeader from '@/components/ChatHeader';
import ToastContainer from '@/components/Toast';
import { AuthProvider } from '@/contexts/AuthContext';

function MyApp({ Component, pageProps }) {
  const router = useRouter();

  const isErrorPage = router.pathname === '/_error';
  if (isErrorPage) {
    return <Component {...pageProps} />;
  }

  // 로그인/회원가입 페이지에서는 헤더 숨김
  const showHeader = !['/', '/register'].includes(router.pathname);

  return (
    <ThemeProvider defaultTheme="dark">
      <AuthProvider>
        {showHeader && <ChatHeader />}
        <Component {...pageProps} />
        <ToastContainer />
      </AuthProvider>
    </ThemeProvider>
  );
}

// 서버 사이드에서 요청 로깅을 위한 getInitialProps 추가
MyApp.getInitialProps = async ({ ctx }) => {
  if (ctx.req) { // 서버 사이드에서만 실행
    const { req } = ctx;
    console.log(`[SSR Request] ${req.method} ${req.url}`);
    // 필요한 경우 추가적인 헤더나 IP 정보 로깅 가능
  }
  return {};
};

export default MyApp;