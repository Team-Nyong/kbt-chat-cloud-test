export default function Health() {
  return null;
}

export async function getServerSideProps({ res }) {
  res.setHeader('Content-Type', 'application/json');
  res.write(JSON.stringify({ status: 'ok', source: 'frontend', uptime: process.uptime() }));
  res.end();
  
  return {
    props: {},
  };
}
