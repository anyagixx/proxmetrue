addEventListener('scheduled', event => event.waitUntil(handleScheduled()));
// Use with Yongge's Serv00 SSH script or the GitHub/VPS/router deployment scripts to call keepalive and restart URLs.
// Separate each /up or /re URL with spaces or commas, and include the full http:// prefix.
const urlString = 'http://keepalive-or-restart-page-1 http://keepalive-or-restart-page-2 http://keepalive-or-restart-page-3 ...';
const urls = urlString.split(/[\s,，]+/);
const TIMEOUT = 5000;
async function fetchWithTimeout(url) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), TIMEOUT);
  try {
    await fetch(url, { signal: controller.signal });
console.log(`✅ Success: ${url}`);
  } catch (error) {
console.warn(`❌ Request failed: ${url}, error: ${error.message}`);
  } finally {
    clearTimeout(timeout);
  }
}
async function handleScheduled() {
  console.log('⏳ Scheduled task started');
  await Promise.all(urls.map(fetchWithTimeout));
  console.log('📊 Scheduled task finished');
}
