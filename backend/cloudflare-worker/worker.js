let modelsCache = null;
let modelsCacheAt = 0;
const MODELS_TTL_MS = 15 * 60 * 1000;

let mediaPricingOverridesCache = null;
let mediaPricingOverridesAt = 0;
const MEDIA_PRICING_TTL_MS = 5 * 60 * 1000;
const PRICING_VERSION = 'media-v4';

function imageModel(usdPerRun, extra = {}) {
  return {
    provider: 'replicate',
    category: 'image',
    billingType: 'per_run',
    usdPerRun,
    gateField: 'minImageGatePoints',
    isActive: true,
    ...extra
  };
}

function videoModel(usdPerRun, extra = {}) {
  return {
    provider: 'replicate',
    category: 'video',
    billingType: 'per_run',
    usdPerRun,
    gateField: 'minVideoGatePoints',
    isActive: true,
    ...extra
  };
}

function audioModel(usdPerRun, extra = {}) {
  return {
    provider: 'replicate',
    category: 'audio',
    billingType: 'per_run',
    usdPerRun,
    gateField: 'minAudioGatePoints',
    isActive: true,
    ...extra
  };
}

const HARDCODED_MEDIA_MODELS = {
  'google/imagen-4-fast': imageModel(0.020),
  'google/imagen-4': imageModel(0.040),
  'google/imagen-4-ultra': imageModel(0.060),
  'google/imagen-3': imageModel(0.035),
  'google/imagen-3-fast': imageModel(0.018),
  'google/nano-banana': imageModel(0.039, {
    supportsEdit: true,
    supportsImageInput: true,
    editStrength: 'strong'
  }),
  'black-forest-labs/flux-schnell': imageModel(0.018),
  'black-forest-labs/flux-pro': imageModel(0.050),
  'black-forest-labs/flux-kontext-pro': imageModel(0.055, {
    supportsEdit: true,
    supportsImageInput: true,
    supportsReferenceImage: true,
    editStrength: 'strong'
  }),
  'recraft-ai/recraft-v4': imageModel(0.040),
  'recraft-ai/recraft-v4-pro': imageModel(0.060),
  'recraft-ai/recraft-v4-svg': imageModel(0.040),
  'recraft-ai/recraft-v4-pro-svg': imageModel(0.060),
  'recraft-ai/recraft-v3': imageModel(0.035),
  'recraft-ai/recraft-v3-svg': imageModel(0.035),
  'ideogram-ai/ideogram-v3-turbo': imageModel(0.030),
  'ideogram-ai/ideogram-v3-quality': imageModel(0.050),
  'ideogram-ai/ideogram-v3-balanced': imageModel(0.038),
  'ideogram-ai/ideogram-v2': imageModel(0.035, {
    supportsEdit: true,
    supportsImageInput: true,
    editStrength: 'strong'
  }),
  'ideogram-ai/ideogram-v2-turbo': imageModel(0.025),
  'ideogram-ai/ideogram-v2a': imageModel(0.022),
  'ideogram-ai/ideogram-v2a-turbo': imageModel(0.018),
  'bytedance/seedream-5-lite': imageModel(0.038, {
    supportsEdit: true,
    supportsImageInput: true,
    supportsReferenceImage: true,
    editStrength: 'strong'
  }),
  'bytedance/seedream-4.5': imageModel(0.034, {
    supportsEdit: true,
    supportsImageInput: true,
    editStrength: 'strong'
  }),
  'stability-ai/stable-diffusion-3.5-large': imageModel(0.030),
  'stability-ai/stable-diffusion-3.5-large-turbo': imageModel(0.020),
  'stability-ai/stable-diffusion-3.5-medium': imageModel(0.018),
  'qwen/qwen-image-2': imageModel(0.032, {
    supportsEdit: true,
    supportsImageInput: true,
    editStrength: 'strong'
  }),
  'xai/grok-imagine-image': imageModel(0.045),
  'minimax/image-01': imageModel(0.038, {
    supportsImageInput: true,
    supportsReferenceImage: true,
    editStrength: 'reference'
  }),
  'luma/photon-flash': imageModel(0.020),
  'leonardoai/lucid-origin': imageModel(0.035),
  'prunaai/p-image': imageModel(0.015),
  'prunaai/z-image-turbo': imageModel(0.018),
  'prunaai/hidream-l1-fast': imageModel(0.018),
  'bria/fibo': imageModel(0.030),
  'lucataco/ssd-1b': imageModel(0.015),
  'lucataco/realistic-vision-v5.1': imageModel(0.016),
  'jagilley/controlnet-scribble': imageModel(0.020, {
    supportsEdit: true,
    supportsImageInput: true,
    editStrength: 'control'
  }),
  'google/veo-3-fast': videoModel(0.45),
  'google/veo-3': videoModel(0.75),
  'google/veo-3.1-fast': videoModel(0.55),
  'google/veo-3.1': videoModel(0.85, {
    supportsImageInput: true,
    supportsReferenceImage: true,
    videoMode: 'i2v'
  }),
  'google/veo-2': videoModel(0.60),
  'lightricks/ltx-2.3-fast': videoModel(0.28, {
    supportsAudioInput: true,
    supportsImageInput: true,
    videoMode: 'i2v+audio'
  }),
  'lightricks/ltx-2.3-pro': videoModel(0.45, {
    supportsAudioInput: true,
    supportsImageInput: true,
    videoMode: 'i2v+audio'
  }),
  'pixverse-ai/pixverse-v5': videoModel(0.35),
  'kwaivgi/kling-v2.6': videoModel(0.75, {
    supportsImageInput: true,
    videoMode: 'i2v'
  }),
  'kwaivgi/kling-v1.6-standard': videoModel(0.40),
  'kwaivgi/kling-v2.1': videoModel(0.55, {
    supportsImageInput: true,
    videoMode: 'i2v'
  }),
  'wan-video/wan-2.5-t2v': videoModel(0.28),
  'wan-video/wan-2.5-i2v': videoModel(0.32, {
    supportsImageInput: true,
    videoMode: 'i2v'
  }),
  'wan-video/wan-2.5-i2v-fast': videoModel(0.24, {
    supportsImageInput: true,
    videoMode: 'i2v'
  }),
  'wavespeedai/wan-2.1-t2v-480p': videoModel(0.20),
  'luma/ray-2-540p': videoModel(0.30),
  'luma/ray-2-720p': videoModel(0.42),
  'minimax/video-01': videoModel(0.36),
  'luma/reframe-video': videoModel(0.18, {
    supportsEdit: true
  }),
  'minimax/speech-2.8-turbo': audioModel(0.030),
  'minimax/speech-2.8-hd': audioModel(0.050),
  'qwen/qwen3-tts': audioModel(0.028),
  'elevenlabs/turbo-v2.5': audioModel(0.040),
  'elevenlabs/flash-v2.5': audioModel(0.030),
  'stability-ai/stable-audio-2.5': audioModel(0.050),
  'minimax/music-1.5': audioModel(0.060),
  'elevenlabs/v2-multilingual': audioModel(0.040),
  'elevenlabs/v3': audioModel(0.050),
  'minimax/voice-cloning': audioModel(0.055, {
    supportsAudioInput: true
  }),
};

const MEMORY_SCOPE = 'global';
const MEMORY_SCOPE_COMPAT = ['work', 'personal', 'study', 'global', 'shared'];
const MEMORY_VERSION = 'memory-v14-locked-architecture';
const MEMORY_SCHEMA_VERSION = 10;
const MEMORY_CHECKPOINT_RETENTION_MS = 48 * 60 * 60 * 1000;
const MEMORY_CANDIDATE_PROMOTED_CLEANUP_MS = 3 * 24 * 60 * 60 * 1000;
const MEMORY_DEBUG_LOG_LIMIT = 40;
const MEMORY_DEBUG_PREVIEW_LIMIT = 12;
const MEMORY_SESSION_GAP_MS = 12 * 60 * 60 * 1000;
const MEMORY_EVENT_EVIDENCE_CAP = 5;
const MEMORY_NODE_EVENT_PREVIEW_CAP = 20;
const MEMORY_REVIEW_EXPIRY_DAYS = 30;
const MEMORY_GROUPS = new Set(['identity', 'role', 'project', 'skill', 'goal', 'interest', 'personal', 'preference']);
const MEMORY_CONNECTION_TYPES = new Set([
  'part_of', 'uses', 'depends_on', 'drives', 'supports', 'improves', 'related_to',
  'IS_A', 'BUILDS', 'USES', 'HAS', 'PURSUING', 'RELATED', 'COMPARES', 'LEARNED', 'PREFERS', 'CONTEXT'
]);
const MEMORY_BIDIRECTIONAL_TYPES = new Set(['related_to', 'RELATED', 'COMPARES', 'CONTEXT']);
const MEMORY_BOOTSTRAP_MAX_ENTRIES_PER_RUN = 24;
const MEMORY_BOOTSTRAP_MAX_ANALYZE_ENTRIES = 24;
const MEMORY_BOOTSTRAP_MAX_IMPORT_TEXT_CHARS = 24000;
const MEMORY_BOOTSTRAP_MAX_INCREMENT_WRITES = 24;
const MEMORY_BOOTSTRAP_MAX_NODE_CREATES = 32;
const MEMORY_BOOTSTRAP_MAX_CONNECTION_CREATES = 64;
const MEMORY_SYNTHETIC_IMPORT_MAX_ENTRIES_PER_RUN = 24;

const MEMORY_JOB_DOCS = ['consolidation', 'index_sync', 'health_transition'];
const MEMORY_CONSOLIDATION_NODE_AUTO_THRESHOLD = 0.92;
const MEMORY_CONSOLIDATION_NODE_PENDING_THRESHOLD = 0.78;
const MEMORY_CONSOLIDATION_EVENT_AUTO_THRESHOLD = 0.88;
const MEMORY_CONSOLIDATION_EVENT_PENDING_THRESHOLD = 0.72;
const MEMORY_CONSOLIDATION_MAX_NODE_PAIRS = 40;
const MEMORY_CONSOLIDATION_MAX_EVENT_PAIRS = 60;
const MEMORY_QUEUE_PREVIEW_LIMIT = 25;

const MEMORY_SESSION_COUNTED_TOPIC_CAP = 24;
const MEMORY_SESSION_EVENT_PREVIEW_CAP = 8;
// SURGICAL PATCH: Raised from 2 â†’ 5. Architecture says "one counted topic per session"
// but lifecycle events (started â†’ paused â†’ resumed â†’ completed in one burst) must not be
// silently capped at 2. We still skip creating duplicate same-action events via matchingEvent
// lookup, so this cap now protects against pathological spam, not normal lifecycle flow.
const MEMORY_EVENT_PER_SESSION_NODE_CAP = 5;


const MEMORY_RECALL_ENTRY_NODE_CAP = 5;
const MEMORY_RECALL_NODE_CANDIDATE_CAP = 8;
const MEMORY_RECALL_EVENT_CANDIDATE_CAP = 10;
const MEMORY_RECALL_LIGHT_EVENT_CAP = 2;
const MEMORY_RECALL_DEEP_EVENT_CAP = 3;
const MEMORY_RECALL_LIGHT_NODE_CAP = 3;
const MEMORY_RECALL_DEEP_NODE_CAP = 5;
const MEMORY_RECALL_MAX_NOTE_CHARS = 1200;
const MEMORY_RECALL_DEEP_CUES = ['remember', 'before', 'previous', 'previously', 'last time', 'history', 'earlier', 'what did we', 'did we', 'planned', 'decided', 'continue', 'again', 'still', 'update', 'since'];
const MEMORY_RECALL_UPDATE_CUES = ['still', 'update', 'now', 'anymore', 'fixed', 'resolved', 'healed', 'after that', 'since then', 'progress'];
const MEMORY_EXTRACTION_IDLE_MS_DEFAULT = 10 * 60 * 1000;
const MEMORY_EXTRACTION_LONG_ACTIVE_MS_DEFAULT = 30 * 60 * 1000;
const MEMORY_EXTRACTION_OVERFLOW_MSGS_DEFAULT = 14;
const MEMORY_EXTRACTION_OVERFLOW_CHARS_DEFAULT = 2600;
const MEMORY_EXTRACTION_COOLDOWN_MS_DEFAULT = 5 * 60 * 1000;
const MEMORY_EXTRACTION_MIN_MEANINGFUL_CHARS_DEFAULT = 140;
const MEMORY_EXTRACTION_MIN_USER_MESSAGES_DEFAULT = 1;
const MEMORY_EXTRACTION_BRIDGE_MESSAGE_COUNT = 4;
const MEMORY_EXTRACTION_SUMMARY_MAX_PER_TURN = 3;
const MEMORY_EXTRACTION_PACKET_PREVIEW_CHARS = 900;
// V3.3.1 HOTFIX â€” Subrequest budget guard for free-plan Cloudflare Workers.
// Cloudflare free plan limit: ~50 subrequests per invocation.
// The learning path was burning ~40 in debug/trace writes before core writes could run.
const MEMORY_LEARNING_SUBREQUEST_BUDGET = 30;  // target total for debug/trace layer
const MEMORY_LEARNING_BUDGET_SOFT_STOP = 25;    // suppress optional debug above this
const MEMORY_LEARNING_BUDGET_EMERGENCY = 28;    // emergency: only lock release + job status
const MEMORY_LEARNING_BUDGET_CRITICAL_STAGES = new Set([
  'learning_job_finished', 'learning_job_failed', 'learning_lock_released'
]);

// V3.3.2 HOTFIX â€” Firestore quota-safe mode.
// This keeps the working memory engine intact while preventing graph/debug/admin
// endpoints and optional polish work from burning the Firestore free quota.
const MEMORY_QUOTA_SAFE_MODE = true;
const MEMORY_GRAPH_NODE_LIMIT = 50;
const MEMORY_GRAPH_EDGE_LIMIT = 80;
const MEMORY_GRAPH_EVENT_LIMIT = 30;
const MEMORY_GRAPH_SESSION_LIMIT = 10;
const MEMORY_CANDIDATE_LOAD_LIMIT = 30;
const MEMORY_DEBUG_LOG_LOAD_LIMIT = 20;
const MEMORY_JOB_LOG_LIMIT = 20;
const MEMORY_NODE_SLICE_LOAD_LIMIT = 10;
const MEMORY_FINAL_STATUS_AUDIT_LIMIT = 20;
const MEMORY_FINAL_STATUS_QUEUE_LIMIT = 20;
const MEMORY_PASS2_DEFER_IN_QUOTA_SAFE = true;
const MEMORY_SKIP_META_REFRESH_IN_QUOTA_SAFE = true;
const MEMORY_SKIP_FULL_INDEX_SYNC_IN_QUOTA_SAFE = true;
const MEMORY_STOPWORDS = new Set(['the','a','an','and','or','but','if','then','than','to','of','for','on','in','at','by','with','from','is','are','was','were','be','been','being','it','this','that','these','those','i','me','my','we','our','you','your','he','she','they','them','their','what','why','how','when','where','which','who','do','did','does','done','have','has','had','can','could','should','would','will','shall','am','bro']);
const MEMORY_CANDIDATE_PER_SLICE_CAP = 2;
const MEMORY_ALLOWED_CLUSTERS = new Set(['work', 'learning', 'health', 'sports', 'finance', 'relationships', 'personal', 'general']);
const MEMORY_BLOCKED_CANDIDATE_KEYS = new Set([
  // Assistant / chat meta junk
  'assistant', 'ai assistant', 'ai', 'bot', 'chatbot', 'claude', 'chatgpt', 'gpt', 'llm', 'model',
  // Conversation meta
  'chat', 'conversation', 'dialogue', 'thread', 'session', 'talk', 'discussion', 'exchange',
  // Memory meta (should never become memory itself)
  'memory', 'memory object', 'memories', 'knowledge', 'context', 'note', 'notes', 'data', 'info', 'information',
  // UI / title junk
  'chat title', 'app title', 'app name', 'title', 'name', 'label', 'category',
  // Message meta
  'message', 'reply', 'response', 'question', 'answer', 'query', 'request', 'prompt',
  // Vague placeholders
  'topic', 'subject', 'thing', 'stuff', 'something', 'anything', 'nothing', 'anyway', 'somehow',
  // User-to-assistant vocatives
  'user', 'person', 'human', 'bro', 'dude', 'guy', 'friend', 'buddy', 'mate', 'pal',
  // Pure greetings (should never be nodes)
  'hello', 'hi', 'hey', 'greeting', 'goodbye', 'bye', 'thanks', 'thank you', 'welcome',
  // Generic help phrases
  'help', 'support', 'issue', 'problem', 'feedback', 'general'
]);
const MEMORY_BLOCKED_CANDIDATE_REGEX = /^(hi+|hello+|hey+|yo|ok|okay|kk|hmm+|huh|lol+|lmao|haha+|nice|cool|great|awesome|thanks|thank you|ty|thx|wyd|bro|dude|bruh|alright|fine|sure|yep|yup|yeah|yea|nope|nah|no|yes|same|true|exactly|right|got it|gotcha|i see|understood|sounds good|will do|on it|idk|idc|omg|wtf|fr|ong|fyi|btw|tbh|imo|ikr|wdym)$/i;

function buildMemoryThreadKey(threadId, sourceTag = 'chat') {
  const raw = String(threadId || '').trim();
  if (raw) return normalizeMemoryKey(raw).slice(0, 100) || `thread_${Date.now()}`;
  return `source_${normalizeMemoryKey(sourceTag || 'chat') || 'chat'}`;
}


// V3.1.5: utility/model-helper calls must not pollute the real memory log or trigger learning.
function isUtilityMemorySourceTag(sourceTag = '') {
  const src = String(sourceTag || '').trim().toLowerCase();
  return src === 'utility' || src.startsWith('utility:') || src.includes('auto_title') || src.includes('rewrite') || src.includes('title_generation');
}

function sanitizeMemoryJobPart(value = '', max = 80) {
  return String(value || '').replace(/[^a-zA-Z0-9_\-]/g, '_').slice(0, max) || 'x';
}

function buildMemoryLearningJobId(threadKey = '', userMsgId = '', nowMs = Date.now()) {
  const msgPart = sanitizeMemoryJobPart(userMsgId || threadKey, 90);
  return `mlj_${nowMs}_${msgPart}_${Math.random().toString(36).slice(2, 7)}`;
}

function parseFirebaseServiceAccountFromEnv(env) {
  const raw = env?.FIREBASE_SERVICE_ACCOUNT_JSON || env?.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) throw new Error('firebase service account env missing');
  return typeof raw === 'string' ? JSON.parse(raw) : raw;
}

function buildMemorySessionId(threadKey, startedAt = Date.now()) {
  return `sess_${threadKey}_${startedAt}`.replace(/[^a-zA-Z0-9_:-]/g, '_');
}

function buildMemoryEventId(sessionId, primaryNodeId = 'root', startedAt = Date.now()) {
  return `evt_${sessionId}_${String(primaryNodeId || 'root').slice(-40)}_${startedAt}`.replace(/[^a-zA-Z0-9_:-]/g, '_');
}

function buildNodeIndexDocId(nodeId) {
  return `idx_${String(nodeId || '').replace(/[^a-zA-Z0-9_:-]/g, '_')}`;
}

function buildEventIndexDocId(eventId) {
  return `idx_${String(eventId || '').replace(/[^a-zA-Z0-9_:-]/g, '_')}`;
}

function buildLegacyMergeAuditId(kind, primaryId, secondaryId) {
  return `audit_${kind}_${String(primaryId || '').slice(-24)}_${String(secondaryId || '').slice(-24)}_${Date.now()}`.replace(/[^a-zA-Z0-9_:-]/g, '_');
}

function safeIsoDateFromMs(ms) {
  const ts = num(ms, 0) || Date.now();
  return new Date(ts).toISOString().slice(0, 10);
}

function computeMemoryTierFromTimestamps(lastTouchedAt, importanceClass = 'ordinary', nowMs = Date.now()) {
  if (String(importanceClass || '').toLowerCase() === 'life_significant') return 'permanent';
  const ageMs = Math.max(0, nowMs - num(lastTouchedAt, nowMs));
  const days = ageMs / (24 * 60 * 60 * 1000);
  if (days <= 30) return 'hot';
  if (days <= 180) return 'warm';
  return 'cold';
}

function buildEventRetentionScore(item, nowMs = Date.now()) {
  const confidence = Math.max(0, Math.min(1, num(item?.confidence, 0.7)));
  const role = String(item?.roleInEvent || 'supporting_proof');
  const roleWeight = role === 'primary_proof' ? 1.0 : role === 'status_update' ? 0.92 : role === 'time_anchor' ? 0.88 : 0.8;
  const ageMs = Math.max(0, nowMs - num(item?.timestamp, nowMs));
  const recencyFactor = Math.max(0.45, 1 - (ageMs / (180 * 24 * 60 * 60 * 1000)));
  return Number((confidence * roleWeight * recencyFactor).toFixed(4));
}

function buildEventEvidenceItem({
  snippet,
  sourceType = 'user_message',
  messageId = '',
  timestamp = Date.now(),
  confidence = 0.82,
  roleInEvent = 'supporting_proof'
} = {}) {
  const cleanSnippet = trimMemoryText(snippet, 260);
  if (!cleanSnippet) return null;
  const item = {
    snippet: cleanSnippet,
    sourceType: trimMemoryText(sourceType, 40) || 'user_message',
    messageId: trimMemoryText(messageId, 80),
    timestamp: num(timestamp, Date.now()),
    confidence: Math.max(0, Math.min(1, num(confidence, 0.82))),
    roleInEvent: trimMemoryText(roleInEvent, 40) || 'supporting_proof'
  };
  item.retentionScore = buildEventRetentionScore(item, item.timestamp);
  return item;
}

function capEventEvidence(evidence, maxItems = MEMORY_EVENT_EVIDENCE_CAP) {
  const seen = new Set();
  const items = [];
  for (const raw of Array.isArray(evidence) ? evidence : []) {
    const item = buildEventEvidenceItem(raw || {});
    if (!item) continue;
    const key = `${normalizeMemoryKey(item.snippet)}|${item.sourceType}|${item.roleInEvent}`;
    if (!key || seen.has(key)) continue;
    seen.add(key);
    items.push(item);
  }
  items.sort((a, b) => num(b.retentionScore, 0) - num(a.retentionScore, 0) || num(b.timestamp, 0) - num(a.timestamp, 0));
  return items.slice(0, Math.max(1, maxItems));
}

function boundedUniqueIds(items, cap = MEMORY_NODE_EVENT_PREVIEW_CAP) {
  const out = [];
  const seen = new Set();
  for (const item of Array.isArray(items) ? items : []) {
    const clean = String(item || '').trim();
    if (!clean || seen.has(clean)) continue;
    seen.add(clean);
    out.push(clean);
    if (out.length >= cap) break;
  }
  return out;
}

function pickPrimaryNodeId(nodeIds) {
  const ids = boundedUniqueIds(nodeIds || [], 1);
  return ids[0] || 'root';
}

function summarizeLearnedLabels(learned) {
  return memoryProdSummarizeLearnedLabels(learned);
}

function buildConversationEventSummary(payload, learned, primaryLabel = '') {
  const userText = trimMemoryText(getLastUserMessageText(payload?.messages || []), 180);
  const labels = summarizeLearnedLabels(learned);
  if (primaryLabel && userText) return `${primaryLabel}: ${userText}`.slice(0, 220);
  if (labels.length && userText) return `${labels.join(', ')} â€” ${userText}`.slice(0, 220);
  if (labels.length) return `User discussed ${labels.join(', ')}`.slice(0, 220);
  if (userText) return userText.slice(0, 220);
  return 'Conversation memory event';
}

function eventTypeForGroup(group) {
  const g = String(group || '').toLowerCase();
  if (g === 'project') return 'project_progress';
  if (g === 'goal') return 'goal_update';
  if (g === 'skill') return 'learning_update';
  if (g === 'preference') return 'preference_update';
  if (g === 'personal') return 'personal_update';
  return 'conversation_memory_update';
}

function buildSessionTopicKeys(learned) {
  return memoryProdBuildSessionTopicKeys(learned);
}

function mergeEvidenceForEvent(existingEvidence, incomingEvidence, maxItems = MEMORY_EVENT_EVIDENCE_CAP) {
  return capEventEvidence([...(Array.isArray(existingEvidence) ? existingEvidence : []), ...(Array.isArray(incomingEvidence) ? incomingEvidence : [])], maxItems);
}

function eventUpdateSummary(existingSummary, payload, learned, primaryLabel = '') {
  const next = buildConversationEventSummary(payload, learned, primaryLabel);
  const prev = trimMemoryText(existingSummary, 220);
  if (!prev) return next;
  if (!next) return prev;
  if (normalizeMemoryKey(prev) == normalizeMemoryKey(next)) return prev;
  const userText = trimMemoryText(getLastUserMessageText(payload?.messages || []), 120);
  return trimMemoryText(`${prev} | update: ${userText || next}`, 220);
}

async function patchMemoryUserMeta(accessToken, projectId, uid, patch = {}) {
  const cleanPatch = {};
  for (const [k, v] of Object.entries(patch || {})) {
    if (v !== undefined) cleanPatch[k] = v;
  }
  if (!Object.keys(cleanPatch).length) return;
  await fsPatchDoc(accessToken, projectId, `users/${uid}`, cleanPatch);
}

async function listMemoryEvents(accessToken, projectId, uid) {
  const docs = await fsListDocs(accessToken, projectId, `users/${uid}/memoryEvents`);
  return docs.map((doc) => ({
    ...parseFirestoreFields(doc.fields || {}),
    id: parseFirestoreFields(doc.fields || {}).id || docIdFromFsDoc(doc)
  }));
}

async function listMemorySessions(accessToken, projectId, uid) {
  const docs = await fsListDocs(accessToken, projectId, `users/${uid}/memorySessions`);
  return docs.map((doc) => ({
    ...parseFirestoreFields(doc.fields || {}),
    id: parseFirestoreFields(doc.fields || {}).id || docIdFromFsDoc(doc)
  }));
}

async function listMemoryDebugLogs(accessToken, projectId, uid) {
  const docs = await fsListDocs(accessToken, projectId, `users/${uid}/memoryDebugLogs`);
  return docs.map((doc) => ({
    ...parseFirestoreFields(doc.fields || {}),
    id: parseFirestoreFields(doc.fields || {}).id || docIdFromFsDoc(doc)
  }));
}


// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// V3.3.1 HOTFIX â€” Per-job subrequest budget tracker
// The budget object is created once per runMemoryLearningJob invocation and
// stored in the module-level _activeLearningBudget slot. The queue consumer
// processes jobs serially so this is safe. All optional debug/trace writes
// check the budget; non-critical stages are buffered in memory and flushed as
// one compact summary doc at the end of the job.
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
function createLearningBudget() {
  return {
    target: MEMORY_LEARNING_SUBREQUEST_BUDGET,
    spent: 0,
    exceeded: false,
    debugBudgetExceeded: false,
    optionalDebugSuppressed: false,
    optionalWorkDeferred: false,
    checkpointAdvanced: false,
    failedRequiredWrites: [],
    stages: [],          // buffered non-critical stage snapshots
    spend(n = 1) {
      this.spent += n;
      if (this.spent >= this.target) { this.exceeded = true; this.debugBudgetExceeded = true; }
    },
    canOptionalWrite() { return this.spent < MEMORY_LEARNING_BUDGET_SOFT_STOP && !this.exceeded; },
    isEmergency() { return this.spent >= MEMORY_LEARNING_BUDGET_EMERGENCY || this.exceeded; },
    bufferStage(stage, data = {}) {
      try {
        this.stages.push({ stage, ts: Date.now(), status: data.status || '', decision: data.decision || '', reason: data.reason || '', note: data.note || '' });
        if (this.stages.length > 60) this.stages.shift(); // cap buffer
      } catch (_) {}
    },
    summary() {
      return {
        subrequestBudgetTarget: this.target,
        subrequestBudgetUsedEstimate: this.spent,
        debugBudgetExceeded: this.debugBudgetExceeded,
        optionalDebugSuppressed: this.optionalDebugSuppressed,
        optionalWorkDeferred: this.optionalWorkDeferred,
        checkpointAdvanced: this.checkpointAdvanced,
        failedRequiredWrites: this.failedRequiredWrites.slice(0, 10),
        bufferedStageCount: this.stages.length
      };
    }
  };
}

// Module-level slot â€” reset at start of each runMemoryLearningJob.
let _activeLearningBudget = null;
function _startLearningBudget() { _activeLearningBudget = createLearningBudget(); return _activeLearningBudget; }
function _getActiveBudget() { return _activeLearningBudget; }
function _clearLearningBudget() { _activeLearningBudget = null; }

// One compact summary doc written at end of the job, replacing many per-stage docs.
async function flushLearningBudgetSummary(accessToken, projectId, uid, budget, extra = {}) {
  if (!budget || !accessToken || !projectId || !uid) return;
  try {
    const nowMs = Date.now();
    const summaryId = `lrn_summary_${nowMs}_${Math.random().toString(36).slice(2, 7)}`;
    const doc = {
      id: summaryId,
      createdAt: nowMs,
      updatedAt: nowMs,
      kind: 'learning_budget_summary',
      uid: trimMemoryText(uid || '', 140),
      ...budget.summary(),
      bufferedStages: budget.stages.slice(0, 60),
      jobId: trimMemoryText(extra.jobId || '', 180),
      sessionId: trimMemoryText(extra.sessionId || '', 160),
      threadId: trimMemoryText(extra.threadId || '', 140),
      resultOk: !!extra.resultOk,
      reason: trimMemoryText(extra.reason || '', 100),
      error: trimMemoryText(extra.error || '', 300),
      processedMessages: num(extra.processedMessages, 0),
      candidateCount: num(extra.candidateCount, 0),
      sliceCount: num(extra.sliceCount, 0),
      eventCount: num(extra.eventCount, 0),
      schemaVersion: MEMORY_SCHEMA_VERSION
    };
    await fsUpsertDoc(accessToken, projectId, `users/${uid}/memoryDebugLogs/${summaryId}`, doc);
  } catch (e) {
    try { console.log(`[learning_budget_summary_flush_failed]: ${String(e?.message || e)}`); } catch (_) {}
  }
}

// V3.1.2 learning hotfix: minimal robust trace writer for learning pipeline heartbeats.
async function writeMemoryLearningTrace(accessToken, projectId, uid, payload = {}) {
  const nowMs = num(payload?.nowMs, Date.now());
  const stage = trimMemoryText(payload?.stage || 'learning_trace', 80);
  const safeStage = stage.replace(/[^a-z0-9_\-]/gi, '_').slice(0, 40) || 'trace';
  const traceId = `learn_${nowMs}_${safeStage}_${Math.random().toString(36).slice(2, 7)}`;
  const doc = {
    id: traceId,
    createdAt: nowMs,
    updatedAt: nowMs,
    kind: 'learning_trace',
    stage,
    status: trimMemoryText(payload?.status || 'observed', 40),
    uid: trimMemoryText(uid || '', 140),
    sourceTag: trimMemoryText(payload?.sourceTag || 'chat', 50),
    threadId: trimMemoryText(payload?.threadId || '', 140),
    threadKey: trimMemoryText(payload?.threadKey || '', 120),
    sessionId: trimMemoryText(payload?.sessionId || '', 160),
    userMsgId: trimMemoryText(payload?.userMsgId || '', 180),
    assistantMsgId: trimMemoryText(payload?.assistantMsgId || '', 180),
    triggerReason: trimMemoryText(payload?.triggerReason || '', 100),
    error: trimMemoryText(payload?.error || '', 500),
    note: trimMemoryText(payload?.note || '', 500),
    rowsProcessed: num(payload?.rowsProcessed, 0),
    rowsLoaded: num(payload?.rowsLoaded, payload?.rowsProcessed || 0),
    sliceMessages: num(payload?.sliceMessages, 0),
    userRows: num(payload?.userRows, 0),
    assistantRows: num(payload?.assistantRows, 0),
    firstMsgId: trimMemoryText(payload?.firstMsgId || '', 180),
    lastMsgId: trimMemoryText(payload?.lastMsgId || '', 180),
    sliceChars: num(payload?.sliceChars, 0),
    failedStep: trimMemoryText(payload?.failedStep || '', 120),
    decision: trimMemoryText(payload?.decision || '', 80),
    checkpointAdvanced: !!payload?.checkpointAdvanced,
    resultOk: payload?.resultOk === undefined ? false : !!payload?.resultOk,
    schemaVersion: MEMORY_SCHEMA_VERSION
  };
  // V3.3.1 HOTFIX â€” Budget guard. Non-critical stages are buffered in memory
  // instead of being written to Firestore. Critical stages always attempt a write.
  const _budget = _getActiveBudget();
  if (_budget) {
    const isCritical = MEMORY_LEARNING_BUDGET_CRITICAL_STAGES.has(stage);
    if (!isCritical) {
      // Buffer instead of write; mark suppressed if we're over soft limit.
      _budget.bufferStage(stage, { status: payload?.status, decision: payload?.decision, note: payload?.note, error: payload?.error });
      if (!_budget.canOptionalWrite()) _budget.optionalDebugSuppressed = true;
      return doc;
    }
    // Critical stage â€” attempt write and count it.
    _budget.spend(1);
    if (_budget.checkpointAdvanced === false && stage === 'checkpoint_advanced') _budget.checkpointAdvanced = true;
  }
  try {
    await fsUpsertDoc(accessToken, projectId, `users/${uid}/memoryDebugLogs/${traceId}`, doc);
  } catch (e) {
    if (_budget) { _budget.debugBudgetExceeded = true; _budget.optionalDebugSuppressed = true; }
    const msg = String(e?.message || e);
    if (msg.includes('Too many subrequests')) {
      if (_budget) _budget.exceeded = true;
      try { console.log(`[memory_learning_trace_budget_exceeded] ${stage}`); } catch (_) {}
    } else {
      try { console.log(`[memory_learning_trace_failed] ${stage}: ${msg}`); } catch (_) {}
    }
  }
  return doc;
}

async function writeMemoryDebugLog(accessToken, projectId, uid, payload = {}) {
  const nowMs = num(payload?.nowMs, Date.now());
  const logId = `dbg_${nowMs}_${Math.random().toString(36).slice(2, 8)}`;
  const eventList = Array.isArray(payload?.eventDocs)
    ? payload.eventDocs.slice(0, 8).map((eventDoc) => ({
        id: trimMemoryText(eventDoc?.id || '', 160),
        summary: trimMemoryText(eventDoc?.summary || '', 180),
        eventType: trimMemoryText(eventDoc?.eventType || '', 60),
        lifecycleAction: trimMemoryText(eventDoc?.lifecycleAction || '', 40),
        status: trimMemoryText(eventDoc?.status || '', 40),
        connectedNodeIds: boundedUniqueIds(eventDoc?.connectedNodeIds || [], 8),
        evidencePreview: Array.isArray(eventDoc?.evidence) ? eventDoc.evidence.slice(0, 2).map((item) => trimMemoryText(item?.snippet || '', 120)).filter(Boolean) : [],
        evidenceCount: Array.isArray(eventDoc?.evidence) ? eventDoc.evidence.length : 0,
        updatedAt: num(eventDoc?.updatedAt || eventDoc?.createdAt, 0)
      }))
    : [];
  const primaryEvent = eventList[0] || null;
  const debugDoc = {
    id: logId,
    createdAt: nowMs,
    updatedAt: nowMs,
    sourceTag: trimMemoryText(payload?.sourceTag || 'chat', 40),
    threadId: trimMemoryText(payload?.threadId || '', 120),
    sessionId: trimMemoryText(payload?.sessionId || '', 160),
    checkpoint: {
      lastProcessedAt: num(payload?.lastProcessedAt, nowMs),
      note: trimMemoryText(payload?.checkpointNote || 'processed latest slice', 120)
    },
    // v2 message-log observability: cursor-based checkpoint, log/thread info.
    // Written whenever processConversationMemoryTurn emits a debug log, so
    // operators can see honestly whether the backend log was used, the cursor
    // advanced, how many messages were processed, and where bridge came from.
    messageLog: payload?.messageLog ? {
      threadKey: trimMemoryText(payload.messageLog.threadKey || '', 100),
      useBackendLog: !!payload.messageLog.useBackendLog,
      source: trimMemoryText(payload.messageLog.source || '', 120),
      cursorPriorMsgId: trimMemoryText(payload.messageLog.cursorPriorMsgId || '', 160),
      cursorNewestMsgId: trimMemoryText(payload.messageLog.cursorNewestMsgId || '', 160),
      cursorAdvanced: !!payload.messageLog.cursorAdvanced,
      rowsProcessed: num(payload.messageLog.rowsProcessed, 0),
      bridgeMsgsFromLog: num(payload.messageLog.bridgeMsgsFromLog, 0)
    } : null,
    trigger: payload?.trigger ? {
      reason: trimMemoryText(payload?.trigger?.reason || '', 80),
      highSignal: !!payload?.trigger?.highSignal,
      manual: !!payload?.trigger?.manual,
      metrics: payload?.trigger?.metrics || null
    } : null,
    packetPreview: trimMemoryText(payload?.packetPreview || '', MEMORY_EXTRACTION_PACKET_PREVIEW_CHARS),
    extraction: {
      status: trimMemoryText(payload?.extractionStatus || payload?.trigger?.reason || (eventList.length ? 'processed' : 'observed'), 60),
      error: trimMemoryText(payload?.learned?.extractionError || payload?.extractionError || '', 220),
      incrementNodes: Array.isArray(payload?.learned?.reinforce_labels) ? payload.learned.reinforce_labels.slice(0, 12) : [],
      newNodes: Array.isArray(payload?.learned?.candidates)
        ? payload.learned.candidates.slice(0, 12).map((x) => ({
            label: trimMemoryText(x?.label || '', 80),
            roleGuess: trimMemoryText(x?.roleGuess || '', 40),
            strength: trimMemoryText(x?.strength || '', 20),
            clusterHint: trimMemoryText(x?.clusterHint || '', 40),
            parentHint: trimMemoryText(x?.parentHint || '', 80),
            eventWorthy: !!x?.eventHint?.worthy,
            action: trimMemoryText(x?.eventHint?.action || '', 40)
          }))
        : [],
      reinforceLabels: Array.isArray(payload?.learned?.reinforce_labels) ? payload.learned.reinforce_labels.slice(0, 12) : [],
      candidates: Array.isArray(payload?.learned?.candidates)
        ? payload.learned.candidates.slice(0, 12).map((x) => ({
            label: trimMemoryText(x?.label || '', 80),
            roleGuess: trimMemoryText(x?.roleGuess || '', 40),
            strength: trimMemoryText(x?.strength || '', 20),
            parentHint: trimMemoryText(x?.parentHint || '', 80),
            clusterHint: trimMemoryText(x?.clusterHint || '', 40),
            eventWorthy: !!x?.eventHint?.worthy,
            action: trimMemoryText(x?.eventHint?.action || '', 40)
          }))
        : [],
      relationHints: Array.isArray(payload?.learned?.relation_hints)
        ? payload.learned.relation_hints.slice(0, 12).map((x) => ({
            from: trimMemoryText(x?.from || '', 80),
            to: trimMemoryText(x?.to || '', 80),
            type: trimMemoryText(x?.type || '', 40)
          }))
        : []
    },
    promotion: {
      candidateCreated: Array.isArray(payload?.candidateCreated) ? payload.candidateCreated.slice(0, 12) : [],
      candidatePromoted: Array.isArray(payload?.candidatePromoted) ? payload.candidatePromoted.slice(0, 12) : [],
      reinforcedNodes: Array.isArray(payload?.reinforcedNodes) ? payload.reinforcedNodes.slice(0, 12) : [],
      skipped: Array.isArray(payload?.skippedItems) ? payload.skippedItems.slice(0, 12) : []
    },
    event: primaryEvent,
    eventList,
    structure: {
      placedNodes: Array.isArray(payload?.placedNodes) ? payload.placedNodes.slice(0, 12) : []
    },
    connection: {
      createdOrUpdated: Array.isArray(payload?.connectionResults) ? payload.connectionResults.slice(0, 16) : []
    },
    counts: {
      reinforceCount: Array.isArray(payload?.learned?.reinforce_labels) ? payload.learned.reinforce_labels.length : 0,
      candidateCount: Array.isArray(payload?.learned?.candidates) ? payload.learned.candidates.length : 0,
      relationHintCount: Array.isArray(payload?.learned?.relation_hints) ? payload.learned.relation_hints.length : 0,
      createdEventCount: eventList.length
    },
    schemaVersion: MEMORY_SCHEMA_VERSION
  };
  // V3.3.1 HOTFIX â€” writeMemoryDebugLog is always optional (per-stage detail).
  // When a learning budget is active, buffer stage name and skip the Firestore write.
  const _budget = _getActiveBudget();
  if (_budget) {
    const stage = trimMemoryText(payload?.stage || debugDoc.stage || 'debug_log', 80);
    _budget.bufferStage(stage, { decision: payload?.decision, reason: trimMemoryText(payload?.reason || '', 120), error: trimMemoryText(payload?.error || '', 120) });
    if (!_budget.canOptionalWrite()) { _budget.optionalDebugSuppressed = true; return debugDoc; }
    // Under soft limit: count the spend but still write.
    _budget.spend(1);
  }
  try {
    await fsUpsertDoc(accessToken, projectId, `users/${uid}/memoryDebugLogs/${logId}`, debugDoc);
  } catch (e) {
    if (_budget) { _budget.debugBudgetExceeded = true; _budget.optionalDebugSuppressed = true; }
    const msg = String(e?.message || e);
    if (msg.includes('Too many subrequests') && _budget) _budget.exceeded = true;
    try { console.log(`[writeMemoryDebugLog_failed] ${msg.slice(0, 120)}`); } catch (_) {}
  }
  return debugDoc;
}

function buildClusterSummaryFromNodes(nodes = []) {
  const distribution = {};
  for (const node of Array.isArray(nodes) ? nodes : []) {
    if (!node || node.deleted || node.isRoot) continue;
    const clusterId = trimMemoryText(node.clusterId || inferClusterIdForNode(node.label, node.group, node.info) || 'general', 40) || 'general';
    distribution[clusterId] = (distribution[clusterId] || 0) + 1;
  }
  const ordered = Object.entries(distribution)
    .sort((a, b) => b[1] - a[1])
    .map(([clusterId, count]) => ({ clusterId, count }));
  return {
    total: ordered.length,
    distribution,
    preview: ordered.slice(0, 8)
  };
}

function buildLatestPipelineFromLogs(logs = []) {
  // SURGICAL PATCH D2: Richer latest-pipeline summary so the admin monitor shows
  // "what just happened" at a glance without drilling into raw logs:
  //  - primary event preview (summary + lifecycle + evidence snippet)
  //  - connection created vs skipped counts
  //  - extraction error surfacing
  //  - candidate skip count
  const latest = Array.isArray(logs) && logs.length ? logs[0] : null;
  if (!latest) {
    return {
      hasLog: false,
      status: 'idle',
      extractionStatus: 'idle',
      triggerReason: '',
      processedAt: 0,
      lastRunAt: 0,
      highSignal: false,
      candidateCreated: 0,
      promoted: 0,
      reinforced: 0,
      skippedCandidates: 0,
      eventCount: 0,
      connectionCount: 0,
      connectionSkipped: 0,
      extractionError: '',
      primaryEvent: null
    };
  }
  const eventList = Array.isArray(latest?.eventList) ? latest.eventList : [];
  const eventCount = eventList.length || (latest?.event ? 1 : 0);
  const connectionResults = Array.isArray(latest?.connection?.createdOrUpdated) ? latest.connection.createdOrUpdated : [];
  const connectionCount = connectionResults.filter((x) => {
    const st = String(x?.state || '').toLowerCase();
    return st.startsWith('created') || st.startsWith('reinforced');
  }).length;
  const connectionSkipped = connectionResults.filter((x) => {
    const st = String(x?.state || '').toLowerCase();
    return st.startsWith('skip') || String(x?.type || '').toLowerCase() === 'skipped';
  }).length;
  const primaryEventDoc = latest?.event || eventList[0] || null;
  const primaryEvent = primaryEventDoc ? {
    id: trimMemoryText(primaryEventDoc.id || '', 160),
    summary: trimMemoryText(primaryEventDoc.summary || '', 180),
    eventType: trimMemoryText(primaryEventDoc.eventType || '', 60),
    lifecycleAction: trimMemoryText(primaryEventDoc.lifecycleAction || '', 40),
    status: trimMemoryText(primaryEventDoc.status || '', 40),
    evidencePreview: Array.isArray(primaryEventDoc.evidencePreview) ? primaryEventDoc.evidencePreview.slice(0, 2) : [],
    evidenceCount: num(primaryEventDoc.evidenceCount, Array.isArray(primaryEventDoc.evidence) ? primaryEventDoc.evidence.length : 0)
  } : null;
  return {
    hasLog: true,
    status: trimMemoryText(latest?.extraction?.status || latest?.checkpoint?.note || 'processed', 60),
    extractionStatus: trimMemoryText(latest?.extraction?.status || 'processed', 60),
    extractionError: trimMemoryText(latest?.extraction?.error || '', 220),
    triggerReason: trimMemoryText(latest?.trigger?.reason || '', 80),
    processedAt: num(latest?.updatedAt || latest?.createdAt, 0),
    lastRunAt: num(latest?.createdAt, 0),
    highSignal: !!latest?.trigger?.highSignal,
    candidateCreated: Array.isArray(latest?.promotion?.candidateCreated) ? latest.promotion.candidateCreated.length : 0,
    promoted: Array.isArray(latest?.promotion?.candidatePromoted) ? latest.promotion.candidatePromoted.length : 0,
    reinforced: Array.isArray(latest?.promotion?.reinforcedNodes) ? latest.promotion.reinforcedNodes.length : 0,
    skippedCandidates: Array.isArray(latest?.promotion?.skipped) ? latest.promotion.skipped.length : 0,
    eventCount,
    connectionCount,
    connectionSkipped,
    primaryEvent
  };
}


async function getMemoryDebugStatusPayload(accessToken, projectId, uid, cfg) {
  const quotaSafe = MEMORY_QUOTA_SAFE_MODE;
  const [userDoc, profile, nodes, connections, candidates, events, sessions, logs, statsDoc, jobLogs] = await Promise.all([
    fsGetDoc(accessToken, projectId, `users/${uid}`),
    readUnifiedMemoryProfile(accessToken, projectId, uid, cfg),
    quotaSafe ? listMemoryNodesCapped(accessToken, projectId, uid, MEMORY_GRAPH_NODE_LIMIT) : listMemoryNodes(accessToken, projectId, uid),
    quotaSafe ? listMemoryConnectionsCapped(accessToken, projectId, uid, MEMORY_GRAPH_EDGE_LIMIT) : listMemoryConnections(accessToken, projectId, uid),
    quotaSafe ? listMemoryCandidatesCapped(accessToken, projectId, uid, MEMORY_CANDIDATE_LOAD_LIMIT) : listMemoryCandidates(accessToken, projectId, uid),
    quotaSafe ? listMemoryEventsCapped(accessToken, projectId, uid, MEMORY_GRAPH_EVENT_LIMIT) : listMemoryEvents(accessToken, projectId, uid),
    quotaSafe ? listMemorySessionsCapped(accessToken, projectId, uid, MEMORY_GRAPH_SESSION_LIMIT) : listMemorySessions(accessToken, projectId, uid),
    quotaSafe ? listMemoryDebugLogsCapped(accessToken, projectId, uid, MEMORY_DEBUG_LOG_LOAD_LIMIT) : listMemoryDebugLogs(accessToken, projectId, uid),
    readMemoryStatsDoc(accessToken, projectId, uid),
    listMemoryLearningJobsCapped(accessToken, projectId, uid, MEMORY_JOB_LOG_LIMIT),
  ]);
  const user = parseFirestoreFields(userDoc?.fields || {});
  const activeNodes = nodes.filter((n) => !n.deleted);
  const activeConnections = connections.filter((c) => !c.deleted);
  const activeCandidates = candidates.filter((c) => !c.deleted && String(c.status || '').toLowerCase() !== 'promoted');
  const activeEvents = events.filter((e) => !e.deleted);
  const activeSessions = sessions.filter((s) => !s.deleted).sort((a, b) => num(b.lastActivityAt, 0) - num(a.lastActivityAt, 0));
  const recentLogs = logs.sort((a, b) => num(b.createdAt, 0) - num(a.createdAt, 0)).slice(0, quotaSafe ? MEMORY_DEBUG_LOG_LOAD_LIMIT : MEMORY_DEBUG_PREVIEW_LIMIT);
  const clusterSummary = buildClusterSummaryFromNodes(activeNodes);
  const latestPipeline = buildLatestPipelineFromLogs(recentLogs);
  const metaCounts = {
    nodeCount: memoryStatsCount(statsDoc, user, 'nodeCount', activeNodes.length),
    connectionCount: memoryStatsCount(statsDoc, user, 'connectionCount', activeConnections.length),
    candidateCount: memoryStatsCount(statsDoc, user, 'candidateCount', activeCandidates.length),
    eventCount: memoryStatsCount(statsDoc, user, 'eventCount', activeEvents.length),
    sessionCount: memoryStatsCount(statsDoc, user, 'sessionCount', activeSessions.length),
    autoLearnedCount: memoryStatsCount(statsDoc, user, 'autoLearnedCount', activeNodes.filter((n) => n.learned).length),
  };
  return {
    ok: true,
    uid,
    activeMode: MEMORY_SCOPE,
    quotaSafeMode: quotaSafe,
    limited: quotaSafe,
    limits: { nodes: MEMORY_GRAPH_NODE_LIMIT, connections: MEMORY_GRAPH_EDGE_LIMIT, candidates: MEMORY_CANDIDATE_LOAD_LIMIT, events: MEMORY_GRAPH_EVENT_LIMIT, sessions: MEMORY_GRAPH_SESSION_LIMIT, debugLogs: MEMORY_DEBUG_LOG_LOAD_LIMIT, learningJobs: MEMORY_JOB_LOG_LIMIT },
    profile: responseProfileForMode(profile, MEMORY_SCOPE),
    memoryMeta: {
      memoryEnabled: user.memoryEnabled !== false,
      memoryNodeCount: metaCounts.nodeCount,
      memoryConnectionCount: metaCounts.connectionCount,
      memoryCandidateCount: metaCounts.candidateCount,
      memoryEventCount: metaCounts.eventCount,
      memorySessionCount: metaCounts.sessionCount,
      memoryAutoLearnedCount: metaCounts.autoLearnedCount,
      memoryLastProcessedAt: num(user.memoryLastProcessedAt || statsDoc.lastLearningAt, 0),
      memoryLastDecayAt: num(user.memoryLastDecayAt, 0),
      memoryVersion: user.memoryVersion || MEMORY_VERSION,
      memorySchemaVersion: num(user.memorySchemaVersion, MEMORY_SCHEMA_VERSION)
    },
    stats: { nodes: metaCounts.nodeCount, connections: metaCounts.connectionCount, candidates: metaCounts.candidateCount, events: metaCounts.eventCount, sessions: metaCounts.sessionCount, debugLogs: recentLogs.length, learningJobs: jobLogs.length, clusters: clusterSummary.total, previewNodes: activeNodes.length, previewConnections: activeConnections.length, previewCandidates: activeCandidates.length, previewEvents: activeEvents.length },
    latestPipeline,
    clusterSummary,
    activeSessionPreview: activeSessions.slice(0, 5).map((s) => ({ id: s.id, threadKey: s.threadKey, threadId: s.threadId || '', sourceTag: s.sourceTag, startedAt: s.startedAt, lastActivityAt: s.lastActivityAt, turnCount: num(s.turnCount, 0), messageCount: num(s.messageCount, 0), lastProcessedMessageCount: num(s.lastProcessedMessageCount, 0), lastProcessedAt: num(s.lastProcessedAt, 0), lastProcessedMsgId: trimMemoryText(s.lastProcessedMsgId || '', 160), lastProcessedMsgIdPrev: trimMemoryText(s.lastProcessedMsgIdPrev || '', 160), checkpointExpiresAt: num(s.checkpointExpiresAt, 0), pendingSinceAt: num(s.pendingSinceAt, 0), pendingSliceMessageCount: num(s.pendingSliceMessageCount, 0), status: s.status || 'active' })),
    candidatePreview: activeCandidates.slice(0, 10).map((c) => ({ id: c.id, label: c.label || '', strength: c.strength || '', status: c.status || 'candidate', mentionCount: num(c.mentionCount, 0), expiresAt: num(c.expiresAt, 0), updatedAt: num(c.updatedAt || c.lastSeenAt || c.createdAt, 0) })),
    recentEvents: activeEvents.sort((a, b) => num(b.updatedAt || b.createdAt, 0) - num(a.updatedAt || a.createdAt, 0)).slice(0, 8).map((e) => ({ id: e.id, summary: e.summary || '', eventType: e.eventType || 'general', importanceClass: e.importanceClass || 'ordinary', memoryTier: e.memoryTier || computeMemoryTierFromTimestamps(e.updatedAt || e.createdAt || Date.now(), e.importanceClass), updatedAt: num(e.updatedAt || e.createdAt, 0) })),
    recentLogs,
    recentLearningJobs: jobLogs.slice(0, 8).map((j) => ({ id: j.id, status: j.status || '', resultOk: !!j.resultOk, triggerReason: j.triggerReason || '', updatedAt: num(j.updatedAt || j.createdAt, 0), error: trimMemoryText(j.error || '', 160) }))
  };
}

async function listMemoryThreads(accessToken, projectId, uid) {
  const docs = await fsListDocs(accessToken, projectId, `users/${uid}/memoryThreads`);
  return docs.map((doc) => ({
    ...parseFirestoreFields(doc.fields || {}),
    id: parseFirestoreFields(doc.fields || {}).id || docIdFromFsDoc(doc)
  }));
}

async function listJobStateDocs(accessToken, projectId, uid) {
  const docs = await fsListDocs(accessToken, projectId, `users/${uid}/jobState`);
  return docs.map((doc) => ({
    ...parseFirestoreFields(doc.fields || {}),
    id: parseFirestoreFields(doc.fields || {}).id || docIdFromFsDoc(doc)
  }));
}

async function listNodeIndexDocs(accessToken, projectId, uid) {
  const docs = await fsListDocs(accessToken, projectId, `users/${uid}/nodeIndex`);
  return docs.map((doc) => ({
    ...parseFirestoreFields(doc.fields || {}),
    id: parseFirestoreFields(doc.fields || {}).id || docIdFromFsDoc(doc)
  })).filter((doc) => !doc.deleted);
}

async function listEventIndexDocs(accessToken, projectId, uid) {
  const docs = await fsListDocs(accessToken, projectId, `users/${uid}/eventIndex`);
  return docs.map((doc) => ({
    ...parseFirestoreFields(doc.fields || {}),
    id: parseFirestoreFields(doc.fields || {}).id || docIdFromFsDoc(doc)
  })).filter((doc) => !doc.deleted);
}

async function syncNodeIndexDoc(accessToken, projectId, uid, node) {
  if (!node || node.deleted) return null;
  const docId = buildNodeIndexDocId(node.id || node.nodeId || '');
  if (!docId) return null;
  const payload = {
    id: docId,
    nodeId: node.id,
    label: trimMemoryText(node.label || '', 120),
    aliases: boundedUniqueIds(node.aliases || [], 12),
    type: trimMemoryText(node.group || 'interest', 40),
    clusterId: trimMemoryText(node.group || 'interest', 40),
    heat: num(node.heat, 0),
    healthState: node.deleted ? 'deleted' : (num(node.heat, 0) >= 45 ? 'active' : num(node.heat, 0) >= 20 ? 'weak' : 'dormant'),
    confidence: Math.max(0.35, Math.min(0.99, num(node.learned ? 0.82 : 0.92, 0.82))),
    eventCount: num(node.eventCount, 0),
    lastEventAt: num(node.lastEventAt, 0),
    updatedAt: Date.now(),
    deleted: false,
    schemaVersion: MEMORY_SCHEMA_VERSION
  };
  await fsUpsertDoc(accessToken, projectId, `users/${uid}/nodeIndex/${docId}`, payload);
  return payload;
}

async function syncMemoryNodeIndexes(accessToken, projectId, uid, nodes) {
  const safeNodes = Array.isArray(nodes) ? nodes : [];
  const writes = [];
  for (const node of safeNodes) {
    if (!node || node.deleted) continue;
    const docId = buildNodeIndexDocId(node.id || node.nodeId || '');
    if (!docId) continue;
    writes.push(makeFirestoreUpdateWrite(projectId, `users/${uid}/nodeIndex/${docId}`, {
      id: docId,
      nodeId: node.id,
      label: trimMemoryText(node.label || '', 120),
      aliases: boundedUniqueIds(node.aliases || [], 12),
      type: trimMemoryText(node.group || 'interest', 40),
      clusterId: trimMemoryText(node.clusterId || inferClusterIdForNode(node.label, node.group, node.info) || 'general', 40),
      heat: num(node.heat, 0),
      healthState: node.deleted ? 'deleted' : (num(node.heat, 0) >= 45 ? 'active' : num(node.heat, 0) >= 20 ? 'weak' : 'dormant'),
      confidence: Math.max(0.35, Math.min(0.99, num(node.learned ? 0.82 : 0.92, 0.82))),
      eventCount: num(node.eventCount, 0),
      lastEventAt: num(node.lastEventAt, 0),
      importanceClass: trimMemoryText(node.importanceClass || inferImportanceForLabel(node.label, node.group, node.info), 40),
      updatedAt: Date.now(),
      deleted: false,
      schemaVersion: MEMORY_SCHEMA_VERSION
    }));
  }
  if (writes.length) await fsCommitWritesInChunks(accessToken, projectId, writes, 250);
}

async function syncEventIndexDoc(accessToken, projectId, uid, eventDoc) {
  if (!eventDoc || eventDoc.deleted) return null;
  const docId = buildEventIndexDocId(eventDoc.id || eventDoc.eventId || '');
  if (!docId) return null;
  const payload = {
    id: docId,
    eventId: eventDoc.id || eventDoc.eventId,
    primaryNodeId: eventDoc.primaryNodeId || 'root',
    connectedNodeIds: boundedUniqueIds(eventDoc.connectedNodeIds || [], 5),
    absoluteDate: eventDoc.absoluteDate || safeIsoDateFromMs(eventDoc.startAt || Date.now()),
    importanceClass: trimMemoryText(eventDoc.importanceClass || 'ordinary', 40),
    memoryTier: trimMemoryText(eventDoc.memoryTier || computeMemoryTierFromTimestamps(eventDoc.updatedAt || eventDoc.createdAt || Date.now(), eventDoc.importanceClass), 40),
    status: trimMemoryText(eventDoc.status || 'recorded', 40),
    valence: trimMemoryText(eventDoc.valence || 'neutral', 40),
    eventType: trimMemoryText(eventDoc.eventType || 'conversation_memory_update', 60),
    summary: trimMemoryText(eventDoc.summary || '', 120),
    confidence: Math.max(0, Math.min(1, num(eventDoc.confidence, 0.8))),
    clusterIds: boundedUniqueIds([eventDoc.resolvedClusterId || '', ...(Array.isArray(eventDoc.facets) ? eventDoc.facets : []), ...(Array.isArray(eventDoc.clusterIds) ? eventDoc.clusterIds : [])], 4),
    facets: boundedUniqueIds(Array.isArray(eventDoc.facets) && eventDoc.facets.length ? eventDoc.facets : [eventDoc.resolvedClusterId || 'general'], 4),
    createdAt: num(eventDoc.createdAt, Date.now()),
    updatedAt: num(eventDoc.updatedAt, Date.now()),
    deleted: false,
    schemaVersion: MEMORY_SCHEMA_VERSION
  };
  await fsUpsertDoc(accessToken, projectId, `users/${uid}/eventIndex/${docId}`, payload);
  return payload;
}

async function updateNodeEventPreview(accessToken, projectId, uid, node, eventDoc) {
  if (!node || !eventDoc || node.deleted) return;
  const previewIds = boundedUniqueIds([eventDoc.id || eventDoc.eventId, ...(Array.isArray(node.linkedEventIds) ? node.linkedEventIds : [])], MEMORY_NODE_EVENT_PREVIEW_CAP);
  await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${node.id}`, {
    linkedEventIds: previewIds,
    eventCount: Math.max(num(node.eventCount, 0) + 1, previewIds.length),
    lastEventAt: num(eventDoc.updatedAt || eventDoc.createdAt, Date.now())
  });
  node.linkedEventIds = previewIds;
  node.eventCount = Math.max(num(node.eventCount, 0) + 1, previewIds.length);
  node.lastEventAt = num(eventDoc.updatedAt || eventDoc.createdAt, Date.now());
}

async function createOrReuseMemorySession(accessToken, projectId, uid, cfg, payload = {}) {
  return memoryProdCreateOrReuseMemorySession(accessToken, projectId, uid, cfg, payload);
}

function classifyEventImportance(learned, connectedNodes = []) {
  const strong = (Array.isArray(learned?.new_nodes) ? learned.new_nodes : []).some((item) => String(item?.strength || '').toLowerCase() === 'strong');
  const importantGroup = connectedNodes.some((node) => ['project', 'goal', 'role', 'preference', 'skill'].includes(String(node?.group || '').toLowerCase()));
  if (strong || importantGroup) return 'important';
  return 'ordinary';
}

async function createOrUpdateConversationMemoryEvent(accessToken, projectId, uid, cfg, payload = {}) {
  return memoryProdCreateOrUpdateConversationMemoryEvent(accessToken, projectId, uid, cfg, payload);
}

async function syncMemoryOperationalDocs(accessToken, projectId, uid) {
  for (const jobName of MEMORY_JOB_DOCS) {
    await fsUpsertDoc(accessToken, projectId, `users/${uid}/jobState/${jobName}`, {
      id: jobName,
      jobName,
      status: 'idle',
      lastRunAt: 0,
      lastSuccessAt: 0,
      currentCursor: '',
      errorCount: 0,
      lockedBy: '',
      lockedAt: 0,
      updatedAt: Date.now(),
      schemaVersion: MEMORY_SCHEMA_VERSION
    });
  }
}


async function listConsolidationQueueDocs(accessToken, projectId, uid) {
  const docs = await fsListDocs(accessToken, projectId, `users/${uid}/consolidationQueue`);
  return docs.map((doc) => ({
    ...parseFirestoreFields(doc.fields || {}),
    id: parseFirestoreFields(doc.fields || {}).id || docIdFromFsDoc(doc)
  }));
}

async function listMergeAuditDocs(accessToken, projectId, uid) {
  const docs = await fsListDocs(accessToken, projectId, `users/${uid}/mergeAudit`);
  return docs.map((doc) => ({
    ...parseFirestoreFields(doc.fields || {}),
    id: parseFirestoreFields(doc.fields || {}).id || docIdFromFsDoc(doc)
  }));
}

function buildConsolidationQueueId(itemType, primaryId, secondaryId) {
  const a = trimMemoryText(primaryId || '', 120).replace(/[^a-zA-Z0-9_:-]/g, '_');
  const b = trimMemoryText(secondaryId || '', 120).replace(/[^a-zA-Z0-9_:-]/g, '_');
  return `cq_${itemType}_${a}_${b}`;
}

function buildMergeAuditId(kind, primaryId, secondaryId, nowMs) {
  const a = trimMemoryText(primaryId || '', 120).replace(/[^a-zA-Z0-9_:-]/g, '_');
  const b = trimMemoryText(secondaryId || '', 120).replace(/[^a-zA-Z0-9_:-]/g, '_');
  return `ma_${kind}_${a}_${b}_${nowMs}`;
}

function tokenizeForSimilarity(value) {
  return new Set(String(value || '').toLowerCase().replace(/[^a-z0-9\s_-]/g, ' ').split(/\s+/).filter(Boolean));
}

function jaccardSimilarity(a, b) {
  const sa = tokenizeForSimilarity(a);
  const sb = tokenizeForSimilarity(b);
  if (!sa.size || !sb.size) return 0;
  let inter = 0;
  for (const t of sa) if (sb.has(t)) inter += 1;
  const union = new Set([...sa, ...sb]).size;
  return union ? inter / union : 0;
}

function scoreNodeMergeCandidate(a, b) {
  if (!a || !b) return 0;
  if (a.id === b.id) return 0;
  if (String(a.group || '') !== String(b.group || '')) return 0;
  const keyA = normalizeMemoryKey(a.normalizedKey || a.label || '');
  const keyB = normalizeMemoryKey(b.normalizedKey || b.label || '');
  const exact = keyA && keyA === keyB ? 1 : 0;
  const aliasA = [a.label, ...(Array.isArray(a.aliases) ? a.aliases : [])].join(' ');
  const aliasB = [b.label, ...(Array.isArray(b.aliases) ? b.aliases : [])].join(' ');
  const aliasScore = jaccardSimilarity(aliasA, aliasB);
  const edgeA = tokenizeForSimilarity([a.parentId || '', ...(Array.isArray(a.linkedEventIds) ? a.linkedEventIds : [])].join(' '));
  const edgeB = tokenizeForSimilarity([b.parentId || '', ...(Array.isArray(b.linkedEventIds) ? b.linkedEventIds : [])].join(' '));
  let edgeInter = 0;
  for (const t of edgeA) if (edgeB.has(t)) edgeInter += 1;
  const edgeUnion = new Set([...edgeA, ...edgeB]).size || 1;
  const edgeScore = edgeInter / edgeUnion;
  return (exact * 0.55) + (aliasScore * 0.3) + (edgeScore * 0.15);
}

function scoreEventMergeCandidate(a, b) {
  if (!a || !b) return 0;
  if (a.id === b.id) return 0;
  if (String(a.primaryNodeId || '') !== String(b.primaryNodeId || '')) return 0;
  if (String(a.eventType || '') !== String(b.eventType || '')) return 0;
  if (String(a.valence || 'neutral') !== String(b.valence || 'neutral')) return 0;
  if (String(a.recurrenceType || 'one_time') === 'recurring' || String(b.recurrenceType || 'one_time') === 'recurring') return 0;
  const dayA = safeIsoDateFromMs(a.startAt || a.createdAt || Date.now());
  const dayB = safeIsoDateFromMs(b.startAt || b.createdAt || Date.now());
  const diffMs = Math.abs(num(a.startAt || a.createdAt, 0) - num(b.startAt || b.createdAt, 0));
  const dateScore = dayA === dayB ? 1 : diffMs <= 7 * 24 * 60 * 60 * 1000 ? 0.72 : diffMs <= 30 * 24 * 60 * 60 * 1000 ? 0.32 : 0;
  if (!dateScore) return 0;
  const summaryScore = jaccardSimilarity(a.summary || '', b.summary || '');
  const nodeOverlap = jaccardSimilarity((a.connectedNodeIds || []).join(' '), (b.connectedNodeIds || []).join(' '));
  return (dateScore * 0.45) + (summaryScore * 0.35) + (nodeOverlap * 0.2);
}

async function writeConsolidationQueueEntry(accessToken, projectId, uid, entry) {
  const nowMs = num(entry?.nowMs, Date.now());
  const id = entry.id || buildConsolidationQueueId(entry.itemType || 'item', entry.primaryId || '', entry.secondaryId || '');
  const doc = {
    id,
    itemType: trimMemoryText(entry.itemType || 'item', 40),
    candidateIds: boundedUniqueIds(entry.candidateIds || [entry.primaryId, entry.secondaryId], 4),
    similarityScore: Math.max(0, Math.min(1, num(entry.similarityScore, 0))),
    reason: trimMemoryText(entry.reason || '', 180),
    outcome: trimMemoryText(entry.outcome || 'pending', 40),
    reviewExpiresAt: num(entry.reviewExpiresAt, nowMs + MEMORY_REVIEW_EXPIRY_DAYS * 24 * 60 * 60 * 1000),
    createdAt: num(entry.createdAt, nowMs),
    processedAt: num(entry.processedAt, 0),
    schemaVersion: MEMORY_SCHEMA_VERSION,
    updatedAt: nowMs
  };
  await fsUpsertDoc(accessToken, projectId, `users/${uid}/consolidationQueue/${id}`, doc);
  return doc;
}

async function writeMergeAudit(accessToken, projectId, uid, entry) {
  const nowMs = Date.now();
  const id = entry.id || buildMergeAuditId(entry.mergeType || 'item', entry.primaryId || '', entry.secondaryId || '', nowMs);
  const doc = {
    id,
    mergeType: trimMemoryText(entry.mergeType || 'item', 40),
    primaryId: trimMemoryText(entry.primaryId || '', 160),
    secondaryId: trimMemoryText(entry.secondaryId || '', 160),
    secondarySnapshot: entry.secondarySnapshot || {},
    mergedAt: num(entry.mergedAt, nowMs),
    mergedBy: trimMemoryText(entry.mergedBy || 'phase5_consolidation_job', 120),
    canRollback: entry.canRollback !== false,
    schemaVersion: MEMORY_SCHEMA_VERSION
  };
  await fsCreateDoc(accessToken, projectId, `users/${uid}/mergeAudit/${id}`, doc).catch(async () => {
    await fsUpsertDoc(accessToken, projectId, `users/${uid}/mergeAudit/${id}`, doc);
  });
  return doc;
}

async function markNodeSoftMerged(accessToken, projectId, uid, primaryNode, secondaryNode, nowMs) {
  await writeMergeAudit(accessToken, projectId, uid, {
    mergeType: 'node',
    primaryId: primaryNode.id,
    secondaryId: secondaryNode.id,
    secondarySnapshot: secondaryNode,
    mergedAt: nowMs,
    mergedBy: 'phase5_consolidation_job'
  });
  const mergedEventIds = boundedUniqueIds([...(Array.isArray(primaryNode.linkedEventIds) ? primaryNode.linkedEventIds : []), ...(Array.isArray(secondaryNode.linkedEventIds) ? secondaryNode.linkedEventIds : [])], MEMORY_NODE_EVENT_PREVIEW_CAP);
  await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${primaryNode.id}`, {
    aliases: boundedUniqueIds([...(Array.isArray(primaryNode.aliases) ? primaryNode.aliases : []), secondaryNode.label, ...(Array.isArray(secondaryNode.aliases) ? secondaryNode.aliases : [])], 20),
    linkedEventIds: mergedEventIds,
    eventCount: Math.max(num(primaryNode.eventCount, 0), 0) + Math.max(num(secondaryNode.eventCount, 0), 0),
    heat: Math.max(num(primaryNode.heat, 0), num(secondaryNode.heat, 0)),
    updatedAt: nowMs,
    schemaVersion: MEMORY_SCHEMA_VERSION
  });
  await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${secondaryNode.id}`, {
    deleted: true,
    deletedAt: nowMs,
    healthState: 'merged',
    mergedIntoNodeId: primaryNode.id,
    schemaVersion: MEMORY_SCHEMA_VERSION
  });
  await syncNodeIndexDoc(accessToken, projectId, uid, { ...primaryNode, linkedEventIds: mergedEventIds, eventCount: Math.max(num(primaryNode.eventCount, 0), 0) + Math.max(num(secondaryNode.eventCount, 0), 0), heat: Math.max(num(primaryNode.heat, 0), num(secondaryNode.heat, 0)) });
  await fsUpsertDoc(accessToken, projectId, `users/${uid}/nodeIndex/${buildNodeIndexDocId(secondaryNode.id)}`, {
    id: buildNodeIndexDocId(secondaryNode.id), nodeId: secondaryNode.id, label: secondaryNode.label || '', deleted: true, updatedAt: nowMs, schemaVersion: MEMORY_SCHEMA_VERSION
  });
}

async function markEventSoftMerged(accessToken, projectId, uid, primaryEvent, secondaryEvent, nowMs, cfg) {
  await writeMergeAudit(accessToken, projectId, uid, {
    mergeType: 'event',
    primaryId: primaryEvent.id,
    secondaryId: secondaryEvent.id,
    secondarySnapshot: secondaryEvent,
    mergedAt: nowMs,
    mergedBy: 'phase5_consolidation_job'
  });
  const mergedEvidence = mergeEvidenceForEvent(primaryEvent.evidence || [], secondaryEvent.evidence || [], Math.max(1, num(cfg?.memoryEventEvidenceCap, MEMORY_EVENT_EVIDENCE_CAP)));
  await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryEvents/${primaryEvent.id}`, {
    evidence: mergedEvidence,
    connectedNodeIds: boundedUniqueIds([...(Array.isArray(primaryEvent.connectedNodeIds) ? primaryEvent.connectedNodeIds : []), ...(Array.isArray(secondaryEvent.connectedNodeIds) ? secondaryEvent.connectedNodeIds : [])], 8),
    mergedFromEventIds: boundedUniqueIds([...(Array.isArray(primaryEvent.mergedFromEventIds) ? primaryEvent.mergedFromEventIds : []), secondaryEvent.id], 20),
    sourceSessionCount: Math.max(1, num(primaryEvent.sourceSessionCount, 1)) + Math.max(1, num(secondaryEvent.sourceSessionCount, 1)),
    confidence: Math.max(num(primaryEvent.confidence, 0.7), num(secondaryEvent.confidence, 0.7)),
    updatedAt: nowMs,
    schemaVersion: MEMORY_SCHEMA_VERSION
  });
  await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryEvents/${secondaryEvent.id}`, {
    deleted: true,
    deletedAt: nowMs,
    status: 'merged',
    mergedIntoEventId: primaryEvent.id,
    schemaVersion: MEMORY_SCHEMA_VERSION
  });
  await syncEventIndexDoc(accessToken, projectId, uid, { ...primaryEvent, evidence: mergedEvidence, mergedFromEventIds: boundedUniqueIds([...(Array.isArray(primaryEvent.mergedFromEventIds) ? primaryEvent.mergedFromEventIds : []), secondaryEvent.id], 20), sourceSessionCount: Math.max(1, num(primaryEvent.sourceSessionCount, 1)) + Math.max(1, num(secondaryEvent.sourceSessionCount, 1)), updatedAt: nowMs });
  await fsUpsertDoc(accessToken, projectId, `users/${uid}/eventIndex/${buildEventIndexDocId(secondaryEvent.id)}`, {
    id: buildEventIndexDocId(secondaryEvent.id), eventId: secondaryEvent.id, deleted: true, updatedAt: nowMs, schemaVersion: MEMORY_SCHEMA_VERSION
  });
}

async function runMemoryConsolidation(accessToken, projectId, uid, cfg, options = {}) {
  const nowMs = Date.now();
  const dryRun = options.dryRun !== false;
  const jobName = 'consolidation';
  await fsPatchDoc(accessToken, projectId, `users/${uid}/jobState/${jobName}`, {
    status: dryRun ? 'dry_run' : 'running',
    lastRunAt: nowMs,
    updatedAt: nowMs,
    schemaVersion: MEMORY_SCHEMA_VERSION
  }).catch(() => null);

  const [nodes, events, queueDocs] = await Promise.all([
    listMemoryNodes(accessToken, projectId, uid),
    listMemoryEvents(accessToken, projectId, uid),
    listConsolidationQueueDocs(accessToken, projectId, uid)
  ]);

  const queueKeySet = new Set(queueDocs.map((q) => `${q.itemType}:${(q.candidateIds || []).join(':')}`));
  let nodePairsScanned = 0;
  let eventPairsScanned = 0;
  let autoMergedNodes = 0;
  let autoMergedEvents = 0;
  let queuedReviews = 0;

  const eligibleNodes = nodes.filter((n) => !n.deleted && !n.isRoot && String(n.importanceClass || 'ordinary') !== 'life_significant');
  for (let i = 0; i < eligibleNodes.length && nodePairsScanned < MEMORY_CONSOLIDATION_MAX_NODE_PAIRS; i++) {
    for (let j = i + 1; j < eligibleNodes.length && nodePairsScanned < MEMORY_CONSOLIDATION_MAX_NODE_PAIRS; j++) {
      const a = eligibleNodes[i];
      const b = eligibleNodes[j];
      const score = scoreNodeMergeCandidate(a, b);
      if (score < num(cfg?.memoryConsolidationNodePendingThreshold, MEMORY_CONSOLIDATION_NODE_PENDING_THRESHOLD)) continue;
      nodePairsScanned += 1;
      const ordered = [a.id, b.id].sort();
      const qKey = `node:${ordered.join(':')}`;
      if (queueKeySet.has(qKey)) continue;
      const outcome = score >= num(cfg?.memoryConsolidationNodeAutoThreshold, MEMORY_CONSOLIDATION_NODE_AUTO_THRESHOLD) ? 'auto_merge' : 'pendingReview';
      await writeConsolidationQueueEntry(accessToken, projectId, uid, {
        itemType: 'node',
        primaryId: ordered[0],
        secondaryId: ordered[1],
        candidateIds: ordered,
        similarityScore: score,
        reason: `node_similarity:${score.toFixed(2)}`,
        outcome,
        reviewExpiresAt: nowMs + MEMORY_REVIEW_EXPIRY_DAYS * 24 * 60 * 60 * 1000,
        processedAt: outcome === 'auto_merge' && !dryRun ? nowMs : 0
      });
      if (outcome === 'auto_merge') {
        if (!dryRun) {
          const primary = num(a.count, 0) >= num(b.count, 0) ? a : b;
          const secondary = primary.id === a.id ? b : a;
          await markNodeSoftMerged(accessToken, projectId, uid, primary, secondary, nowMs);
        }
        autoMergedNodes += 1;
      } else {
        queuedReviews += 1;
      }
    }
  }

  const eligibleEvents = events.filter((e) => !e.deleted && String(e.status || '') !== 'merged');
  for (let i = 0; i < eligibleEvents.length && eventPairsScanned < MEMORY_CONSOLIDATION_MAX_EVENT_PAIRS; i++) {
    for (let j = i + 1; j < eligibleEvents.length && eventPairsScanned < MEMORY_CONSOLIDATION_MAX_EVENT_PAIRS; j++) {
      const a = eligibleEvents[i];
      const b = eligibleEvents[j];
      const score = scoreEventMergeCandidate(a, b);
      if (score < num(cfg?.memoryConsolidationEventPendingThreshold, MEMORY_CONSOLIDATION_EVENT_PENDING_THRESHOLD)) continue;
      eventPairsScanned += 1;
      const ordered = [a.id, b.id].sort();
      const qKey = `event:${ordered.join(':')}`;
      if (queueKeySet.has(qKey)) continue;
      const outcome = score >= num(cfg?.memoryConsolidationEventAutoThreshold, MEMORY_CONSOLIDATION_EVENT_AUTO_THRESHOLD) ? 'auto_merge' : 'pendingReview';
      await writeConsolidationQueueEntry(accessToken, projectId, uid, {
        itemType: 'event',
        primaryId: ordered[0],
        secondaryId: ordered[1],
        candidateIds: ordered,
        similarityScore: score,
        reason: `event_similarity:${score.toFixed(2)}`,
        outcome,
        reviewExpiresAt: nowMs + MEMORY_REVIEW_EXPIRY_DAYS * 24 * 60 * 60 * 1000,
        processedAt: outcome === 'auto_merge' && !dryRun ? nowMs : 0
      });
      if (outcome === 'auto_merge') {
        if (!dryRun) {
          const primary = num(a.confidence, 0.7) >= num(b.confidence, 0.7) ? a : b;
          const secondary = primary.id === a.id ? b : a;
          await markEventSoftMerged(accessToken, projectId, uid, primary, secondary, nowMs, cfg);
        }
        autoMergedEvents += 1;
      } else {
        queuedReviews += 1;
      }
    }
  }

  const refreshedQueue = await listConsolidationQueueDocs(accessToken, projectId, uid);
  for (const entry of refreshedQueue) {
    if (entry.outcome !== 'pendingReview') continue;
    if (num(entry.reviewExpiresAt, 0) && num(entry.reviewExpiresAt, 0) < nowMs) {
      await fsPatchDoc(accessToken, projectId, `users/${uid}/consolidationQueue/${entry.id}`, {
        outcome: 'keep_separate',
        processedAt: nowMs,
        updatedAt: nowMs,
        schemaVersion: MEMORY_SCHEMA_VERSION
      });
    }
  }

  await fsPatchDoc(accessToken, projectId, `users/${uid}/jobState/${jobName}`, {
    status: 'idle',
    lastRunAt: nowMs,
    lastSuccessAt: nowMs,
    updatedAt: nowMs,
    schemaVersion: MEMORY_SCHEMA_VERSION
  }).catch(() => null);

  await patchMemoryUserMeta(accessToken, projectId, uid, {
    memoryLastProcessedAt: nowMs,
    memoryVersion: MEMORY_VERSION,
    memorySchemaVersion: MEMORY_SCHEMA_VERSION
  });

  return {
    ok: true,
    uid,
    dryRun,
    job: jobName,
    nodePairsScanned,
    eventPairsScanned,
    autoMergedNodes,
    autoMergedEvents,
    queuedReviews,
    queuePreview: (await listConsolidationQueueDocs(accessToken, projectId, uid)).sort((a, b) => num(b.updatedAt, 0) - num(a.updatedAt, 0)).slice(0, MEMORY_QUEUE_PREVIEW_LIMIT),
    auditPreview: (await listMergeAuditDocs(accessToken, projectId, uid)).sort((a, b) => num(b.mergedAt, 0) - num(a.mergedAt, 0)).slice(0, MEMORY_QUEUE_PREVIEW_LIMIT)
  };
}

async function getMemoryConsolidationStatus(accessToken, projectId, uid) {
  const [queueDocs, auditDocs, jobDoc] = await Promise.all([
    listConsolidationQueueDocs(accessToken, projectId, uid),
    listMergeAuditDocs(accessToken, projectId, uid),
    fsGetDoc(accessToken, projectId, `users/${uid}/jobState/consolidation`)
  ]);
  const queue = queueDocs.sort((a, b) => num(b.updatedAt, 0) - num(a.updatedAt, 0));
  const audits = auditDocs.sort((a, b) => num(b.mergedAt, 0) - num(a.mergedAt, 0));
  return {
    ok: true,
    uid,
    jobState: parseFirestoreFields(jobDoc?.fields || {}),
    queueStats: {
      total: queue.length,
      pendingReview: queue.filter((item) => item.outcome === 'pendingReview').length,
      autoMerged: queue.filter((item) => item.outcome === 'auto_merge').length,
      keptSeparate: queue.filter((item) => item.outcome === 'keep_separate').length
    },
    queuePreview: queue.slice(0, MEMORY_QUEUE_PREVIEW_LIMIT),
    auditPreview: audits.slice(0, MEMORY_QUEUE_PREVIEW_LIMIT)
  };
}

function memoryProdNormalizeMemoryGroup(value) {
  const v = String(value || '').trim().toLowerCase();
  const mapped = ({ role: 'identity', personal: 'interest', study: 'skill', work: 'project' })[v] || v;
  return ['identity', 'goal', 'project', 'skill', 'habit', 'interest', 'preference', 'reserve'].includes(mapped) ? mapped : 'interest';
}

function memoryProdBuildExistingMemorySummary(nodes, _mode) {
  const visible = buildUnifiedMemoryView(nodes || [], []).nodes
    .sort((a, b) => num(b.count, 0) - num(a.count, 0))
    .slice(0, 60)
    .map((n) => ({
      id: trimMemoryText(n.id || '', 120),
      label: trimMemoryText(n.label || '', 80),
      group: trimMemoryText(n.group || 'interest', 24),
      cluster: trimMemoryText(n.clusterId || inferClusterIdForNode(n.label, n.group, n.info) || 'general', 24),
      state: trimMemoryText(n.currentState || 'unknown', 24),
      aliases: boundedUniqueIds(n.aliases || [], 6),
      count: num(n.count, 0),
      heat: num(n.heat, 0),
      summary: trimMemoryText(n.info || '', 120),
      parentId: trimMemoryText(n.parentId || '', 120)
    }));
  return JSON.stringify({ existing_nodes: visible });
}

function memoryProdSummarizeLearnedLabels(learned) {
  const labels = [];
  for (const raw of Array.isArray(learned?.reinforce_labels) ? learned.reinforce_labels : []) {
    const label = trimMemoryText(raw, 80);
    if (label) labels.push(label);
  }
  for (const item of Array.isArray(learned?.candidates) ? learned.candidates : []) {
    const label = trimMemoryText(item?.label || item?.canonicalLabel || '', 80);
    if (label) labels.push(label);
  }
  for (const item of Array.isArray(learned?.new_nodes) ? learned.new_nodes : []) {
    const label = trimMemoryText(item?.label, 80);
    if (label) labels.push(label);
  }
  for (const raw of Array.isArray(learned?.increment_nodes) ? learned.increment_nodes : []) {
    const label = trimMemoryText(raw, 80);
    if (label) labels.push(label);
  }
  return boundedUniqueIds(labels, 8);
}

function memoryProdBuildSessionTopicKeys(learned) {
  const raw = [];
  for (const label of memoryProdSummarizeLearnedLabels(learned)) {
    const key = normalizeMemoryKey(label);
    if (key) raw.push(key);
  }
  return boundedUniqueIds(raw, MEMORY_SESSION_COUNTED_TOPIC_CAP);
}

function memoryProdSimpleHash(value) {
  const raw = String(value || '');
  let hash = 0;
  for (let i = 0; i < raw.length; i++) hash = ((hash << 5) - hash) + raw.charCodeAt(i);
  return `h_${Math.abs(hash >>> 0).toString(36)}`;
}

function memoryProdBuildMessageSignature(message, index = 0) {
  const role = String(message?.role || 'user').toLowerCase();
  const content = trimMemoryText(typeof message?.content === 'string' ? message.content : String(message?.content || ''), 500);
  return `${index}:${role}:${memoryProdSimpleHash(content)}`;
}

// ============================================================================
// BACKEND-OWNED MESSAGE LOG (v2 spine)
// ----------------------------------------------------------------------------
// Production architecture: the worker OWNS the memory-relevant message history.
// Flutter sends only the current turn + a clientMsgId. The worker appends the
// message to Firestore and uses its own append-only log as the source of truth
// for checkpoints, bridge context, and the learning pipeline's unprocessed
// slice. This replaces the fragile "client messages.length" checkpoint that
// broke silently when Flutter sent only the current turn.
//
// Firestore layout:
//   users/{uid}/memoryThreads/{threadKey}                 -- thread metadata
//   users/{uid}/memoryThreads/{threadKey}/messages/{msgId} -- append-only log
//   users/{uid}/memoryThreadIdempotency/{threadKey__cmid} -- clientMsgId sentinel
//
// msgId is lexicographically sortable: `${paddedTs}_${rand}_${roleHint}`.
// Sorting by `id` ascending == sorting by wall-clock creation order. This lets
// us checkpoint with a single `lastProcessedMsgId` string cursor and fetch
// "messages after cursor" via a Firestore structured query.
// ============================================================================

const MEMORY_LOG_SCHEMA_VERSION = 1;
const MEMORY_LOG_MAX_FETCH_PER_QUERY = 300;
const MEMORY_LOG_BRIDGE_WINDOW_DEFAULT = 6;
const MEMORY_LOG_RECALL_CONTEXT_WINDOW = 8;
const MEMORY_LOG_IDEMPOTENCY_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const MEMORY_LOG_MAX_CONTENT_CHARS = 8000;
const MEMORY_LOG_ASSISTANT_DEDUPE_WINDOW_MS = 60 * 1000;

function memoryLogBuildMsgId(roleHint, nowMs = Date.now()) {
  const ts = String(nowMs).padStart(14, '0');
  const rand = Math.floor(Math.random() * 1e12).toString(36);
  const r = String(roleHint || 'msg').toLowerCase().replace(/[^a-z]/g, '').slice(0, 4) || 'msg';
  return `${ts}_${rand}_${r}`;
}

function memoryLogBuildIdempotencyDocId(threadKey, clientMsgId) {
  const tk = normalizeMemoryKey(String(threadKey || '')).slice(0, 80);
  const cmid = normalizeMemoryKey(String(clientMsgId || '')).slice(0, 120);
  return `${tk || 'nothread'}__${cmid || 'nocmid'}`;
}

function memoryLogToStandardMessages(logMessages) {
  return (Array.isArray(logMessages) ? logMessages : [])
    .map((m) => ({
      role: String(m?.role || 'user').toLowerCase(),
      content: typeof m?.content === 'string' ? m.content : String(m?.content || '')
    }))
    .filter((m) => m.content.trim().length > 0);
}

async function memoryLogCheckClientIdempotency(accessToken, projectId, uid, threadKey, clientMsgId) {
  if (!clientMsgId || !threadKey) return null;
  const docId = memoryLogBuildIdempotencyDocId(threadKey, clientMsgId);
  try {
    const doc = await fsGetDoc(accessToken, projectId, `users/${uid}/memoryThreadIdempotency/${docId}`);
    if (!doc || !doc.fields) return null;
    const parsed = parseFirestoreFields(doc.fields);
    const existingMsgId = trimMemoryText(parsed?.msgId || '', 160);
    if (!existingMsgId) return null;
    // Respect TTL on stamp; expired stamps are treated as absent.
    const expiresAt = num(parsed?.expiresAt, 0);
    if (expiresAt && Date.now() > expiresAt) return null;
    return { msgId: existingMsgId, stampedAt: num(parsed?.createdAt, 0) };
  } catch (_) { return null; }
}

async function memoryLogStampClientIdempotency(accessToken, projectId, uid, threadKey, clientMsgId, msgId, nowMs = Date.now()) {
  if (!clientMsgId || !threadKey || !msgId) return;
  const docId = memoryLogBuildIdempotencyDocId(threadKey, clientMsgId);
  try {
    await fsCreateOrPatchDoc(accessToken, projectId, `users/${uid}/memoryThreadIdempotency/${docId}`, {
      id: docId,
      threadKey,
      clientMsgId: trimMemoryText(String(clientMsgId), 200),
      msgId,
      uid,
      createdAt: nowMs,
      expiresAt: nowMs + MEMORY_LOG_IDEMPOTENCY_TTL_MS
    });
  } catch (_) { /* best effort */ }
}

async function memoryLogAppendMessage(accessToken, projectId, uid, params = {}) {
  const threadKey = String(params?.threadKey || '').trim();
  const role = String(params?.role || 'user').toLowerCase();
  const contentRaw = typeof params?.content === 'string' ? params.content : String(params?.content || '');
  const content = contentRaw.trim();
  if (!threadKey) return { ok: false, error: 'missing_threadKey' };
  if (!content) return { ok: false, error: 'empty_content' };
  if (!['user', 'assistant', 'system'].includes(role)) return { ok: false, error: 'invalid_role' };

  const nowMs = num(params?.nowMs, Date.now());
  const clientMsgId = trimMemoryText(String(params?.clientMsgId || ''), 200);

  // Dedupe user messages by clientMsgId.
  if (role === 'user' && clientMsgId) {
    const existing = await memoryLogCheckClientIdempotency(accessToken, projectId, uid, threadKey, clientMsgId);
    if (existing) {
      return { ok: true, deduped: true, msgId: existing.msgId, reason: 'clientMsgId_exists' };
    }
  }

  // Best-effort assistant dedupe: if the last assistant message in this thread
  // was appended within a short window AND has identical trimmed content, treat
  // the new write as a retry and skip. Not perfect, honestly a best-effort guard.
  if (role === 'assistant') {
    try {
      const recent = await memoryLogListRecentMessages(accessToken, projectId, uid, threadKey, 2);
      for (const prev of recent.reverse()) {
        if (String(prev?.role || '').toLowerCase() !== 'assistant') continue;
        const prevContent = typeof prev?.content === 'string' ? prev.content : String(prev?.content || '');
        const prevCreatedAt = num(prev?.createdAt, 0);
        if (prevContent.trim() === content && nowMs - prevCreatedAt <= MEMORY_LOG_ASSISTANT_DEDUPE_WINDOW_MS) {
          return { ok: true, deduped: true, msgId: String(prev.id || ''), reason: 'assistant_retry_detected' };
        }
        break;
      }
    } catch (_) { /* ignore dedupe probe errors */ }
  }

  const msgId = memoryLogBuildMsgId(role, nowMs);
  const doc = {
    id: msgId,
    uid,
    threadKey,
    role,
    content: trimMemoryText(content, MEMORY_LOG_MAX_CONTENT_CHARS),
    sourceTag: trimMemoryText(String(params?.sourceTag || 'chat'), 40) || 'chat',
    clientMsgId: clientMsgId || '',
    provider: trimMemoryText(String(params?.provider || ''), 60) || '',
    model: trimMemoryText(String(params?.model || ''), 160) || '',
    linkedUserMsgId: trimMemoryText(String(params?.linkedUserMsgId || ''), 160) || '',
    createdAt: nowMs,
    ts: nowMs,
    processedForMemory: false,
    schemaVersion: MEMORY_LOG_SCHEMA_VERSION
  };

  try {
    await fsCreateOrPatchDoc(accessToken, projectId, `users/${uid}/memoryThreads/${threadKey}/messages/${msgId}`, doc);
    // Update thread metadata counters (best-effort).
    await fsCreateOrPatchDoc(accessToken, projectId, `users/${uid}/memoryThreads/${threadKey}`, {
      id: threadKey,
      threadKey,
      uid,
      lastMessageAt: nowMs,
      lastMessageId: msgId,
      lastMessageRole: role,
      updatedAt: nowMs
    }).catch(() => null);
    if (role === 'user' && clientMsgId) {
      await memoryLogStampClientIdempotency(accessToken, projectId, uid, threadKey, clientMsgId, msgId, nowMs).catch(() => null);
    }
    return { ok: true, deduped: false, msgId, createdAt: nowMs };
  } catch (e) {
    return { ok: false, error: String(e?.message || e) };
  }
}

async function memoryLogListMessagesAfter(accessToken, projectId, uid, threadKey, afterMsgId = '', options = {}) {
  if (!threadKey) return [];
  const limit = Math.max(1, Math.min(MEMORY_LOG_MAX_FETCH_PER_QUERY, num(options?.limit, MEMORY_LOG_MAX_FETCH_PER_QUERY)));
  // Prefer structured query with `id > afterMsgId` ascending for efficient pagination.
  try {
    const filters = afterMsgId
      ? [{ field: { fieldPath: 'id' }, op: 'GREATER_THAN', value: { stringValue: String(afterMsgId) } }]
      : [];
    const docs = await fsRunQuery(accessToken, projectId, `users/${uid}/memoryThreads/${threadKey}`, 'messages', {
      filters,
      orderBy: [{ field: 'id', direction: 'ASCENDING' }],
      limit
    });
    const parsed = (Array.isArray(docs) ? docs : []).map((doc) => parseFirestoreFields(doc?.fields || {})).filter((m) => m && m.id);
    parsed.sort((a, b) => String(a.id || '').localeCompare(String(b.id || '')));
    return parsed;
  } catch (_) {
    // Fallback: list all, sort + filter in memory. Safe up to a few hundred msgs/thread.
    try {
      const all = await fsListDocs(accessToken, projectId, `users/${uid}/memoryThreads/${threadKey}/messages`, 500);
      const parsed = (Array.isArray(all) ? all : []).map((d) => parseFirestoreFields(d?.fields || {})).filter((m) => m && m.id);
      parsed.sort((a, b) => String(a.id || '').localeCompare(String(b.id || '')));
      if (!afterMsgId) return parsed.slice(-limit);
      return parsed.filter((m) => String(m.id || '') > String(afterMsgId)).slice(0, limit);
    } catch (__) { return []; }
  }
}

async function memoryLogListRecentMessages(accessToken, projectId, uid, threadKey, limit = MEMORY_LOG_BRIDGE_WINDOW_DEFAULT) {
  if (!threadKey) return [];
  const cap = Math.max(1, Math.min(MEMORY_LOG_MAX_FETCH_PER_QUERY, num(limit, MEMORY_LOG_BRIDGE_WINDOW_DEFAULT)));
  try {
    const all = await fsListDocs(accessToken, projectId, `users/${uid}/memoryThreads/${threadKey}/messages`, 500);
    const parsed = (Array.isArray(all) ? all : []).map((d) => parseFirestoreFields(d?.fields || {})).filter((m) => m && m.id);
    parsed.sort((a, b) => String(a.id || '').localeCompare(String(b.id || '')));
    return parsed.slice(-cap);
  } catch (_) { return []; }
}

async function memoryLogListBridgeBefore(accessToken, projectId, uid, threadKey, beforeMsgId, limit = MEMORY_LOG_BRIDGE_WINDOW_DEFAULT) {
  if (!threadKey) return [];
  const cap = Math.max(1, Math.min(50, num(limit, MEMORY_LOG_BRIDGE_WINDOW_DEFAULT)));
  try {
    const all = await fsListDocs(accessToken, projectId, `users/${uid}/memoryThreads/${threadKey}/messages`, 500);
    const parsed = (Array.isArray(all) ? all : []).map((d) => parseFirestoreFields(d?.fields || {})).filter((m) => m && m.id);
    parsed.sort((a, b) => String(a.id || '').localeCompare(String(b.id || '')));
    const cutoff = String(beforeMsgId || '');
    const before = cutoff ? parsed.filter((m) => String(m.id || '') < cutoff) : parsed;
    return before.slice(-cap);
  } catch (_) { return []; }
}

/**
 * Cursor-based unprocessed slice derivation.
 * Replaces memoryProdGetUnprocessedMessageSlice (which relied on client array length).
 * Queries the backend log for messages after `session.lastProcessedMsgId` and
 * returns them in standard {role, content} format.
 *
 * On first call for a session (no cursor yet), returns an empty slice rather than
 * "dumping everything" so the system starts clean and advances the cursor on the
 * next real append. That matches the doctrine: the backend log is truth going
 * forward; we do not retroactively learn from pre-cursor history unless explicitly
 * bootstrapped via /memory/bootstrap.
 */
async function memoryLogGetUnprocessedSliceByCursor(accessToken, projectId, uid, session, threadKey, options = {}) {
  const cursor = trimMemoryText(String(session?.lastProcessedMsgId || ''), 160);
  const hardLimit = num(options?.limit, 30);
  if (!threadKey) return { messages: [], newestMsgId: cursor, rows: [] };
  const rows = await memoryLogListMessagesAfter(accessToken, projectId, uid, threadKey, cursor, { limit: hardLimit });
  const messages = memoryLogToStandardMessages(rows);
  const newestMsgId = rows.length ? String(rows[rows.length - 1].id || '') : cursor;
  return { messages, newestMsgId, rows };
}

/**
 * Cursor-based bridge context.
 * Returns up to N messages BEFORE the slice (i.e., before the first row-id of the
 * new slice), for pronoun resolution and continuity. If the slice is empty, falls
 * back to the last N messages overall.
 */
async function memoryLogBuildBridgeByCursor(accessToken, projectId, uid, threadKey, sliceRows = [], bridgeCount = MEMORY_LOG_BRIDGE_WINDOW_DEFAULT) {
  if (!threadKey) return [];
  const beforeId = Array.isArray(sliceRows) && sliceRows.length ? String(sliceRows[0]?.id || '') : '';
  if (beforeId) {
    const rows = await memoryLogListBridgeBefore(accessToken, projectId, uid, threadKey, beforeId, bridgeCount);
    return memoryLogToStandardMessages(rows);
  }
  const rows = await memoryLogListRecentMessages(accessToken, projectId, uid, threadKey, bridgeCount);
  return memoryLogToStandardMessages(rows);
}

/** Build checkpoint patch from a newestMsgId cursor (log-native). */
function memoryLogBuildCursorCheckpointPatch(newestMsgId, priorMsgId = '', extraCount = 0, nowMs = Date.now()) {
  return {
    lastProcessedMsgId: trimMemoryText(String(newestMsgId || ''), 160),
    lastProcessedMsgIdPrev: trimMemoryText(String(priorMsgId || ''), 160),
    lastProcessedAt: nowMs,
    // Legacy count kept for debug only; no longer authoritative.
    lastProcessedMessageCount: Math.max(0, num(extraCount, 0))
  };
}

/** Back-compat: old fragile checkpoint payload builder, preserved for fallback paths. */
function memoryProdGetSessionCheckpointPayload(messages) {
  const safe = Array.isArray(messages) ? messages : [];
  const lastUserText = trimMemoryText(getLastUserMessageText(safe), 320);
  const lastMessageSig = safe.length ? memoryProdBuildMessageSignature(safe[safe.length - 1], safe.length - 1) : '';
  return {
    lastProcessedMessageCount: safe.length,
    lastProcessedLastUserHash: lastUserText ? memoryProdSimpleHash(lastUserText) : '',
    lastProcessedMessageSignature: lastMessageSig,
    lastProcessedAt: Date.now()
  };
}

function memoryProdGetUnprocessedMessageSlice(session, messages) {
  const safe = Array.isArray(messages) ? messages : [];
  if (!safe.length) return [];
  const checkpointCount = Math.max(0, num(session?.lastProcessedMessageCount, 0));
  const checkpointUserHash = trimMemoryText(session?.lastProcessedLastUserHash || '', 80);
  const currentUserHash = memoryProdSimpleHash(trimMemoryText(getLastUserMessageText(safe), 320));
  const lastSignature = trimMemoryText(session?.lastProcessedMessageSignature || '', 160);
  const currentSignature = memoryProdBuildMessageSignature(safe[safe.length - 1], safe.length - 1);

  if (checkpointCount > 0 && safe.length > checkpointCount) return safe.slice(checkpointCount);
  if (checkpointCount > 0 && safe.length === checkpointCount && checkpointUserHash && checkpointUserHash === currentUserHash && lastSignature === currentSignature) return [];
  if (checkpointCount > 0 && safe.length < checkpointCount && checkpointUserHash && checkpointUserHash === currentUserHash) return [];
  return safe.slice(Math.max(0, safe.length - Math.min(safe.length, 6)));
}


function memoryProdCountMeaningfulUserMessages(messages) {
  return (Array.isArray(messages) ? messages : []).filter((m) => String(m?.role || '').toLowerCase() === 'user').map((m) => trimMemoryText(typeof m?.content === 'string' ? m.content : String(m?.content || ''), 400)).filter((text) => text.length >= 12 && text.split(/\s+/).filter(Boolean).length >= 3).length;
}

function memoryProdEstimateSliceChars(messages, assistantText = '') {
  let total = trimMemoryText(assistantText, 1200).length;
  for (const m of Array.isArray(messages) ? messages : []) {
    total += trimMemoryText(typeof m?.content === 'string' ? m.content : String(m?.content || ''), 800).length;
  }
  return total;
}

function memoryProdHasHighSignalCue(text) {
  const hay = String(text || '').toLowerCase().replace(/['\u2019]/g, "'"); // normalize curly apostrophes to straight
  if (!hay) return false;
  // Expanded regex â€” covers contractions (i'm), building/launching/working patterns,
  // goals, preferences, identity, life-memory, project/product cues.
  // Previously missed things like "i'm building GPMai" because only "i am building" was listed.
  return /\b(i started|i stopped|i paused|i resumed|i launched|i completed|i fixed|i changed my plan|my goal is|my plan is|my dream is|i want to|i plan to|i aim to|i prefer|i love|i like|i hate|i dislike|i am building|i'm building|im building|i am working on|i'm working on|im working on|i am launching|i'm launching|im launching|i am creating|i'm creating|im creating|i am developing|i'm developing|im developing|i am making|i'm making|im making|i am learning|i'm learning|im learning|i am training|i'm training|im training|i am studying|i'm studying|im studying|i have|i've|i was diagnosed|i take medicine|i take medication|i am a|i am an|i'm a|i'm an|im a|im an|my father died|my mother died|my parents are getting divorced|grandfather died|grandmother died|breakup|divorce|trauma|abuse|grief|surgery|injury|diagnosed|medicine|medication|allergy|panic disorder|anxiety|depression|ocd|adhd|autism|blocked|deadline|exam|play store|release|launch|startup|project|product|app|building an app|building a app|building ai|serious ai app|production ai|production app|ship it|second brain|memory brain)\b/.test(hay);
}

function memoryProdGetBridgeContextMessages(messages, session, bridgeCount = MEMORY_EXTRACTION_BRIDGE_MESSAGE_COUNT) {
  const safe = Array.isArray(messages) ? messages : [];
  if (!safe.length) return [];
  const checkpointCount = Math.max(0, num(session?.lastProcessedMessageCount, 0));
  if (checkpointCount <= 0) return safe.slice(Math.max(0, safe.length - Math.min(safe.length, bridgeCount)));
  const start = Math.max(0, checkpointCount - Math.max(0, bridgeCount));
  return safe.slice(start, checkpointCount);
}

function memoryProdBuildExtractionConversationText(packet) {
  // v3.3.6 â€” strict bridge/slice separation.
  const bridge = [];
  const slice = [];
  const assistant = [];
  for (const m of Array.isArray(packet?.bridgeMessages) ? packet.bridgeMessages : []) {
    const role = String(m?.role || 'user').toUpperCase();
    const content = trimMemoryText(typeof m?.content === 'string' ? m.content : String(m?.content || ''), 500);
    if (content) bridge.push(`${role}: ${content}`);
  }
  for (const m of Array.isArray(packet?.sliceMessages) ? packet.sliceMessages : []) {
    const role = String(m?.role || 'user').toUpperCase();
    const content = trimMemoryText(typeof m?.content === 'string' ? m.content : String(m?.content || ''), 700);
    if (!content) continue;
    if (role === 'ASSISTANT') assistant.push(`${role}: ${content}`);
    else slice.push(`${role}: ${content}`);
  }
  const planned = Array.isArray(packet?.plannedAnchorHints) ? packet.plannedAnchorHints : [];
  const activeHints = Array.isArray(packet?.activeAnchorHints) ? packet.activeAnchorHints : [];
  const chunks = [
    '<bridge_context_reference_only>',
    bridge.join('\n\n') || '(none)',
    '</bridge_context_reference_only>',
    '',
    '<extract_from_new_slice_only>',
    slice.join('\n\n') || '(none)',
    '</extract_from_new_slice_only>',
    '',
    '<assistant_context_do_not_extract>',
    [
      ...assistant,
      trimMemoryText(packet?.assistantText || '', 1000)
    ].filter(Boolean).join('\n\n') || '(none)',
    '</assistant_context_do_not_extract>'
  ];
  if (planned.length) chunks.push('', '<planned_anchor_hints_inside_conversation>', JSON.stringify(planned.slice(0, 8)), '</planned_anchor_hints_inside_conversation>');
  if (activeHints.length) chunks.push('', '<active_anchor_hints_inside_conversation>', JSON.stringify(activeHints.slice(0, 8)), '</active_anchor_hints_inside_conversation>');
  return chunks.join('\n').slice(0, 9000);
}

// SURGICAL PATCH E4: Pre-extraction node narrowing.
// Before asking the LLM to extract, backend finds the most likely relevant existing
// nodes for the user's text. This way the LLM can see "football already exists as
// a node" and return it in reinforce_labels instead of inventing a new paraphrase.
// Scoring: exact label/alias hit > token overlap > substring hit > cluster token hit.
// Heuristic node shortlist â€” used ONLY as secondary signal merged with semantic shortlist,
// or as last-resort fallback when OpenAI embeddings are unavailable. Not the primary semantic path.
function memoryProdFindRelevantNodesForText(userText, bridgeText, nodes, topN = 6) {
  const safeNodes = Array.isArray(nodes) ? nodes.filter((n) => n && !n.deleted && !n.isRoot) : [];
  if (!safeNodes.length) return [];
  const haystack = `${userText || ''}\n${bridgeText || ''}`.toLowerCase();
  if (!haystack.trim()) return [];
  const userTokens = new Set(memoryProdTokenizeForMatch(haystack));
  if (!userTokens.size) return [];
  const scored = [];
  for (const node of safeNodes) {
    const labelKey = normalizeMemoryKey(node.normalizedKey || node.label);
    if (!labelKey) continue;
    const labelTokens = new Set(memoryProdTokenizeForMatch(node.label || ''));
    const aliasKeys = Array.isArray(node.aliases) ? node.aliases.map(normalizeMemoryKey).filter(Boolean) : [];
    let score = 0;
    // Exact label as a whole word in user text (very strong signal)
    const labelWord = String(node.label || '').toLowerCase().trim();
    if (labelWord && labelWord.length >= 3 && haystack.includes(labelWord)) score += 100;
    // Alias whole-word match
    for (const al of Array.isArray(node.aliases) ? node.aliases : []) {
      const alWord = String(al || '').toLowerCase().trim();
      if (alWord && alWord.length >= 3 && haystack.includes(alWord)) { score += 70; break; }
    }
    // Token overlap (label tokens seen in user tokens)
    let overlap = 0;
    for (const t of labelTokens) if (userTokens.has(t)) overlap += 1;
    if (overlap >= 2) score += 30 + overlap * 4;
    else if (overlap === 1 && labelTokens.size <= 3) score += 14;
    // Normalized key substring (covers tense variants)
    if (labelKey.length >= 4) {
      const userKey = normalizeMemoryKey(haystack);
      if (userKey && (userKey.includes(labelKey) || aliasKeys.some((ak) => ak.length >= 4 && userKey.includes(ak)))) score += 12;
    }
    // Cluster hint soft-boost (only if some token overlap exists)
    if (overlap >= 1 && String(node.clusterId || '').length) score += 3;
    // Recency small boost so recently touched nodes surface first
    const lastMs = Math.max(num(node.lastMentioned, 0), num(node.lastEventAt, 0), num(node.updatedAt, 0));
    if (lastMs) {
      const daysSince = Math.max(0, (Date.now() - lastMs) / (24 * 60 * 60 * 1000));
      if (daysSince <= 7) score += 4;
      else if (daysSince <= 30) score += 2;
    }
    if (score > 0) scored.push({ node, score });
  }
  scored.sort((a, b) => b.score - a.score);
  const limit = Math.max(1, Math.min(12, topN));
  return scored.slice(0, limit).map(({ node }) => ({
    id: trimMemoryText(node.id || '', 160),
    label: trimMemoryText(node.label || '', 80),
    aliases: boundedUniqueIds(Array.isArray(node.aliases) ? node.aliases : [], 6),
    group: trimMemoryText(node.group || '', 40),
    clusterId: trimMemoryText(node.clusterId || '', 40),
    currentState: trimMemoryText(node.currentState || '', 24),
    importanceClass: trimMemoryText(node.importanceClass || '', 40),
    summary: trimMemoryText(node.info || '', 180)
  }));
}

// UNIVERSAL NODE UPDATE PATCH â€” implicit anchor references + active anchor hints.
// This lets the same Pass 1 LLM confirm references like "this app" / "it" / "the backend"
// while the backend remains the final arbiter before any slice/event write.
function memoryProdHasImplicitNodeReferenceCue(text) {
  const hay = String(text || '').toLowerCase().replace(/[â€™]/g, "'");
  if (!hay.trim()) return false;
  return /\b(?:this|that)\s+(?:app|project|tool|product|startup|platform|site|service|system|feature|module|backend|frontend|ui|screen|page)\b/.test(hay)
    || /\b(?:the)\s+(?:app|project|tool|product|system|feature|module|backend|frontend|ui|screen|page)\b/.test(hay)
    || /\b(?:it|its)\s+(?:has|have|uses|use|needs|need|will|can|should|is|was|got|gets|contains|includes|supports)\b/.test(hay)
    || /\b(?:i\s+(?:fixed|changed|updated|stopped|paused|resumed|launched|completed)\s+it)\b/.test(hay);
}

function memoryProdReferenceDomainFromText(text) {
  const hay = String(text || '').toLowerCase();
  if (/\b(app|project|tool|product|startup|platform|site|service|system|backend|frontend|ui|screen|page|feature|module)\b/.test(hay)) return 'project';
  if (/\b(skill|technique|practice|training|learning|lesson)\b/.test(hay)) return 'skill';
  if (/\b(habit|routine)\b/.test(hay)) return 'habit';
  return '';
}

function memoryProdBuildActiveAnchorHints(nodes = [], bridgeMessages = [], sliceMessages = [], topN = 6) {
  const bridgeText = (Array.isArray(bridgeMessages) ? bridgeMessages : []).map((m) => String(m?.content || m?.text || '')).join(' ');
  const sliceText = (Array.isArray(sliceMessages) ? sliceMessages : []).map((m) => String(m?.content || m?.text || '')).join(' ');
  const hay = `${bridgeText}\n${sliceText}`.toLowerCase();
  const domain = memoryProdReferenceDomainFromText(sliceText || bridgeText);
  const scored = [];
  for (const node of Array.isArray(nodes) ? nodes : []) {
    if (!node || node.deleted || node.isRoot) continue;
    const label = trimMemoryText(node.label || '', 80);
    const key = normalizeMemoryKey(node.normalizedKey || label);
    if (!label || !key) continue;
    const group = memoryProdNormalizeMemoryGroup(node.group || 'interest');
    const state = trimMemoryText(node.currentState || '', 24);
    const labels = [label, ...(Array.isArray(node.aliases) ? node.aliases : [])].filter(Boolean);
    let score = 0;
    for (const raw of labels) {
      const low = String(raw || '').toLowerCase().trim();
      if (low.length >= 3 && hay.includes(low)) score += 90;
    }
    if (domain && group === domain) score += 24;
    if (domain === 'project' && ['project', 'goal'].includes(group)) score += 12;
    if (['active', 'unknown', ''].includes(state)) score += 10;
    const lastMs = Math.max(num(node.lastMentioned, 0), num(node.lastSliceAt, 0), num(node.lastEventAt, 0), num(node.updatedAt, 0), num(node.dateAdded, 0));
    if (lastMs) {
      const hours = Math.max(0, (Date.now() - lastMs) / (60 * 60 * 1000));
      if (hours <= 2) score += 18;
      else if (hours <= 24) score += 10;
      else if (hours <= 168) score += 5;
    }
    if (score <= 0) continue;
    scored.push({
      id: trimMemoryText(node.id || '', 160),
      label,
      group,
      currentState: state || 'unknown',
      clusterId: trimMemoryText(node.clusterId || '', 40),
      latestSliceSummary: trimMemoryText(node.latestSliceSummary || node.info || '', 180),
      score,
      reason: domain ? `implicit_${domain}_anchor_hint` : 'recent_or_bridge_anchor_hint'
    });
  }
  scored.sort((a, b) => b.score - a.score);
  const seen = new Set();
  const out = [];
  for (const item of scored) {
    const key = normalizeMemoryKey(item.label);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    out.push(item);
    if (out.length >= Math.max(1, topN)) break;
  }
  return out;
}

function memoryProdBuildPlannedAnchorHints(sliceMessages = [], bridgeMessages = [], topN = 6) {
  // v3.3.5 â€” Same-batch planned anchors. These are NOT writes. They are hints
  // saying: "the current unprocessed slice itself introduced this durable anchor."
  // This lets the LLM confirm "this app" â†’ "Kaka" even before Kaka exists in Firestore.
  // v3.3.6 â€” planned anchors must come from the NEW unprocessed slice only.
  // Bridge messages are old context: they may resolve references, but they must not
  // re-create planned anchors on later turns.
  const allMessages = Array.isArray(sliceMessages) ? sliceMessages : [];
  const scored = [];
  const push = (label, score = 0, reason = 'planned_anchor') => {
    let clean = trimMemoryText(label || '', 80);
    const calledInside = clean.match(/\b(?:app|project|tool|product|startup|platform|site|service|system)\s+(?:called|named)\s+([A-Za-z][A-Za-z0-9+._-]*(?:\s+[A-Za-z][A-Za-z0-9+._-]*){0,2})\b/i);
    if (calledInside?.[1]) clean = trimMemoryText(calledInside[1], 80);
    clean = clean.replace(/^(?:an?|the)\s+(?:app|project|tool|product|startup|platform|site|service|system)\s+/i, '').trim();
    if (!clean || /\b(?:called|named)\b/i.test(clean) || memoryProdIsGenericNodeLabel(clean) || memoryProdLooksGenericScopedLabel(clean)) return;
    const key = normalizeMemoryKey(clean);
    if (!key) return;
    scored.push({
      label: clean,
      normalizedKey: key,
      aliasKeys: memoryProdEntityAliasKeys(clean),
      group: 'project',
      roleGuess: 'project',
      currentState: 'active',
      source: 'same_batch',
      reason,
      score
    });
  };
  for (const m of allMessages) {
    if (String(m?.role || '').toLowerCase() !== 'user') continue;
    const text = String(m?.content || m?.text || '').replace(/[â€™]/g, "'").trim();
    if (!text) continue;
    const named = memoryProdExtractNamedProjectAnchor(text);
    if (named?.primaryAnchor) push(named.primaryAnchor, 95, named.reason || 'named_project_anchor_same_batch');
    const ranked = memoryProdRankedAnchors(text, text, 5)
      .filter((a) => ['called_pattern', 'build_pattern'].includes(a.source));
    for (const a of ranked) push(a.label, 70 + num(a.score, 0), `ranked_${a.source}`);
  }
  scored.sort((a, b) => b.score - a.score);
  const out = [];
  const seen = new Set();
  for (const item of scored) {
    const keys = memoryProdEntityAliasKeys(item.label);
    const primaryKey = keys[0] || normalizeMemoryKey(item.label);
    if (!primaryKey || seen.has(primaryKey)) continue;
    seen.add(primaryKey);
    out.push({
      label: item.label,
      normalizedKey: primaryKey,
      aliasKeys: keys,
      group: item.group,
      roleGuess: item.roleGuess,
      currentState: item.currentState,
      source: item.source,
      reason: item.reason,
      score: item.score
    });
    if (out.length >= Math.max(1, topN)) break;
  }
  return out;
}

function memoryProdResolveImplicitAnchorFromContext(userText = '', activeAnchorHints = [], relevantNodes = [], existingNodes = []) {
  if (!memoryProdHasImplicitNodeReferenceCue(userText)) return null;
  const domain = memoryProdReferenceDomainFromText(userText);
  const byKey = new Map();
  const add = (raw, bonus = 0, source = 'unknown') => {
    if (!raw) return;
    const label = trimMemoryText(raw.label || '', 80);
    const key = normalizeMemoryKey(raw.normalizedKey || label);
    if (!key || !label) return;
    const group = memoryProdNormalizeMemoryGroup(raw.group || raw.roleGuess || 'interest');
    let score = num(raw.score, 0) + bonus;
    if (domain && group === domain) score += 28;
    if (domain === 'project' && ['project', 'goal'].includes(group)) score += 12;
    if (String(raw.currentState || '').toLowerCase() === 'active') score += 10;
    const prev = byKey.get(key);
    if (!prev || score > prev.score) byKey.set(key, { ...raw, label, key, group, score, source });
  };
  for (const h of Array.isArray(activeAnchorHints) ? activeAnchorHints : []) add(h, 20, 'active_anchor_hint');
  for (const n of Array.isArray(relevantNodes) ? relevantNodes : []) add(n, 10, 'relevant_node');
  for (const n of Array.isArray(existingNodes) ? existingNodes : []) add(n, 0, 'existing_node');
  let candidates = Array.from(byKey.values()).filter((x) => !x.deleted && !x.isRoot);
  if (domain) candidates = candidates.filter((x) => x.group === domain || (domain === 'project' && ['project', 'goal'].includes(x.group)) || candidates.length === 1);
  candidates.sort((a, b) => b.score - a.score);
  if (!candidates.length) return { ambiguous: true, reason: 'implicit_reference_no_anchor', candidates: [] };
  const first = candidates[0];
  const second = candidates[1] || null;
  if (second && first.score < second.score + 18) {
    return { ambiguous: true, reason: 'implicit_reference_multiple_plausible_anchors', candidates: candidates.slice(0, 3).map((c) => ({ id: c.id || '', label: c.label, score: c.score, group: c.group })) };
  }
  return { ambiguous: false, node: first, label: first.label, nodeId: first.id || '', confidence: Math.min(0.96, Math.max(0.72, first.score / 120)), reason: first.source || first.reason || 'implicit_reference_resolved' };
}

function memoryProdNormalizeNodeUpdate(raw = {}, userText = '') {
  const eventHint = raw?.eventHint || {};
  const action = memoryProdNormalizeLifecycleAction(raw?.lifecycleAction || raw?.action || eventHint?.action || memoryProdInferLifecycleActionFromText(raw?.summaryHint || userText));
  const eventType = trimMemoryText(raw?.eventType || eventHint?.eventType || (action ? memoryProdEventTypeFromLifecycleAction(action, raw?.roleGuess || raw?.group || '') : ''), 60);
  const summaryHint = trimMemoryText(raw?.summaryHint || raw?.summary || eventHint?.summary || userText, 260);
  const edgeHints = Array.isArray(raw?.edgeHints) ? raw.edgeHints : (Array.isArray(raw?.relationHints) ? raw.relationHints : []);
  const resolutionConfidence = typeof raw?.resolutionConfidence === 'number'
    ? Math.max(0, Math.min(1, raw.resolutionConfidence))
    : (typeof raw?.confidence === 'number' ? Math.max(0, Math.min(1, raw.confidence)) : 0.74);
  return {
    anchorLabel: trimMemoryText(raw?.anchorLabel || raw?.label || raw?.nodeLabel || '', 80),
    anchorNodeId: trimMemoryText(raw?.anchorNodeId || raw?.nodeId || '', 160),
    resolvedFrom: trimMemoryText(raw?.resolvedFrom || raw?.referenceText || raw?.pronoun || '', 100),
    resolutionReason: trimMemoryText(raw?.resolutionReason || raw?.reason || '', 220),
    resolutionConfidence,
    ambiguous: raw?.ambiguous === true,
    alternativeAnchors: Array.isArray(raw?.alternativeAnchors) ? raw.alternativeAnchors.slice(0, 5).map((x) => trimMemoryText(x?.label || x || '', 80)).filter(Boolean) : [],
    detailDisposition: trimMemoryText(raw?.detailDisposition || raw?.disposition || '', 40),
    summaryHint,
    meaningful: raw?.meaningful !== false,
    eventWorthy: raw?.eventWorthy === true || eventHint?.worthy === true || !!action || /\b(fixed|resolved|blocked|stuck|launched|released|completed|stopped|paused|resumed|started|changed|switched|migrated|broke|broken|failed|issue|bug|error)\b/i.test(summaryHint),
    updateKind: trimMemoryText(raw?.updateKind || raw?.kind || (action ? 'lifecycle' : 'detail'), 40),
    lifecycleAction: action,
    eventType,
    confidence: resolutionConfidence,
    edgeHints,
    raw
  };
}

function memoryProdCleanNodeUpdateObjectText(value = '') {
  return trimMemoryText(String(value || '')
    .replace(/[â€œâ€"'`]+/g, '')
    .replace(/\s+(?:today|now|right now|currently|for now|recently)\b.*$/i, '')
    .replace(/[.,;:!?]+$/g, '')
    .replace(/\s+/g, ' ')
    .trim(), 120);
}

function memoryProdBuildScopedNodeUpdateSummary(userText = '', anchorLabel = '', detailLabel = '', fallback = '') {
  const anchor = trimMemoryText(anchorLabel || '', 80);
  const text = String(userText || '').replace(/[â€™]/g, "'").replace(/\s+/g, ' ').trim();
  if (!anchor || !text) return trimMemoryText(fallback || text, 260);

  const cleanObject = (v) => memoryProdCleanNodeUpdateObjectText(v || '');
  const normalizeObject = (v) => cleanObject(v || '').replace(/\breq\b/ig, 'requirements').replace(/\bsummary\b/ig, 'summaries').replace(/\s+/g, ' ').trim();
  const patterns = [
    {
      re: /\b(?:another|one|a|the)\s+feature\s+of\s+(.{2,80}?)\s+is\s+(?:it\s+)?(?:can\s+)?(.{2,140})$/i,
      build: (m) => `${anchor} can ${normalizeObject(m[2]).replace(/^can\s+/i, '')}.`
    },
    {
      re: /\b(?:this\s+app|that\s+app|it|the\s+app)\s+can\s+(.{2,140})$/i,
      build: (m) => `${anchor} can ${normalizeObject(m[1])}.`
    },
    {
      re: /\b(.{2,80}?)\s+can\s+(.{2,140})$/i,
      build: (m) => `${anchor} can ${normalizeObject(m[2])}.`
    },
    {
      re: /\b(?:the\s+)?(?:core|main|primary|key)\s+feature\s+of\s+(.{2,80}?)\s+is\s+(.{2,120})$/i,
      build: (m) => `${anchor}'s core feature is ${normalizeObject(m[2])}.`
    },
    {
      re: /\b(.{2,80}?)\s+(?:has|have|includes|contains)\s+(?:a\s+)?(?:core\s+|main\s+|key\s+)?feature\s+(?:called|named)?\s*(.{2,120})$/i,
      build: (m) => `${anchor} has a feature called ${normalizeObject(m[2])}.`
    },
    {
      re: /\b(?:the\s+)?backend\s+of\s+(.{2,80}?)\s+(?:is|uses|will\s+use|will\s+be)\s+(.{2,120})$/i,
      build: (m) => `${anchor}'s backend is ${normalizeObject(m[2])}.`
    },
    {
      re: /\b(?:the\s+)?backend\s+(?:is|uses|will\s+use|will\s+be)\s+(.{2,120})$/i,
      build: (m) => `${anchor}'s backend is ${normalizeObject(m[1])}.`
    },
    {
      re: /\b(?:the\s+)?(?:ui|frontend|screen|page)\s+of\s+(.{2,80}?)\s+(?:is|uses|has|will\s+be)\s+(.{2,120})$/i,
      build: (m) => `${anchor}'s UI ${/^(has|uses)\b/i.test(m[0]) ? 'uses' : 'is'} ${normalizeObject(m[2])}.`
    },
    {
      re: /\b(.{2,80}?)\s+(?:uses|use|will\s+use|is\s+using)\s+(.{2,120})$/i,
      build: (m) => `${anchor} uses ${normalizeObject(m[2])}.`
    }
  ];
  for (const ptn of patterns) {
    const m = text.match(ptn.re);
    if (m) {
      const built = trimMemoryText(ptn.build(m), 260);
      if (built && !/\b(?:this app|that app|it)\b/i.test(built)) return built;
      if (built) return built.replace(/\b(?:this app|that app|it)\b/ig, anchor);
    }
  }
  if (detailLabel) {
    const detail = cleanObject(detailLabel);
    if (detail && new RegExp(`\\b${detail.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i').test(text)) {
      if (/\bfeature\b/i.test(text)) return trimMemoryText(`${anchor} has a feature called ${detail}.`, 260);
      if (/\bbug|issue|error|problem\b/i.test(text)) return trimMemoryText(`${anchor} has ${detail}.`, 260);
    }
  }
  return trimMemoryText(fallback || `${anchor}: ${text}`, 260);
}

function memoryProdCandidateLabelLooksAttachedDetail(label = '', userText = '') {
  const cleanLabel = trimMemoryText(label || '', 80);
  const key = normalizeMemoryKey(cleanLabel);
  const text = String(userText || '').replace(/[â€™]/g, "'").toLowerCase();
  if (!cleanLabel || !key || !text.trim()) return false;
  if (memoryProdIsTransientDetailLabel(cleanLabel, userText)) return true;
  if (/\b(feature|module|screen|page|ui|backend|frontend|login|bug|issue|error|problem|auth|database|graph)\b/i.test(cleanLabel)) return true;
  const labelWords = cleanLabel.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\s+/g, '\\s+');
  try {
    if (new RegExp(`\\b(?:core|main|primary|key)?\\s*feature\\s+(?:called|named|is)?\\s*${labelWords}\\b`, 'i').test(userText)) return true;
    if (new RegExp(`\\b(?:is|called|named)\\s+${labelWords}\\b`, 'i').test(userText) && /\bfeature\b/i.test(userText)) return true;
    if (new RegExp(`\\b${labelWords}\\s+(?:feature|module|screen|page|bug|issue|error)\\b`, 'i').test(userText)) return true;
  } catch (_) {}
  return false;
}

function memoryProdCoalesceCandidatesIntoNodeUpdates(learned = {}, context = {}) {
  const userText = trimMemoryText(context?.userText || '', 1000);
  const existingNodes = Array.isArray(context?.existingNodes) ? context.existingNodes : [];
  const packet = context?.packet || {};
  const selfReport = learned?.self_report || learned?.selfReport || {};
  const anchorRefs = memoryProdBuildAnchorRefs(existingNodes, packet);
  const rechecks = [];

  // Candidate coalescing must not guess on ambiguous pronouns. It may still collapse a
  // direct scoped alias like "Kaka app" â†’ "Kaka" if alias keys prove the match.
  const llmAmbiguous = selfReport?.ambiguous_references === true;
  const rawUpdates = Array.isArray(learned?.node_updates) ? learned.node_updates.slice() : [];
  const normalizedUpdates = rawUpdates.map((u) => memoryProdNormalizeNodeUpdate(u, userText));
  const updateAnchorRefs = [];
  for (const u of normalizedUpdates) {
    if (u.ambiguous) continue;
    const ref = memoryProdFindAnchorRefByAlias(anchorRefs, u.anchorLabel);
    if (ref) updateAnchorRefs.push(ref);
  }

  const findTargetForCandidate = (candidate) => {
    const label = trimMemoryText(candidate?.label || '', 80);
    if (!label) return null;
    const aliasRef = memoryProdFindAnchorRefByAlias(anchorRefs, label);
    if (aliasRef) {
      const sameVisible = normalizeMemoryKey(aliasRef.label) === normalizeMemoryKey(label);
      if (!sameVisible || candidate?._coalesceEvenExact === true) return { ref: aliasRef, reason: sameVisible ? 'exact_anchor_update' : 'scoped_alias_to_anchor' };
    }
    if (updateAnchorRefs.length === 1) return { ref: updateAnchorRefs[0], reason: 'single_llm_node_update_anchor' };
    if (!llmAmbiguous && anchorRefs.length === 1 && (memoryProdHasImplicitNodeReferenceCue(userText) || memoryProdCandidateLabelLooksAttachedDetail(label, userText))) {
      return { ref: anchorRefs[0], reason: 'single_context_anchor' };
    }
    return null;
  };

  const survivors = [];
  const appendedUpdates = [];
  const seenUpdateKeys = new Set(normalizedUpdates.map((u) => `${normalizeMemoryKey(u.anchorLabel)}|${normalizeMemoryKey(u.summaryHint)}`));

  for (const c of Array.isArray(learned?.candidates) ? learned.candidates : []) {
    const label = trimMemoryText(c?.label || '', 80);
    if (!label) continue;
    const target = findTargetForCandidate(c);
    const exactTarget = target?.ref && normalizeMemoryKey(target.ref.label) === normalizeMemoryKey(label);
    const attachedDetail = memoryProdCandidateLabelLooksAttachedDetail(label, userText);
    const scopedAlias = !!target?.ref && !exactTarget && memoryProdLabelsAliasEquivalent(label, target.ref.label);
    const shouldCoalesce = !!target?.ref && (scopedAlias || attachedDetail || /\b(app|project|tool|product|platform|system|service)\b$/i.test(label));

    if (!shouldCoalesce) {
      survivors.push(c);
      continue;
    }

    const targetLabel = trimMemoryText(target.ref.label || '', 80);
    if (!targetLabel || normalizeMemoryKey(targetLabel) === normalizeMemoryKey(label)) {
      // Keep the actual anchor candidate; this is how same-batch planned anchors get created.
      survivors.push(c);
      continue;
    }

    const summary = memoryProdBuildScopedNodeUpdateSummary(
      userText,
      targetLabel,
      label,
      c?.summaryHint || c?.eventHint?.summary || userText
    );
    const eventAction = memoryProdNormalizeLifecycleAction(c?.eventHint?.action || c?.stateHint || memoryProdInferLifecycleActionFromText(summary || userText));
    const update = {
      anchorLabel: targetLabel,
      anchorNodeId: target.ref.id || '',
      resolvedFrom: label,
      resolutionReason: target.reason || 'candidate_coalesced_into_anchor',
      resolutionConfidence: scopedAlias ? 0.94 : 0.86,
      ambiguous: false,
      alternativeAnchors: [],
      detailDisposition: 'attach_to_anchor',
      summaryHint: summary,
      meaningful: true,
      eventWorthy: c?.eventHint?.worthy === true || !!eventAction || /\b(fixed|bug|issue|error|blocked|stuck|broken|failed)\b/i.test(summary),
      updateKind: c?.eventHint?.worthy === true ? 'progress' : (attachedDetail ? 'feature_detail' : 'technical_detail'),
      lifecycleAction: eventAction || '',
      eventType: c?.eventHint?.eventType || memoryProdEventTypeFromLifecycleAction(eventAction, target.ref.group || 'project'),
      confidence: scopedAlias ? 0.94 : 0.86,
      edgeHints: Array.isArray(c?.relationHints) ? c.relationHints : [],
      _coalescedFromCandidate: label
    };
    const dedupeKey = `${normalizeMemoryKey(update.anchorLabel)}|${normalizeMemoryKey(update.summaryHint)}`;
    if (!seenUpdateKeys.has(dedupeKey)) {
      appendedUpdates.push(update);
      seenUpdateKeys.add(dedupeKey);
    }
    rechecks.push({
      kind: 'candidate_coalesced_into_node_update',
      label,
      primaryAnchor: targetLabel,
      reason: scopedAlias ? 'scoped_alias_to_existing_or_planned_anchor' : 'detail_attached_to_anchor',
      summaryHint: summary
    });
  }

  return {
    ...learned,
    candidates: survivors,
    node_updates: [...normalizedUpdates, ...appendedUpdates],
    backendRechecks: [...(Array.isArray(learned?.backendRechecks) ? learned.backendRechecks : []), ...rechecks],
    backend_rechecks: [...(Array.isArray(learned?.backend_rechecks) ? learned.backend_rechecks : []), ...rechecks]
  };
}

function memoryProdNodeUpdateSummaryLooksMeaningful(summary = '', userText = '') {
  const text = trimMemoryText(summary || userText || '', 240);
  if (!text || memoryProdUserTextLooksTrivial(text)) return false;
  if (memoryProdIsPureUtilityUserText(text)) return false;
  const words = text.split(/\s+/).filter(Boolean);
  if (words.length < 3 && !/[A-Z][a-zA-Z0-9]{2,}/.test(text)) return false;
  if (/^(ok|yes|no|thanks|thank you|continue|nice|cool|lol|haha)$/i.test(text.trim())) return false;
  return true;
}

function memoryProdBuildApprovedNodeUpdates(learned = {}, userText = '', existingNodes = [], packet = {}) {
  const rechecks = [];
  const relevantNodes = Array.isArray(packet?.relevantNodes) ? packet.relevantNodes : [];
  const activeAnchorHints = Array.isArray(packet?.activeAnchorHints) ? packet.activeAnchorHints : memoryProdBuildActiveAnchorHints(existingNodes, packet?.bridgeMessages || [], packet?.sliceMessages || [], 6);
  const plannedAnchorHints = Array.isArray(packet?.plannedAnchorHints) ? packet.plannedAnchorHints : [];
  const anchorRefs = memoryProdBuildAnchorRefs(existingNodes, { ...packet, activeAnchorHints, plannedAnchorHints, relevantNodes });
  const rawUpdates = Array.isArray(learned?.node_updates) ? learned.node_updates.slice() : [];
  const selfReport = learned?.self_report || learned?.selfReport || null;

  // LLM-first, backend-safe fallback: only synthesize an implicit update when the
  // context has one unambiguous anchor. If the LLM reports ambiguity, do nothing.
  if (!rawUpdates.length && memoryProdHasImplicitNodeReferenceCue(userText) && memoryProdNodeUpdateSummaryLooksMeaningful(userText, userText)) {
    const ambiguousReported = selfReport && selfReport.ambiguous_references === true;
    const viableAnchors = anchorRefs.filter((r) => r && !r.ambiguous && (memoryProdReferenceDomainFromText(userText) !== 'project' || ['project', 'goal'].includes(memoryProdNormalizeMemoryGroup(r.group))));
    if (!ambiguousReported && viableAnchors.length === 1) {
      const resolved = viableAnchors[0];
      rawUpdates.push({
        anchorLabel: resolved.label,
        anchorNodeId: resolved.id || '',
        resolvedFrom: 'implicit_reference_backend_fallback_unique_anchor',
        resolutionReason: `Only one viable anchor in context: ${resolved.label}`,
        resolutionConfidence: 0.82,
        ambiguous: false,
        detailDisposition: 'attach_to_anchor',
        summaryHint: memoryProdBuildScopedNodeUpdateSummary(userText, resolved.label, '', `${resolved.label}: ${trimMemoryText(userText, 180)}`),
        meaningful: true,
        eventWorthy: !!memoryProdInferLifecycleActionFromText(userText) || /\b(fixed|bug|error|issue|blocked|stuck|broken|failed)\b/i.test(userText),
        lifecycleAction: memoryProdInferLifecycleActionFromText(userText),
        eventType: memoryProdEventTypeFromLifecycleAction(memoryProdInferLifecycleActionFromText(userText), resolved.group || ''),
        updateKind: memoryProdInferLifecycleActionFromText(userText) ? 'lifecycle' : 'implicit_detail',
        confidence: 0.82
      });
      rechecks.push({ kind: 'node_update_backend_fallback_created', label: resolved.label, reason: 'unique_anchor_context' });
    } else if (ambiguousReported || viableAnchors.length > 1) {
      rechecks.push({ kind: 'node_update_ambiguous_reference_skipped', reason: ambiguousReported ? 'llm_reported_ambiguous_reference' : 'multiple_viable_anchors', candidates: viableAnchors.slice(0, 4).map((x) => ({ label: x.label, source: x.source, score: x.score })) });
    }
  }

  const approved = [];
  const seen = new Set();
  for (const raw of rawUpdates) {
    const upd = memoryProdNormalizeNodeUpdate(raw, userText);
    if (!upd.meaningful || !memoryProdNodeUpdateSummaryLooksMeaningful(upd.summaryHint, userText)) {
      rechecks.push({ kind: 'node_update_rejected', reason: 'not_meaningful', label: upd.anchorLabel || '' });
      continue;
    }

    const implicit = memoryProdHasImplicitNodeReferenceCue(userText)
      || /\b(this|that|it|its|the app|this app|that app|this project|the project|the backend|the ui)\b/i.test(`${upd.resolvedFrom || ''} ${upd.anchorLabel || ''}`);
    const ambiguousReported = upd.ambiguous === true || (selfReport && selfReport.ambiguous_references === true);
    if (implicit && ambiguousReported) {
      rechecks.push({ kind: 'node_update_rejected', reason: 'llm_ambiguous_reference', label: upd.anchorLabel || '', alternatives: upd.alternativeAnchors || [] });
      continue;
    }

    let node = null;
    let anchorRef = null;
    if (upd.anchorNodeId) {
      node = (Array.isArray(existingNodes) ? existingNodes : []).find((n) => n && !n.deleted && n.id === upd.anchorNodeId) || null;
      if (node) anchorRef = memoryProdBuildAnchorRef(node.label || upd.anchorLabel, 'existing_node_id', { id: node.id, group: node.group, currentState: node.currentState, score: 100 });
    }
    if (!node && upd.anchorLabel && !memoryProdIsGenericNodeLabel(upd.anchorLabel)) {
      node = memoryProdFindExistingNodeByLabelLoose(existingNodes, upd.anchorLabel);
      if (node) anchorRef = memoryProdBuildAnchorRef(node.label || upd.anchorLabel, 'existing_node_alias', { id: node.id, group: node.group, currentState: node.currentState, score: 95 });
    }
    if (!anchorRef && upd.anchorLabel) anchorRef = memoryProdFindAnchorRefByAlias(anchorRefs, upd.anchorLabel);

    const anchorGeneric = !upd.anchorLabel || memoryProdIsGenericNodeLabel(upd.anchorLabel) || /^(this|that|it|this app|that app|the app|this project|the project)$/i.test(upd.anchorLabel.trim());
    if (!anchorRef && (anchorGeneric || implicit)) {
      const viableAnchors = anchorRefs.filter((r) => r && (memoryProdReferenceDomainFromText(userText) !== 'project' || ['project', 'goal'].includes(memoryProdNormalizeMemoryGroup(r.group))));
      if (viableAnchors.length === 1 && !ambiguousReported) {
        anchorRef = viableAnchors[0];
        node = anchorRef.id ? ((Array.isArray(existingNodes) ? existingNodes : []).find((n) => n && n.id === anchorRef.id) || null) : null;
        upd.resolvedFrom = upd.resolvedFrom || 'implicit_reference';
        upd.resolutionReason = upd.resolutionReason || `Unique viable anchor in packet: ${anchorRef.label}`;
        upd.confidence = Math.max(upd.confidence, 0.82);
      } else {
        rechecks.push({ kind: 'node_update_rejected', reason: viableAnchors.length > 1 ? 'implicit_reference_multiple_plausible_anchors' : 'implicit_reference_unresolved', label: upd.anchorLabel || '', candidates: viableAnchors.slice(0, 4).map((x) => ({ label: x.label, source: x.source, score: x.score })) });
        continue;
      }
    }

    if (!node && anchorRef?.id) node = (Array.isArray(existingNodes) ? existingNodes : []).find((n) => n && !n.deleted && n.id === anchorRef.id) || null;
    const plannedAnchor = !node?.id && anchorRef?.planned === true;
    if (!node?.id && !plannedAnchor) {
      rechecks.push({ kind: 'node_update_rejected', reason: 'anchor_not_existing_or_planned', label: upd.anchorLabel || '' });
      continue;
    }

    const minConfidence = implicit ? 0.82 : 0.54;
    if (upd.confidence < minConfidence) {
      rechecks.push({ kind: 'node_update_rejected', reason: 'low_confidence_reference_resolution', label: anchorRef?.label || node?.label || upd.anchorLabel, confidence: upd.confidence, required: minConfidence });
      continue;
    }

    const finalLabel = trimMemoryText(node?.label || anchorRef?.label || upd.anchorLabel, 80);
    const finalGroup = memoryProdNormalizeMemoryGroup(node?.group || anchorRef?.group || 'project');
    const repairedSummary = memoryProdBuildScopedNodeUpdateSummary(userText, finalLabel, '', upd.summaryHint || userText);
    upd.summaryHint = trimMemoryText(repairedSummary || upd.summaryHint, 260);

    const dedupeAnchor = node?.id || `planned:${normalizeMemoryKey(finalLabel)}`;
    const key = `${dedupeAnchor}|${normalizeMemoryKey(upd.summaryHint)}`;
    if (seen.has(key)) continue;
    seen.add(key);
    const stateHint = memoryProdNodeStateFromLifecycleAction(upd.lifecycleAction, node?.currentState || anchorRef?.currentState || '');

    approved.push({
      ...upd,
      anchorLabel: finalLabel,
      anchorNodeId: trimMemoryText(node?.id || '', 160),
      nodeId: trimMemoryText(node?.id || '', 160),
      node: node || null,
      plannedAnchor: plannedAnchor ? { ...anchorRef, label: finalLabel, group: finalGroup } : null,
      stateHint,
      eventHint: {
        worthy: upd.eventWorthy === true,
        action: upd.lifecycleAction || '',
        summary: trimMemoryText(upd.summaryHint, 220),
        timeText: trimMemoryText(upd.raw?.timeText || upd.raw?.eventHint?.timeText || '', 80),
        eventType: trimMemoryText(upd.eventType || memoryProdEventTypeFromLifecycleAction(upd.lifecycleAction, finalGroup), 60),
        sameOngoingIncident: upd.raw?.sameOngoingIncident === true || upd.raw?.eventHint?.sameOngoingIncident === true,
        reuseHint: trimMemoryText(upd.raw?.reuseHint || upd.raw?.eventHint?.reuseHint || '', 220)
      },
      importanceHint: trimMemoryText(upd.raw?.importanceHint || node?.importanceClass || inferImportanceForLabel(finalLabel, finalGroup, upd.summaryHint), 40),
      confidence: upd.confidence
    });
    rechecks.push({
      kind: implicit ? 'llm_reference_confirmed' : 'node_update_approved',
      label: finalLabel,
      resolvedFrom: upd.resolvedFrom || '',
      resolutionReason: upd.resolutionReason || '',
      plannedAnchor,
      eventWorthy: upd.eventWorthy === true,
      updateKind: upd.updateKind
    });
  }
  return { node_updates: approved, backend_rechecks: rechecks };
}

// Synchronous packet builder kept for legacy callers (bootstrap path). The core learning
// turn uses memoryProdBuildExtractionPacketAsync below, which adds real semantic shortlist,
// buried-off-topic detection, and triage tags â€” all required by the locked architecture.
function memoryProdBuildExtractionPacket(session, fullMessages, sliceMessages, assistantText, nodes, payload, cfg, trigger) {
  const bridgeMessages = memoryProdGetBridgeContextMessages(fullMessages, session, MEMORY_EXTRACTION_BRIDGE_MESSAGE_COUNT);
  const lastUserText = getLastUserMessageText(Array.isArray(sliceMessages) ? sliceMessages : []);
  const bridgeText = (Array.isArray(bridgeMessages) ? bridgeMessages : []).map((m) => String(m?.content || m?.text || '')).join(' ');
  const relevantNodes = memoryProdFindRelevantNodesForText(lastUserText, bridgeText, nodes, 6);
  const activeAnchorHints = memoryProdBuildActiveAnchorHints(nodes, bridgeMessages, sliceMessages, 6);
  const plannedAnchorHints = memoryProdBuildPlannedAnchorHints(sliceMessages, bridgeMessages, 6);
  const packet = {
    version: 2,
    model: String(cfg?.memoryLearnModel || 'google/gemini-2.5-flash-lite'),
    session: {
      id: trimMemoryText(session?.id || '', 160),
      threadKey: trimMemoryText(session?.threadKey || '', 120),
      sourceTag: trimMemoryText(session?.sourceTag || '', 40),
      startedAt: num(session?.startedAt, 0),
      turnCount: num(session?.turnCount, 0),
      messageCount: Array.isArray(fullMessages) ? fullMessages.length : num(session?.messageCount, 0)
    },
    checkpoint: {
      lastProcessedMessageCount: Math.max(0, num(session?.lastProcessedMessageCount, 0)),
      lastProcessedAt: num(session?.lastProcessedAt, 0),
      lastProcessedMessageSignature: trimMemoryText(session?.lastProcessedMessageSignature || '', 160)
    },
    trigger: {
      reason: trimMemoryText(trigger?.reason || 'manual', 80),
      highSignal: !!trigger?.highSignal,
      manual: !!trigger?.manual,
      metrics: trigger?.metrics || null
    },
    source: {
      threadId: trimMemoryText(payload?.threadId || payload?.chatId || payload?.conversationId || '', 120),
      sourceTag: trimMemoryText(payload?.sourceTag || session?.sourceTag || 'chat', 40),
      triggerReason: trimMemoryText(payload?.triggerReason || '', 80)
    },
    bridgeMessages,
    sliceMessages: Array.isArray(sliceMessages) ? sliceMessages : [],
    assistantText: trimMemoryText(assistantText || '', 1200),
    relevantNodes,
    activeAnchorHints,
    plannedAnchorHints,
    existingSummary: memoryProdBuildExistingMemorySummary(nodes, MEMORY_SCOPE),
    conversationText: '',
    packetPreview: ''
  };
  packet.conversationText = memoryProdBuildExtractionConversationText(packet);
  packet.packetPreview = trimMemoryText(packet.conversationText, MEMORY_EXTRACTION_PACKET_PREVIEW_CHARS);
  return packet;
}

// Async packet builder â€” this is the production path used by the core learning turn.
// It replaces the heuristic shortlist with real semantic shortlist (embeddings), detects
// buried off-topic sentences, computes triage signals, and attaches everything the Pass 1
// prompt + triage router need. If OpenAI embeddings are unavailable, it degrades GRACEFULLY:
// the triage router will see offTopicSentences=[] and competingConceptCount=0 from the
// semantic layer, but the full deterministic triage (correction cues, contradictions,
// action density, life fast lane, slice size) still operates. This preserves architecture
// fidelity â€” we do NOT silently substitute heuristic semantic matching.
async function memoryProdBuildExtractionPacketAsync(env, accessToken, projectId, uid, session, fullMessages, sliceMessages, assistantText, nodes, payload, cfg, trigger) {
  const bridgeMessages = Array.isArray(payload?.bridgeMessagesOverride)
    ? payload.bridgeMessagesOverride
    : memoryProdGetBridgeContextMessages(fullMessages, session, MEMORY_EXTRACTION_BRIDGE_MESSAGE_COUNT);
  const lastUserText = getLastUserMessageText(Array.isArray(sliceMessages) ? sliceMessages : []);
  const bridgeText = (Array.isArray(bridgeMessages) ? bridgeMessages : []).map((m) => String(m?.content || m?.text || '')).join(' ');
  const allSliceUserText = (Array.isArray(sliceMessages) ? sliceMessages : [])
    .filter((m) => String(m?.role || '').toLowerCase() === 'user')
    .map((m) => String(m?.text || m?.content || ''))
    .join('\n');
  const fullSliceText = `${allSliceUserText}\n${lastUserText}`.trim();

  // Real semantic shortlist (embeddings).
  const semantic = await memoryProdSemanticShortlistNodes(env, accessToken, projectId, uid, cfg, fullSliceText, bridgeText, nodes, MEMORY_EMBEDDING_SHORTLIST_TOP_N);
  // Merge with heuristic shortlist as secondary signal (not replacement).
  const heuristicItems = memoryProdFindRelevantNodesForText(lastUserText, bridgeText, nodes, 6);
  const mergedShortlist = (() => {
    const byId = new Map();
    for (const item of semantic.items || []) byId.set(item.id, { ...item, source: 'semantic' });
    for (const h of heuristicItems || []) {
      if (!byId.has(h.id)) byId.set(h.id, { ...h, source: 'heuristic', semanticScore: 0 });
      else byId.get(h.id).source = 'semantic+heuristic';
    }
    return Array.from(byId.values()).sort((a, b) => num(b.semanticScore, 0) - num(a.semanticScore, 0));
  })();
  const activeAnchorHints = memoryProdBuildActiveAnchorHints(nodes, bridgeMessages, sliceMessages, 6);
  const plannedAnchorHints = memoryProdBuildPlannedAnchorHints(sliceMessages, bridgeMessages, 6);

  // Buried off-topic detection.
  const sentences = memoryProdSplitIntoSentences(fullSliceText);
  const offTopicSentences = semantic.available
    ? await memoryProdDetectOffTopicSentences(env, accessToken, projectId, uid, cfg, sentences, nodes, semantic.embeddingMap)
    : [];

  // Triage signals (deterministic + semantic).
  const correctionCue = memoryProdDetectCorrectionCue(fullSliceText);
  const actionDensity = memoryProdCountActionDensity(fullSliceText);
  const stateContradiction = memoryProdDetectStateContradiction(fullSliceText, nodes);
  const lifeFastLane = memoryProdIsLifeMemoryText(fullSliceText);
  const competingConceptCount = memoryProdCountCompetingConcepts(semantic.items || []);
  const sliceChars = memoryProdEstimateSliceChars(sliceMessages, assistantText);

  const triageSignals = {
    correctionCue,
    actionDensity,
    stateContradiction,
    lifeFastLane,
    competingConceptCount,
    offTopicSentences,
    sliceChars,
    semanticAvailable: semantic.available
  };
  const triageDecision = memoryProdClassifyTriageTier(cfg, triageSignals);

  const packet = {
    version: 3,
    model: triageDecision.model,
    session: {
      id: trimMemoryText(session?.id || '', 160),
      threadKey: trimMemoryText(session?.threadKey || '', 120),
      sourceTag: trimMemoryText(session?.sourceTag || '', 40),
      startedAt: num(session?.startedAt, 0),
      turnCount: num(session?.turnCount, 0),
      messageCount: Array.isArray(fullMessages) ? fullMessages.length : num(session?.messageCount, 0)
    },
    checkpoint: {
      lastProcessedMessageCount: Math.max(0, num(session?.lastProcessedMessageCount, 0)),
      lastProcessedAt: num(session?.lastProcessedAt, 0),
      lastProcessedMessageSignature: trimMemoryText(session?.lastProcessedMessageSignature || '', 160)
    },
    trigger: {
      reason: trimMemoryText(trigger?.reason || 'manual', 80),
      highSignal: !!trigger?.highSignal,
      manual: !!trigger?.manual,
      metrics: trigger?.metrics || null
    },
    source: {
      threadId: trimMemoryText(payload?.threadId || payload?.chatId || payload?.conversationId || '', 120),
      sourceTag: trimMemoryText(payload?.sourceTag || session?.sourceTag || 'chat', 40),
      triggerReason: trimMemoryText(payload?.triggerReason || '', 80)
    },
    bridgeMessages,
    sliceMessages: Array.isArray(sliceMessages) ? sliceMessages : [],
    assistantText: trimMemoryText(assistantText || '', 1200),
    relevantNodes: mergedShortlist.slice(0, 10),
    activeAnchorHints,
    plannedAnchorHints,
    offTopicSentences,
    triageTags: {
      tier: triageDecision.tier,
      model: triageDecision.model,
      reasons: triageDecision.reasons,
      signals: {
        correctionCue,
        actionDensity,
        stateContradictionKind: stateContradiction?.kind || '',
        lifeFastLane,
        competingConceptCount,
        offTopicCount: offTopicSentences.length,
        sliceChars,
        semanticAvailable: semantic.available
      }
    },
    existingSummary: memoryProdBuildExistingMemorySummary(nodes, MEMORY_SCOPE),
    conversationText: '',
    packetPreview: '',
    // Expose semantic artifacts to downstream so we don't re-embed.
    _semantic: {
      available: semantic.available,
      embeddingMap: semantic.embeddingMap,
      sliceEmbedding: semantic.sliceEmbedding
    },
    _triageDecision: triageDecision
  };
  packet.conversationText = memoryProdBuildExtractionConversationText(packet);
  packet.packetPreview = trimMemoryText(packet.conversationText, MEMORY_EXTRACTION_PACKET_PREVIEW_CHARS);
  return packet;
}

function memoryProdClassifyExtractionTrigger(session, fullMessages, sliceMessages, assistantText, payload, cfg) {
  const nowMs = num(payload?.nowMs, Date.now());
  const safeSlice = Array.isArray(sliceMessages) ? sliceMessages : [];
  const minChars = Math.max(80, num(cfg?.memoryExtractMinMeaningfulChars, MEMORY_EXTRACTION_MIN_MEANINGFUL_CHARS_DEFAULT));
  const minUserMessages = Math.max(1, num(cfg?.memoryExtractMinUserMessages, MEMORY_EXTRACTION_MIN_USER_MESSAGES_DEFAULT));
  const overflowMessages = Math.max(6, num(cfg?.memoryExtractOverflowMessages, MEMORY_EXTRACTION_OVERFLOW_MSGS_DEFAULT));
  const overflowChars = Math.max(1200, num(cfg?.memoryExtractOverflowChars, MEMORY_EXTRACTION_OVERFLOW_CHARS_DEFAULT));
  const idleMs = Math.max(60 * 1000, num(cfg?.memoryExtractIdleMs, MEMORY_EXTRACTION_IDLE_MS_DEFAULT));
  const longActiveMs = Math.max(10 * 60 * 1000, num(cfg?.memoryExtractLongActiveMs, MEMORY_EXTRACTION_LONG_ACTIVE_MS_DEFAULT));
  const cooldownMs = 0;
  const meaningfulUserMessages = memoryProdCountMeaningfulUserMessages(safeSlice);
  const sliceChars = memoryProdEstimateSliceChars(safeSlice, assistantText);
  const combinedPreviewText = `${getLastUserMessageText(safeSlice)}
${trimMemoryText(assistantText || '', 500)}`;
  const highSignal = memoryProdHasHighSignalCue(combinedPreviewText);
  const lastProcessedAt = num(session?.lastProcessedAt || session?.prevLastProcessedAt, 0);
  const previousLastActivityAt = num(session?.prevLastActivityAt, 0);
  const idleGapMs = previousLastActivityAt > 0 ? Math.max(0, nowMs - previousLastActivityAt) : 0;
  const activeSinceMs = Math.max(num(session?.startedAt, nowMs), lastProcessedAt || num(session?.startedAt, nowMs));
  const activeDurationMs = Math.max(0, nowMs - activeSinceMs);
  const manual = payload?.forceExtract === true || /background|leave|flush|thread_switch|manual/.test(String(payload?.triggerReason || '').toLowerCase());
  const metrics = {
    sliceMessages: safeSlice.length,
    sliceChars,
    meaningfulUserMessages,
    idleGapMs,
    activeDurationMs,
    cooldownRemainingMs: 0
  };
  if (!safeSlice.length) return { shouldExtract: false, reason: 'checkpoint_no_new_slice', highSignal, manual, metrics };
  // Prevent assistant-only length inflation from triggering learning on trivial user turns.
  // The caller can safely advance the backend cursor for this exact reason.
  if (!manual && !highSignal && meaningfulUserMessages === 0 && memoryProdSliceHasOnlyTrivialUserContent(safeSlice)) {
    return { shouldExtract: false, reason: 'trivial_user_only', highSignal, manual, metrics };
  }
  // ARCH Â§5 â€” Pure utility skip. weather/translate/calculate/rewrite/etc. without personal
  // anchors should answer normally but never enter memory. Cursor advances for noise so the
  // same packet is not re-evaluated next turn (handled at the caller via cursorAdvancedForNoise).
  if (!manual && !highSignal) {
    const lastUserUtilityText = getLastUserMessageText(safeSlice);
    if (lastUserUtilityText && memoryProdIsPureUtilityUserText(lastUserUtilityText)) {
      return { shouldExtract: false, reason: 'pure_utility_skip', highSignal, manual, metrics };
    }
  }
  // SURGICAL PATCH: Fresh-UID strong first message must always extract.
  // Previously, "I'm building GPMai" (35 chars, 1 message) was silently deferred because
  // none of the 3 conditions below matched (sliceChars >= 220, meaningfulUserMessages >= 2,
  // slice.length >= 3). The high-signal path technically existed but depended on a regex
  // that missed contractions. Now: if this is genuinely the first processed slice on this
  // session (no lastProcessedAt) AND the message is not trivial AND has at least a few real
  // words, we extract immediately with reason 'fresh_session_first_meaningful'.
  const lastUserText = getLastUserMessageText(safeSlice);
  const lastUserNotTrivial = lastUserText && !memoryProdUserTextLooksTrivial(lastUserText);
  const implicitReferenceCue = lastUserNotTrivial && memoryProdHasImplicitNodeReferenceCue(lastUserText);
  metrics.implicitReferenceCue = !!implicitReferenceCue;
  if (implicitReferenceCue && meaningfulUserMessages >= 1 && !memoryProdIsPureUtilityUserText(lastUserText)) {
    return { shouldExtract: true, reason: 'reference_update_detected', highSignal, manual, metrics };
  }
  if (!lastProcessedAt && lastUserNotTrivial && meaningfulUserMessages >= 1 && sliceChars >= 20) {
    return { shouldExtract: true, reason: 'fresh_session_first_meaningful', highSignal, manual, metrics };
  }
  if (!manual && meaningfulUserMessages < minUserMessages && sliceChars < minChars && !highSignal) {
    return { shouldExtract: false, reason: 'minimum_slice_guard', highSignal, manual, metrics };
  }
  if (manual) return { shouldExtract: true, reason: payload?.triggerReason || 'manual_flush', highSignal, manual, metrics };
  if (highSignal) return { shouldExtract: true, reason: 'high_signal_priority', highSignal, manual, metrics };
  if (!lastProcessedAt && (sliceChars >= Math.max(minChars, 220) || meaningfulUserMessages >= 2 || safeSlice.length >= 3)) {
    return { shouldExtract: true, reason: 'initial_meaningful_slice', highSignal, manual, metrics };
  }
  if (safeSlice.length >= overflowMessages || sliceChars >= overflowChars) {
    return { shouldExtract: true, reason: 'slice_overflow', highSignal, manual, metrics };
  }
  if (idleGapMs >= idleMs) {
    return { shouldExtract: true, reason: 'idle_pause', highSignal, manual, metrics };
  }
  if (activeDurationMs >= longActiveMs && sliceChars >= minChars) {
    return { shouldExtract: true, reason: 'long_active_chat', highSignal, manual, metrics };
  }
  return { shouldExtract: false, reason: 'awaiting_trigger', highSignal, manual, metrics };
}

function memoryProdHasPreferenceCue(text) {
  const hay = String(text || '').toLowerCase();
  return /\b(i prefer|i like|i love|i hate|i dislike|favorite|favourite|i enjoy|i don't like|i dont like)\b/.test(hay);
}

function memoryProdIsLifeMemoryText(text) {
  const hay = String(text || '').toLowerCase();
  if (!hay) return false;
  // SURGICAL PATCH E2: Expanded semantic variants for grief/loss/diagnosis/trauma.
  // Previously missed: "i lost", "is no longer with us", "passed on", "we lost",
  // "say goodbye to", "we buried", "funeral for", etc.
  return /(diagnos|diagnosed|disorder|therapy|medication|medicine|allerg|migraine|asthma|diabetes|ocd|adhd|autis|anxiety|depress|ptsd|panic|insomnia|trauma|abuse|grief|grieving|bereav|funeral|died|death|passed away|pass away|passed on|passed on from|is no longer with us|no longer with us|we lost|i lost (my|our)|lost my|lost our|loss of|say goodbye to|said goodbye to|saying goodbye to|we buried|had to bury|i buried|gone too soon|breakup|broke up|broken up|divorce|divorced|separat|family problem|family crisis|parents are|mother is sick|father is sick|surgery|hospital|injury|accident|car accident|chronic|condition|illness|abusive|caregiver|caretaker|miscarriage|stillbirth|terminal|hospice)/.test(hay);
}

function memoryProdUserTextLooksTrivial(text) {
  const clean = trimMemoryText(text, 280).toLowerCase();
  const rawTrim = String(text || '').trim();
  const words = clean.split(/\s+/).filter(Boolean);
  if (!clean) return true;
  // High-signal cues override trivial classification
  if (memoryProdHasHighSignalCue(clean) || memoryProdIsLifeMemoryText(clean) || memoryProdHasPreferenceCue(clean)) return false;
  // Emoji-only or near-emoji-only messages
  try {
    const strippedOfEmoji = rawTrim.replace(/[\p{Extended_Pictographic}\p{Emoji_Presentation}\uFE0F\u200D]/gu, '').trim();
    if (rawTrim.length > 0 && strippedOfEmoji.length < 3) return true;
  } catch (_) { /* regex unicode not supported, skip */ }
  // Short acknowledgement/chatter patterns (expanded)
  if (/^(hi+|hello+|hey+|yo|sup|ok|okay|k|kk|hmm+|huh|lol+|lmao|haha+|nice|cool|great|awesome|thanks|thank you|ty|thx|what are you doing|wyd|bro|dude|bruh|alright|alrighty|fine|sure|yep|yup|yeah|yea|nope|nah|no|yes|sup bro|ok bro|nice bro|thanks bro|nice claude|ok claude|good claude|cool claude|got it|gotcha|ic|i see|same|true|exactly|agreed|right|makes sense|understood|sounds good|will do|on it|wdym|idk|idc|omg|wtf|fr|ong|fyi|btw|tbh|imo|ikr)\b/.test(clean)) return true;
  // Conversational meta-phrases directed at the assistant
  if (/\b(you are|you're|u r|ur|you)\s+(so\s+|really\s+|very\s+)?(good|bad|cool|funny|smart|dumb|amazing|awesome|great|nice|helpful|annoying|useful|useless|wrong|right)\b/.test(clean) && words.length < 9) return true;
  // Pure filler question addressed at assistant
  if (/^(are you there|you there|hello\??|are you working|you working)/.test(clean) && words.length < 6) return true;
  // Very short messages without substance
  if (words.length < 4 && clean.length < 28) return true;
  // Pure punctuation/symbol messages
  if (/^[\s\W_]+$/.test(rawTrim) && rawTrim.length < 10) return true;
  return false;
}

function memoryProdIsPureUtilityUserText(text) {
  // ARCH Â§5 â€” Pure utility skip. Detects task-only requests (weather/translate/calculate/
  // rewrite/summarize/explain-code) the app should answer but memory must not store as
  // candidate/node/slice/event. Conservative: returns true ONLY when the message matches
  // a utility pattern AND lacks any personal anchor (high-signal cue, life event,
  // preference, possessive 'my/our X' reference) that would make it "utility + personal
  // context" per PDF Â§5.
  const raw = trimMemoryText(text, 280).toLowerCase().replace(/[\u2019]/g, "'");
  if (!raw) return false;
  // Personal-context override: if the message also carries a real anchor or life cue,
  // it is NOT pure utility â€” let the regular trigger logic decide.
  if (memoryProdHasHighSignalCue(raw)) return false;
  if (memoryProdIsLifeMemoryText(raw)) return false;
  if (memoryProdHasPreferenceCue(raw)) return false;
  // Possessive-anchor override: "for my X", "of my X", "my X tomorrow/today/yesterday".
  // Per Â§5 the example "weather for my football match tomorrow" must NOT skip â€” the
  // football match deserves its own memory consideration even if the weather does not.
  // We treat any "my <word longer than 2 chars>" as a personal anchor signal that
  // pulls the message out of the pure-utility lane.
  if (/\b(?:my|our)\s+[a-z][a-z0-9'-]{2,}/.test(raw)) return false;
  // Conservative utility patterns covering the Â§5 examples plus common variants.
  const patterns = [
    /^(?:what(?:'s| is| are)?|how(?:'s| is| are)?|hows)\s+(?:the\s+)?(?:weather|temperature|forecast|humidity|rain|wind|climate)\b/,
    /\b(?:translate|translation of)\b\s+(?:this|that|the following|to|into)/,
    /\b(?:calculate|compute)\s+(?:[\d.]|what)/,
    /\bwhat(?:'s| is)\s+\d+\s*[\+\-\*\/x%]\s*\d+/,
    /\b\d+\s*%\s+of\s+\d+/,
    /\b(?:rewrite|reword|rephrase|paraphrase)\s+(?:this|that|the following|my)/,
    /\b(?:summari[sz]e|tl;dr|tldr)\s+(?:this|that|the following|the article|the text|the doc|the document|the paragraph|the email|it)/,
    /\b(?:explain|describe|what does)\s+(?:this|that|the following|the)\s+(?:code|function|snippet|error|stack ?trace|log|regex|formula)/,
    /\b(?:fix|debug|optimi[sz]e|format|lint|refactor)\s+(?:this|that|the following|my)\s+(?:code|function|snippet|sql|query|regex)/,
    /\b(?:convert|encode|decode|parse)\s+(?:this|that|the following|to|from)/,
    /\b(?:define|definition of|meaning of)\s+(?:this|that|the word|the term)\b/
  ];
  for (const re of patterns) if (re.test(raw)) return true;
  return false;
}

function memoryProdSanitizeClusterHint(value, label = '', group = '', info = '') {
  const raw = normalizeMemoryKey(trimMemoryText(value || '', 40)).replace(/_/g, ' ');
  const aliasMap = {
    work: 'work', software: 'work', app: 'work', apps: 'work', product: 'work', startup: 'work', business: 'work', tech: 'work', coding: 'work', development: 'work',
    study: 'learning', learning: 'learning', education: 'learning', exam: 'learning', skill: 'learning',
    health: 'health', medical: 'health', medicine: 'health', disorder: 'health', mental_health: 'health', wellbeing: 'health',
    sport: 'sports', sports: 'sports', boxing: 'sports', football: 'sports', fitness: 'sports', technique: 'sports',
    finance: 'finance', money: 'finance',
    relationship: 'relationships', relationships: 'relationships', family: 'relationships', social: 'relationships',
    personal: 'personal', identity: 'personal', self: 'personal',
    general: 'general'
  };
  const inferred = aliasMap[raw] || inferClusterIdForNode(label, group, `${value || ''} ${info || ''}`);
  return MEMORY_ALLOWED_CLUSTERS.has(inferred) ? inferred : 'general';
}

function memoryProdApplyFastLaneProfile(item, userText = '') {
  const safe = { ...(item || {}) };
  const hay = `${safe.label || ''} ${safe.summaryHint || ''} ${userText || ''}`.toLowerCase();
  const lowerUser = String(userText || '').toLowerCase();
  let directDurable = !!safe.directDurable;
  let importanceHint = trimMemoryText(safe.importanceHint || '', 40);
  let roleGuess = memoryProdNormalizeMemoryGroup(safe.roleGuess || safe.group || 'interest');
  let clusterHint = memoryProdSanitizeClusterHint(safe.clusterHint, safe.label, roleGuess, safe.summaryHint || '');
  const eventHint = {
    worthy: !!safe?.eventHint?.worthy,
    action: trimMemoryText(safe?.eventHint?.action || '', 40),
    summary: trimMemoryText(safe?.eventHint?.summary || safe.summaryHint || '', 220),
    timeText: trimMemoryText(safe?.eventHint?.timeText || '', 80),
    eventType: trimMemoryText(safe?.eventHint?.eventType || '', 60)
  };

  if (/(diagnos|disorder|therapy|medication|medicine|allerg|migraine|asthma|diabetes|ocd|adhd|autis|anxiety|depress|ptsd|panic|insomnia|surgery|hospital|injury|chronic|condition|illness)/.test(hay)) {
    directDurable = true;
    importanceHint = importanceHint || 'important';
    clusterHint = 'health';
    if (/(diagnos|therapy|medication|medicine|surgery|hospital|injury|allerg)/.test(lowerUser) || /(diagnos|therapy|medication|medicine|surgery|hospital|injury|allerg)/.test(hay)) {
      eventHint.worthy = true;
      eventHint.eventType = eventHint.eventType || 'health_update';
      eventHint.summary = trimMemoryText(eventHint.summary || `Health update related to ${safe.label || 'health'}`, 220);
    }
  }
  if (/(trauma|abuse|grief|bereav|funeral|died|death|passed away|pass away|lost my|loss of|breakup|broke up|divorce|divorced|separat|family problem|family crisis|parents are getting divorced|caregiver|caretaker|abusive|grandfather died|grandmother died|mother died|father died|car accident|accident)/.test(hay)) {
    directDurable = true;
    importanceHint = 'life_significant';
    clusterHint = /(family|parent|mother|father|grandfather|grandmother|brother|sister|relationship|breakup|divorce)/.test(hay) ? 'relationships' : (clusterHint || 'personal');
    eventHint.worthy = true;
    eventHint.eventType = eventHint.eventType || 'life_event';
    eventHint.summary = trimMemoryText(eventHint.summary || (safe.summaryHint || userText || safe.label || 'Major life event'), 220);
  }
  if (memoryProdHasPreferenceCue(userText || hay)) {
    directDurable = true;
    importanceHint = importanceHint || 'important';
    roleGuess = roleGuess === 'identity' ? 'identity' : 'preference';
  }
  if (/(\b(i am|iâ€™m|im|i'm)\b|\b(i work as|working as|i study|studying|i train to be|i'm training to be|training to be)\b)/.test(String(userText || '').toLowerCase()) && /(student|founder|developer|designer|creator|boxer|athlete|muslim|hindu|christian|autistic|adhd|engineer|doctor|nurse|teacher|writer|programmer)/.test(hay)) {
    directDurable = true;
    importanceHint = importanceHint || 'important';
    roleGuess = 'identity';
    clusterHint = clusterHint || 'personal';
  }

  if (!eventHint.worthy && directDurable && /(death|died|passed away|pass away|lost my|breakup|broke up|divorce|divorced|separat|trauma|abuse|diagnos|diagnosed|surgery|injury|accident|medicine|medication|allerg)/.test(hay)) {
    eventHint.worthy = true;
    eventHint.eventType = eventHint.eventType || (clusterHint === 'health' ? 'health_update' : 'life_event');
    eventHint.summary = trimMemoryText(eventHint.summary || (safe.summaryHint || userText || safe.label || 'Important life update'), 220);
  }

  return {
    ...safe,
    roleGuess,
    clusterHint,
    directDurable,
    eventHint,
    importanceHint: importanceHint || inferImportanceForLabel(safe.label || '', roleGuess, safe.summaryHint || ''),
    strength: directDurable ? 'strong' : memoryProdNormalizeStrength(safe.strength || 'medium')
  };
}

function memoryProdIsBlockedCandidateLabel(label) {
  const raw = trimMemoryText(label || '', 80);
  const key = normalizeMemoryKey(raw);
  if (!key) return true;
  if (MEMORY_BLOCKED_CANDIDATE_KEYS.has(key)) return true;
  if (MEMORY_BLOCKED_CANDIDATE_REGEX.test(raw)) return true;
  // Pure greeting/ack patterns with optional punctuation
  if (/^(hi|hello|hey|yo|ok|okay|thanks|thank_you|wyd|bye|goodbye|sup)$/.test(key)) return true;
  // Labels that are just pronouns or filler
  if (/^(he|she|they|it|we|us|them|you|me|my|your|our|their|this|that|these|those)$/.test(key)) return true;
  // Pure emoji or symbols after normalization
  if (!/[a-z0-9]/.test(key)) return true;
  return false;
}

function memoryProdTokenOverlapCount(a, b) {
  const sa = new Set(memoryProdTokenizeForMatch(a));
  const sb = new Set(memoryProdTokenizeForMatch(b));
  let overlap = 0;
  for (const token of sa) if (sb.has(token)) overlap += 1;
  return overlap;
}

function memoryProdMergeSummaryHints(base, addition, maxLen = 260) {
  const a = trimMemoryText(base || '', maxLen);
  const b = trimMemoryText(addition || '', maxLen);
  if (!a) return b;
  if (!b) return a;
  if (normalizeMemoryKey(a) === normalizeMemoryKey(b)) return a;
  if (a.toLowerCase().includes(b.toLowerCase())) return a;
  if (b.toLowerCase().includes(a.toLowerCase())) return b;
  return trimMemoryText(`${a} | ${b}`, maxLen);
}

function memoryProdNormalizeNodeInfoFragment(text = '') {
  return trimMemoryText(String(text || '')
    .replace(/[â€œâ€]/g, '"')
    .replace(/[â€™]/g, "'")
    .replace(/\breq\b/ig, 'requirements')
    .replace(/\bsummry\b/ig, 'summary')
    .replace(/\bfast\s+summary\b/ig, 'fast summaries')
    .replace(/\s+/g, ' ')
    .replace(/^[|;:,.\s]+|[|;:,.\s]+$/g, '')
    .trim(), 260);
}

function memoryProdStableAnchorLabel(anchorLabel = '') {
  const clean = trimMemoryText(anchorLabel || '', 80);
  return clean ? clean.charAt(0).toUpperCase() + clean.slice(1) : 'This node';
}

function memoryProdSummaryFactKey(summary = '', anchorLabel = '') {
  const anchorKey = normalizeMemoryKey(anchorLabel || '');
  let key = normalizeMemoryKey(summary || '');
  if (!key) return '';
  if (anchorKey) key = key.replace(new RegExp(`(^|_)${anchorKey}(_|$)`, 'g'), '_');
  key = key
    .replace(/^(user_)?(i_)?(started|start|building|build|built|working_on|work_on|created|creating|making|make)_+/g, 'start_')
    .replace(/_?(an?|the)_?(app|project|tool|product|system)_?(called|named)?_?/g, '_')
    .replace(/_?(called|named)_?/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '');
  if (/\b(started|building|build|built|working on|app called|project called)\b/i.test(summary || '')) return `identity:${anchorKey || key}`;
  const core = String(summary || '').match(/\bcore\s+feature\s+(?:is|of\s+.+?\s+is)\s+(.{2,80})/i) || String(summary || '').match(/\bfeature\s+(?:called|named|is)\s+(.{2,80})/i);
  if (core?.[1]) return `core_feature:${normalizeMemoryKey(core[1])}`;
  const can = String(summary || '').match(/\b(?:can|could|will)\s+(.{2,120})/i);
  if (can?.[1]) return `capability:${normalizeMemoryKey(can[1])}`;
  const uses = String(summary || '').match(/\buses?\s+(.{2,100})/i);
  if (uses?.[1]) return `uses:${normalizeMemoryKey(uses[1])}`;
  return key;
}

function memoryProdEscapeRegExp(value = '') {
  return String(value || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function memoryProdCanonicalNodeInfoFact(summary = '', anchorLabel = '') {
  const anchor = memoryProdStableAnchorLabel(anchorLabel);
  const raw = memoryProdNormalizeNodeInfoFragment(summary);
  if (!raw) return '';
  const lower = raw.toLowerCase();
  if (/\b(started|building|build|built|working on|creating|making)\b.*\b(app|project|tool|product|system)\b/.test(lower) || /\b(app|project|tool|product|system)\s+(called|named)\b/.test(lower)) {
    return `${anchor} is an app project.`;
  }
  const anchorEsc = memoryProdEscapeRegExp(anchor);
  const possessiveCore = raw.match(new RegExp(`^${anchorEsc}['â€™]s\\s+core\\s+feature\\s+is\\s+(.{2,100})`, 'i'));
  if (possessiveCore?.[1]) return trimMemoryText(`Core feature is ${memoryProdNormalizeNodeInfoFragment(possessiveCore[1]).replace(/\.$/, '')}.`, 160);
  const core = raw.match(/\bcore\s+feature\s+(?:is|of\s+.+?\s+is)\s+(.{2,100})/i) || raw.match(/\bfeature\s+(?:called|named|is)\s+(.{2,100})/i);
  if (core?.[1]) return trimMemoryText(`Core feature is ${memoryProdNormalizeNodeInfoFragment(core[1]).replace(/\.$/, '')}.`, 160);
  const can = raw.match(new RegExp(`^${anchorEsc}\\s+can\\s+(.{2,140})`, 'i')) || raw.match(/\b(?:this app|that app|it|the app)\s+can\s+(.{2,140})/i);
  if (can?.[1]) return trimMemoryText(`It can ${memoryProdNormalizeNodeInfoFragment(can[1]).replace(/^can\s+/i, '').replace(/\.$/, '')}.`, 180);
  if (/\|/.test(raw)) return '';
  return raw.endsWith('.') ? raw : `${raw}.`;
}

function memoryProdSplitInfoFacts(info = '') {
  return String(info || '')
    .replace(/\s+\|\s+/g, '. ')
    .split(/(?:\n+|(?<=[.!?])\s+|\s*;\s*)/)
    .map((x) => memoryProdNormalizeNodeInfoFragment(x))
    .filter(Boolean);
}

function memoryProdMergeStableNodeInfo(existingInfo = '', newSummary = '', anchorLabel = '', maxLen = 520) {
  const facts = [];
  const seen = new Set();
  const add = (text) => {
    const fact = memoryProdCanonicalNodeInfoFact(text, anchorLabel);
    if (!fact) return;
    const key = memoryProdSummaryFactKey(fact, anchorLabel);
    if (!key || seen.has(key)) return;
    seen.add(key);
    facts.push(fact);
  };
  for (const part of memoryProdSplitInfoFacts(existingInfo)) add(part);
  add(newSummary);
  if (!facts.length) return trimMemoryText(memoryProdNormalizeNodeInfoFragment(newSummary || existingInfo), maxLen);
  const identityKey = `identity:${normalizeMemoryKey(anchorLabel || '')}`;
  facts.sort((a, b) => (memoryProdSummaryFactKey(a, anchorLabel) === identityKey ? 0 : 1) - (memoryProdSummaryFactKey(b, anchorLabel) === identityKey ? 0 : 1));
  return trimMemoryText(facts.slice(0, 6).join(' '), maxLen);
}

function memoryProdInitialNodeInfo(label = '', group = '', summary = '') {
  const clean = memoryProdMergeStableNodeInfo('', summary, label, 260);
  if (clean) return clean;
  const anchor = memoryProdStableAnchorLabel(label);
  const g = memoryProdNormalizeMemoryGroup(group || 'interest');
  if (g === 'project') return `${anchor} is a project.`;
  if (g === 'skill') return `${anchor} is a skill the user is working on.`;
  if (g === 'goal') return `${anchor} is a goal.`;
  return trimMemoryText(summary || '', 220);
}

function memoryProdCleanNodeInfoForPrompt(info = '', anchorLabel = '') {
  return memoryProdMergeStableNodeInfo('', info, anchorLabel, 520);
}

function memoryProdCandidatePriority(item, userText = '') {
  const safe = item || {};
  let score = 0;
  if (safe.directDurable) score += 90;
  if (String(safe.importanceHint || '') === 'life_significant') score += 50;
  if (String(safe.importanceHint || '') === 'important') score += 20;
  if (safe.eventHint?.worthy) score += 18;
  if (memoryProdHasHighSignalCue(userText)) score += 12;
  if (memoryProdNormalizeStrength(safe.strength) === 'strong') score += 12;
  const group = memoryProdNormalizeMemoryGroup(safe.roleGuess || safe.group || 'interest');
  if (['project', 'goal', 'identity', 'preference', 'habit'].includes(group)) score += 10;
  score += Math.min(8, memoryProdTokenizeForMatch(safe.label || '').length);
  return score;
}

function memoryProdShouldMergeCandidateIntoPrimary(primary, candidate) {
  if (!primary || !candidate) return false;
  if (candidate.directDurable) return false;
  const primaryKey = normalizeMemoryKey(primary.label || '');
  const candidateKey = normalizeMemoryKey(candidate.label || '');
  if (!primaryKey || !candidateKey || primaryKey === candidateKey) return true;
  if (candidate.parentHint && normalizeMemoryKey(candidate.parentHint) === primaryKey) return true;
  if (candidateKey.includes(primaryKey) || primaryKey.includes(candidateKey)) return true;
  const labelOverlap = memoryProdTokenOverlapCount(primary.label || '', candidate.label || '');
  const summaryOverlap = memoryProdTokenOverlapCount(primary.summaryHint || '', candidate.summaryHint || '');
  if (labelOverlap >= 1 && primary.clusterHint === candidate.clusterHint) return true;
  if (summaryOverlap >= 2 && primary.clusterHint === candidate.clusterHint) return true;
  if (primary.clusterHint === candidate.clusterHint && memoryProdNormalizeMemoryGroup(primary.roleGuess) === memoryProdNormalizeMemoryGroup(candidate.roleGuess) && labelOverlap >= 1) return true;
  return false;
}

function memoryProdAbsorbCandidate(primary, candidate) {
  primary.summaryHint = memoryProdMergeSummaryHints(primary.summaryHint || '', candidate.summaryHint || '', 260);
  primary.eventHint = primary.eventHint || { worthy: false, action: '', summary: '', timeText: '', eventType: '' };
  if (candidate.eventHint?.worthy) {
    primary.eventHint.worthy = true;
    if (!primary.eventHint.action) primary.eventHint.action = candidate.eventHint.action || '';
    primary.eventHint.summary = memoryProdMergeSummaryHints(primary.eventHint.summary || '', candidate.eventHint.summary || candidate.summaryHint || '', 220);
    if (!primary.eventHint.eventType) primary.eventHint.eventType = candidate.eventHint.eventType || '';
    if (!primary.eventHint.timeText) primary.eventHint.timeText = candidate.eventHint.timeText || '';
  }
  if (!primary.parentHint && candidate.parentHint) primary.parentHint = candidate.parentHint;
  if ((!primary.clusterHint || primary.clusterHint === 'general') && candidate.clusterHint) primary.clusterHint = candidate.clusterHint;
  primary.relationHints = [...(Array.isArray(primary.relationHints) ? primary.relationHints : []), ...(Array.isArray(candidate.relationHints) ? candidate.relationHints : [])];
  primary.aliases = boundedUniqueIds([...(Array.isArray(primary.aliases) ? primary.aliases : []), candidate.label], 12);
  return primary;
}

function memoryProdLooksGenericScopedLabel(label) {
  const key = normalizeMemoryKey(label || '');
  if (!key) return false;
  // Candidate is now rare and clear routines / habits may be durable nodes.
  // Only treat truly unanchored scoped phrases or motivational filler as bad anchors.
  if (/^(practice_everyday|practice_every_day|practice_daily|daily_practice|work_everyday|work_every_day|study_everyday|study_every_day|train_everyday|train_every_day|routine_goal|be_consistent|stay_focused|stay_consistent|keep_going|work_hard|try_hard|do_better|improve_myself|self_improvement|get_better|push_myself|give_my_best|do_my_best|my_goal|my_plan|my_schedule|move_forward|level_up|grow_more)$/.test(key)) return true;
  if (/\b(be_consistent|stay_focused|keep_going|work_hard|try_hard|do_better|improve_myself|get_better|push_myself|give_my_best|do_my_best)\b/.test(key) && memoryProdTokenizeForMatch(key).length <= 4) return true;
  return false;
}


function memoryProdCleanConceptPhrase(value) {
  const raw = trimMemoryText(value || '', 80)
    .replace(/^(to\s+|the\s+|a\s+|an\s+)/i, '')
    .replace(/\b(every day|everyday|daily|again|today|now|more|better)\b/ig, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  if (!raw) return '';
  const tokens = memoryProdTokenizeForMatch(raw);
  if (!tokens.length) return '';
  return trimMemoryText(tokens.join(' '), 60);
}

// V3.3.3 â€” Canonical label + snap safety helpers.
// Deterministic backend guards: normalize action-wrapped labels before matching,
// then snap to existing memory so reinforce paths win over duplicate creation.
const MEMORY_ABSTRACT_AMBITION_RE = /^(?:do\s+|create\s+|build\s+|make\s+)?(?:some\s+)?(?:something|anything|things?|stuff)(?:\s+(?:that|which|like)\b.*)?$/i;
const MEMORY_CONCRETE_AMBITION_RE = /\bscience\s+research\b/i;
const MEMORY_ACTION_LABEL_PREFIX_RE = /^(?:(?:i\s+)?(?:want\s+to|wanna|going\s+to|gonna|planning\s+to|trying\s+to|hope\s+to|hoping\s+to|would\s+like\s+to|to)\s+|(?:learn|learning|learned|study|studying|studied|practice|practicing|practising|practiced|practised|play|playing|played|do|doing|done|build|building|built|work\s+on|working\s+on|worked\s+on|use|using|used|start|started|starting|stop|stopped|quit|paused|pausing|resume|resumed|resuming)\s+)/i;
const MEMORY_LABEL_FILLER_RE = /\b(?:today|now|again|daily|every\s+day|everyday|someday|eventually|more|better)\b/ig;
const MEMORY_TRANSIENT_DETAIL_RE = /\b(?:injur(?:y|ed)|pain|hurt|sprain|strain|rehab|physio|doctor|diagnosed|mri|surgery|bug|error|issue|fix(?:ed)?|login\s+bug|auth\s+bug|hook\s+punch|jab|blocker|problem|milestone)\b/i;
const MEMORY_INJURY_PERSISTENCE_RE = /\b(?:still\s+hurts?|rehab|physio|doctor|diagnosed|mri|surgery|chronic|for\s+\d+\s+(?:weeks?|months?)|\d+\s+(?:weeks?|months?)|weeks?|months?)\b/i;

function memoryProdTitleCaseLabelFromKey(key) {
  return trimMemoryText(String(key || '').replace(/_/g, ' ').replace(/\s+/g, ' ').trim().split(' ').filter(Boolean).map((part) => {
    if (/^[a-z]{2,4}$/i.test(part) && /^(api|ui|ux|ai|ml|dm|id|jwt|mri)$/i.test(part)) return part.toUpperCase();
    return part.charAt(0).toUpperCase() + part.slice(1);
  }).join(' '), 80);
}

function memoryProdPreserveCanonicalCasing(label, userText = '') {
  const clean = trimMemoryText(label || '', 80);
  if (!clean) return '';
  const source = String(userText || '');
  try {
    const escaped = clean.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\s+/g, '\\s+');
    const m = source.match(new RegExp('\\b(' + escaped + ')\\b', 'i'));
    if (m && m[1]) return trimMemoryText(m[1], 80);
  } catch (_) {}
  return clean;
}

function memoryProdIsAbstractAmbitionLabel(label) {
  const clean = String(label || '').toLowerCase().replace(/[^a-z0-9\s]+/g, ' ').replace(/\s+/g, ' ').trim();
  if (!clean) return false;
  return MEMORY_ABSTRACT_AMBITION_RE.test(clean)
    || /^something\s+(?:big|great|amazing|important)$/.test(clean)
    || /^(?:things?|something|stuff)\s+that\s+(?:shock|change|impact|move|help|fix|improve)\b/.test(clean);
}

function memoryProdCanonicalizeLabel(rawLabel, userText = '') {
  const raw = trimMemoryText(rawLabel || '', 80);
  const text = String(userText || '');
  if (!raw) return { canonical: '', normalizedKey: '', raw, wasModified: false, droppedPrefix: '', droppedSuffix: '', vetoSignal: 'empty_label' };
  const rawKey = normalizeMemoryKey(raw);
  const lowerRaw = raw.toLowerCase().replace(/[^a-z0-9\s]+/g, ' ').replace(/\s+/g, ' ').trim();

  // Concrete ambition salvage: keep the real anchor, veto the vague world-changing phrase.
  if (MEMORY_CONCRETE_AMBITION_RE.test(text) && /^(science|research|science\s+research|science\s+research\s+goal)$/i.test(lowerRaw)) {
    return { canonical: 'Science Research Goal', normalizedKey: normalizeMemoryKey('Science Research Goal'), raw, wasModified: normalizeMemoryKey(raw) !== normalizeMemoryKey('Science Research Goal'), droppedPrefix: '', droppedSuffix: '', vetoSignal: null };
  }
  if (memoryProdIsAbstractAmbitionLabel(raw)) {
    return { canonical: raw, normalizedKey: rawKey, raw, wasModified: false, droppedPrefix: '', droppedSuffix: '', vetoSignal: 'abstract_ambition' };
  }

  let working = raw.replace(/[â€™]/g, "'").replace(/\s+/g, ' ').trim();
  let droppedPrefix = '';
  for (let i = 0; i < 4; i++) {
    const before = working;
    working = working.replace(MEMORY_ACTION_LABEL_PREFIX_RE, (m) => {
      droppedPrefix = trimMemoryText((droppedPrefix + ' ' + m).trim(), 80);
      return '';
    }).trim();
    if (before === working) break;
  }
  const beforeFillers = working;
  working = working.replace(MEMORY_LABEL_FILLER_RE, ' ').replace(/\s+/g, ' ').trim();
  const droppedSuffix = beforeFillers !== working ? 'time_filler' : '';
  working = working.replace(/^(?:the|a|an|my|your|our)\s+/i, '').trim();
  if (!working) working = raw;

  const cleaned = memoryProdCleanConceptPhrase(working) || normalizeMemoryKey(working).replace(/_/g, ' ');
  let canonical = memoryProdTitleCaseLabelFromKey(cleaned);
  canonical = memoryProdPreserveCanonicalCasing(canonical, text) || canonical;
  const normalizedKey = normalizeMemoryKey(canonical);
  return {
    canonical,
    normalizedKey,
    raw,
    wasModified: normalizedKey !== rawKey,
    droppedPrefix: trimMemoryText(droppedPrefix, 80),
    droppedSuffix,
    vetoSignal: null
  };
}

// v3.3.5 â€” Canonical Anchor Coalescer helpers.
// Alias keys are internal matching keys only. We do NOT rewrite the user's visible label
// globally; we use these keys to stop scoped duplicates like "Kaka app" when "Kaka"
// already exists or is being created in the same batch.
const MEMORY_ENTITY_ALIAS_SUFFIX_RE = /\b(?:app|application|project|tool|product|startup|platform|site|website|service|system|software|module|feature|engine)\b$/i;

function memoryProdEntityAliasKeys(label = '') {
  const raw = trimMemoryText(label || '', 100);
  if (!raw) return [];
  const variants = [];
  const push = (v) => {
    const k = normalizeMemoryKey(v || '');
    if (!k) return;
    if (!variants.includes(k)) variants.push(k);
  };
  const clean = raw
    .replace(/[â€™]/g, "'")
    .replace(/[â€œâ€"'`]+/g, '')
    .replace(/[^a-zA-Z0-9+._\-\s]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  push(clean);
  const noArticle = clean.replace(/^(?:the|a|an|my|our|your)\s+/i, '').trim();
  push(noArticle);
  const suffixStripped = noArticle.replace(MEMORY_ENTITY_ALIAS_SUFFIX_RE, '').replace(/\s+/g, ' ').trim();
  if (suffixStripped && suffixStripped !== noArticle) {
    const baseKey = normalizeMemoryKey(suffixStripped);
    // Keep this conservative: only create the base alias if the base still looks like a
    // real named anchor, not a generic noun such as "web" or "new".
    if (baseKey && !memoryProdIsGenericNodeLabel(suffixStripped) && !memoryProdLooksGenericScopedLabel(suffixStripped)) {
      const tokenCount = memoryProdTokenizeForMatch(suffixStripped).length;
      if (tokenCount >= 1 && tokenCount <= 5) push(suffixStripped);
    }
  }
  return boundedUniqueIds(variants, 8);
}

function memoryProdNodeAliasKeys(node = {}) {
  const keys = [];
  const pushAll = (label) => {
    for (const k of memoryProdEntityAliasKeys(label || '')) if (k && !keys.includes(k)) keys.push(k);
  };
  pushAll(node.normalizedKey || node.label || '');
  pushAll(node.label || '');
  for (const al of Array.isArray(node.aliases) ? node.aliases : []) pushAll(al);
  return boundedUniqueIds(keys, 16);
}

function memoryProdLabelsAliasEquivalent(a = '', b = '') {
  const aKeys = new Set(memoryProdEntityAliasKeys(a));
  if (!aKeys.size) return false;
  for (const k of memoryProdEntityAliasKeys(b)) if (aKeys.has(k)) return true;
  return false;
}

function memoryProdFindNodeByAliasKeys(nodes = [], label = '') {
  const labelKeys = new Set(memoryProdEntityAliasKeys(label));
  if (!labelKeys.size) return null;
  for (const node of Array.isArray(nodes) ? nodes : []) {
    if (!node || node.deleted || node.isRoot) continue;
    for (const k of memoryProdNodeAliasKeys(node)) {
      if (labelKeys.has(k)) return node;
    }
  }
  return null;
}

function memoryProdBuildAnchorRef(label = '', source = 'unknown', extra = {}) {
  const cleanLabel = trimMemoryText(label || '', 80);
  const keys = memoryProdEntityAliasKeys(cleanLabel);
  if (!cleanLabel || !keys.length) return null;
  return {
    id: trimMemoryText(extra.id || extra.nodeId || '', 160),
    label: cleanLabel,
    group: memoryProdNormalizeMemoryGroup(extra.group || extra.roleGuess || 'project'),
    currentState: trimMemoryText(extra.currentState || extra.state || 'active', 24),
    clusterId: trimMemoryText(extra.clusterId || extra.clusterHint || '', 40),
    source,
    reason: trimMemoryText(extra.reason || source, 160),
    score: num(extra.score, 0),
    aliasKeys: keys,
    planned: extra.planned === true
  };
}

function memoryProdFindAnchorRefByAlias(anchorRefs = [], label = '') {
  const keys = new Set(memoryProdEntityAliasKeys(label));
  if (!keys.size) return null;
  for (const ref of Array.isArray(anchorRefs) ? anchorRefs : []) {
    const refKeys = Array.isArray(ref?.aliasKeys) && ref.aliasKeys.length ? ref.aliasKeys : memoryProdEntityAliasKeys(ref?.label || '');
    if (refKeys.some((k) => keys.has(k))) return ref;
  }
  return null;
}

function memoryProdBuildAnchorRefs(existingNodes = [], packet = {}) {
  const refs = [];
  const seen = new Set();
  const add = (ref) => {
    if (!ref?.label) return;
    const keys = ref.aliasKeys || memoryProdEntityAliasKeys(ref.label);
    if (!keys.length) return;
    const idKey = ref.id ? `id:${ref.id}` : `keys:${keys.join('|')}`;
    if (seen.has(idKey)) return;
    seen.add(idKey);
    refs.push({ ...ref, aliasKeys: keys });
  };
  for (const node of Array.isArray(existingNodes) ? existingNodes : []) {
    if (!node || node.deleted || node.isRoot) continue;
    add(memoryProdBuildAnchorRef(node.label || node.normalizedKey || '', 'existing_node', {
      id: node.id,
      group: node.group,
      currentState: node.currentState,
      clusterId: node.clusterId,
      score: 80,
      reason: 'existing_node'
    }));
  }
  for (const h of Array.isArray(packet?.activeAnchorHints) ? packet.activeAnchorHints : []) {
    add(memoryProdBuildAnchorRef(h.label || '', 'active_anchor_hint', { ...h, score: num(h.score, 0) + 40 }));
  }
  for (const h of Array.isArray(packet?.plannedAnchorHints) ? packet.plannedAnchorHints : []) {
    add(memoryProdBuildAnchorRef(h.label || '', 'planned_anchor_hint', { ...h, planned: true, score: num(h.score, 0) + 70 }));
  }
  for (const h of Array.isArray(packet?.relevantNodes) ? packet.relevantNodes : []) {
    add(memoryProdBuildAnchorRef(h.label || '', 'relevant_node', { ...h, score: num(h.score, 0) + 20 }));
  }
  refs.sort((a, b) => (b.score || 0) - (a.score || 0));
  return refs;
}

function memoryProdFindNodeByNormalizedOrAlias(nodes, normalizedKey) {
  const key = normalizeMemoryKey(normalizedKey || '');
  if (!key) return null;
  const aliasKeys = new Set(memoryProdEntityAliasKeys(normalizedKey || key));
  aliasKeys.add(key);
  return (Array.isArray(nodes) ? nodes : []).find((n) => {
    if (!n || n.deleted) return false;
    const nodeKeys = memoryProdNodeAliasKeys(n);
    return nodeKeys.some((nk) => aliasKeys.has(nk));
  }) || null;
}

function memoryProdFindCandidateByNormalized(candidates, normalizedKey) {
  const key = normalizeMemoryKey(normalizedKey || '');
  if (!key) return null;
  return (Array.isArray(candidates) ? candidates : []).find((c) => !c?.deleted && String(c?.status || '').toLowerCase() !== 'promoted' && normalizeMemoryKey(c.normalizedKey || c.label || '') === key) || null;
}

function memoryProdSnapToExistingByCanonical(nodes = [], candidates = [], canonicalInfo = {}, fourLayerMatch = null) {
  const key = normalizeMemoryKey(canonicalInfo?.normalizedKey || canonicalInfo?.canonical || '');
  if (!key) return null;
  const node = memoryProdFindNodeByNormalizedOrAlias(nodes, key);
  if (node) return { kind: 'node_match', node, source: 'exact_key_or_alias' };
  const candidate = memoryProdFindCandidateByNormalized(candidates, key);
  if (candidate) return { kind: 'candidate_match', candidate, source: 'exact_candidate_key' };
  const fl = fourLayerMatch?.bestMatch || fourLayerMatch || null;
  if (fl && ['exact', 'exact_alias', 'exact_candidate'].includes(fl.source) && normalizeMemoryKey(fl.label || canonicalInfo?.canonical || '') === key) {
    if (fl.kind === 'node') return { kind: 'node_match', node: { id: fl.id, label: fl.label, _fromFourLayerMatch: true }, source: 'four_layer_' + fl.source };
    if (fl.kind === 'candidate') return { kind: 'candidate_match', candidate: { id: fl.id, label: fl.label, _fromFourLayerMatch: true }, source: 'four_layer_' + fl.source };
  }
  return null;
}

function memoryProdFindAnchorNodeInText(nodes = [], text = '') {
  const hay = ' ' + String(text || '').toLowerCase().replace(/[^a-z0-9\s_-]+/g, ' ').replace(/\s+/g, ' ') + ' ';
  if (!hay.trim()) return null;
  const candidates = [];
  for (const node of Array.isArray(nodes) ? nodes : []) {
    if (!node || node.deleted || node.isRoot) continue;
    const labels = [node.label, ...(Array.isArray(node.aliases) ? node.aliases : [])].map((x) => trimMemoryText(x || '', 80)).filter(Boolean);
    for (const label of labels) {
      const phrase = String(label).toLowerCase().replace(/[^a-z0-9\s_-]+/g, ' ').replace(/\s+/g, ' ').trim();
      if (!phrase || phrase.length < 3) continue;
      const escaped = phrase.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const re = new RegExp('(^|\\s)' + escaped + '(\\s|$)', 'i');
      if (re.test(hay)) candidates.push({ node, len: phrase.length });
    }
  }
  candidates.sort((a, b) => b.len - a.len);
  return candidates[0]?.node || null;
}

function memoryProdIsTransientDetailLabel(label, userText = '') {
  const hay = `${label || ''} ${userText || ''}`;
  return MEMORY_TRANSIENT_DETAIL_RE.test(hay);
}

function memoryProdIsPersistentInjuryText(userText = '') {
  return MEMORY_INJURY_PERSISTENCE_RE.test(String(userText || ''));
}

function memoryProdDetectEventFacets(userText = '', primaryCluster = 'general', node = null, eventHint = null) {
  const hay = `${userText || ''} ${node?.label || ''} ${node?.group || ''} ${eventHint?.summary || ''} ${eventHint?.eventType || ''}`.toLowerCase();
  const facets = [];
  const add = (facet) => { if (facet && !facets.includes(facet)) facets.push(facet); };
  add(primaryCluster || node?.clusterId || 'general');
  if (/\b(injur(?:y|ed)|pain|hurt|sprain|doctor|hospital|medication|medicine|surgery|diagnos|allerg|ocd|adhd|anxiety|depress|panic|migraine|asthma|diabetes|chronic|condition|illness|rehab|physio|stroke)\b/.test(hay)) add('health');
  if (/\b(football|soccer|basketball|boxing|tennis|gym|sparring|cardio|running|swimming|kickboxing|jab|hook\s+punch|training|athlete|match)\b/.test(hay)) add('sports');
  if (/\b(app|project|bug|deploy|ship|launch|code|debug|backend|frontend|api|customer|deadline|sprint|ticket|repo|worker|firestore|flutter|habitflow|gpmai)\b/.test(hay)) add('work');
  if (/\b(family|parent|mother|father|grandmother|grandfather|friend|girlfriend|boyfriend|partner|breakup|divorce|funeral|death|died|grief)\b/.test(hay)) add('relationships');
  if (/\b(course|exam|study|lecture|semester|learned|learning|practice|technique|lesson|hook\s+punch)\b/.test(hay)) add('learning');
  if (/\b(paid|invoice|salary|expense|savings|budget|debt|loan|income|finance|money)\b/.test(hay)) add('finance');
  const allowed = new Set(['work', 'learning', 'health', 'sports', 'finance', 'relationships', 'personal', 'general']);
  return boundedUniqueIds(facets.filter((f) => allowed.has(f)), 3);
}

function memoryProdDetectEventTags(userText = '') {
  const hay = String(userText || '').toLowerCase();
  const tags = [];
  const add = (tag) => { if (tag && !tags.includes(tag)) tags.push(tag); };
  if (/\binjur(?:y|ed)\b|\bhurt\b|\bpain\b/.test(hay)) add('injury');
  if (/\bleg\b/.test(hay)) add('leg');
  if (/\bknee\b/.test(hay)) add('knee');
  if (/\bshoulder\b/.test(hay)) add('shoulder');
  if (/\bbug\b|\berror\b|\bissue\b/.test(hay)) add('bug');
  if (/\bhook\s+punch\b/.test(hay)) add('hook_punch');
  if (/\bstroke\b/.test(hay)) add('stroke');
  return boundedUniqueIds(tags, 8);
}

// =============================================================================
// v3.1.14 â€” Architecture alignment helpers
// Anchor scoring + node gate + debug stage logging.
// These are surgical additions only. They do NOT replace the engine â€” they
// pre-condition Pass 1 output before it reaches prepareLearnedOutput, the
// event creator, and the slice writer.
// =============================================================================

const MEMORY_GENERIC_NODE_LABELS = new Set([
  'building project', 'project', 'app', 'my app', 'this app', 'core engine',
  'engine', 'issue', 'problem', 'thing', 'task', 'feature', 'update', 'work',
  'conversation', 'chat', 'assistant', 'message', 'goal', 'goal in general',
  'improvement', 'motivation', 'build app', 'to build app', 'to build', 'to make',
  'to create', 'to develop', 'startup', 'idea', 'plan', 'side project',
  'some app', 'some project', 'an app', 'a project', 'the app', 'the project',
  'product', 'service', 'system', 'tool', 'thing called', 'something', 'stuff',
  'work everyday', 'practice everyday', 'build something', 'make something',
  'new thing', 'new project', 'new app', 'next app', 'next project'
]);

function memoryProdNormalizeAnchorKey(value) {
  return String(value || '').toLowerCase().replace(/[^a-z0-9 ]+/g, ' ').replace(/\s+/g, ' ').trim();
}

function memoryProdIsGenericNodeLabel(label) {
  const key = memoryProdNormalizeAnchorKey(label);
  if (!key) return true;
  if (MEMORY_GENERIC_NODE_LABELS.has(key)) return true;
  // single-word generics that are too vague to be durable nodes on their own
  if (/^(thing|stuff|something|anything|everything|task|tasks|item|items|issue|issues|problem|problems|update|updates|goal|goals|plan|plans|idea|ideas|project|projects|app|apps|product|products|system|systems|service|services|tool|tools|engine|engines|work|job|jobs|chat|chats|conversation|conversations|message|messages|note|notes|stuff|things|features|build|builds|launch|launches)$/.test(key)) return true;
  return false;
}

function memoryProdScoreAnchorCandidate(rawLabel, userText) {
  // Trim trailing junk: stop words after the captured concept ("boxing and want" â†’ "boxing").
  let trimmed = String(rawLabel || '').trim();
  // Strip trailing connectives + filler.
  trimmed = trimmed.replace(/\s+(and|or|but|so|then|to|for|in|on|with|the|a|an|of|i|we|that|this|these|those|its|his|her|their|our|my|your|because|while|when|after|before|until)\b.*$/i, '').trim();
  // Strip leading determiners.
  trimmed = trimmed.replace(/^(a|an|the|my|your|his|her|their|our)\s+/i, '').trim();
  if (!trimmed) return null;
  const cleaned = memoryProdCleanConceptPhrase(trimmed);
  if (!cleaned) return null;
  if (memoryProdIsBlockedCandidateLabel(cleaned)) return null;
  if (memoryProdIsGenericNodeLabel(cleaned)) return null;
  if (memoryProdLooksGenericScopedLabel(cleaned)) return null;
  // Preserve the user's original casing if it appears in userText. Helps "GPMai" stay "GPMai".
  let displayLabel = trimmed;
  try {
    const escaped = cleaned.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const re = new RegExp(`\\b(${escaped})\\b`, 'i');
    const matchInOriginal = (userText || '').match(re);
    if (matchInOriginal && matchInOriginal[1]) displayLabel = matchInOriginal[1];
  } catch (_) {}
  let score = 0;
  const tokens = cleaned.split(/\s+/);
  if (tokens.length === 1) score += 8;
  else if (tokens.length === 2) score += 4;
  else if (tokens.length === 3) score += 2;
  // Proper-noun bonus from the original (un-lowercased) text.
  if (/[A-Z]/.test(displayLabel)) score += 6;
  if (/^[A-Z][A-Za-z0-9]*$/.test(displayLabel) && displayLabel.length >= 3) score += 4;
  // Penalize labels that are common English verbs/nouns with no semantic weight.
  if (/^(start|started|stop|stopped|build|building|use|using|do|done|make|made|fix|fixed|run|running|see|saw|want|wanting|need|got|get|getting|go|going|come|coming|tell|told|say|said)$/i.test(cleaned)) score -= 20;
  return { label: displayLabel, key: cleaned, score };
}

// Scored anchor extraction. Tries every pattern, scores each candidate, returns the best.
// Patterns include:
//   "(app|project|tool|product|startup|company|game|site|service) called X"
//   "called X" / "named X" / "is called X"
//   "X is the (core engine|backbone|foundation|basis) of Y"
//   "(building|launching|creating|developing|making|working on) X"
//   "(started|resumed|stopped|paused) Y"
//   "I use X for Y"  (X is the tool, Y is the project â€” both worth scoring)
function memoryProdExtractAnchorCandidates(userText = '', extraText = '') {
  const hay = `${userText || ''} ${extraText || ''}`.replace(/[â€™]/g, "'");
  if (!trimMemoryText(hay, 40)) return [];
  const candidates = [];
  const push = (raw, bonus = 0, source = '') => {
    const scored = memoryProdScoreAnchorCandidate(raw, userText);
    if (!scored) return;
    candidates.push({ ...scored, score: scored.score + bonus, source });
  };
  // Strongest signals: explicit "called X" / "named X" â€” anything after these is likely the proper name.
  const calledPatterns = [
    /\b(?:app|project|tool|product|startup|company|game|site|service|brand|platform|library|framework|model|feature|engine|module)\s+(?:called|named)\s+([A-Za-z][A-Za-z0-9+._-]*(?:\s+[A-Za-z][A-Za-z0-9+._-]*){0,2})/ig,
    /\b(?:called|named)\s+([A-Za-z][A-Za-z0-9+._-]{1,40})\b/ig,
    /\bis\s+called\s+([A-Za-z][A-Za-z0-9+._-]{1,40})\b/ig,
    /\bproject\s+called\s+([A-Za-z][A-Za-z0-9+._-]{1,40})/ig,
  ];
  for (const rx of calledPatterns) {
    let m;
    while ((m = rx.exec(hay)) !== null) push(m[1], 30, 'called_pattern');
  }
  // Building / launching / creating / developing â€” strong intent marker.
  const buildPatterns = [
    /\b(?:building|launching|creating|developing|making|working on|started building|started to build|i started build|i\s+build|i\s+made|just made|just built)\s+([A-Za-z][A-Za-z0-9+._-]*(?:\s+[A-Za-z][A-Za-z0-9+._-]*){0,3})/ig,
  ];
  for (const rx of buildPatterns) {
    let m;
    while ((m = rx.exec(hay)) !== null) push(m[1], 12, 'build_pattern');
  }
  // Lifecycle verbs that name the concept directly: "I started boxing", "I resumed GPMai".
  const lifecyclePatterns = [
    /\b(?:i\s+)?(?:started|resumed|paused|stopped|quit|finished|launched|completed|fixed|blocked on|stuck on|begun)\s+(?:learning\s+|practicing\s+|doing\s+|playing\s+|using\s+|working on\s+)?([A-Za-z][A-Za-z0-9+._-]*(?:\s+[A-Za-z][A-Za-z0-9+._-]*){0,2})/ig,
    /\b(?:learning|studying|practicing|training)\s+([A-Za-z][A-Za-z0-9+._-]*(?:\s+[A-Za-z][A-Za-z0-9+._-]*){0,2})/ig,
  ];
  for (const rx of lifecyclePatterns) {
    let m;
    while ((m = rx.exec(hay)) !== null) push(m[1], 8, 'lifecycle_pattern');
  }
  // "I use X for Y" â€” both X (tool) and Y (project) are anchor candidates.
  const usesPatterns = [
    /\b(?:i\s+)?(?:use|using)\s+([A-Za-z][A-Za-z0-9+._-]{1,30})\s+(?:for|in|on)\s+([A-Za-z][A-Za-z0-9+._-]{1,30})/ig,
  ];
  for (const rx of usesPatterns) {
    let m;
    while ((m = rx.exec(hay)) !== null) {
      push(m[1], 5, 'uses_tool');
      push(m[2], 8, 'uses_project');
    }
  }
  // "X is the core engine of Y" / "X is part of Y"
  const relationPatterns = [
    /\b([A-Za-z][A-Za-z0-9+._-]{2,30})\s+(?:is the|is a|is)\s+(?:core engine|backbone|foundation|basis|heart|brain|main module|key part)\s+of\s+([A-Za-z][A-Za-z0-9+._-]{2,30})/ig,
  ];
  for (const rx of relationPatterns) {
    let m;
    while ((m = rx.exec(hay)) !== null) {
      push(m[2], 6, 'relation_parent');
      push(m[1], 4, 'relation_child');
    }
  }
  // Also surface any standalone proper-noun-shaped tokens 3+ chars long that don't appear in stop list.
  const properNounRe = /\b([A-Z][A-Za-z0-9]{2,30}|[a-z][a-z0-9]*(?=[A-Z]))\b/g;
  let pn;
  while ((pn = properNounRe.exec(userText || '')) !== null) {
    const tok = pn[1];
    if (!tok || tok.length < 3) continue;
    if (/^(I|I'm|I've|Im|Ive|The|This|That|These|Those|My|Your|Our|Their|And|But|Or|For|With|From)$/i.test(tok)) continue;
    push(tok, 3, 'proper_noun');
  }
  // Lowercase tokens after "called" / "named" / "build" â€” common case where user types "gpmai".
  // Already covered by called/build patterns above with high bonus.

  return candidates;
}

// Pick the single best anchor. Returns '' if no candidate scores positive.
function memoryProdInferPrimaryConceptLabel(userText = '', extraText = '') {
  const cands = memoryProdExtractAnchorCandidates(userText, extraText);
  if (!cands.length) return '';
  const dedup = new Map();
  for (const c of cands) {
    const key = c.key || memoryProdNormalizeAnchorKey(c.label);
    if (!key) continue;
    const prev = dedup.get(key);
    if (!prev || c.score > prev.score) dedup.set(key, c);
  }
  const sorted = Array.from(dedup.values()).sort((a, b) => b.score - a.score);
  if (!sorted.length || sorted[0].score <= 0) return '';
  return sorted[0].label;
}

// Convenience: return the top-K anchor candidates with scores. Used for primary-vs-connected
// node decision in event creation.
function memoryProdRankedAnchors(userText = '', extraText = '', limit = 5) {
  const cands = memoryProdExtractAnchorCandidates(userText, extraText);
  if (!cands.length) return [];
  const dedup = new Map();
  for (const c of cands) {
    const key = c.key || memoryProdNormalizeAnchorKey(c.label);
    if (!key) continue;
    const prev = dedup.get(key);
    if (!prev || c.score > prev.score) dedup.set(key, c);
  }
  return Array.from(dedup.values()).sort((a, b) => b.score - a.score).slice(0, Math.max(1, limit));
}


// ---------------------------------------------------------------------------
// V3.1.15 â€” Strong learning arbiter helpers
// Backend rules propose anchors/details first; LLM remains a meaning adviser.
// These helpers are intentionally deterministic, small, and library-free.
// ---------------------------------------------------------------------------

function memoryProdCleanArbiterPhrase(value = '', max = 80) {
  let out = trimMemoryText(value || '', max)
    .replace(/[â€œâ€"'`]+/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  out = out.replace(/^(a|an|the|my|your|our|their|his|her|this|that)\s+/i, '').trim();
  out = out.replace(/\s+(today|yesterday|tomorrow|now|again|currently|right now|for now|recently|later|this week|last week|next week)\b.*$/i, '').trim();
  out = out.replace(/\s+(because|but|and then|then|so|while|when|after|before)\b.*$/i, '').trim();
  out = out.replace(/[.,;:!?]+$/g, '').trim();
  return trimMemoryText(out, max);
}

function memoryProdArbiterDisplayLabel(raw, userText = '') {
  const cleaned = memoryProdCleanArbiterPhrase(raw, 80);
  if (!cleaned) return '';
  try {
    const escaped = cleaned.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const re = new RegExp(`\\b(${escaped})\\b`, 'i');
    const m = String(userText || '').match(re);
    if (m && m[1]) return trimMemoryText(m[1], 80);
  } catch (_) {}
  return cleaned;
}

function memoryProdArbiterConceptValid(label = '') {
  const cleaned = memoryProdCleanArbiterPhrase(label, 80);
  if (!cleaned) return false;
  if (memoryProdIsBlockedCandidateLabel(cleaned)) return false;
  if (memoryProdIsGenericNodeLabel(cleaned)) return false;
  if (memoryProdLooksGenericScopedLabel(cleaned)) return false;
  return memoryProdTokenizeForMatch(cleaned).length > 0;
}

function memoryProdFindExistingNodeByLabelLoose(nodes = [], label = '') {
  const key = normalizeMemoryKey(label || '');
  if (!key) return null;
  const aliasHit = memoryProdFindNodeByAliasKeys(nodes, label);
  if (aliasHit) return aliasHit;
  for (const node of Array.isArray(nodes) ? nodes : []) {
    if (!node || node.deleted) continue;
    const nk = normalizeMemoryKey(node.normalizedKey || node.label || '');
    if (nk === key) return node;
    const aliases = Array.isArray(node.aliases) ? node.aliases : [];
    if (aliases.some((a) => normalizeMemoryKey(a || '') === key)) return node;
  }
  return memoryProdFindBestExistingNodeMatch(nodes, { label, roleGuess: '' });
}

function memoryProdRrfFuseAnchorRanks(lanes = [], k = 60) {
  const scores = new Map();
  for (const lane of Array.isArray(lanes) ? lanes : []) {
    const source = lane?.source || 'unknown';
    const weight = typeof lane?.weight === 'number' ? lane.weight : 1;
    const anchors = Array.isArray(lane?.anchors) ? lane.anchors : [];
    anchors.forEach((raw, idx) => {
      const label = trimMemoryText(raw?.label || raw || '', 80);
      const key = normalizeMemoryKey(label);
      if (!key || !label) return;
      const inc = weight * (1 / (k + idx + 1));
      const prev = scores.get(key) || { key, label, score: 0, sources: [] };
      prev.score += inc;
      prev.sources.push({ source, rank: idx + 1, weight });
      // Prefer nicer casing from proper labels / existing nodes.
      if (/[A-Z]/.test(label) && !/[A-Z]/.test(prev.label)) prev.label = label;
      scores.set(key, prev);
    });
  }
  return Array.from(scores.values()).sort((a, b) => b.score - a.score);
}

function memoryProdExtractDetailUnderAnchor(userText = '') {
  const text = String(userText || '').replace(/[â€™]/g, "'").trim();
  if (!text) return null;
  const patterns = [
    { action: 'learned', roleGuess: 'skill', eventType: 'skill_milestone', regex: /\b(?:i\s+)?(?:learned|learnt|practiced|practised|trained|improved|mastered)\s+(.{2,80}?)\s+(?:in|for|inside|within|on)\s+([A-Za-z][A-Za-z0-9+._-]*(?:\s+[A-Za-z][A-Za-z0-9+._-]*){0,4})\b/ig },
    { action: 'fixed', roleGuess: 'project', eventType: 'project_progress', regex: /\b(?:i\s+)?(?:fixed|debugged|solved|resolved|changed|updated|implemented|built|worked on|improved)\s+(.{2,90}?)\s+(?:in|for|inside|within|on)\s+([A-Za-z][A-Za-z0-9+._-]*(?:\s+[A-Za-z][A-Za-z0-9+._-]*){0,4})\b/ig }
  ];
  for (const p of patterns) {
    let m;
    p.regex.lastIndex = 0;
    while ((m = p.regex.exec(text)) !== null) {
      const detail = memoryProdCleanArbiterPhrase(m[1], 80);
      const concept = memoryProdArbiterDisplayLabel(m[2], userText);
      if (!detail || !concept) continue;
      if (!memoryProdArbiterConceptValid(concept)) continue;
      if (normalizeMemoryKey(detail) === normalizeMemoryKey(concept)) continue;
      return {
        kind: 'detail_under_anchor',
        action: p.action,
        primaryAnchor: concept,
        detailLabel: detail,
        roleGuess: p.roleGuess,
        eventType: p.eventType,
        confidence: 0.96,
        reason: 'learned_or_fixed_detail_inside_concept'
      };
    }
  }
  return null;
}

function memoryProdExtractShallowLifecycleAnchor(userText = '') {
  const text = String(userText || '').replace(/[â€™]/g, "'").trim();
  if (!text) return null;
  const stoppedEarly = text.match(/\b(?:i\s+)?(?:stopped|quit|gave up|dropped|no longer|not doing anymore|don't do anymore|dont do anymore)\s+(?:learning|practicing|practising|training|playing|working on)?\s*([A-Za-z][A-Za-z0-9+._-]*(?:\s+[A-Za-z][A-Za-z0-9+._-]*){0,3})\b/i);
  if (stoppedEarly?.[1]) {
    const concept = memoryProdArbiterDisplayLabel(stoppedEarly[1], userText);
    if (memoryProdArbiterConceptValid(concept)) return { kind: 'clear_but_shallow_candidate', action: 'stopped', primaryAnchor: concept, roleGuess: 'skill', confidence: 0.92, reason: 'clear_lifecycle_update_without_new_detail' };
  }
  const pausedEarly = text.match(/\b(?:i\s+)?(?:paused|put on hold|taking a break from|stepping back from)\s+(?:learning|practicing|practising|training|playing|working on)?\s*([A-Za-z][A-Za-z0-9+._-]*(?:\s+[A-Za-z][A-Za-z0-9+._-]*){0,3})\b/i);
  if (pausedEarly?.[1]) {
    const concept = memoryProdArbiterDisplayLabel(pausedEarly[1], userText);
    if (memoryProdArbiterConceptValid(concept)) return { kind: 'clear_but_shallow_candidate', action: 'paused', primaryAnchor: concept, roleGuess: 'skill', confidence: 0.92, reason: 'clear_lifecycle_update_without_new_detail' };
  }
  const resumedEarly = text.match(/\b(?:i\s+)?(?:resumed|restarted|started again|got back into|getting back into|back to)\s+(?:learning|practicing|practising|training|playing|working on)?\s*([A-Za-z][A-Za-z0-9+._-]*(?:\s+[A-Za-z][A-Za-z0-9+._-]*){0,3})\b/i);
  if (resumedEarly?.[1]) {
    const concept = memoryProdArbiterDisplayLabel(resumedEarly[1], userText);
    if (memoryProdArbiterConceptValid(concept)) return { kind: 'clear_but_shallow_candidate', action: 'resumed', primaryAnchor: concept, roleGuess: 'skill', confidence: 0.92, reason: 'clear_lifecycle_update_without_new_detail' };
  }
  const patterns = [
    { action: 'started', roleGuess: 'skill', regex: /\b(?:i\s+)?(?:started|began|got into|picked up|took up)\s+(?:learning|practicing|practising|training|playing|doing)?\s*([A-Za-z][A-Za-z0-9+._-]*(?:\s+[A-Za-z][A-Za-z0-9+._-]*){0,3})\b/i },
    { action: 'started', roleGuess: 'skill', regex: /\b(?:i\s+am|i'm|im)?\s*(?:learning|practicing|practising|training|studying)\s+([A-Za-z][A-Za-z0-9+._-]*(?:\s+[A-Za-z][A-Za-z0-9+._-]*){0,3})\b/i },
    { action: 'resumed', roleGuess: 'skill', regex: /\b(?:i\s+)?(?:resumed|restarted|started again|got back into|getting back into|back to)\s+(?:learning|practicing|practising|training|playing|working on)?\s*([A-Za-z][A-Za-z0-9+._-]*(?:\s+[A-Za-z][A-Za-z0-9+._-]*){0,3})\b/i },
    { action: 'stopped', roleGuess: 'skill', regex: /\b(?:i\s+)?(?:stopped|quit|gave up|dropped|no longer|not doing anymore|don't do anymore|dont do anymore)\s+(?:learning|practicing|practising|training|playing|working on)?\s*([A-Za-z][A-Za-z0-9+._-]*(?:\s+[A-Za-z][A-Za-z0-9+._-]*){0,3})\b/i },
    { action: 'paused', roleGuess: 'skill', regex: /\b(?:i\s+)?(?:paused|put on hold|taking a break from|stepping back from)\s+(?:learning|practicing|practising|training|playing|working on)?\s*([A-Za-z][A-Za-z0-9+._-]*(?:\s+[A-Za-z][A-Za-z0-9+._-]*){0,3})\b/i },
    { action: 'started', roleGuess: 'interest', regex: /\b(?:i\s+am|i'm|im)\s+(?:serious about|interested in|into)\s+([A-Za-z][A-Za-z0-9+._-]*(?:\s+[A-Za-z][A-Za-z0-9+._-]*){0,3})\b/i },
    { action: 'started', roleGuess: 'skill', regex: /\b(?:i\s+)?(?:want to learn|wanna learn|plan to learn|trying to learn)\s+([A-Za-z][A-Za-z0-9+._-]*(?:\s+[A-Za-z][A-Za-z0-9+._-]*){0,3})\b/i }
  ];
  for (const p of patterns) {
    const m = text.match(p.regex);
    if (!m || !m[1]) continue;
    const concept = memoryProdArbiterDisplayLabel(m[1], userText);
    if (!memoryProdArbiterConceptValid(concept)) continue;
    return {
      kind: 'clear_but_shallow_candidate',
      action: p.action,
      primaryAnchor: concept,
      roleGuess: p.roleGuess,
      confidence: 0.9,
      reason: 'clear_concept_without_meaningful_detail'
    };
  }
  return null;
}

function memoryProdExtractNamedProjectAnchor(userText = '') {
  const text = String(userText || '').replace(/[â€™]/g, "'").trim();
  if (!text) return null;
  const named = memoryProdRankedAnchors(text, text, 5).find((a) => ['called_pattern', 'build_pattern', 'proper_noun'].includes(a.source));
  if (!named || !memoryProdArbiterConceptValid(named.label)) return null;
  if (!/(app|project|tool|product|startup|platform|site|service|called|named|building|developing|creating|launching|working on)/i.test(text)) return null;
  const action = memoryProdNormalizeLifecycleAction(memoryProdInferLifecycleActionFromText(text)) || 'started';
  return {
    kind: 'named_project_anchor',
    action,
    primaryAnchor: named.label,
    roleGuess: 'project',
    confidence: 0.9,
    reason: 'named_project_or_product_anchor'
  };
}

function memoryProdBuildBackendRuleProposal(userText = '', existingNodes = [], llmCandidates = []) {
  if (memoryProdUserTextLooksTrivial(userText) && !memoryProdIsLifeMemoryText(userText)) return null;
  const detail = memoryProdExtractDetailUnderAnchor(userText);
  const namedProject = memoryProdExtractNamedProjectAnchor(userText);
  const shallow = memoryProdExtractShallowLifecycleAnchor(userText);
  const ruleRanks = [];
  if (detail?.primaryAnchor) ruleRanks.push({ label: detail.primaryAnchor });
  if (namedProject?.primaryAnchor) ruleRanks.push({ label: namedProject.primaryAnchor });
  if (shallow?.primaryAnchor) ruleRanks.push({ label: shallow.primaryAnchor });
  const llmRanks = (Array.isArray(llmCandidates) ? llmCandidates : []).map((c) => ({ label: c?.label || '' })).filter((x) => x.label);
  const existingRanks = [];
  for (const proposal of [detail, namedProject, shallow]) {
    if (!proposal?.primaryAnchor) continue;
    const existing = memoryProdFindExistingNodeByLabelLoose(existingNodes, proposal.primaryAnchor);
    if (existing?.label) existingRanks.push({ label: existing.label });
  }
  const fused = memoryProdRrfFuseAnchorRanks([
    { source: 'backend_rules', weight: 3, anchors: ruleRanks },
    { source: 'existing_memory', weight: 2.5, anchors: existingRanks },
    { source: 'llm', weight: 1, anchors: llmRanks }
  ]);
  const chosenLabel = fused[0]?.label || detail?.primaryAnchor || namedProject?.primaryAnchor || shallow?.primaryAnchor || '';
  const chosenExisting = chosenLabel ? memoryProdFindExistingNodeByLabelLoose(existingNodes, chosenLabel) : null;
  const base = detail || namedProject || shallow;
  if (!base) return null;
  return {
    ...base,
    primaryAnchor: chosenExisting?.label || base.primaryAnchor,
    existingNode: chosenExisting || null,
    fusedAnchors: fused.slice(0, 5)
  };
}

function memoryProdRoleFromProposal(proposal, fallback = 'interest') {
  if (proposal?.existingNode?.group) return memoryProdNormalizeMemoryGroup(proposal.existingNode.group);
  return memoryProdNormalizeMemoryGroup(proposal?.roleGuess || fallback || 'interest');
}

function memoryProdApplyBackendArbiterToLearned(learned, userText = '', existingNodes = [], fourLayerMatch = null) {
  const safe = {
    candidates: Array.isArray(learned?.candidates) ? learned.candidates.slice() : [],
    reinforce_labels: Array.isArray(learned?.reinforce_labels) ? learned.reinforce_labels.slice() : [],
    relation_hints: Array.isArray(learned?.relation_hints) ? learned.relation_hints.slice() : [],
    node_updates: Array.isArray(learned?.node_updates) ? learned.node_updates.slice() : [],
    backend_rechecks: Array.isArray(learned?.backend_rechecks) ? learned.backend_rechecks.slice() : []
  };

  // V3.3.3: canonicalize LLM-emitted labels before backend proposal / matching.
  const canonicalizedCandidates = [];
  for (const c of safe.candidates) {
    const canon = memoryProdCanonicalizeLabel(c?.label || '', userText);
    if (canon.vetoSignal === 'abstract_ambition') {
      safe.backend_rechecks.push({ kind: 'candidate_vetoed_abstract_ambition', label: c?.label || '', reason: canon.vetoSignal });
      continue;
    }
    if (canon.canonical && canon.wasModified) {
      c._rawLabel = c.label;
      c.label = canon.canonical;
      c._canonicalized = canon;
      c.aliases = boundedUniqueIds([...(Array.isArray(c.aliases) ? c.aliases : []), canon.raw], 12);
      safe.backend_rechecks.push({ kind: 'label_canonicalized', raw: canon.raw, canonical: canon.canonical, droppedPrefix: canon.droppedPrefix || '', source: 'arbiter' });
    }
    canonicalizedCandidates.push(c);
  }
  safe.candidates = canonicalizedCandidates;

  // Universal node-update pipeline: when the LLM correctly attached a detail to an existing
  // anchor via node_updates, keep that detail out of candidates/nodes.
  const nodeUpdateText = (Array.isArray(safe.node_updates) ? safe.node_updates : [])
    .map((u) => trimMemoryText(u?.summaryHint || u?.summary || '', 160))
    .join(' ');
  if (nodeUpdateText) {
    safe.candidates = safe.candidates.filter((c) => {
      const label = trimMemoryText(c?.label || '', 80);
      if (!label) return false;
      const looksAttachedDetail = memoryProdIsTransientDetailLabel(label, nodeUpdateText)
        || /\b(feature|screen|page|module|ui|backend|frontend|login|bug|issue|error)\b/i.test(label);
      if (looksAttachedDetail && !memoryProdIsPersistentInjuryText(nodeUpdateText)) {
        safe.backend_rechecks.push({ kind: 'candidate_vetoed_by_node_update', label, reason: 'detail_attached_to_existing_anchor' });
        return false;
      }
      return true;
    });
  }

  // Preserve the concrete anchor in vague ambition statements instead of storing the vague phrase.
  if (MEMORY_CONCRETE_AMBITION_RE.test(userText) && /\b(something|anything|things?|stuff)\b/i.test(userText)) {
    safe.candidates = safe.candidates.filter((c) => !['science', 'research'].includes(normalizeMemoryKey(c?.label || '')) && !memoryProdIsAbstractAmbitionLabel(c?.label || ''));
    if (!safe.candidates.some((c) => normalizeMemoryKey(c?.label || '') === normalizeMemoryKey('Science Research Goal'))) {
      safe.candidates.unshift({ label: 'Science Research Goal', roleGuess: 'goal', group: 'goal', strength: 'medium', summaryHint: trimMemoryText(userText, 220), _forceCandidate: true, _arbiterReason: 'concrete_ambition_anchor_salvaged' });
    }
    safe.backend_rechecks.push({ kind: 'abstract_ambition_concrete_anchor_salvaged', label: 'Science Research Goal' });
  }

  const proposal = memoryProdBuildBackendRuleProposal(userText, existingNodes, safe.candidates);
  // ARCH Â§6, Â§8 â€” Four-layer match feedback. When the matcher has an exact / exact_alias
  // / exact_candidate hit and the deterministic backend rule lane has NOT proven a primary
  // anchor, we still need to make sure existing-memory matches reinforce instead of
  // duplicate-create. The rules below run BEFORE the early return guard so a strong LLM
  // candidate that happens to alias an existing node is forced into the reinforce path.
  // Hard backend rules below (named_project / detail_under_anchor / clear_but_shallow)
  // continue to override RRF-ranked LLM proposals â€” that's the Â§1 invariant.
  const fl = fourLayerMatch || null;
  const flBest = fl?.bestMatch || null;
  const flExactSources = new Set(['exact', 'exact_alias', 'exact_candidate']);
  if (flBest && flExactSources.has(flBest.source) && flBest.kind === 'node' && flBest.label) {
    const flKey = normalizeMemoryKey(flBest.label);
    // Tag any LLM candidate that resolves to this exact existing node so the candidate
    // path treats it as reinforce, not create. We do not delete the candidate; we just
    // mark the existence so memoryProdCreateOrPromoteMemoryTopic's existing-node lookup
    // wins downstream.
    for (const c of safe.candidates) {
      const ck = normalizeMemoryKey(c?.label || '');
      if (!ck) continue;
      if (ck === flKey) {
        c._fourLayerExistingMatch = { id: flBest.id, label: flBest.label, source: flBest.source };
        c._arbiterReason = c._arbiterReason || `four_layer_${flBest.source}_match`;
      }
    }
    // Promote the matched node label into reinforce_labels so the increment path also picks
    // it up. Bounded; deduplicated downstream by boundedUniqueIds.
    safe.reinforce_labels = boundedUniqueIds([flBest.label, ...safe.reinforce_labels], 12);
    safe.backend_rechecks.push({ kind: 'four_layer_match_used', label: flBest.label, source: flBest.source, reason: 'existing_memory_match_reinforce_path' });
  }
  if (!proposal?.primaryAnchor) return safe;

  const anchor = trimMemoryText(proposal.primaryAnchor, 80);
  const roleGuess = memoryProdRoleFromProposal(proposal, proposal.roleGuess || 'interest');
  let existingNode = proposal.existingNode || memoryProdFindExistingNodeByLabelLoose(existingNodes, anchor);
  // ARCH Â§6 â€” If the bounded hot shortlist did not contain the anchor's true existing node
  // but the four-layer match found an exact/alias hit on this exact label, use that match
  // as the existingNode source so the arbiter chooses 'reinforce' over 'durable'.
  if (!existingNode && flBest && flExactSources.has(flBest.source) && flBest.kind === 'node') {
    const anchorKeyTmp = normalizeMemoryKey(anchor);
    const flKeyTmp = normalizeMemoryKey(flBest.label);
    if (anchorKeyTmp && anchorKeyTmp === flKeyTmp) {
      existingNode = { id: flBest.id, label: flBest.label, _fromFourLayerMatch: true };
      safe.backend_rechecks.push({ kind: 'four_layer_match_resolves_anchor', label: flBest.label, source: flBest.source, reason: 'bounded_shortlist_missed_existing_node' });
    }
  }
  const anchorKey = normalizeMemoryKey(anchor);
  const detailKey = normalizeMemoryKey(proposal.detailLabel || '');
  const action = memoryProdNormalizeLifecycleAction(proposal.action || '');
  const isDetailRule = proposal.kind === 'detail_under_anchor';
  const isShallowRule = proposal.kind === 'clear_but_shallow_candidate';
  const isNamedProject = proposal.kind === 'named_project_anchor';
  const summary = isDetailRule
    ? trimMemoryText(`${anchor}: ${capitalizeMemoryWord(action || 'updated')} ${proposal.detailLabel}. ${userText}`, 220)
    : trimMemoryText(userText, 220);

  // Remove detail-only LLM candidates when backend proves they belong under an anchor.
  if (isDetailRule && detailKey) {
    safe.candidates = safe.candidates.filter((c) => normalizeMemoryKey(c?.label || '') !== detailKey);
    safe.backend_rechecks.push({ kind: 'detail_only_candidate_vetoed', label: proposal.detailLabel, primaryAnchor: anchor, reason: 'detail_attached_to_anchor' });
  }
  // When a backend anchor is proven, do not keep generic LLM labels as candidate pollution
  // (e.g. "building project", "core engine", "issue"). Keep only real independent concepts.
  safe.candidates = safe.candidates.filter((c) => {
    const k = normalizeMemoryKey(c?.label || '');
    if (!k) return false;
    if (k === anchorKey) return true;
    if (memoryProdIsGenericNodeLabel(c?.label || '') || memoryProdLooksGenericScopedLabel(c?.label || '')) {
      safe.backend_rechecks.push({ kind: 'generic_candidate_vetoed_by_anchor', label: c?.label || '', primaryAnchor: anchor });
      return false;
    }
    return true;
  });

  let anchorCandidate = safe.candidates.find((c) => normalizeMemoryKey(c?.label || '') === anchorKey);
  if (!anchorCandidate) {
    anchorCandidate = safe.candidates.find((c) => memoryProdFindExistingNodeByLabelLoose([existingNode].filter(Boolean), c?.label || ''));
  }
  if (!anchorCandidate) {
    anchorCandidate = { label: anchor, roleGuess, strength: isDetailRule || isNamedProject ? 'strong' : 'medium' };
    safe.candidates.unshift(anchorCandidate);
  }

  anchorCandidate.label = anchor;
  anchorCandidate.roleGuess = roleGuess;
  anchorCandidate.group = roleGuess;
  anchorCandidate.clusterHint = memoryProdSanitizeClusterHint(anchorCandidate.clusterHint || existingNode?.clusterId || '', anchor, roleGuess, summary);
  anchorCandidate.summaryHint = memoryProdMergeSummaryHints(anchorCandidate.summaryHint || existingNode?.info || '', summary, 220);
  anchorCandidate.stateHint = trimMemoryText(memoryProdNodeStateFromLifecycleAction(action, anchorCandidate.stateHint || existingNode?.currentState || ''), 24);
  anchorCandidate.importanceHint = trimMemoryText(anchorCandidate.importanceHint || existingNode?.importanceClass || inferImportanceForLabel(anchor, roleGuess, summary), 40);
  anchorCandidate._backendProposal = proposal;
  anchorCandidate._rrfFusedAnchors = proposal.fusedAnchors || [];
  anchorCandidate._primaryAnchor = anchor;
  anchorCandidate._detailLabel = trimMemoryText(proposal.detailLabel || '', 80);
  anchorCandidate._arbiterReason = proposal.reason || proposal.kind;

  if (isDetailRule) {
    anchorCandidate.strength = 'strong';
    anchorCandidate._arbiterDecision = existingNode ? 'reinforce' : 'durable';
    anchorCandidate._hasMeaningfulDetail = true;
    anchorCandidate._allowDurable = true;
    anchorCandidate.eventHint = {
      ...(anchorCandidate.eventHint || {}),
      worthy: true,
      action,
      summary: trimMemoryText(userText, 220),
      timeText: trimMemoryText(anchorCandidate?.eventHint?.timeText || '', 80),
      eventType: proposal.eventType || memoryProdEventTypeFromLifecycleAction(action, roleGuess),
      detailLabel: proposal.detailLabel,
      sameOngoingIncident: anchorCandidate?.eventHint?.sameOngoingIncident === true,
      reuseHint: trimMemoryText(anchorCandidate?.eventHint?.reuseHint || '', 220)
    };
    safe.backend_rechecks.push({ kind: 'arbiter_decision', decision: anchorCandidate._arbiterDecision, label: anchor, detailLabel: proposal.detailLabel, reason: 'detail_attached_to_anchor' });
  } else if (isShallowRule) {
    anchorCandidate.strength = 'medium';
    anchorCandidate._arbiterDecision = existingNode ? 'reinforce' : 'candidate';
    anchorCandidate._forceCandidate = !existingNode;
    anchorCandidate._clearButShallow = true;
    anchorCandidate._allowDurable = false;
    anchorCandidate.eventHint = existingNode ? {
      ...(anchorCandidate.eventHint || {}),
      worthy: !!action,
      action,
      summary: trimMemoryText(userText, 220),
      timeText: trimMemoryText(anchorCandidate?.eventHint?.timeText || '', 80),
      eventType: memoryProdEventTypeFromLifecycleAction(action, roleGuess),
      sameOngoingIncident: anchorCandidate?.eventHint?.sameOngoingIncident === true,
      reuseHint: trimMemoryText(anchorCandidate?.eventHint?.reuseHint || '', 220)
    } : {
      ...(anchorCandidate.eventHint || {}),
      worthy: false,
      action: '',
      summary: trimMemoryText(userText, 220),
      timeText: '',
      eventType: ''
    };
    safe.backend_rechecks.push({ kind: 'arbiter_decision', decision: anchorCandidate._arbiterDecision, label: anchor, reason: 'clear_but_shallow_candidate' });
  } else if (isNamedProject) {
    anchorCandidate.strength = 'strong';
    anchorCandidate._arbiterDecision = existingNode ? 'reinforce' : 'durable';
    anchorCandidate._namedProjectAnchor = true;
    anchorCandidate._hasMeaningfulDetail = true;
    anchorCandidate._allowDurable = true;
    anchorCandidate.eventHint = {
      ...(anchorCandidate.eventHint || {}),
      worthy: true,
      action,
      summary: trimMemoryText(userText, 220),
      timeText: trimMemoryText(anchorCandidate?.eventHint?.timeText || '', 80),
      eventType: memoryProdEventTypeFromLifecycleAction(action, 'project')
    };
    safe.backend_rechecks.push({ kind: 'arbiter_decision', decision: anchorCandidate._arbiterDecision, label: anchor, reason: 'named_project_anchor' });
  }

  // If there is an existing node, let the downstream existing-node branch reinforce it,
  // but keep it as candidate object so event/slice writing has the event/detail payload.
  if (existingNode?.label) {
    safe.reinforce_labels = boundedUniqueIds([existingNode.label, ...safe.reinforce_labels], 12);
  }

  safe.candidates = safe.candidates.filter((c, idx, arr) => {
    const k = normalizeMemoryKey(c?.label || '');
    if (!k) return false;
    return arr.findIndex((x) => normalizeMemoryKey(x?.label || '') === k) === idx;
  });
  return safe;
}

// Hard node gate. Called right before any node-write decision.
// Returns { allow: boolean, reason: string, suggestedDowngrade: 'candidate'|'reject'|null }.
function memoryProdNodeGate(candidate, userText = '') {
  const label = trimMemoryText(candidate?.label || '', 80);
  if (!label) return { allow: false, reason: 'empty_label', suggestedDowngrade: 'reject' };
  if (memoryProdIsBlockedCandidateLabel(label)) return { allow: false, reason: 'blocked_label', suggestedDowngrade: 'reject' };
  if (memoryProdIsGenericNodeLabel(label)) return { allow: false, reason: 'generic_label', suggestedDowngrade: 'candidate' };
  if (memoryProdLooksGenericScopedLabel(label)) return { allow: false, reason: 'generic_scoped_label', suggestedDowngrade: 'candidate' };
  // Life Fast Lane bypasses the meaningful-detail requirement.
  if (candidate?.directDurable === true || candidate?.importanceHint === 'life_significant') {
    return { allow: true, reason: 'life_fast_lane' };
  }
  if (candidate?._forceCandidate === true || candidate?._clearButShallow === true || candidate?._arbiterDecision === 'candidate') {
    return { allow: false, reason: 'clear_but_shallow_candidate', suggestedDowngrade: 'candidate' };
  }
  if (candidate?._allowDurable === true || candidate?._arbiterDecision === 'durable') {
    return { allow: true, reason: candidate?._arbiterReason || 'arbiter_allows_durable' };
  }
  // Strong signal + meaningful detail â†’ durable. Event action alone is not enough.
  const hasDetail = memoryProdHasMeaningfulDetail(candidate, userText);
  const isStrong = candidate?.strength === 'strong';
  if (isStrong && hasDetail) return { allow: true, reason: 'strong_with_meaningful_detail' };
  if (hasDetail && (candidate?.eventHint?.worthy === true || candidate?.sourceType === 'bootstrap' || candidate?.sourceType === 'profile')) return { allow: true, reason: 'meaningful_detail' };
  // Clear-but-shallow â†’ candidate.
  return { allow: false, reason: 'clear_but_shallow', suggestedDowngrade: 'candidate' };
}

// ARCH Â§8 â€” Candidate gate. Blocks trivial / filler / pronoun-only / blocked labels.
// Returns { allow, reason } so callers can log a structured reject.
function memoryProdCandidateGate(item, userText = '') {
  const label = trimMemoryText(item?.label || '', 80);
  if (!label) return { allow: false, reason: 'empty_label' };
  if (memoryProdIsAbstractAmbitionLabel(label)) return { allow: false, reason: 'abstract_ambition' };
  // Blocked-vocabulary labels (assistant / message / thing / hello / ...).
  if (memoryProdIsBlockedCandidateLabel(label)) return { allow: false, reason: 'blocked_label' };
  if (memoryProdIsGenericNodeLabel(label) || memoryProdLooksGenericScopedLabel(label)) return { allow: false, reason: 'generic_or_scoped_candidate' };
  // Candidate should be rare: one-turn internal implementation details belong as Slices
  // under the resolved project/app/skill anchor, not as standalone candidate concepts.
  if ((memoryProdIsTransientDetailLabel(label, userText) || /\b(feature|screen|page|module|ui|backend|frontend|login|auth|bug|issue|error)\b/i.test(label)) && !memoryProdIsPersistentInjuryText(userText)) {
    return { allow: false, reason: 'transient_detail_candidate' };
  }
  // Pure pronouns / one-word filler that should never enter as candidates.
  const norm = label.toLowerCase().trim();
  if (/^(i|me|my|mine|you|your|he|she|him|her|they|them|it|this|that|these|those|us|we|our)$/.test(norm)) {
    return { allow: false, reason: 'pronoun_only' };
  }
  // Filler-self-improvement phrases per PDF Â§8 ("improve myself", "stay focused", "work hard"
  // "be better", "do my best", "level up") â€” block UNLESS attached to a real anchor in userText.
  const fillerRe = /^(improve myself|stay focused|work hard|be better|do my best|level up|try harder|get better|push myself|focus more|stay disciplined|stay consistent)$/;
  if (fillerRe.test(norm)) {
    // If there is a high-signal cue or a named anchor (Capitalised word) in userText, allow.
    if (memoryProdHasHighSignalCue(userText) || /[A-Z][a-zA-Z]{3,}/.test(String(userText || ''))) {
      return { allow: true, reason: 'filler_with_real_anchor' };
    }
    return { allow: false, reason: 'filler_without_anchor' };
  }
  return { allow: true, reason: 'candidate_allowed' };
}

// ARCH Â§8 â€” Slice gate. Decides whether a slice should be written for a node update.
// Inputs:
//   { hasMeaningfulUpdate, hasUserEvidence, alreadyWrittenForNodeTurn, lifecycleAction }
// User-evidence rule: assistant-only claims do not create user memory (Â§8 "User evidence exists").
function memoryProdSliceGate(input = {}) {
  const hasMeaningfulUpdate = input?.hasMeaningfulUpdate === true;
  const hasUserEvidence = input?.hasUserEvidence === true;
  const alreadyWrittenForNodeTurn = input?.alreadyWrittenForNodeTurn === true;
  const lifecycleAction = trimMemoryText(input?.lifecycleAction || '', 40);
  if (alreadyWrittenForNodeTurn) return { allow: false, reason: 'duplicate_for_node_turn' };
  if (!hasUserEvidence) return { allow: false, reason: 'no_user_evidence' };
  if (!hasMeaningfulUpdate && !lifecycleAction) return { allow: false, reason: 'no_meaningful_update' };
  return { allow: true, reason: 'meaningful_update_with_user_evidence' };
}

// ARCH Â§8 â€” Event gate. Validates an event candidate before write/update.
// Returns one of:
//   { allow: true,  decision: 'create' | 'update', reason, dedupedEventId? }
//   { allow: false, reason }
// Dedup rule: same eventType + same primaryNodeId within the dedup window collapses to "update".
function memoryProdEventGate(input = {}) {
  const action = trimMemoryText(input?.lifecycleAction || input?.action || '', 40);
  const eventType = trimMemoryText(input?.eventType || '', 60);
  const primaryNodeId = trimMemoryText(input?.primaryNodeId || '', 160);
  const userEvidenceMsgIds = Array.isArray(input?.userEvidenceMsgIds) ? input.userEvidenceMsgIds.filter(Boolean) : [];
  const ongoing = Array.isArray(input?.recentEventsForNode) ? input.recentEventsForNode : [];
  const nowMs = num(input?.nowMs, Date.now());
  if (!action && !eventType) return { allow: false, reason: 'no_action' };
  if (!primaryNodeId) return { allow: false, reason: 'no_primary_durable_node' };
  if (!userEvidenceMsgIds.length) return { allow: false, reason: 'no_user_evidence' };
  // Dedup ongoing incident: if a recent event exists with same type and primary node within
  // the dedup window, collapse to update instead of create.
  const dedupKey = (eventType || action).toLowerCase();
  const within = ongoing.find((e) => {
    if (!e || e.deleted) return false;
    if (trimMemoryText(e.primaryNodeId || '', 160) !== primaryNodeId) return false;
    const eType = trimMemoryText(e.eventType || e.lifecycleAction || '', 60).toLowerCase();
    if (eType !== dedupKey) return false;
    const ts = num(e.updatedAt || e.createdAt, 0);
    return ts > 0 && (nowMs - ts) <= MEMORY_EVENT_DEDUP_WINDOW_MS;
  });
  if (within) return { allow: true, decision: 'update', reason: 'dedup_ongoing_incident', dedupedEventId: within.id || '' };
  return { allow: true, decision: 'create', reason: 'new_distinct_happening' };
}

// ARCH Â§8 â€” Edge gate. Enforces: both nodes durable, valid type, explicit relation,
// not co-mention only, direction valid, not duplicate.
const MEMORY_VALID_EDGE_TYPES = new Set(['part_of', 'uses', 'depends_on', 'drives', 'supports', 'improves', 'related_to']);
const MEMORY_EXPLICIT_RELATION_RE = /\b(part of|inside|within|consists of|made of|uses|using|use|built (?:with|on|using)|powered by|backed by|relies on|depends on|requires|needs|drives|motivates|leads to|supports|improves|enhances|because|due to|caused by)\b/i;
function memoryProdEdgeGate(input = {}) {
  const fromNode = input?.fromNode || null;
  const toNode = input?.toNode || null;
  const type = normalizeMemoryConnectionType(trimMemoryText(input?.type || 'related_to', 40));
  const userText = String(input?.userText || '');
  const reason = trimMemoryText(input?.reason || '', 220);
  const provenance = String(input?.provenance || '').toLowerCase();
  const existingEdge = input?.existingEdge || null;
  if (!fromNode || !toNode) return { allow: false, reason: 'endpoint_missing' };
  if (fromNode.deleted || toNode.deleted) return { allow: false, reason: 'endpoint_deleted' };
  if (!fromNode.id || !toNode.id) return { allow: false, reason: 'endpoint_missing_id' };
  if (fromNode.id === toNode.id) return { allow: false, reason: 'self_edge' };
  if (!MEMORY_VALID_EDGE_TYPES.has(type)) return { allow: false, reason: 'invalid_edge_type' };
  // Explicit-relation requirement. The relation must be supported by either:
  //   - a backend-rule provenance (e.g. "uses"/"part_of" extracted via deterministic regex)
  //   - the userText itself containing an explicit relation phrase
  //   - a non-empty `reason` string that names the relation (existing edge upserter behavior)
  const reasonHasRelation = MEMORY_EXPLICIT_RELATION_RE.test(reason) || /(explicit|user said|inferred from user text)/i.test(reason);
  const userTextHasRelation = MEMORY_EXPLICIT_RELATION_RE.test(userText);
  const provenanceTrusted = provenance === 'backend_rule' || provenance === 'llm_relation_explicit';
  if (type === 'related_to' && !reasonHasRelation && !userTextHasRelation && !provenanceTrusted) {
    return { allow: false, reason: 'co_mention_only' };
  }
  if (type !== 'related_to' && !reasonHasRelation && !userTextHasRelation && !provenanceTrusted) {
    return { allow: false, reason: 'no_explicit_relation_for_typed_edge' };
  }
  // Direction validation â€” for asymmetric types (uses, depends_on, part_of, drives,
  // supports, improves), the order matters. Bidirectional types (related_to) tolerate
  // any order. We trust the caller's order; the existing canonical key handles dedupe.
  // Duplicate is reinforce, not block.
  return { allow: true, reason: existingEdge ? 'reinforce_existing' : 'new_explicit_relation', isReinforce: !!existingEdge };
}

// Lightweight debug stage writer â€” best-effort, never throws.
async function memoryProdLogDebugStage(accessToken, projectId, uid, stage, payload = {}) {
  try {
    if (!accessToken || !projectId || !uid || !stage) return;
    await writeMemoryDebugLog(accessToken, projectId, uid, {
      stage,
      sessionId: trimMemoryText(payload?.sessionId || '', 160),
      jobId: trimMemoryText(payload?.jobId || '', 160),
      threadId: trimMemoryText(payload?.threadId || payload?.threadKey || '', 160),
      userMsgId: trimMemoryText(payload?.userMsgId || '', 160),
      nodeId: trimMemoryText(payload?.nodeId || '', 160),
      nodeLabel: trimMemoryText(payload?.nodeLabel || '', 80),
      candidateId: trimMemoryText(payload?.candidateId || '', 160),
      sliceId: trimMemoryText(payload?.sliceId || '', 160),
      eventId: trimMemoryText(payload?.eventId || '', 160),
      edgeId: trimMemoryText(payload?.edgeId || '', 160),
      decision: trimMemoryText(payload?.decision || '', 80),
      reason: trimMemoryText(payload?.reason || '', 240),
      confidence: typeof payload?.confidence === 'number' ? payload.confidence : null,
      modelUsed: trimMemoryText(payload?.modelUsed || '', 120),
      triageTier: trimMemoryText(payload?.triageTier || '', 4),
      failedStep: trimMemoryText(payload?.failedStep || '', 80),
      error: trimMemoryText(payload?.error || '', 500),
      details: payload?.details ? trimMemoryText(JSON.stringify(payload.details), 1500) : ''
    });
  } catch (_) { /* swallow â€” debug logging must never fail a turn */ }
}



function memoryProdHasUncertaintyCue(text = '') {
  const lower = String(text || '').toLowerCase();
  if (!lower) return false;
  return /(\bmaybe\b|\bperhaps\b|\bpossibly\b|\bprobably\b|\bmight\b|\bnot sure\b|\bunsure\b|\bunclear\b|\bconfused\b|\bi guess\b|\bkind of\b|\bkinda\b|\bsort of\b|\bsomewhat\b|\bnot really sure\b|\bthinking about\b|\bconsidering\b|\btrying to see if\b|\bfigure out whether\b)/.test(lower);
}


function memoryProdShouldPreferDurable(item) {
  const label = trimMemoryText(item?.label || '', 80);
  const key = normalizeMemoryKey(label);
  if (!label || !key || memoryProdIsBlockedCandidateLabel(label)) return false;
  if (memoryProdIsGenericNodeLabel(label) || memoryProdLooksGenericScopedLabel(label)) return false;
  const role = memoryProdNormalizeMemoryGroup(item?.group || item?.roleGuess || 'interest');
  if (role === 'reserve') return false;
  const combined = trimMemoryText(`${label} ${item?.summaryHint || item?.info || ''} ${item?.stateHint || ''}`, 420);
  if (memoryProdHasUncertaintyCue(combined)) return false;

  // v3.1.15 hard arbiter controls: shallow concepts are candidates, not durable nodes.
  if (item?._arbiterDecision === 'reject') return false;
  if (item?._forceCandidate === true || item?._clearButShallow === true || item?._arbiterDecision === 'candidate') return false;
  if (item?._allowDurable === true || item?._arbiterDecision === 'durable') return true;

  // Life Fast Lane bypasses normal meaningful-detail gating.
  if (item?.directDurable) return true;
  if (String(item?.importanceHint || '').toLowerCase() === 'life_significant') return true;

  // Event-worthy is NOT enough by itself anymore. A lifecycle-only phrase like
  // "started learning X" stays candidate unless there is real detail / named project / life lane.
  if (item?._namedProjectAnchor === true || item?._hasMeaningfulDetail === true) return true;
  if (memoryProdHasMeaningfulDetail(item, combined)) return true;
  return false;
}

function memoryProdBuildHeuristicCandidatesFromUserText(userText = '') {
  const cleanUserText = trimMemoryText(userText || '', 260);
  if (!cleanUserText || memoryProdUserTextLooksTrivial(cleanUserText)) return [];
  const anchor = memoryProdInferPrimaryConceptLabel(cleanUserText, cleanUserText);
  if (!anchor) return [];
  let roleGuess = 'interest';
  if (/(building|launching|developing|creating|project|app|startup|play store|product)/i.test(cleanUserText)) roleGuess = 'project';
  else if (/(goal|want to|plan to|aim to)/i.test(cleanUserText)) roleGuess = 'goal';
  else if (/(practice|training|train|learning|study|studying|skill|boxing|football|flutter)/i.test(cleanUserText)) roleGuess = 'skill';
  else if (/(every day|everyday|daily|routine|habit)/i.test(cleanUserText)) roleGuess = 'habit';
  else if (/(i am|i'm|im a|im an|i work as|i study)/i.test(cleanUserText)) roleGuess = 'identity';
  const action = memoryProdNormalizeLifecycleAction(memoryProdInferLifecycleActionFromText(cleanUserText));
  return [{
    label: anchor,
    roleGuess,
    strength: memoryProdHasHighSignalCue(cleanUserText) || memoryProdIsLifeMemoryText(cleanUserText) ? 'strong' : 'medium',
    clusterHint: memoryProdSanitizeClusterHint('', anchor, roleGuess, cleanUserText),
    parentHint: '',
    importanceHint: inferImportanceForLabel(anchor, roleGuess, cleanUserText),
    summaryHint: trimMemoryText(cleanUserText, 220),
    stateHint: trimMemoryText(memoryProdNodeStateFromLifecycleAction(action), 24),
    eventHint: {
      worthy: !!action || memoryProdIsLifeMemoryText(cleanUserText),
      action,
      summary: trimMemoryText(cleanUserText, 220),
      timeText: '',
      eventType: trimMemoryText(memoryProdEventTypeFromLifecycleAction(action, roleGuess), 60)
    },
    relationHints: []
  }];
}

function memoryProdPrepareLearnedOutput(learned, userText = '', existingNodes = []) {
  const trivialUserText = memoryProdUserTextLooksTrivial(userText);
  const prepared = [];
  const sorted = (Array.isArray(learned?.candidates) ? learned.candidates : [])
    .map((item) => memoryProdApplyFastLaneProfile({ ...(item || {}), clusterHint: memoryProdSanitizeClusterHint(item?.clusterHint || item?.cluster || '', item?.label || '', item?.roleGuess || item?.group || '', item?.summaryHint || item?.info || '') }, userText))
    .filter((item) => {
      if (!trimMemoryText(item?.label || '', 80)) return false;
      if (memoryProdIsBlockedCandidateLabel(item.label)) return false;
      if (trivialUserText && !item.directDurable && !item.eventHint?.worthy) return false;
      if (!item.directDurable && memoryProdTokenizeForMatch(item.label).length === 0) return false;
      return true;
    })
    .sort((a, b) => memoryProdCandidatePriority(b, userText) - memoryProdCandidatePriority(a, userText));

  for (const rawCandidate of sorted) {
    const candidate = { ...rawCandidate };
    // v3.1.14 â€” Anchor rewrite: trigger on broader generic-label detection,
    // not just looksGenericScopedLabel. Also rewrite when an inferred anchor
    // strictly outscores the model's label (e.g. "build app" â†’ "GPMai").
    const inferredAnchorLabel = memoryProdInferPrimaryConceptLabel(userText, `${candidate.summaryHint || ''} ${candidate.label || ''}`);
    const labelIsGeneric = memoryProdIsGenericNodeLabel(candidate.label) || memoryProdLooksGenericScopedLabel(candidate.label);
    if (labelIsGeneric && inferredAnchorLabel && !memoryProdIsBlockedCandidateLabel(inferredAnchorLabel) && !memoryProdIsGenericNodeLabel(inferredAnchorLabel)) {
      candidate.aliases = boundedUniqueIds([candidate.label, ...(Array.isArray(candidate.aliases) ? candidate.aliases : [])], 12);
      candidate.label = inferredAnchorLabel;
      candidate._anchorRewritten = true;
      candidate._anchorRewriteReason = 'generic_label_to_inferred_anchor';
      candidate.summaryHint = memoryProdMergeSummaryHints(candidate.summaryHint || '', userText || '', 220);
      candidate.clusterHint = memoryProdSanitizeClusterHint(candidate.clusterHint || '', inferredAnchorLabel, candidate.roleGuess || candidate.group || 'interest', candidate.summaryHint || userText || '');
    }
    const matchedNode = memoryProdFindBestExistingNodeMatch(existingNodes, candidate);
    if (matchedNode) {
      candidate.aliases = boundedUniqueIds([candidate.label, ...(Array.isArray(candidate.aliases) ? candidate.aliases : []), ...(Array.isArray(matchedNode.aliases) ? matchedNode.aliases : [])], 12);
      candidate.label = matchedNode.label || candidate.label;
      candidate.roleGuess = memoryProdNormalizeMemoryGroup(matchedNode.group || candidate.roleGuess || 'interest');
      candidate.clusterHint = memoryProdSanitizeClusterHint(matchedNode.clusterId || candidate.clusterHint || '', matchedNode.label || candidate.label || '', matchedNode.group || candidate.roleGuess || '', matchedNode.info || candidate.summaryHint || '');
      candidate.parentHint = candidate.parentHint || trimMemoryText(matchedNode.parentId || '', 80);
      // v3.3.6 â€” do not pollute current update summary with old node.info.
      candidate._matchedExistingNodeInfo = trimMemoryText(matchedNode.info || '', 260);
      candidate.summaryHint = trimMemoryText(candidate.summaryHint || candidate.info || userText || '', 220);
    }

    let merged = false;
    for (const primary of prepared) {
      if (memoryProdShouldMergeCandidateIntoPrimary(primary, candidate)) {
        memoryProdAbsorbCandidate(primary, candidate);
        merged = true;
        break;
      }
    }
    if (merged) continue;
    // v3.1.14 â€” Hard node gate: if after anchor rewrite + alias match the label is
    // STILL generic and there is no existing-node match, downgrade to candidate
    // (annotate, don't drop â€” caller decides candidate-vs-node).
    if (!matchedNode && memoryProdIsGenericNodeLabel(candidate.label) && !candidate.directDurable) {
      candidate._gateDowngraded = true;
      candidate._gateReason = 'generic_label_no_match';
      candidate.strength = 'medium';
    }
    if (prepared.length >= MEMORY_CANDIDATE_PER_SLICE_CAP) {
      const bestTarget = prepared
        .map((primary) => ({
          primary,
          score: (memoryProdShouldMergeCandidateIntoPrimary(primary, candidate) ? 100 : 0)
            + (primary.clusterHint === candidate.clusterHint ? 6 : 0)
            + memoryProdTokenOverlapCount(primary.label || '', candidate.label || '')
            + Math.min(3, memoryProdTokenOverlapCount(primary.summaryHint || '', candidate.summaryHint || ''))
        }))
        .sort((a, b) => b.score - a.score)[0];
      if (bestTarget && bestTarget.score >= 100) {
        memoryProdAbsorbCandidate(bestTarget.primary, candidate);
      }
      continue;
    }
    prepared.push({
      ...candidate,
      aliases: boundedUniqueIds([candidate.label, ...(Array.isArray(candidate.aliases) ? candidate.aliases : [])], 12),
      relationHints: Array.isArray(candidate.relationHints) ? candidate.relationHints : []
    });
  }

  return {
    candidates: prepared.map((item) => ({
      ...item,
      summaryHint: trimMemoryText(item.summaryHint || '', 220),
      clusterHint: memoryProdSanitizeClusterHint(item.clusterHint || '', item.label || '', item.roleGuess || item.group || '', item.summaryHint || ''),
      importanceHint: trimMemoryText(item.importanceHint || inferImportanceForLabel(item.label || '', item.roleGuess || item.group || '', item.summaryHint || ''), 40),
      strength: item.directDurable ? 'strong' : memoryProdNormalizeStrength(item.strength || 'medium')
    }))
  };
}

function memoryProdBuildNodeSummaryWithLatestEvent(node, eventDoc) {
  const current = trimMemoryText(node?.info || '', 260);
  const eventDate = trimMemoryText(eventDoc?.absoluteDate || safeIsoDateFromMs(eventDoc?.updatedAt || eventDoc?.createdAt || Date.now()), 20);
  const eventSummary = trimMemoryText(eventDoc?.summary || '', 180);
  const state = trimMemoryText(memoryProdNodeStateFromLifecycleAction(eventDoc?.lifecycleAction || '', trimMemoryText(node?.currentState || '', 24)) || trimMemoryText(node?.currentState || '', 24), 24);
  const evidencePreview = trimMemoryText(Array.isArray(eventDoc?.evidence) && eventDoc.evidence.length ? String(eventDoc.evidence[0]?.snippet || '') : '', 120);
  const latest = trimMemoryText(`Latest update (${eventDate}): ${eventSummary}${state ? ` Current state: ${state}.` : ''}${evidencePreview ? ` Evidence: ${evidencePreview}.` : ''}`, 300);
  if (!current) return latest;
  if (current.toLowerCase().includes(latest.toLowerCase())) return current;
  return trimMemoryText(`${current} ${latest}`, 360);
}

function memoryProdNormalizeStrength(value) {
  const v = String(value || '').trim().toLowerCase();
  return ['weak', 'medium', 'normal', 'strong'].includes(v) ? (v === 'normal' ? 'medium' : v) : 'medium';
}

function memoryProdNormalizeLifecycleAction(value) {
  const v = String(value || '').trim().toLowerCase().replace(/\s+/g, '_');
  const map = {
    start: 'started', started: 'started', begin: 'started', began: 'started', learning: 'started', active: 'started',
    stop: 'stopped', stopped: 'stopped', quit: 'stopped', ended: 'stopped', inactive: 'stopped',
    pause: 'paused', paused: 'paused', hold: 'paused', postponed: 'paused',
    resume: 'resumed', resumed: 'resumed', restart: 'resumed', restarted: 'resumed', continued: 'resumed',
    complete: 'completed', completed: 'completed', finished: 'completed',
    launch: 'launched', launched: 'launched', release: 'launched', released: 'launched', shipped: 'launched',
    block: 'blocked', blocked: 'blocked', issue: 'blocked', failure: 'blocked', setback: 'blocked',
    fix: 'fixed', fixed: 'fixed', resolve: 'fixed', resolved: 'fixed', healed: 'fixed', recovered: 'fixed',
    change: 'changed_plan', changed: 'changed_plan', switched: 'changed_plan', changed_plan: 'changed_plan'
  };
  return map[v] || '';
}

function memoryProdInferLifecycleActionFromText(text) {
  // SURGICAL PATCH E1: Expanded semantic variants for natural language.
  // The regex groups now cover casual speech patterns so "I gave up football",
  // "I got into boxing", "I'm no longer doing X", etc. map to the correct action.
  // Order matters: more specific / negated patterns go first so "no longer doing"
  // is caught as stopped before "doing" matches started.
  const lower = String(text || '').toLowerCase();
  // STOPPED: quit, gave up, no longer, dropped, not doing anymore, left
  if (/(stopped|stop doing|quit|quitting|no longer|not doing anymore|don't do anymore|dont do anymore|gave up|giving up|give up on|ended|dropped|left (boxing|football|the team|my job|my coach)|i don't (do|play|practice) (it )?anymore|i dont (do|play|practice) (it )?anymore|walked away from|stepped away from)/.test(lower)) return 'stopped';
  // PAUSED: break, hold, step back
  if (/(paused|pausing|taking a break|on hold|postponed|put on hold|stepping back|step back from|taking time off|on pause)/.test(lower)) return 'paused';
  // RESUMED: back, restarted, returning
  if (/(resumed|resuming|started again|restarted|restarting|back to|getting back into|got back into|picked (it )?back up|returning to|i'm back at|im back at|returned to)/.test(lower)) return 'resumed';
  // COMPLETED: finished, done with
  if (/(completed|completing|finished|done with|wrapped up|i'm done|im done with|i am done with)/.test(lower)) return 'completed';
  // LAUNCHED: released, shipped
  if (/(launched|launching|released|shipping|shipped|went live|put it out|pushed (it )?out)/.test(lower)) return 'launched';
  // BLOCKED: stuck, hit a wall
  if (/(blocked|stuck on|stuck with|hit a wall|can't move forward|cant move forward|can't proceed|cant proceed|issue with|problem with|bug in|injury|pain|failed|failure|setback|roadblock)/.test(lower)) return 'blocked';
  // FIXED: resolved, healed, recovered
  if (/(fixed|fixing|resolved|resolving|healed|recovered|recovering|sorted out|figured out|solved|got over)/.test(lower)) return 'fixed';
  // STARTED: began, got into, joined, picked up, learning
  if (/(\bstarted\b|\bstart\b|\bbeginning\b|\bbegan\b|\bbegin\b|just started|learning|working on|building|doing now|got into|getting into|i'm into|im into|joined|signed up for|picked up|taking up|took up|started doing)/.test(lower)) return 'started';
  return '';
}

// SURGICAL PATCH: Auto-edge regex inference backup for when the model misses relation_hints.
// Parses user text for directional relationship patterns ("X uses Y", "X depends on Y", etc.)
// and maps phrases back to known labels (learned candidates + existing nodes).
function memoryProdInferConnectionsFromUserText(userText, learnedCandidates = [], existingNodes = []) {
  const out = [];
  const hay = String(userText || '').toLowerCase();
  if (!hay || hay.length < 6) return out;

  // Build a normalized-label registry from candidates + existing nodes (and their aliases).
  const registry = new Map(); // normKey -> displayLabel
  const addLabel = (display, aliases = []) => {
    const primary = trimMemoryText(display || '', 80);
    if (!primary) return;
    const primaryKey = normalizeMemoryKey(primary);
    if (primaryKey) registry.set(primaryKey, primary);
    for (const al of Array.isArray(aliases) ? aliases : []) {
      const k = normalizeMemoryKey(al || '');
      if (k && !registry.has(k)) registry.set(k, primary);
    }
  };
  for (const item of Array.isArray(learnedCandidates) ? learnedCandidates : []) {
    addLabel(item?.label, item?.aliases);
  }
  for (const node of Array.isArray(existingNodes) ? existingNodes : []) {
    if (!node || node.deleted) continue;
    addLabel(node.label, node.aliases);
  }
  if (registry.size === 0) return out;

  // Resolve a free-text phrase back to a known display label.
  const resolvePhrase = (phrase) => {
    const cleaned = trimMemoryText(phrase || '', 60).replace(/[^a-z0-9\- ]+/gi, ' ').trim();
    if (!cleaned) return '';
    const key = normalizeMemoryKey(cleaned);
    if (!key) return '';
    if (registry.has(key)) return registry.get(key);
    // Try substring match against known keys (length >= 3 to avoid matching noise).
    for (const [k, v] of registry.entries()) {
      if (k.length < 3) continue;
      if (key === k) return v;
      if (key.includes(k) || k.includes(key)) return v;
    }
    return '';
  };

  // Directional relationship patterns. Captures are deliberately bounded (2-40 chars)
  // to avoid runaway matches across sentence boundaries.
  const patterns = [
    { type: 'uses',       regex: /([\w][\w\- ]{1,40}?)\s+(?:uses|use|using|built with|built on|runs on|is built with|powered by|implemented with)\s+([\w][\w\- ]{1,40})/gi },
    { type: 'depends_on', regex: /([\w][\w\- ]{1,40}?)\s+(?:depends on|relies on|requires|needs)\s+([\w][\w\- ]{1,40})/gi },
    { type: 'part_of',    regex: /([\w][\w\- ]{1,40}?)\s+(?:is part of|part of|belongs to|inside|within|included in)\s+([\w][\w\- ]{1,40})/gi },
    { type: 'drives',     regex: /([\w][\w\- ]{1,40}?)\s+(?:drives|powers|fuels|enables)\s+([\w][\w\- ]{1,40})/gi },
    { type: 'supports',   regex: /([\w][\w\- ]{1,40}?)\s+(?:supports|helps|assists|backs)\s+([\w][\w\- ]{1,40})/gi },
    { type: 'improves',   regex: /([\w][\w\- ]{1,40}?)\s+(?:improves|boosts|enhances|optimizes|speeds up)\s+([\w][\w\- ]{1,40})/gi }
  ];

  const seen = new Set();
  for (const { type, regex } of patterns) {
    let m;
    regex.lastIndex = 0;
    while ((m = regex.exec(hay)) !== null) {
      const fromLabel = resolvePhrase(m[1]);
      const toLabel = resolvePhrase(m[2]);
      if (!fromLabel || !toLabel) continue;
      if (normalizeMemoryKey(fromLabel) === normalizeMemoryKey(toLabel)) continue;
      const key = `${normalizeMemoryKey(fromLabel)}|${type}|${normalizeMemoryKey(toLabel)}`;
      if (seen.has(key)) continue;
      seen.add(key);
      out.push({
        from: fromLabel,
        to: toLabel,
        type,
        reason: `Inferred from user text: "${trimMemoryText(m[0], 100)}"`
      });
    }
  }
  return out;
}

function memoryProdNodeStateFromLifecycleAction(action, fallback = '') {
  const a = memoryProdNormalizeLifecycleAction(action);
  if (['started', 'resumed', 'fixed', 'launched'].includes(a)) return 'active';
  if (a === 'paused') return 'paused';
  if (a === 'stopped') return 'inactive';
  if (a === 'completed') return 'completed';
  if (a === 'blocked') return 'blocked';
  if (a === 'changed_plan') return fallback || 'active';
  return fallback || '';
}

function memoryProdEventStatusFromLifecycleAction(action) {
  const a = memoryProdNormalizeLifecycleAction(action);
  if (!a) return 'recorded';
  if (['blocked', 'paused'].includes(a)) return 'open';
  if (['fixed', 'completed', 'launched', 'stopped'].includes(a)) return 'resolved';
  return 'recorded';
}

function memoryProdEventTypeFromLifecycleAction(action, group = '') {
  const a = memoryProdNormalizeLifecycleAction(action);
  if (a) return `lifecycle_${a}`;
  const g = memoryProdNormalizeMemoryGroup(group);
  if (g === 'project') return 'project_progress';
  if (g === 'goal') return 'goal_update';
  if (g === 'skill') return 'learning_update';
  if (g === 'habit') return 'habit_update';
  if (g === 'preference') return 'preference_update';
  return 'conversation_memory_update';
}

function memoryProdCandidateExpiryDays(strength, sessionCount = 1) {
  const s = memoryProdNormalizeStrength(strength);
  if (s === 'strong' || sessionCount >= 3) return 45;
  if (s === 'medium' || sessionCount >= 2) return 21;
  return 10;
}

// ARCH Â§3.1 â€” Build a single candidate-evidence entry. Evidence is a bounded array on
// memoryCandidates/{id} that captures *why* this candidate was created or reinforced.
// Types: lifecycle_start | lifecycle_resume | lifecycle_stop | lifecycle_pause |
//        clear_but_shallow | uncertain | possible_duplicate | meaningful_detail | reinforce.
function memoryProdBuildCandidateEvidenceEntry({ type, summary, sourceMsgId = '', role = 'user', confidence = 0.7, nowMs = Date.now() } = {}) {
  return {
    type: trimMemoryText(type || 'reinforce', 40),
    summary: trimMemoryText(summary || '', 220),
    sourceMsgId: trimMemoryText(sourceMsgId || '', 160),
    role: trimMemoryText(role || 'user', 16),
    confidence: typeof confidence === 'number' ? Math.max(0, Math.min(1, confidence)) : 0.7,
    createdAt: num(nowMs, Date.now())
  };
}

// ARCH Â§3.1 â€” Append a new evidence entry to an existing candidate's evidence array,
// dedupe by (type, sourceMsgId), cap at MEMORY_CANDIDATE_EVIDENCE_CAP keeping newest.
function memoryProdAppendCandidateEvidence(existingEvidence, newEntry) {
  const existing = Array.isArray(existingEvidence) ? existingEvidence.slice() : [];
  if (!newEntry || !newEntry.type) return existing.slice(0, MEMORY_CANDIDATE_EVIDENCE_CAP);
  const dedupIdx = existing.findIndex((e) => e && e.type === newEntry.type && trimMemoryText(e.sourceMsgId || '', 160) === trimMemoryText(newEntry.sourceMsgId || '', 160));
  if (dedupIdx >= 0) {
    existing[dedupIdx] = { ...existing[dedupIdx], ...newEntry, createdAt: existing[dedupIdx].createdAt || newEntry.createdAt };
  } else {
    existing.push(newEntry);
  }
  // Keep most recent N (sort by createdAt desc).
  return existing
    .filter(Boolean)
    .sort((a, b) => num(b.createdAt, 0) - num(a.createdAt, 0))
    .slice(0, MEMORY_CANDIDATE_EVIDENCE_CAP);
}

// ARCH Â§3.1 â€” Map a lifecycle action to a candidate-evidence type.
function memoryProdLifecycleActionToEvidenceType(action) {
  const a = String(action || '').toLowerCase().trim();
  if (a === 'started' || a === 'start' || a === 'began' || a === 'begin') return 'lifecycle_start';
  if (a === 'resumed' || a === 'resume' || a === 'restarted') return 'lifecycle_resume';
  if (a === 'stopped' || a === 'stop' || a === 'quit' || a === 'ended') return 'lifecycle_stop';
  if (a === 'paused' || a === 'pause') return 'lifecycle_pause';
  return '';
}

function memoryProdShouldFastPromoteGroup(group) {
  // SURGICAL PATCH P1: Added 'identity' to fast-promote list.
  // Per spec: strong project/goal/preference/habit/identity can promote after 1 strong session.
  // Previously identity had threshold=2 and had to wait across sessions to become durable.
  return ['project', 'goal', 'preference', 'habit', 'identity'].includes(memoryProdNormalizeMemoryGroup(group));
}

function memoryProdSummarizeCandidateEvent(primaryLabel, eventHint, userText) {
  const action = memoryProdNormalizeLifecycleAction(eventHint?.action || '');
  const candidateSummary = trimMemoryText(eventHint?.summary || '', 180);
  if (candidateSummary) return candidateSummary;
  if (action && primaryLabel) return trimMemoryText(`${capitalizeMemoryWord(action)} ${primaryLabel}`, 180);
  if (primaryLabel && userText) return trimMemoryText(`${primaryLabel}: ${userText}`, 180);
  return trimMemoryText(userText || `Update about ${primaryLabel || 'memory'}`, 180);
}

async function memoryProdEnsureMemoryConnection(accessToken, projectId, uid, fromNodeId, toNodeId, type, reason = '', nowMs = Date.now(), existingConnections = null) {
  if (!fromNodeId || !toNodeId || fromNodeId === toNodeId) return null;
  const normalizedType = normalizeMemoryConnectionType(type);
  const allConnections = Array.isArray(existingConnections) ? existingConnections : await listMemoryConnections(accessToken, projectId, uid);
  const existingConn = allConnections.find((c) => !c.deleted && canonicalConnectionKey(c.fromNodeId, c.toNodeId, c.type) === canonicalConnectionKey(fromNodeId, toNodeId, normalizedType));
  const connId = existingConn?.id || buildMemoryConnectionId(MEMORY_SCOPE, fromNodeId, toNodeId, normalizedType);
  const patch = {
    id: connId,
    fromNodeId: MEMORY_BIDIRECTIONAL_TYPES.has(normalizedType) && fromNodeId > toNodeId ? toNodeId : fromNodeId,
    toNodeId: MEMORY_BIDIRECTIONAL_TYPES.has(normalizedType) && fromNodeId > toNodeId ? fromNodeId : toNodeId,
    type: normalizedType,
    coCount: Math.max(1, num(existingConn?.coCount, 0) + 1),
    reason: trimMemoryText(reason || existingConn?.reason || 'Meaningful semantic relationship.', 180),
    modeScope: MEMORY_SCOPE,
    deleted: false,
    createdAt: num(existingConn?.createdAt, nowMs),
    lastUpdated: nowMs,
    state: existingConn ? 'reinforced' : 'created'
  };
  await fsUpsertDoc(accessToken, projectId, `users/${uid}/memoryConnections/${connId}`, patch);
  if (Array.isArray(existingConnections)) {
    const idx = existingConnections.findIndex((c) => c?.id === connId);
    if (idx >= 0) existingConnections[idx] = { ...(existingConnections[idx] || {}), ...patch };
    else existingConnections.push(patch);
  }
  return patch;
}

async function memoryProdChooseParentForCandidate(accessToken, projectId, uid, candidate, existingNodes = null) {
  const nodes = Array.isArray(existingNodes) ? existingNodes : await listMemoryNodes(accessToken, projectId, uid);
  const safeNodes = nodes.filter((node) => !node.deleted);
  const parentHint = trimMemoryText(candidate?.parentHint || candidate?.parentLabel || '', 80);
  if (parentHint) {
    const hinted = memoryProdFindBestExistingNodeMatch(safeNodes, { label: parentHint, roleGuess: 'project' }) || findMemoryNodeByLabel(safeNodes, MEMORY_SCOPE, parentHint);
    if (hinted) return hinted;
  }
  const clusterHint = trimMemoryText(candidate?.clusterHint || '', 40).toLowerCase();
  if (clusterHint && memoryProdNormalizeMemoryGroup(candidate?.roleGuess) !== 'project') {
    const projectParent = safeNodes
      .filter((node) => memoryProdNormalizeMemoryGroup(node.group) === 'project' && String(node.clusterId || '').toLowerCase() === clusterHint)
      .sort((a, b) => num(b.heat, 0) - num(a.heat, 0))[0];
    if (projectParent) return projectParent;
  }
  return safeNodes.find((node) => node.id === 'root' && !node.deleted) || { id: 'root', label: 'You', group: 'identity', isRoot: true };
}


async function memoryProdCreateOrReuseMemorySession(accessToken, projectId, uid, cfg, payload = {}) {
  const nowMs = num(payload?.nowMs, Date.now());
  const sourceTag = trimMemoryText(payload?.sourceTag || 'chat', 40).toLowerCase() || 'chat';
  const threadKey = buildMemoryThreadKey(payload?.threadId || payload?.chatId || payload?.conversationId || '', sourceTag);
  const threadPath = `users/${uid}/memoryThreads/${threadKey}`;
  const existingThread = parseFirestoreFields((await fsGetDoc(accessToken, projectId, threadPath))?.fields || {});
  const activeSessionId = trimMemoryText(existingThread?.activeSessionId || '', 120);
  const activeSession = activeSessionId ? parseFirestoreFields((await fsGetDoc(accessToken, projectId, `users/${uid}/memorySessions/${activeSessionId}`))?.fields || {}) : null;
  const gapMs = Math.max(MEMORY_SESSION_GAP_MS, num(cfg?.memorySessionGapHours, 12) * 60 * 60 * 1000);
  const reuse = activeSession && !activeSession.deleted && activeSession.threadKey === threadKey && (nowMs - num(activeSession.lastActivityAt, 0) <= gapMs);
  const sessionId = reuse ? activeSession.id : buildMemorySessionId(threadKey, nowMs);
  const countedTopicKeys = boundedUniqueIds(reuse && Array.isArray(activeSession?.countedTopicKeys) ? activeSession.countedTopicKeys : [], MEMORY_SESSION_COUNTED_TOPIC_CAP);
  const linkedEventIds = boundedUniqueIds(reuse && Array.isArray(activeSession?.linkedEventIds) ? activeSession.linkedEventIds : [], MEMORY_SESSION_EVENT_PREVIEW_CAP);
  const previousLastActivityAt = num(reuse ? activeSession.lastActivityAt : 0, 0);
  const previousProcessedAt = num(reuse ? activeSession.lastProcessedAt : 0, 0);
  const sessionDoc = {
    id: sessionId,
    threadKey,
    sourceTag,
    threadId: trimMemoryText(payload?.threadId || payload?.chatId || payload?.conversationId || '', 120),
    startedAt: reuse ? num(activeSession.startedAt, nowMs) : nowMs,
    lastActivityAt: nowMs,
    prevLastActivityAt: previousLastActivityAt,
    prevLastProcessedAt: previousProcessedAt,
    turnCount: Math.max(1, num(reuse ? activeSession.turnCount : 0, 0) + 1),
    messageCount: Math.max(1, Array.isArray(payload?.messages) ? payload.messages.length : num(reuse ? activeSession.messageCount : 0, 0)),
    countedTopicKeys,
    linkedEventIds,
    lastEventId: trimMemoryText(reuse ? activeSession.lastEventId : '', 160),
    lastProcessedMessageCount: Math.max(0, num(reuse ? activeSession.lastProcessedMessageCount : 0, 0)),
    lastProcessedLastUserHash: trimMemoryText(reuse ? activeSession.lastProcessedLastUserHash : '', 80),
    lastProcessedMessageSignature: trimMemoryText(reuse ? activeSession.lastProcessedMessageSignature : '', 160),
    lastProcessedAt: previousProcessedAt,
    // v2 cursor checkpoint â€” backend-log MsgId string. Preserved across session reuse.
    lastProcessedMsgId: trimMemoryText(reuse ? activeSession.lastProcessedMsgId : '', 160),
    lastProcessedMsgIdPrev: trimMemoryText(reuse ? activeSession.lastProcessedMsgIdPrev : '', 160),
    checkpointExpiresAt: num(reuse ? activeSession.checkpointExpiresAt : 0, 0),
    pendingSinceAt: num(reuse ? activeSession.pendingSinceAt : 0, 0),
    pendingSliceMessageCount: num(reuse ? activeSession.pendingSliceMessageCount : 0, 0),
    pendingSliceCharCount: num(reuse ? activeSession.pendingSliceCharCount : 0, 0),
    pendingTriggerReason: trimMemoryText(reuse ? activeSession.pendingTriggerReason : '', 80),
    lastExtractionReason: trimMemoryText(reuse ? activeSession.lastExtractionReason : '', 80),
    nextEligibleExtractAt: num(reuse ? activeSession.nextEligibleExtractAt : 0, 0),
    modeScope: MEMORY_SCOPE,
    status: 'active',
    dayKey: safeIsoDateFromMs(nowMs),
    schemaVersion: MEMORY_SCHEMA_VERSION,
    deleted: false,
    updatedAt: nowMs,
    createdAt: reuse ? num(activeSession.createdAt, nowMs) : nowMs
  };
  await fsUpsertDoc(accessToken, projectId, `users/${uid}/memorySessions/${sessionId}`, sessionDoc);
  await fsUpsertDoc(accessToken, projectId, threadPath, {
    id: threadKey,
    threadKey,
    activeSessionId: sessionId,
    threadId: sessionDoc.threadId,
    sourceTag,
    lastActivityAt: nowMs,
    updatedAt: nowMs,
    createdAt: num(existingThread?.createdAt, nowMs)
  });
  return sessionDoc;
}


// ----------------------------------------------------------------------------
// ARCH Â§11 + Â§13 â€” Session learning lock with optimistic concurrency.
// Enforces "one learning process at a time per session/thread" using Firestore
// commit writes with currentDocument.updateTime preconditions. The lock state
// lives on memorySessions/{id}:
//   learningStatus            'idle' | 'running'
//   learningLockId            jobId of current holder
//   learningLockExpiresAt     epoch-ms; expired locks may be stolen
//   learningLockAcquiredAt    epoch-ms when lock was last taken
//   pendingLearning           true when a contended job asked for follow-up
// Acquire reads the doc + updateTime, then commits a precondition write.
// On precondition-fail (concurrent writer), Firestore returns 400 and we
// classify as contention. This is REAL CAS, not a fake check.
// ----------------------------------------------------------------------------

function memoryProdBuildLockUpdateWrite(projectId, docPath, plainObj, preconditionUpdateTime) {
  // ARCH Â§13 â€” Build a Firestore commit Write with optional updateTime precondition.
  // Mirrors makeFirestoreUpdateWrite shape but adds currentDocument.updateTime so
  // the commit only succeeds when the doc has not been mutated since we read it.
  const write = {
    update: {
      name: buildFirestoreDocName(projectId, docPath),
      fields: toFirestoreFields(plainObj || {})
    },
    updateMask: { fieldPaths: Object.keys(plainObj || {}) }
  };
  if (preconditionUpdateTime) {
    write.currentDocument = { updateTime: preconditionUpdateTime };
  }
  return write;
}

async function memoryProdAcquireLearningLock(accessToken, projectId, uid, sessionId, jobId, nowMs = Date.now(), ttlMs = MEMORY_LEARNING_LOCK_TTL_MS) {
  // ARCH Â§11 â€” Try to acquire the per-session learning lock atomically.
  // Returns one of:
  //   { acquired: true,  expiresAt }                                    â€” lock held by jobId
  //   { acquired: false, reason: 'busy', holderJobId, holderExpiresAt } â€” another job holds it (not expired)
  //   { acquired: false, reason: 'session_missing' }                    â€” session doc not found
  //   { acquired: false, reason: 'precondition_lost', error }           â€” lost CAS race after retries
  //   { acquired: false, reason: 'commit_error', error }                â€” non-precondition Firestore failure
  if (!sessionId || !jobId) return { acquired: false, reason: 'invalid_args' };
  const docPath = `users/${uid}/memorySessions/${sessionId}`;
  const maxAttempts = MEMORY_LEARNING_LOCK_MAX_ACQUIRE_RETRIES + 1;
  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    const raw = await fsGetDoc(accessToken, projectId, docPath);
    if (!raw) return { acquired: false, reason: 'session_missing' };
    const fields = parseFirestoreFields(raw.fields || {});
    const updateTime = raw.updateTime || '';
    const status = String(fields?.learningStatus || 'idle').toLowerCase();
    const holderId = trimMemoryText(fields?.learningLockId || '', 180);
    const holderExp = num(fields?.learningLockExpiresAt, 0);
    const expired = holderExp > 0 && holderExp < nowMs;
    if (status === 'running' && holderId && holderId !== jobId && !expired) {
      return { acquired: false, reason: 'busy', holderJobId: holderId, holderExpiresAt: holderExp };
    }
    const newExpiresAt = nowMs + Math.max(5000, ttlMs);
    const lockPatch = {
      learningStatus: 'running',
      learningLockId: jobId,
      learningLockExpiresAt: newExpiresAt,
      learningLockAcquiredAt: nowMs,
      pendingLearning: false,
      updatedAt: nowMs,
      schemaVersion: MEMORY_SCHEMA_VERSION
    };
    const write = memoryProdBuildLockUpdateWrite(projectId, docPath, lockPatch, updateTime);
    try {
      await fsCommitWrites(accessToken, projectId, [write]);
      return { acquired: true, expiresAt: newExpiresAt };
    } catch (err) {
      const errText = String(err?.message || err || '');
      // Firestore returns FAILED_PRECONDITION (400) when the doc was mutated mid-CAS.
      if (/FAILED_PRECONDITION|400/.test(errText)) {
        if (attempt >= MEMORY_LEARNING_LOCK_MAX_ACQUIRE_RETRIES) {
          return { acquired: false, reason: 'precondition_lost', error: errText };
        }
        continue;
      }
      console.log(`[learning_lock_acquire_error] sid=${sessionId} job=${jobId}: ${errText}`);
      return { acquired: false, reason: 'commit_error', error: errText };
    }
  }
  return { acquired: false, reason: 'precondition_lost' };
}

async function memoryProdReleaseLearningLock(accessToken, projectId, uid, sessionId, jobId, nowMs = Date.now()) {
  // ARCH Â§11 â€” Release the lock if (and only if) we still hold it.
  // Best-effort: if another job already stole an expired lock, no-op. Logs but does not throw.
  // Returns { released, reason?, holderJobId?, pendingLearning? } so callers can dispatch follow-up work.
  if (!sessionId || !jobId) return { released: false, reason: 'invalid_args' };
  const docPath = `users/${uid}/memorySessions/${sessionId}`;
  let raw = null;
  try {
    raw = await fsGetDoc(accessToken, projectId, docPath);
  } catch (err) {
    console.log(`[learning_lock_release_read_error] sid=${sessionId} job=${jobId}: ${String(err?.message || err)}`);
    return { released: false, reason: 'read_error', error: String(err?.message || err) };
  }
  if (!raw) return { released: false, reason: 'session_missing' };
  const fields = parseFirestoreFields(raw.fields || {});
  const holderId = trimMemoryText(fields?.learningLockId || '', 180);
  const pendingLearning = !!fields?.pendingLearning;
  if (holderId && holderId !== jobId) {
    return { released: false, reason: 'not_holder', holderJobId: holderId, pendingLearning };
  }
  const updateTime = raw.updateTime || '';
  const releasePatch = {
    learningStatus: 'idle',
    learningLockId: '',
    learningLockExpiresAt: 0,
    learningLockReleasedAt: nowMs,
    updatedAt: nowMs,
    schemaVersion: MEMORY_SCHEMA_VERSION
  };
  const write = memoryProdBuildLockUpdateWrite(projectId, docPath, releasePatch, updateTime);
  try {
    await fsCommitWrites(accessToken, projectId, [write]);
    return { released: true, pendingLearning };
  } catch (err) {
    const errText = String(err?.message || err || '');
    console.log(`[learning_lock_release_error] sid=${sessionId} job=${jobId}: ${errText}`);
    return { released: false, reason: 'commit_error', error: errText, pendingLearning };
  }
}

async function memoryProdMarkPendingLearning(accessToken, projectId, uid, sessionId, jobId, nowMs = Date.now()) {
  // ARCH Â§11 â€” When the lock is busy, mark pendingLearning=true on the session.
  // The current holder will see this on release and dispatch a follow-up job. The
  // contended job itself returns immediately without running Pass 1.
  if (!sessionId) return { marked: false, reason: 'invalid_args' };
  const patch = {
    pendingLearning: true,
    pendingLearningRequestedBy: trimMemoryText(jobId || '', 180),
    pendingLearningRequestedAt: nowMs,
    updatedAt: nowMs,
    schemaVersion: MEMORY_SCHEMA_VERSION
  };
  try {
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memorySessions/${sessionId}`, patch);
    return { marked: true };
  } catch (err) {
    console.log(`[learning_lock_mark_pending_error] sid=${sessionId} job=${jobId}: ${String(err?.message || err)}`);
    return { marked: false, reason: 'patch_error', error: String(err?.message || err) };
  }
}


function memoryProdBuildMemoryLearningUserPrompt(_mode, packet) {
  // SURGICAL PATCH E3: Rewritten prompt with:
  //  - Explicit semantic equivalence groups for lifecycle actions
  //  - Life-event rule (death/grief/diagnosis â†’ directDurable + life_event)
  //  - Anchor rule (main concept wins, scoped phrases absorbed)
  //  - Connection anti-rules (no same-cluster / no co-mention edges)
  //  - <relevant_nodes> section so LLM can match against pre-narrowed existing nodes
  const relevantNodesJson = JSON.stringify(Array.isArray(packet?.relevantNodes) ? packet.relevantNodes : []);
  const activeAnchorHintsJson = JSON.stringify(Array.isArray(packet?.activeAnchorHints) ? packet.activeAnchorHints : []);
  const plannedAnchorHintsJson = JSON.stringify(Array.isArray(packet?.plannedAnchorHints) ? packet.plannedAnchorHints : []);
  return [
    'You are the GPMai production memory extraction engine. This is a serious long-term semantic brain, not a toy chatbot.',
    'Return ONLY valid JSON. No markdown. No explanations. No commentary.',
    '',
    'Required JSON shape:',
    '{"reinforce_labels":["label"],"node_updates":[{"anchorLabel":"existing/planned anchor label, not a pronoun","anchorNodeId":"optional existing node id","resolvedFrom":"this app|it|kaka app|direct label","resolutionReason":"why this reference maps to the anchor","resolutionConfidence":0.92,"ambiguous":false,"alternativeAnchors":[],"detailDisposition":"attach_to_anchor|standalone_candidate|ambiguous_skip","summaryHint":"complete meaningful update attached to the anchor","meaningful":true,"eventWorthy":false,"updateKind":"feature_detail|technical_detail|progress|blocker|fix|lifecycle|decision|other","lifecycleAction":"","eventType":"","confidence":0.92,"edgeHints":[]}],"candidates":[{"label":"...","roleGuess":"project","strength":"strong","clusterHint":"work","parentHint":"GPMai","importanceHint":"important","summaryHint":"...","stateHint":"active","eventHint":{"worthy":true,"action":"started","summary":"...","timeText":"...","eventType":"lifecycle_started"},"relationHints":[{"to":"...","type":"supports","reason":"..."}]}],"relation_hints":[{"from":"...","to":"...","type":"depends_on","reason":"..."}]}',
    '',
    '===== CORE DECISIONS =====',
    '1) Identify the MAIN DURABLE CONCEPT in the new slice (a real noun the user will care about later: boxing, GPMai, anxiety, grandmother, Flutter).',
    '2) If the main concept already matches a node in <relevant_nodes> or <existing_memory>, PUT ITS EXACT EXISTING LABEL in reinforce_labels. Do NOT create a paraphrased candidate for the same thing.',
    '3) Candidate should be RARE. Use candidates only for genuinely low-confidence, vague, fuzzy, ambiguous, unresolved concepts. Clear meaningful user-life concepts should be expressed as strong durable-ready candidates so backend can promote them directly.',
    '4) If something HAPPENED to that concept (lifecycle change, life event, progress, blocker), set eventHint.worthy=true and fill action + summary.',
    '5) node_updates is for meaningful updates about an EXISTING node OR a SAME-BATCH PLANNED anchor. If the new user slice says "this app", "it", "kaka app", "the backend", "the UI", etc., resolve it using <planned_anchor_hints>, <active_anchor_hints>, <relevant_nodes>, and bridge context. You MUST explicitly fill resolutionReason, resolutionConfidence, ambiguous, and detailDisposition.',
    '6) Example: previous/same-slice context introduced app called Kaka; current says "the core feature of this app is Graph" â†’ node_updates[0].anchorLabel="Kaka", resolvedFrom="this app", resolutionReason="Kaka was the app just introduced", resolutionConfidence=0.92, ambiguous=false, detailDisposition="attach_to_anchor", summaryHint="Kaka core feature is Graph.", meaningful=true, eventWorthy=false. Do NOT create candidates for Graph or Kaka app. 7) If two anchors are plausible, set ambiguous=true and do NOT guess.',
    '',
    '===== LIFECYCLE ACTION â€” SEMANTIC EQUIVALENCE GROUPS =====',
    'Map ALL of these to the same canonical action. action must be one of: started, paused, resumed, stopped, blocked, fixed, completed, launched, changed_plan.',
    '  started   := started, began, begin, got into, getting into, joined, signed up for, picked up, took up, learning, now doing, "I\'m into X", "I\'m a X now"',
    '  stopped   := stopped, quit, gave up, "no longer", "don\'t do anymore", "not doing anymore", ended, dropped, walked away, left (the sport/team)',
    '  paused    := paused, "on hold", "taking a break", postponed, "stepping back", "put on hold"',
    '  resumed   := resumed, "started again", restarted, "back to", "getting back into", "returned to", "picked back up"',
    '  blocked   := blocked, stuck, "hit a wall", issue, problem, bug, injury, pain, failed, setback, roadblock',
    '  fixed     := fixed, resolved, healed, recovered, "sorted out", "figured out", solved, "got over"',
    '  completed := completed, finished, "done with", "wrapped up"',
    '  launched  := launched, released, shipped, "went live", "pushed out"',
    '  changed_plan := changed, switched, pivoted, "changed my mind", "rethinking"',
    '',
    '===== LIFE-MEMORY RULE (CRITICAL) =====',
    'Death, grief, loss, diagnosis, medical conditions, trauma, abuse, breakup, divorce, family crisis, major injury, surgery, hospital stay â†’ TREAT AS DIRECT DURABLE.',
    '  - Create a candidate for the affected concept (the person, the condition, the event) with strength="strong", importanceHint="life_significant".',
    '  - Set eventHint.worthy=true.',
    '  - Set eventHint.eventType="life_event" for death/grief/loss/trauma, or "health_update" for diagnosis/medication/surgery/injury.',
    '  - clusterHint should be "relationships" for family loss, "health" for medical, otherwise "personal".',
    '  - Examples mapping to life_event: "my grandmother passed away", "I lost my grandfather", "my mother is no longer with us", "we lost our dog", "my parents divorced", "I went through a breakup".',
    '  - Examples mapping to health_update: "I was diagnosed with OCD", "I take medicine for anxiety", "I had surgery last week".',
    '',
    '===== ANCHOR RULE (CRITICAL) =====',
    'The main concept should be the most durable user-life concept in the slice. When there is a clear noun anchor, prefer it over a scoped detail phrase.',
    '  Clear routines / habits / daily-life patterns ARE valid durable concepts when they are understandable (examples: "morning routine", "study habit", "sleep routine", "gym habit").',
    '  Only reject labels that are truly unanchored or motivational filler (examples: "practice everyday", "be consistent", "work hard", "improve myself", "stay focused", "keep going") when there is no clearer concept.',
    '  Example input: "I started boxing and want to practice every day."',
    '    â†’ candidate label = "boxing" (NOT "practice everyday")',
    '    â†’ eventHint.action = "started", eventHint.summary = "Started boxing and wants to practice every day."',
    '    â†’ roleGuess = "skill", clusterHint = "sports", stateHint = "active"',
    '  Example input: "I\'m trying to fix my sleep routine."',
    '    â†’ candidate label = "sleep routine" (valid durable concept)',
    '',
    '===== CONNECTION / relation_hints RULES (STRICT) =====',
    'type must be one of: part_of, uses, depends_on, drives, supports, improves, related_to.',
    'ONLY emit a relation_hint when the user explicitly states a directional semantic relationship ("X uses Y", "X depends on Y", "X is part of Y", "X drives Y").',
    'DO NOT emit relation_hints just because two concepts are mentioned in the same message.',
    'DO NOT emit relation_hints just because two concepts share a cluster (boxing and football are both sports but are NOT connected).',
    'DO NOT use related_to as a junk drawer â€” use a stronger type or skip entirely.',
    'Example OK: "I use Flutter for GPMai" â†’ {"from":"GPMai","to":"Flutter","type":"uses","reason":"User said: I use Flutter for GPMai."}',
    'Example NOT OK: user mentions boxing AND football â†’ do NOT emit any relation_hint between them.',
    '',
    '===== OTHER RULES =====',
    '- roleGuess must be one of: identity, goal, project, skill, habit, interest, preference, reserve',
    '- strength must be one of: weak, medium, strong',
    '- importanceHint must be one of: ordinary, important, life_significant',
    '- stateHint should reflect current state: active, paused, inactive, completed, blocked',
    '- Extract from durable meaning, not trivial one-off chatter (ignore "hi", "ok", "thanks", meta-chatter).',
    '- STRICT SCOPE: extract new memory ONLY from <extract_from_new_slice_only>. Use <bridge_context_reference_only> only as a dictionary to resolve pronouns/references such as this app/it/the backend. Never copy bridge-only facts into candidates, node_updates.summaryHint, or event summaries.',
    '- parentHint is optional and should only be set when a real semantic container exists.',
    '- Do NOT emit more than 2 candidates for one slice unless they are clearly independent real-life concepts. Paraphrases and scoped details MUST be merged into the strongest matching main concept.',
    '- If <relevant_nodes> already contains a matching concept, PREFER reinforce_labels over a new candidate.',
    '',
    '<session>', JSON.stringify(packet?.session || {}), '</session>',
    '<checkpoint>', JSON.stringify(packet?.checkpoint || {}), '</checkpoint>',
    '<trigger>', JSON.stringify(packet?.trigger || {}), '</trigger>',
    '',
    '<planned_anchor_hints>', plannedAnchorHintsJson, '</planned_anchor_hints>',
    '<active_anchor_hints>', activeAnchorHintsJson, '</active_anchor_hints>',
    '<relevant_nodes>', relevantNodesJson, '</relevant_nodes>',
    '',
    '<existing_memory>', packet?.existingSummary || '', '</existing_memory>',
    '',
    '<scope_rule>', 'Extract ONLY from extract_from_new_slice_only. Bridge and assistant context are reference-only and must not become new memory.', '</scope_rule>',
    packet?.conversationText || '',
  ].join('\n');
}

async function memoryProdAnalyzeConversationForMemory(env, cfg, mode, nodes, packet) {
  const safePacket = packet && typeof packet === 'object' ? packet : null;
  const conversationText = trimMemoryText(safePacket?.conversationText || '', 9000);
  if (!conversationText) return { reinforce_labels: [], candidates: [], relation_hints: [], new_nodes: [], new_connections: [], packetPreview: '', triage: null, selfReport: null, backendRechecks: [] };
  const existingSummary = trimMemoryText(safePacket?.existingSummary || memoryProdBuildExistingMemorySummary(nodes, mode), 4000);
  const finalPacket = {
    ...safePacket,
    existingSummary,
    conversationText,
  };
  const userText = trimMemoryText(getLastUserMessageText(finalPacket?.sliceMessages || []), 220);

  // Triage decision: already computed in memoryProdBuildExtractionPacketAsync when called
  // from the production path. For legacy callers (bootstrap) we compute a minimal Tier B
  // decision here so the engine still runs with the stronger prompt.
  const triageDecision = finalPacket?._triageDecision || memoryProdClassifyTriageTier(cfg, {
    correctionCue: false,
    actionDensity: memoryProdCountActionDensity(userText),
    stateContradiction: null,
    lifeFastLane: memoryProdIsLifeMemoryText(userText),
    competingConceptCount: 0,
    offTopicSentences: [],
    sliceChars: memoryProdEstimateSliceChars(finalPacket?.sliceMessages || [], finalPacket?.assistantText || '')
  });

  // Run Pass 1 with Tier B-first â†’ optional Tier C confidence fallback. Tier A entries
  // start directly on the strong model.
  const pass1 = await memoryProdRunPass1WithTriage(env, cfg, mode, nodes, finalPacket, triageDecision);
  const parsed = pass1.rawParsed || {};
  const extractionError = pass1.extractionError || '';
  const selfReport = parsed?.self_report || null;

  // Normalize raw candidates into the shape the downstream pipeline expects.
  const fallbackCandidates = Array.isArray(parsed.new_nodes) ? parsed.new_nodes : [];
  const heuristicCandidates = (!Array.isArray(parsed.candidates) || !parsed.candidates.length) && !((Array.isArray(parsed.reinforce_labels) ? parsed.reinforce_labels : []).length)
    ? memoryProdBuildHeuristicCandidatesFromUserText(userText)
    : [];
  const rawCandidates = Array.isArray(parsed.candidates) && parsed.candidates.length ? parsed.candidates : (fallbackCandidates.length ? fallbackCandidates : heuristicCandidates);
  const rawPreparedCandidates = rawCandidates.map((item) => {
    const action = memoryProdNormalizeLifecycleAction(item?.eventHint?.action || item?.action || item?.stateHint || memoryProdInferLifecycleActionFromText(userText));
    const worthy = item?.eventHint?.worthy === true || !!action || !!item?.eventType;
    const roleGuess = memoryProdNormalizeMemoryGroup(item?.roleGuess || item?.group || 'interest');
    return {
      label: trimMemoryText(item?.label || item?.canonicalLabel || '', 80),
      roleGuess,
      strength: memoryProdNormalizeStrength(item?.strength || 'medium'),
      clusterHint: memoryProdSanitizeClusterHint(item?.clusterHint || item?.cluster || '', item?.label || '', roleGuess, item?.summaryHint || item?.info || ''),
      parentHint: trimMemoryText(item?.parentHint || item?.parent || '', 80),
      importanceHint: trimMemoryText(item?.importanceHint || item?.importance || inferImportanceForLabel(item?.label || '', roleGuess, item?.summaryHint || item?.info || ''), 40),
      summaryHint: trimMemoryText(item?.summaryHint || item?.info || '', 220),
      stateHint: trimMemoryText(item?.stateHint || memoryProdNodeStateFromLifecycleAction(action), 24),
      eventHint: {
        worthy,
        action,
        summary: trimMemoryText(item?.eventHint?.summary || item?.summaryHint || item?.info || '', 220),
        timeText: trimMemoryText(item?.eventHint?.timeText || item?.timeAnchor || '', 80),
        eventType: trimMemoryText(item?.eventHint?.eventType || item?.eventType || memoryProdEventTypeFromLifecycleAction(action, roleGuess), 60),
        sameOngoingIncident: item?.eventHint?.sameOngoingIncident === true,
        reuseHint: trimMemoryText(item?.eventHint?.reuseHint || '', 220)
      },
      relationHints: Array.isArray(item?.relationHints) ? item.relationHints : [],
      _sourceUserText: userText
    };
  }).filter((item) => item.label);

  const rawNodeUpdates = (Array.isArray(parsed.node_updates) ? parsed.node_updates : [])
    .map((item) => memoryProdNormalizeNodeUpdate(item, userText))
    .filter((item) => item.summaryHint || item.anchorLabel || item.anchorNodeId);

  // Existing anti-pollution normaliser (Fast Lane + alias merge + per-slice cap).
  const preparedLearned = memoryProdPrepareLearnedOutput({ candidates: rawPreparedCandidates }, userText, nodes);
  let candidates = preparedLearned.candidates;

  // Build initial learned object.
  let relation_hints = [];
  for (const rel of Array.isArray(parsed.relation_hints) ? parsed.relation_hints : []) relation_hints.push(rel);
  for (const rel of Array.isArray(parsed.new_connections) ? parsed.new_connections : []) relation_hints.push(rel);
  for (const candidate of candidates) {
    for (const rel of Array.isArray(candidate.relationHints) ? candidate.relationHints : []) {
      relation_hints.push({ from: candidate.label, to: rel?.to || rel?.label || '', type: rel?.type || 'related_to', reason: rel?.reason || '' });
    }
  }
  let reinforce_labels = boundedUniqueIds([
    ...(Array.isArray(parsed.reinforce_labels) ? parsed.reinforce_labels : []),
    ...(Array.isArray(parsed.increment_nodes) ? parsed.increment_nodes : [])
  ], 12);

  // v3.1.15 â€” backend proposal + RRF/fusion + hard arbiter.
  // This runs before the older backend recheck so detail-only labels can be rewritten
  // to their true anchor and clear-but-shallow concepts can be forced to candidate.
  // Phase B cleanup: also compute the four-layer match here so its result feeds into
  // the arbiter's existing-memory decision (not just debug traces).
  const _flUserText = userText;
  const _flCandidateLabels = boundedUniqueIds([
    ...candidates.map((c) => c?.label || '').filter(Boolean),
    ...reinforce_labels
  ], 12);
  const _flSemanticItems = Array.isArray(finalPacket?.relevantNodes) ? finalPacket.relevantNodes : [];
  const _flMatch = memoryProdFourLayerMatchExisting({
    userText: _flUserText,
    candidateLabels: _flCandidateLabels,
    hotNodes: nodes,
    hotCandidates: [],
    semanticItems: _flSemanticItems
  });
  const arbiterAdjusted = memoryProdApplyBackendArbiterToLearned({
    candidates,
    reinforce_labels,
    relation_hints,
    node_updates: rawNodeUpdates
  }, userText, nodes, _flMatch);
  candidates = arbiterAdjusted.candidates;
  reinforce_labels = arbiterAdjusted.reinforce_labels;
  relation_hints = arbiterAdjusted.relation_hints;

  // Backend recheck layer â€” independent safety net that can downgrade/collapse/drop items.
  const rechecked = memoryProdBackendRecheckPass1({
    candidates,
    reinforce_labels,
    relation_hints,
    node_updates: arbiterAdjusted.node_updates || rawNodeUpdates,
    self_report: selfReport,
    backend_rechecks: arbiterAdjusted.backend_rechecks || []
  }, userText, nodes, {
    stateContradiction: finalPacket?.triageTags?.signals?.stateContradictionKind ? { kind: finalPacket.triageTags.signals.stateContradictionKind } : null,
    tier: triageDecision?.tier,
    selfReport
  });

  const approvedNodeUpdates = memoryProdBuildApprovedNodeUpdates(rechecked, userText, nodes, finalPacket);
  const combinedBackendRechecks = [
    ...(Array.isArray(rechecked.backend_rechecks) ? rechecked.backend_rechecks : []),
    ...(Array.isArray(approvedNodeUpdates.backend_rechecks) ? approvedNodeUpdates.backend_rechecks : [])
  ];

  return {
    reinforce_labels: boundedUniqueIds([...(Array.isArray(rechecked.reinforce_labels) ? rechecked.reinforce_labels : []), ...approvedNodeUpdates.node_updates.map((u) => u.anchorLabel).filter(Boolean)], 12),
    candidates: rechecked.candidates,
    node_updates: approvedNodeUpdates.node_updates,
    relation_hints: rechecked.relation_hints,
    new_nodes: rechecked.candidates.map((item) => ({ label: item.label, group: item.roleGuess, parent: item.parentHint, suggestedLevel: 3, info: item.summaryHint, strength: item.strength })),
    new_connections: rechecked.relation_hints,
    packetPreview: trimMemoryText(finalPacket?.packetPreview || conversationText, MEMORY_EXTRACTION_PACKET_PREVIEW_CHARS),
    extractionError: trimMemoryText(extractionError || '', 220),
    triage: {
      tierPlanned: triageDecision?.tier || 'B',
      modelPlanned: triageDecision?.model || '',
      reasons: triageDecision?.reasons || [],
      tierUsed: pass1.tierUsed || 'B',
      modelUsed: pass1.modelUsed || '',
      escalationChain: pass1.escalationChain || []
    },
    selfReport,
    backendRechecks: combinedBackendRechecks
  };
}

function memoryProdGroupPromotionThreshold(group, cfg, strength = 'medium') {
  // SURGICAL PATCH P2/P3: Promotion threshold table (aligned with locked spec).
  //   life_significant / directDurable       â†’ handled before this function (immediate)
  //   project/goal/preference/habit/identity  â†’ 1 session if strong, else 2   (fast-promote)
  //   skill + strong                          â†’ 1 session (strong training signal counts)
  //   everything else (interest/general/etc.) â†’ 2 sessions
  // Notes:
  //   - identity is now part of fast-promote (see P1), so the old special-case "identity returns 2"
  //     is removed. An identity label without strong strength still falls through to 2 via the
  //     ordinary path, which is the correct conservative default.
  const g = memoryProdNormalizeMemoryGroup(group);
  const s = memoryProdNormalizeStrength(strength);
  if (memoryProdShouldFastPromoteGroup(g) && s === 'strong') return 1;
  if (g === 'skill' && s === 'strong') return 1;
  return memoryProdShouldFastPromoteGroup(g) ? num(cfg.memoryCandidatePromoteSessionsStrong, 1) : num(cfg.memoryCandidatePromoteSessionsWeak, 2);
}


function memoryProdTokenizeForMatch(value) {
  return String(value || '').toLowerCase().replace(/[^a-z0-9\s]/g, ' ').split(/\s+/).filter((x) => x && !MEMORY_STOPWORDS.has(x));
}

function memoryProdFindBestExistingNodeMatch(nodes, item) {
  const safeNodes = Array.isArray(nodes) ? nodes.filter((n) => !n.deleted) : [];
  const label = trimMemoryText(item?.label || '', 80);
  const key = normalizeMemoryKey(label);
  const itemAliasKeys = new Set(memoryProdEntityAliasKeys(label));
  if (key) itemAliasKeys.add(key);
  if (!key) return null;
  let best = null;
  let bestScore = 0;
  const desiredGroup = memoryProdNormalizeMemoryGroup(item?.group || item?.roleGuess || '');
  const desiredCluster = memoryProdSanitizeClusterHint(item?.clusterHint || '', label, desiredGroup, item?.summaryHint || item?.info || '').toLowerCase();
  const labelTokens = new Set(memoryProdTokenizeForMatch(label));
  const summaryTokens = new Set(memoryProdTokenizeForMatch(item?.summaryHint || item?.info || ''));
  for (const node of safeNodes) {
    const nodeKey = normalizeMemoryKey(node.normalizedKey || node.label);
    const aliasKeys = memoryProdNodeAliasKeys(node);
    let score = 0;
    if (aliasKeys.some((ak) => itemAliasKeys.has(ak)) || nodeKey === key) score += 112;
    else if (nodeKey && (nodeKey.includes(key) || key.includes(nodeKey))) score += 62;
    const nodeTokens = new Set(memoryProdTokenizeForMatch(node.label || ''));
    const overlap = [...labelTokens].filter((t) => nodeTokens.has(t)).length;
    if (!score && overlap >= 2) score += 48 + Math.min(20, overlap * 5);
    else if (!score && overlap === 1 && labelTokens.size <= 3 && nodeTokens.size <= 5) score += 34;
    const nodeInfoTokens = new Set(memoryProdTokenizeForMatch(node.info || ''));
    const summaryOverlap = [...summaryTokens].filter((t) => nodeInfoTokens.has(t)).length;
    if (summaryOverlap >= 2) score += 18;
    if (desiredGroup && memoryProdNormalizeMemoryGroup(node.group) === desiredGroup) score += 14;
    if (desiredCluster && String(node.clusterId || '').toLowerCase() === desiredCluster) score += 12;
    if (score > bestScore) {
      best = node;
      bestScore = score;
    }
  }
  return bestScore >= 55 ? best : null;
}

async function memoryProdCreateOrPromoteMemoryTopic(accessToken, projectId, uid, cfg, item) {
  const nowMs = num(item?.nowMs, Date.now());
  const rawLabel = trimMemoryText(item?.label, 80);
  const canonicalSourceText = trimMemoryText(item?._sourceUserText || item?.summaryHint || item?.info || item?.eventHint?.summary || '', 800);
  const canonicalInfo = memoryProdCanonicalizeLabel(rawLabel, canonicalSourceText);
  if (canonicalInfo.vetoSignal === 'abstract_ambition') {
    return { node: null, promoted: false, skipped: true, reason: 'candidate_gate_rejected:abstract_ambition', canonicalInfo };
  }
  let label = trimMemoryText(canonicalInfo.canonical || rawLabel, 80);
  let key = normalizeMemoryKey(canonicalInfo.normalizedKey || label);
  item = { ...(item || {}), label, _rawLabel: rawLabel, _canonicalized: canonicalInfo };
  const sessionId = trimMemoryText(item?.sessionId || item?.session?.id || '', 120);
  if (!label || !key) return { node: null, promoted: false, skipped: true };

  const suppressions = Array.isArray(item?.suppressions) ? item.suppressions : await listMemorySuppressions(accessToken, projectId, uid);
  const suppression = suppressions.find((s) => !s.deleted && normalizeMemoryKey(s.normalizedKey || s.label) === key && num(s.suppressedUntil, 0) > nowMs);
  if (suppression) return { node: null, promoted: false, skipped: true, reason: 'suppressed' };

  const nodes = Array.isArray(item?.existingNodes) ? item.existingNodes : await listMemoryNodes(accessToken, projectId, uid);

  // V3.3.3: cross-domain/detail redirect. If a transient detail is clearly under an
  // existing durable anchor in the same user text, reinforce the anchor and let
  // event/slice carry the detail. Persistent injuries are allowed to become health nodes.
  const anchorNodeForDetail = memoryProdIsTransientDetailLabel(label, canonicalSourceText) && !memoryProdIsPersistentInjuryText(canonicalSourceText)
    ? memoryProdFindAnchorNodeInText(nodes, canonicalSourceText)
    : null;
  if (anchorNodeForDetail && normalizeMemoryKey(anchorNodeForDetail.label || '') !== key) {
    item._crossDomainRedirect = { fromLabel: label, toLabel: anchorNodeForDetail.label, reason: 'existing_anchor_transient_detail' };
    item.summaryHint = trimMemoryText(item.summaryHint || canonicalSourceText || rawLabel, 220);
    item.eventHint = {
      ...(item.eventHint || {}),
      worthy: true,
      action: trimMemoryText(item?.eventHint?.action || memoryProdInferLifecycleActionFromText(canonicalSourceText) || (/injur|hurt|pain/i.test(canonicalSourceText) ? 'injured' : /fix|fixed/i.test(canonicalSourceText) ? 'fixed' : /learn|learned/i.test(canonicalSourceText) ? 'learned' : 'updated'), 40),
      summary: trimMemoryText(item?.eventHint?.summary || canonicalSourceText || item.summaryHint || '', 220),
      eventType: trimMemoryText(item?.eventHint?.eventType || (/injur|hurt|pain/i.test(canonicalSourceText) ? 'health_update' : /bug|error|issue|fix/i.test(canonicalSourceText) ? 'problem_update' : /learn|learned/i.test(canonicalSourceText) ? 'learning_update' : 'conversation_memory_update'), 60)
    };
    label = trimMemoryText(anchorNodeForDetail.label || label, 80);
    key = normalizeMemoryKey(anchorNodeForDetail.normalizedKey || anchorNodeForDetail.label || label);
    item.label = label;
    item._canonicalized = { ...(item._canonicalized || {}), canonical: label, normalizedKey: key, crossDomainRedirect: true };
  }

  // ARCH Â§6, Â§12 â€” When the caller passes a bounded hot shortlist (Phase B), it may not
  // contain a node that exists in the full memoryNodes collection. Before we treat this
  // label as new, do a single targeted exact-key probe (one fsGetDoc on the deterministic
  // node id). This keeps the hot path bounded but never silently creates a duplicate.
  // Phase B cleanup: if the arbiter's four-layer match flagged an existing node id for
  // this candidate, prefer that (cheap in-memory check; the probe is the fallback).
  const nodeSnap = memoryProdSnapToExistingByCanonical(nodes, [], item._canonicalized || canonicalInfo, item?._fourLayerExistingMatch || null);
  let existing = nodeSnap?.kind === 'node_match' ? nodeSnap.node : null;
  if (!existing) existing = memoryProdFindBestExistingNodeMatch(nodes, item) || findMemoryNodeByLabel(nodes, MEMORY_SCOPE, label);
  if (!existing && item?._fourLayerExistingMatch?.id) {
    // The arbiter saw an exact / exact_alias / exact_candidate hit on this label. Try the
    // hot working set first by id; only if missing fall through to fsGetDoc.
    const flMatch = item._fourLayerExistingMatch;
    existing = nodes.find((n) => !n?.deleted && n?.id === flMatch.id) || null;
    if (!existing) {
      const probedById = await fsGetDoc(accessToken, projectId, `users/${uid}/memoryNodes/${flMatch.id}`).catch((err) => {
        console.log(`[four_layer_match_probe_error] uid=${uid} nodeId=${flMatch.id}: ${String(err?.message || err)}`);
        return null;
      });
      if (probedById) {
        const fields = parseFirestoreFields(probedById.fields || {});
        if (!fields.deleted) existing = { ...fields, id: fields.id || flMatch.id };
      }
    }
  }
  if (!existing && Array.isArray(item?.existingNodes)) {
    const probed = await memoryProdProbeNodeByLabel(accessToken, projectId, uid, label);
    if (probed) existing = probed;
  }
  if (existing && !existing.deleted) {
    const sameSession = !!sessionId && trimMemoryText(existing.lastSessionId || '', 120) === sessionId;
    const patch = {
      mentionCount: Math.max(1, num(existing.mentionCount, num(existing.count, 1)) + 1),
      count: sameSession ? Math.max(1, num(existing.count, 1)) : Math.max(1, num(existing.count, 1) + 1),
      sessionCount: sameSession ? Math.max(1, num(existing.sessionCount, 1)) : Math.max(1, num(existing.sessionCount, 1) + 1),
      lastSessionId: sessionId || trimMemoryText(existing.lastSessionId || '', 120),
      lastMentioned: nowMs,
      updatedAt: nowMs,
      deleted: false,
      heat: Math.min(100, num(existing.heat, 0) + (sameSession ? 3 : 6)),
      currentState: trimMemoryText(item?.stateHint || existing.currentState || '', 24),
      aliases: boundedUniqueIds([...(Array.isArray(existing.aliases) ? existing.aliases : []), label], 12),
      info: memoryProdMergeStableNodeInfo(existing.info || '', item?.summaryHint || item?.info || '', existing.label || label, 520),
      schemaVersion: MEMORY_SCHEMA_VERSION
    };
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${existing.id}`, patch);
    const node = { ...existing, ...patch };
    return { node, promoted: false, skipped: false, candidate: false, existing: true, sameSession };
  }

  const group = memoryProdNormalizeMemoryGroup(item?.group || item?.roleGuess);
  const strength = memoryProdNormalizeStrength(item?.strength);
  const clusterHint = memoryProdSanitizeClusterHint(item?.clusterHint || '', label, group, item?.summaryHint || item?.info || '');
  const directDurable = item?.directDurable === true;
  const candidates = Array.isArray(item?.existingCandidates) ? item.existingCandidates : await listMemoryCandidates(accessToken, projectId, uid);
  const candidateId = buildMemoryCandidateId(MEMORY_SCOPE, label);
  const candidateSnap = memoryProdSnapToExistingByCanonical([], candidates, item._canonicalized || canonicalInfo, item?._fourLayerExistingMatch || null);
  let existingCandidate = candidateSnap?.kind === 'candidate_match' ? candidateSnap.candidate : null;
  if (!existingCandidate) existingCandidate = candidates.find((c) => c.id === candidateId || normalizeMemoryKey(c.normalizedKey || c.label) === key);
  // ARCH Â§3.1, Â§6 â€” Same targeted-probe fallback as for nodes: if the caller passed a
  // bounded candidate shortlist and it lacks this label, do a single deterministic-id read
  // before treating this as a brand-new candidate. Required so reinforcement of an existing
  // (cold) candidate appends to its evidence array instead of starting a parallel one.
  if (!existingCandidate && Array.isArray(item?.existingCandidates)) {
    const probed = await memoryProdProbeCandidateByLabel(accessToken, projectId, uid, label);
    if (probed) existingCandidate = probed;
  }
  const sameCandidateSession = !!sessionId && trimMemoryText(existingCandidate?.lastSessionId || '', 120) === sessionId;
  const nextSessionCount = existingCandidate ? Math.max(1, num(existingCandidate.sessionCount, 1) + (sameCandidateSession ? 0 : 1)) : 1;
  const nextMentionCount = Math.max(1, num(existingCandidate?.mentionCount, 0) + 1);
  const expiresAt = nowMs + (memoryProdCandidateExpiryDays(strength, nextSessionCount) * 24 * 60 * 60 * 1000);
  const gateText = trimMemoryText(item?._sourceUserText || item?.summaryHint || item?.info || '', 600);
  const nodeGate = memoryProdNodeGate(item, gateText);
  const forceCandidate = item?._forceCandidate === true || item?._clearButShallow === true || item?._arbiterDecision === 'candidate' || (nodeGate?.allow === false && nodeGate?.suggestedDowngrade === 'candidate' && item?.directDurable !== true && String(item?.importanceHint || '').toLowerCase() !== 'life_significant');
  const forceReject = item?._arbiterDecision === 'reject' || (nodeGate?.allow === false && nodeGate?.suggestedDowngrade === 'reject');
  if (forceReject) {
    return { node: null, promoted: false, skipped: true, reason: nodeGate?.reason || item?._arbiterReason || 'node_gate_rejected' };
  }
  // ARCH Â§8 â€” Candidate gate. Runs AFTER suppression / existing-durable-node checks and
  // BEFORE any new candidate or node doc is written. We do not gate the reinforce path
  // for an already-existing candidate (existingCandidate present): if the user repeats a
  // label that's already in the candidate set, reinforcement is safe. We DO gate brand-new
  // candidate writes and brand-new durable-node writes for trivial/filler/pronoun-only/
  // blocked labels â€” which is what PDF Â§8 ("Not trivial / Not filler") requires.
  // Life-significant items and explicit-allowed sources (bootstrap, profile, fast lane)
  // bypass the gate, mirroring the same exception list the node gate already honours.
  if (!existingCandidate
      && item?.directDurable !== true
      && String(item?.importanceHint || '').toLowerCase() !== 'life_significant'
      && item?.sourceType !== 'profile') {
    const _candGate = memoryProdCandidateGate(item, gateText);
    if (!_candGate.allow) {
      return { node: null, promoted: false, skipped: true, reason: trimMemoryText(`candidate_gate_rejected:${_candGate.reason || 'unknown'}`, 160) };
    }
  }
  const directDurablePreference = !forceCandidate && memoryProdShouldPreferDurable(item);
  const immediate = !forceCandidate && (item?.sourceType === 'profile' || item?.sourceType === 'bootstrap' || item?.directDurable === true || String(item?.importanceHint || '').toLowerCase() === 'life_significant' || directDurablePreference);
  const threshold = memoryProdGroupPromotionThreshold(group, cfg, strength);
  const shouldPromote = !forceCandidate && (immediate || nextSessionCount >= threshold || (memoryProdShouldFastPromoteGroup(group) && strength === 'strong' && directDurablePreference));

  if (!shouldPromote) {
    // ARCH Â§3.1 â€” Build/append the candidate-evidence array. Determine evidence type from
    // the lifecycle action (start/resume/stop/pause), the arbiter decision, or default to
    // 'reinforce' for repeat mentions of an already-existing candidate.
    const lifecycleAction = trimMemoryText(item?.eventHint?.action || item?.stateHint || '', 40);
    let evidenceType = memoryProdLifecycleActionToEvidenceType(lifecycleAction);
    if (!evidenceType) {
      if (item?._clearButShallow === true || item?._arbiterDecision === 'candidate') evidenceType = 'clear_but_shallow';
      else if (existingCandidate) evidenceType = 'reinforce';
      else if (item?._hasMeaningfulDetail === true) evidenceType = 'meaningful_detail';
      else evidenceType = 'uncertain';
    }
    const newEvidence = memoryProdBuildCandidateEvidenceEntry({
      type: evidenceType,
      summary: trimMemoryText(item?._sourceUserText || item?.summaryHint || item?.info || '', 220),
      sourceMsgId: trimMemoryText(item?._sourceMsgId || item?.sourceMsgId || '', 160),
      role: 'user',
      confidence: typeof item?.confidence === 'number' ? item.confidence : 0.7,
      nowMs
    });
    const evidence = memoryProdAppendCandidateEvidence(Array.isArray(existingCandidate?.evidence) ? existingCandidate.evidence : [], newEvidence);
    const candidateDoc = {
      id: candidateId,
      label,
      normalizedKey: key,
      modeScope: MEMORY_SCOPE,
      roleGuess: group,
      clusterHint,
      parentGuess: trimMemoryText(item?.parentHint || item?.parentLabel || '', 80),
      importanceHint: trimMemoryText(item?.importanceHint || inferImportanceForLabel(label, group, item?.summaryHint || item?.info || ''), 40),
      currentStateGuess: trimMemoryText(item?.stateHint || '', 24),
      info: trimMemoryText(item?.summaryHint || item?.info || '', 220),
      sessionCount: nextSessionCount,
      mentionCount: nextMentionCount,
      lastSessionId: sessionId,
      strength,
      status: 'candidate',
      firstSeenAt: num(existingCandidate?.firstSeenAt, nowMs),
      lastSeenAt: nowMs,
      expiresAt,
      deleted: false,
      arbiterDecision: trimMemoryText(item?._arbiterDecision || (forceCandidate ? 'candidate' : ''), 40),
      arbiterReason: trimMemoryText(item?._arbiterReason || nodeGate?.reason || '', 160),
      detailLabel: trimMemoryText(item?._detailLabel || '', 80),
      // ARCH Â§3.1 â€” bounded evidence array for shallow lifecycle and reinforcement audit.
      evidence,
      firstEvidenceAt: num(existingCandidate?.firstEvidenceAt, nowMs),
      lastEvidenceAt: nowMs,
      schemaVersion: MEMORY_SCHEMA_VERSION
    };
    await fsUpsertDoc(accessToken, projectId, `users/${uid}/memoryCandidates/${candidateId}`, candidateDoc);
    return { node: null, promoted: false, skipped: false, candidate: true, candidateId, candidateDoc, reinforced: !!existingCandidate };
  }

  const parentNode = await memoryProdChooseParentForCandidate(accessToken, projectId, uid, item, nodes);
  const relation = normalizeMemoryConnectionType(item?.type || (parentNode?.id && parentNode.id !== 'root' ? 'part_of' : inferConnectionTypeForGroup(group)));
  const level = parentNode?.id && parentNode.id !== 'root' ? Math.max(2, Math.min(4, num(parentNode.level, 1) + 1)) : Math.max(1, Math.min(4, clampInt(item?.suggestedLevel, memoryProdShouldFastPromoteGroup(group) ? 2 : 3, 1, 4)));
  const nodeId = buildMemoryNodeId(MEMORY_SCOPE, label);
  const nodeDoc = {
    id: nodeId,
    label,
    normalizedKey: key,
    aliases: boundedUniqueIds([label, ...(Array.isArray(item?.aliases) ? item.aliases : [])], 12),
    group,
    level,
    parentId: parentNode?.id || 'root',
    count: nextSessionCount,
    mentionCount: nextMentionCount,
    sessionCount: nextSessionCount,
    lastSessionId: sessionId,
    heat: 50,
    confidence: strength === 'strong' ? 0.9 : nextSessionCount >= 2 ? 0.82 : 0.74,
    info: memoryProdInitialNodeInfo(label, group, item?.summaryHint || item?.info || ''),
    learned: item?.sourceType !== 'profile',
    isRoot: false,
    identityDefining: group === 'identity',
    currentState: trimMemoryText(item?.stateHint || '', 24),
    modeScope: MEMORY_SCOPE,
    sourceType: item?.sourceType || 'learned',
    deleted: false,
    dateAdded: nowMs,
    lastMentioned: nowMs,
    suppressedUntil: 0,
    linkedEventIds: [],
    eventCount: 0,
    lastEventAt: 0,
    clusterId: clusterHint,
    importanceClass: trimMemoryText(item?.importanceHint || inferImportanceForLabel(label, group, item?.summaryHint || item?.info || ''), 40),
    schemaVersion: MEMORY_SCHEMA_VERSION,
    updatedAt: nowMs
  };
  await fsUpsertDoc(accessToken, projectId, `users/${uid}/memoryNodes/${nodeId}`, nodeDoc);
  if (parentNode?.id && parentNode.id !== 'root') {
    await memoryProdEnsureMemoryConnection(accessToken, projectId, uid, parentNode.id, nodeId, relation, trimMemoryText(item?.info || item?.reason || 'Placed under semantic parent.', 180), nowMs, Array.isArray(item?.existingConnections) ? item.existingConnections : null);
  }
  if (existingCandidate) {
    // ARCH Â§3.1 â€” Preserve candidate evidence trail at promotion. Audit fields
    // `promotedFromCandidateId` and `priorCandidateEvidence` keep the lifecycle history
    // visible on the node even after the candidate is marked deleted.
    const priorEvidence = Array.isArray(existingCandidate?.evidence) ? existingCandidate.evidence.slice(0, MEMORY_CANDIDATE_EVIDENCE_CAP) : [];
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${nodeId}`, {
      promotedFromCandidateId: trimMemoryText(existingCandidate.id || '', 160),
      priorCandidateEvidence: priorEvidence,
      promotedAt: nowMs
    }).catch((err) => {
      console.log(`[candidate_promotion_evidence_patch_error] uid=${uid} node=${nodeId}: ${String(err?.message || err)}`);
    });
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryCandidates/${existingCandidate.id}`, {
      status: 'promoted',
      promotedToNodeId: nodeId,
      lastSeenAt: nowMs,
      cleanupAfterAt: nowMs + MEMORY_CANDIDATE_PROMOTED_CLEANUP_MS,
      deleted: true,
      deletedAt: nowMs,
      schemaVersion: MEMORY_SCHEMA_VERSION
    });
  }
  return { node: nodeDoc, promoted: true, skipped: false, candidate: false, candidateId };
}

async function memoryProdIncrementMemoryNodesByLabels(accessToken, projectId, uid, mode, labels, nowMs = Date.now(), sessionId = '') {
  const nodes = await listMemoryNodes(accessToken, projectId, uid);
  const seenIds = new Set();
  const updates = [];
  for (const raw of labels || []) {
    const node = findMemoryNodeByLabel(nodes, mode, trimMemoryText(raw, 80));
    if (!node || seenIds.has(node.id)) continue;
    seenIds.add(node.id);
    const sameSession = !!sessionId && trimMemoryText(node.lastSessionId || '', 120) === sessionId;
    const nextCount = sameSession ? Math.max(1, num(node.count, 1)) : Math.max(1, num(node.count, 1) + 1);
    updates.push(fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${node.id}`, {
      count: nextCount,
      mentionCount: Math.max(1, num(node.mentionCount, num(node.count, 1)) + 1),
      sessionCount: sameSession ? Math.max(1, num(node.sessionCount, 1)) : Math.max(1, num(node.sessionCount, 1) + 1),
      lastSessionId: sessionId || trimMemoryText(node.lastSessionId || '', 120),
      heat: Math.min(100, num(node.heat, 0) + (sameSession ? 3 : 5)),
      lastMentioned: nowMs,
      deleted: false,
      modeScope: MEMORY_SCOPE,
      schemaVersion: MEMORY_SCHEMA_VERSION
    }));
  }
  await Promise.all(updates);
}


async function memoryProdGenerateDurableNodeSummary(env, cfg, node, packet, candidate, latestEvent = null) {
  if (cfg?.memorySummaryEnabled === false) return '';
  // SURGICAL PATCH E6: Richer summary draft with latest event context so the summary
  // reflects timeline truth (current state + most recent event + evidence snippet).
  const safeEventHint = candidate?.eventHint || null;
  const latestEventSummary = latestEvent ? {
    summary: trimMemoryText(latestEvent.summary || '', 180),
    lifecycleAction: trimMemoryText(latestEvent.lifecycleAction || '', 40),
    eventType: trimMemoryText(latestEvent.eventType || '', 60),
    importanceClass: trimMemoryText(latestEvent.importanceClass || '', 40),
    occurredAt: trimMemoryText(latestEvent.absoluteDate || safeIsoDateFromMs(latestEvent.updatedAt || latestEvent.createdAt || Date.now()), 20),
    evidenceSnippet: Array.isArray(latestEvent.evidence) && latestEvent.evidence.length ? trimMemoryText(String(latestEvent.evidence[0]?.snippet || ''), 140) : ''
  } : null;
  const draft = {
    label: trimMemoryText(node?.label || '', 80),
    group: trimMemoryText(node?.group || candidate?.roleGuess || '', 40),
    clusterId: trimMemoryText(node?.clusterId || candidate?.clusterHint || '', 40),
    currentState: trimMemoryText(node?.currentState || candidate?.stateHint || '', 24),
    importanceClass: trimMemoryText(node?.importanceClass || candidate?.importanceHint || '', 40),
    parentHint: trimMemoryText(candidate?.parentHint || '', 80),
    previousSummary: trimMemoryText(node?.info || '', 260),
    eventHint: safeEventHint,
    latestEvent: latestEventSummary,
    packetPreview: trimMemoryText(packet?.packetPreview || packet?.conversationText || '', 700)
  };
  if (!draft.label) return '';
  const prompt = [
    'Write a medium-detail self-understandable memory summary for a durable GPMai node.',
    'Return plain text only. No markdown. No bullet points. No quotes around the whole output.',
    'Length: 2 to 3 sentences (roughly 200-260 characters). Must be complete and understandable later without the original chat.',
    'Rules:',
    '- Mention what the concept IS (1 short clause).',
    '- Mention CURRENT STATE if known (active, paused, stopped, completed, blocked).',
    '- If latestEvent is provided, include what happened and when (use occurredAt date if present).',
    '- For life_significant / life_event / health_update: acknowledge the significance with care but stay factual.',
    '- Do not invent facts that are not in the draft. Do not add advice or commentary.',
    '- If previousSummary exists and is still true, preserve its useful information while weaving in the latest event.',
    '',
    JSON.stringify(draft)
  ].join('\n');
  try {
    const data = await callOpenRouterChat(env, {
      model: cfg?.memorySummaryModel || 'openai/gpt-4o-mini',
      messages: [{ role: 'system', content: 'You write compact durable memory summaries for a production memory engine. Return plain text only. 2-3 sentences. No markdown.' }, { role: 'user', content: prompt }],
      temperature: 0.2,
      max_tokens: 220
    });
    return trimMemoryText(stripMarkdownFences(String(data?.choices?.[0]?.message?.content || '').trim()), 360);
  } catch (_e) {
    return trimMemoryText(candidate?.summaryHint || node?.info || '', 360);
  }
}

async function memoryProdRefreshDurableNodeSummaries(env, accessToken, projectId, uid, cfg, outcomes, packet) {
  if (cfg?.memorySummaryEnabled === false) return;
  const limit = Math.max(1, num(cfg?.memorySummaryMaxPerTurn, MEMORY_EXTRACTION_SUMMARY_MAX_PER_TURN));
  const targets = (Array.isArray(outcomes) ? outcomes : []).filter((outcome) => outcome?.node && (outcome?.promoted || trimMemoryText(outcome?.node?.info || '', 60).length < 40)).slice(0, limit);
  for (const outcome of targets) {
    const summary = await memoryProdGenerateDurableNodeSummary(env, cfg, outcome.node, packet, outcome.candidate, null);
    if (!summary) continue;
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${outcome.node.id}`, {
      info: summary,
      updatedAt: Date.now(),
      schemaVersion: MEMORY_SCHEMA_VERSION
    }).catch(() => null);
    outcome.node = { ...outcome.node, info: summary };
  }
}

// SURGICAL PATCH E6: Post-event node summary refresh.
// After an event is created/updated for a node, rewrite the node.info via LLM so the
// durable summary reflects the latest timeline truth. Bounded per turn to avoid LLM spam.
async function memoryProdRefreshNodeSummaryAfterEvent(env, accessToken, projectId, uid, cfg, node, eventDoc, packet, counterRef) {
  if (!node || !eventDoc) return;
  if (cfg?.memorySummaryEnabled === false) return;
  const cap = Math.max(1, num(cfg?.memorySummaryMaxPerTurn, MEMORY_EXTRACTION_SUMMARY_MAX_PER_TURN));
  const counter = counterRef && typeof counterRef === 'object' ? counterRef : { count: 0 };
  if (counter.count >= cap) return;
  counter.count += 1;
  const fakeCandidate = {
    roleGuess: node.group || '',
    clusterHint: node.clusterId || '',
    stateHint: node.currentState || '',
    importanceHint: node.importanceClass || eventDoc.importanceClass || '',
    parentHint: '',
    summaryHint: eventDoc.summary || '',
    eventHint: {
      worthy: true,
      action: eventDoc.lifecycleAction || '',
      summary: eventDoc.summary || '',
      eventType: eventDoc.eventType || '',
      timeText: ''
    }
  };
  const newSummary = await memoryProdGenerateDurableNodeSummary(env, cfg, node, packet || { packetPreview: eventDoc.summary || '' }, fakeCandidate, eventDoc);
  if (!newSummary) return;
  await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${node.id}`, {
    info: newSummary,
    updatedAt: Date.now(),
    schemaVersion: MEMORY_SCHEMA_VERSION
  }).catch(() => null);
}


async function getMemoryEventDocsByIds(accessToken, projectId, uid, eventIds = [], maxItems = MEMORY_SESSION_EVENT_PREVIEW_CAP) {
  const ids = boundedUniqueIds(eventIds || [], Math.max(1, maxItems));
  if (!ids.length) return [];
  const docs = await Promise.all(ids.map((id) => fsGetDoc(accessToken, projectId, `users/${uid}/memoryEvents/${id}`).catch(() => null)));
  return docs.map((doc) => ({
    ...parseFirestoreFields(doc?.fields || {}),
    id: parseFirestoreFields(doc?.fields || {}).id || docIdFromFsDoc(doc)
  })).filter((doc) => doc && doc.id && !doc.deleted);
}

function mergeNodeOutcomeIntoWorkingSet(nodes, nextNode) {
  const safe = Array.isArray(nodes) ? nodes.slice() : [];
  if (!nextNode || !nextNode.id) return safe;
  const idx = safe.findIndex((item) => item?.id === nextNode.id);
  if (idx >= 0) safe[idx] = { ...safe[idx], ...nextNode };
  else safe.push(nextNode);
  return safe;
}

async function memoryProdCreateOrUpdateConversationMemoryEvent(accessToken, projectId, uid, cfg, payload = {}) {
  const session = payload?.session;
  const node = payload?.node;
  const allNodes = Array.isArray(payload?.nodes) ? payload.nodes : [];
  const relatedNodeIds = boundedUniqueIds([node?.id, ...(Array.isArray(payload?.relatedNodeIds) ? payload.relatedNodeIds : [])], 8);
  const eventHint = payload?.eventHint || {};
  const userText = trimMemoryText(getLastUserMessageText(payload?.messages || []), 220);
  if (!session || !node || !eventHint?.worthy) return null;

  const nowMs = num(payload?.nowMs, Date.now());
  const lifecycleAction = memoryProdNormalizeLifecycleAction(eventHint?.action || memoryProdInferLifecycleActionFromText(userText));
  const eventType = trimMemoryText(eventHint?.eventType || memoryProdEventTypeFromLifecycleAction(lifecycleAction, node.group), 60);
  const importanceClass = trimMemoryText(payload?.importanceHint || node.importanceClass || 'ordinary', 40) || 'ordinary';
  const summary = memoryProdSummarizeCandidateEvent(node.label, eventHint, userText);
  const resolvedClusterId = trimMemoryText(node.clusterId || inferClusterIdForNode(node.label, node.group, node.info) || 'general', 40);
  const eventFacets = memoryProdDetectEventFacets(userText || summary, resolvedClusterId, node, eventHint);
  const eventTags = memoryProdDetectEventTags(userText || summary);

  // SURGICAL PATCH E7: Semantic evidence role assignment.
  //   primary_proof  â†’ the user stating a life event / health fact (most load-bearing evidence)
  //   status_update  â†’ a lifecycle action (started/stopped/etc.) on an existing concept
  //   time_anchor    â†’ evidence that includes a time reference ("last week", "yesterday", "in 2023")
  //   supporting_proof â†’ assistant acknowledgment / secondary mention
  const isLifeEvent = eventType === 'life_event' || eventType === 'health_update' || importanceClass === 'life_significant' || memoryProdIsLifeMemoryText(userText);
  const hasTimeAnchor = /\b(yesterday|today|tonight|this morning|this afternoon|last (week|month|year|night)|next (week|month|year)|on (monday|tuesday|wednesday|thursday|friday|saturday|sunday)|in (january|february|march|april|may|june|july|august|september|october|november|december)|in (19|20)\d{2}|(\d+) (days?|weeks?|months?|years?) ago|since (last|\d))/i.test(userText);
  let primaryRole = 'primary_proof';
  if (isLifeEvent) primaryRole = 'primary_proof';
  else if (lifecycleAction) primaryRole = 'status_update';
  else if (hasTimeAnchor) primaryRole = 'time_anchor';

  const incomingEvidence = capEventEvidence([
    buildEventEvidenceItem({
      snippet: userText,
      sourceType: 'user_message',
      messageId: trimMemoryText(payload?.lastUserMessageId || '', 80),
      timestamp: nowMs,
      confidence: isLifeEvent ? 0.96 : 0.92,
      roleInEvent: primaryRole
    }),
    buildEventEvidenceItem({
      snippet: trimMemoryText(payload?.assistantText || '', 220),
      sourceType: 'assistant_message',
      messageId: trimMemoryText(payload?.assistantMessageId || '', 80),
      timestamp: nowMs,
      confidence: 0.7,
      roleInEvent: 'supporting_proof'
    })
  ], Math.max(1, num(cfg?.memoryEventEvidenceCap, MEMORY_EVENT_EVIDENCE_CAP)));

  const candidateEventIds = boundedUniqueIds([...(Array.isArray(session?.linkedEventIds) ? session.linkedEventIds : []), session?.lastEventId || ''], MEMORY_SESSION_EVENT_PREVIEW_CAP);
  const existingEvents = await getMemoryEventDocsByIds(accessToken, projectId, uid, candidateEventIds, MEMORY_SESSION_EVENT_PREVIEW_CAP);
  const sameSessionEvents = existingEvents
    .filter((eventDoc) => !eventDoc.deleted && eventDoc.sessionId === session.id && eventDoc.primaryNodeId === node.id)
    .sort((a, b) => num(b.updatedAt || b.createdAt, 0) - num(a.updatedAt || a.createdAt, 0));
  const matchingEvent = lifecycleAction ? sameSessionEvents.find((eventDoc) => memoryProdNormalizeLifecycleAction(eventDoc.lifecycleAction || '') === lifecycleAction) : null;
  const existingEvent = matchingEvent || (!lifecycleAction ? sameSessionEvents[0] || null : null);

  if (existingEvent) {
    const mergedEvidence = mergeEvidenceForEvent(existingEvent.evidence || [], incomingEvidence, Math.max(1, num(cfg?.memoryEventEvidenceCap, MEMORY_EVENT_EVIDENCE_CAP)));
    const mergedNodeIds = boundedUniqueIds([...(Array.isArray(existingEvent.connectedNodeIds) ? existingEvent.connectedNodeIds : []), ...relatedNodeIds], 8);
    const patch = {
      summary: trimMemoryText(summary || existingEvent.summary || '', 220),
      eventType,
      lifecycleAction: lifecycleAction || trimMemoryText(existingEvent.lifecycleAction || '', 40),
      endAt: nowMs,
      updatedAt: nowMs,
      connectedNodeIds: mergedNodeIds,
      facets: boundedUniqueIds([...(Array.isArray(existingEvent.facets) ? existingEvent.facets : []), ...eventFacets], 4),
      eventTags: boundedUniqueIds([...(Array.isArray(existingEvent.eventTags) ? existingEvent.eventTags : []), ...eventTags], 12),
      confidence: Math.max(num(existingEvent.confidence, 0.72), Math.min(0.98, num(existingEvent.confidence, 0.72) + 0.04)),
      evidence: mergedEvidence,
      evidenceOverflow: mergedEvidence.length >= Math.max(1, num(cfg?.memoryEventEvidenceCap, MEMORY_EVENT_EVIDENCE_CAP)),
      sourceSessionCount: Math.max(1, num(existingEvent.sourceSessionCount, 1)),
      memoryTier: computeMemoryTierFromTimestamps(nowMs, existingEvent.importanceClass || importanceClass, nowMs),
      valence: existingEvent.valence || 'neutral',
      status: memoryProdEventStatusFromLifecycleAction(lifecycleAction) || existingEvent.status || 'recorded',
      importanceClass: existingEvent.importanceClass || importanceClass,
      schemaVersion: MEMORY_SCHEMA_VERSION
    };
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryEvents/${existingEvent.id}`, patch);
    const updatedEvent = { ...existingEvent, ...patch };
    await syncEventIndexDoc(accessToken, projectId, uid, updatedEvent);
    for (const relatedId of mergedNodeIds) {
      const relatedNode = allNodes.find((item) => item.id === relatedId);
      if (relatedNode) await updateNodeEventPreview(accessToken, projectId, uid, relatedNode, updatedEvent);
    }
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${node.id}`, {
      currentState: lifecycleAction ? memoryProdNodeStateFromLifecycleAction(lifecycleAction, trimMemoryText(node.currentState || '', 24)) : trimMemoryText(node.currentState || '', 24),
      lastEventAt: nowMs,
      info: memoryProdBuildNodeSummaryWithLatestEvent(node, updatedEvent),
      updatedAt: nowMs,
      schemaVersion: MEMORY_SCHEMA_VERSION
    });
    return updatedEvent;
  }

  if (sameSessionEvents.length >= MEMORY_EVENT_PER_SESSION_NODE_CAP) {
    // SURGICAL PATCH: Distinct-lifecycle-action bypass.
    // If the new action is a lifecycle action the node hasn't seen this session, still
    // allow the event through. Caps only protect against same-action spam, not against
    // real timeline changes (started â†’ paused â†’ stopped all deserve their own events).
    if (!lifecycleAction) return null;
    const sessionActionSet = new Set(
      sameSessionEvents
        .map((e) => memoryProdNormalizeLifecycleAction(e.lifecycleAction || ''))
        .filter(Boolean)
    );
    if (sessionActionSet.has(lifecycleAction)) return null;
    // else: fall through and create the new distinct-action event
  }

  const eventId = buildMemoryEventId(session.id, node.id, nowMs);
  const eventDoc = {
    id: eventId,
    eventId,
    summary: trimMemoryText(summary, 220),
    eventType,
    lifecycleAction,
    absoluteDate: safeIsoDateFromMs(session.startedAt || nowMs),
    startAt: nowMs,
    endAt: nowMs,
    resolvedAt: ['resolved', 'completed', 'launched', 'stopped', 'fixed'].includes(lifecycleAction) ? nowMs : 0,
    valence: 'neutral',
    intensity: relatedNodeIds.length >= 3 ? 'high' : relatedNodeIds.length >= 1 ? 'medium' : 'low',
    status: memoryProdEventStatusFromLifecycleAction(lifecycleAction),
    importanceClass,
    decayRate: importanceClass === 'important' ? 'slow' : 'normal',
    recurrenceType: 'one_time',
    connectedNodeIds: relatedNodeIds,
    primaryNodeId: node.id,
    resolvedClusterId,
    facets: eventFacets,
    eventTags,
    clusterConfidence: 0.72,
    sessionId: session.id,
    threadId: trimMemoryText(session.threadId || '', 120),
    sourceSessionCount: 1,
    confidence: Math.max(0.62, Math.min(0.96, 0.72 + (Math.min(relatedNodeIds.length, 4) * 0.05))),
    evidence: incomingEvidence,
    evidenceOverflow: false,
    mergedFromEventIds: [],
    pendingReview: false,
    reviewExpiresAt: nowMs + (Math.max(7, num(cfg?.memoryReviewExpiryDays, MEMORY_REVIEW_EXPIRY_DAYS)) * 24 * 60 * 60 * 1000),
    memoryTier: computeMemoryTierFromTimestamps(nowMs, importanceClass, nowMs),
    modeScope: MEMORY_SCOPE,
    sourceTag: trimMemoryText(payload?.sourceTag || session.sourceTag || 'chat', 40),
    schemaVersion: MEMORY_SCHEMA_VERSION,
    deleted: false,
    createdAt: nowMs,
    updatedAt: nowMs
  };
  await fsUpsertDoc(accessToken, projectId, `users/${uid}/memoryEvents/${eventId}`, eventDoc);
  await syncEventIndexDoc(accessToken, projectId, uid, eventDoc);
  for (const relatedId of relatedNodeIds) {
    const relatedNode = allNodes.find((item) => item.id === relatedId);
    if (relatedNode) await updateNodeEventPreview(accessToken, projectId, uid, relatedNode, eventDoc);
  }
  await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${node.id}`, {
    currentState: lifecycleAction ? memoryProdNodeStateFromLifecycleAction(lifecycleAction, trimMemoryText(node.currentState || '', 24)) : trimMemoryText(node.currentState || '', 24),
    lastEventAt: nowMs,
    info: memoryProdBuildNodeSummaryWithLatestEvent(node, eventDoc),
    updatedAt: nowMs,
    schemaVersion: MEMORY_SCHEMA_VERSION
  });
  return eventDoc;
}

async function memoryProdUpsertMemoryConnectionsFromLearned(accessToken, projectId, uid, mode, learnedConnections, nowMs = Date.now(), existingNodes = null, existingConnections = null, existingCandidates = null, userTextForGate = '') {
  const nodes = Array.isArray(existingNodes) ? existingNodes : await listMemoryNodes(accessToken, projectId, uid);
  const safe = Array.isArray(learnedConnections) ? learnedConnections : [];
  // SURGICAL PATCH C2: Candidate-aware skip reason.
  // When an endpoint doesn't resolve to a durable node, we now also check if it exists as
  // a candidate so we can surface "candidate_not_yet_durable" instead of bare "unresolved".
  // This gives admin the truth: edge is waiting for the endpoint to mature, not lost forever.
  const candidates = Array.isArray(existingCandidates) ? existingCandidates : await listMemoryCandidates(accessToken, projectId, uid).catch(() => []);
  const resolveCandidate = (label) => {
    const key = normalizeMemoryKey(label || '');
    if (!key) return null;
    return (candidates || []).find((c) => !c.deleted && String(c.status || '').toLowerCase() !== 'promoted' && (normalizeMemoryKey(c.normalizedKey || c.label || '') === key)) || null;
  };
  const allConnections = Array.isArray(existingConnections) ? existingConnections : await listMemoryConnections(accessToken, projectId, uid).catch(() => []);
  const results = { created: [], skipped: [] };
  for (const item of safe) {
    const fromLabel = trimMemoryText(item?.from || '', 80);
    const toLabel = trimMemoryText(item?.to || '', 80);
    const relationType = normalizeMemoryConnectionType(item?.type || 'related_to');
    const relationReason = trimMemoryText(item?.reason || '', 220);
    const provenance = trimMemoryText(item?.provenance || '', 40);
    if (!fromLabel || !toLabel) {
      results.skipped.push({ from: fromLabel, to: toLabel, reason: 'missing_label' });
      continue;
    }
    // Endpoint resolution first â€” gate cannot say co-mention without seeing both nodes.
    let fromNode = findMemoryNodeByLabel(nodes, mode, fromLabel);
    if (!fromNode) fromNode = memoryProdFindBestExistingNodeMatch(nodes, { label: fromLabel, roleGuess: '' });
    let toNode = findMemoryNodeByLabel(nodes, mode, toLabel);
    if (!toNode) toNode = memoryProdFindBestExistingNodeMatch(nodes, { label: toLabel, roleGuess: '' });
    // ARCH Â§6, Â§12 â€” When the caller passed a bounded hot shortlist as `existingNodes`, an
    // endpoint that exists in the full collection may be missing from the in-memory list.
    // Targeted exact-key probe (one fsGetDoc) before reporting unresolved.
    if (!fromNode && Array.isArray(existingNodes)) {
      fromNode = await memoryProdProbeNodeByLabel(accessToken, projectId, uid, fromLabel);
    }
    if (!toNode && Array.isArray(existingNodes)) {
      toNode = await memoryProdProbeNodeByLabel(accessToken, projectId, uid, toLabel);
    }
    if (!fromNode || !toNode) {
      const fromCandidate = !fromNode ? resolveCandidate(fromLabel) : null;
      const toCandidate = !toNode ? resolveCandidate(toLabel) : null;
      let reason;
      if (!fromNode && !toNode) {
        reason = (fromCandidate && toCandidate) ? 'both_candidate_not_yet_durable'
          : fromCandidate ? 'from_candidate_to_unresolved'
          : toCandidate ? 'from_unresolved_to_candidate'
          : 'both_unresolved';
      } else if (!fromNode) {
        reason = fromCandidate ? 'from_candidate_not_yet_durable' : 'from_unresolved';
      } else {
        reason = toCandidate ? 'to_candidate_not_yet_durable' : 'to_unresolved';
      }
      results.skipped.push({ from: fromLabel, to: toLabel, reason, type: relationType });
      continue;
    }
    // ARCH Â§8 â€” Edge gate. Replaces the inline weak_related_to regex check with a
    // proper gate that requires both nodes durable, valid type, explicit relation,
    // direction validation, and dedup-as-reinforce.
    const existingEdge = allConnections.find((c) => !c.deleted && canonicalConnectionKey(c.fromNodeId, c.toNodeId, c.type) === canonicalConnectionKey(fromNode.id, toNode.id, relationType)) || null;
    const gate = memoryProdEdgeGate({
      fromNode, toNode, type: relationType,
      userText: userTextForGate, reason: relationReason,
      provenance, existingEdge
    });
    if (!gate.allow) {
      results.skipped.push({ from: fromLabel, to: toLabel, reason: gate.reason || 'edge_gate_rejected', type: relationType });
      continue;
    }
    const upserted = await memoryProdEnsureMemoryConnection(
      accessToken, projectId, uid, fromNode.id, toNode.id,
      relationType,
      trimMemoryText(relationReason || 'Meaningful semantic relationship.', 180),
      nowMs, existingConnections
    );
    if (upserted) results.created.push({ from: fromNode.label, to: toNode.label, type: upserted.type || relationType, state: upserted.state || (gate.isReinforce ? 'reinforced' : 'created'), gateReason: gate.reason });
  }
  return results;
}


async function memoryProdProcessConversationMemoryTurn(env, accessToken, projectId, uid, cfg, payload) {
  if (payload?.skipBootstrap !== true) {
    await ensureMemoryBootstrap(accessToken, projectId, uid, cfg, { ensureOperationalDocs: false, ensureProfile: false, ensureRootIndex: false });
  }

  const requestedMode = normalizeMemoryMode(payload?.mode || MEMORY_SCOPE);
  const nowMs = num(payload?.nowMs, Date.now());
  // ARCH Â§1, Â§9 â€” Required-write tracking for the Â§9 failure rule:
  //   "If a required write fails, the checkpoint must not advance."
  // Required classes: candidate-or-node, slice, event. Edge writes are optional per Â§9.
  // The tracker records each required write outcome; the checkpoint guard at the end of
  // the turn refuses to advance when failedRequiredWrites is non-empty and emits
  // checkpoint_blocked instead.
  const _requiredWrites = [];
  const _failedRequiredWrites = () => _requiredWrites.filter((w) => w && w.ok === false);
  // requiredWrite(label, fn) wraps an async required write. On thrown error or null/undefined
  // return value, it records ok=false and re-thrown errors are swallowed at this layer (the
  // failed-list is the source of truth). This avoids ad-hoc `.catch(() => null)` calls that
  // hide failures from the checkpoint guard.
  const requiredWrite = async (label, fn, meta = {}) => {
    try {
      const result = await fn();
      const ok = result !== null && result !== undefined && result !== false;
      _requiredWrites.push({ label, ok, meta, error: ok ? null : 'returned_null_or_false' });
      return ok ? result : null;
    } catch (err) {
      const errText = String(err?.message || err || 'required_write_threw');
      console.log(`[required_write_failed] label=${label} ${meta && meta.nodeId ? `nodeId=${meta.nodeId}` : ''}: ${errText}`);
      _requiredWrites.push({ label, ok: false, meta, error: errText });
      return null;
    }
  };
  const session = await memoryProdCreateOrReuseMemorySession(accessToken, projectId, uid, cfg, {
    threadId: payload?.threadId,
    chatId: payload?.chatId,
    conversationId: payload?.conversationId,
    sourceTag: payload?.sourceTag,
    messages: payload?.messages,
    nowMs
  });

  // V3.1.2 learning hotfix: heartbeat immediately after session creation.
  // If this appears but lastProcessedAt stays 0, the learner reached the session
  // stage and failed later; the trace/debug logs will show the failing stage.
  await fsPatchDoc(accessToken, projectId, `users/${uid}/memorySessions/${session.id}`, {
    status: 'learning_started',
    pendingTriggerReason: trimMemoryText(payload?.triggerReason || 'learning_started', 80),
    pendingSinceAt: num(session?.pendingSinceAt, 0) || nowMs,
    lastActivityAt: nowMs,
    updatedAt: nowMs,
    schemaVersion: MEMORY_SCHEMA_VERSION
  }).catch(() => null);
  await writeMemoryLearningTrace(accessToken, projectId, uid, {
    nowMs,
    stage: 'learning_started',
    status: 'started',
    sourceTag: payload?.sourceTag,
    threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
    threadKey: payload?.threadKey || buildMemoryThreadKey(payload?.threadId || payload?.chatId || payload?.conversationId || '', payload?.sourceTag || 'chat'),
    sessionId: session.id,
    userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
    assistantMsgId: payload?.assistantMsgId || '',
    triggerReason: payload?.triggerReason || 'chat_turn_complete'
  }).catch(() => null);
  await writeMemoryLearningTrace(accessToken, projectId, uid, {
    nowMs,
    stage: 'session_loaded',
    status: 'ok',
    sourceTag: payload?.sourceTag,
    threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
    threadKey: payload?.threadKey || buildMemoryThreadKey(payload?.threadId || payload?.chatId || payload?.conversationId || '', payload?.sourceTag || 'chat'),
    sessionId: session.id,
    userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
    assistantMsgId: payload?.assistantMsgId || '',
    triggerReason: payload?.triggerReason || 'chat_turn_complete',
    rowsProcessed: num(session?.lastProcessedMessageCount, 0),
    note: `messageCount=${num(session?.messageCount, 0)} lastProcessedMsgId=${trimMemoryText(session?.lastProcessedMsgId || '', 80)} lastProcessedAt=${num(session?.lastProcessedAt, 0)}`
  }).catch(() => null);

  // ------------------------------------------------------------------------
  // BACKEND-OWNED LOG SLICE + CURSOR CHECKPOINT (v2)
  // ------------------------------------------------------------------------
  // When payload.useBackendLog is true, we derive both the unprocessed slice
  // and the bridge context from Firestore (users/{uid}/memoryThreads/{threadKey}/messages)
  // instead of trusting client-supplied messages[]. This is the permanent fix
  // for the "checkpoint_no_new_slice" silent-skip bug: the cursor is a
  // lastProcessedMsgId string, not a client array length.
  //
  // Fallback: if useBackendLog is false/absent OR the threadKey is missing
  // OR the log is empty (pre-migration), we use the legacy client-array flow.
  const threadKey = trimMemoryText(payload?.threadKey || buildMemoryThreadKey(payload?.threadId || payload?.chatId || payload?.conversationId || '', payload?.sourceTag || 'chat'), 100);
  const useBackendLog = !!payload?.useBackendLog && !!threadKey;
  let fullMessages = Array.isArray(payload?.messages) ? payload.messages : [];
  let sliceMessages = [];
  let cursorAdvanceInfo = { priorMsgId: trimMemoryText(session?.lastProcessedMsgId || '', 160), newestMsgId: '', rowsProcessed: 0, source: 'client_messages' };
  let bridgeMessagesFromLog = [];
  let backendRowsForTrace = [];

  if (useBackendLog) {
    try {
      const { messages: sliceFromLog, newestMsgId, rows } = await memoryLogGetUnprocessedSliceByCursor(
        accessToken, projectId, uid, session, threadKey, { limit: 30 }
      );
      backendRowsForTrace = Array.isArray(rows) ? rows.slice() : [];
      sliceMessages = sliceFromLog;
      cursorAdvanceInfo = {
        priorMsgId: trimMemoryText(session?.lastProcessedMsgId || '', 160),
        newestMsgId: newestMsgId || trimMemoryText(session?.lastProcessedMsgId || '', 160),
        rowsProcessed: rows.length,
        source: 'backend_log'
      };
      if (payload?.forceExtract === true) {
        // V3.1.4 diagnostic/repair behavior: forceExtract must be able to re-read
        // the latest backend-log window even when the checkpoint cursor is already
        // at the newest message. This is used only by explicit debug/manual calls.
        const forcedRows = await memoryLogListRecentMessages(accessToken, projectId, uid, threadKey, Math.max(2, Math.min(30, num(payload?.forceLimit, 30))));
        if (forcedRows.length) {
          sliceMessages = memoryLogToStandardMessages(forcedRows);
          cursorAdvanceInfo = {
            priorMsgId: trimMemoryText(session?.lastProcessedMsgId || '', 160),
            newestMsgId: String(forcedRows[forcedRows.length - 1]?.id || newestMsgId || ''),
            rowsProcessed: forcedRows.length,
            source: 'backend_log_force_latest'
          };
          rows.splice(0, rows.length, ...forcedRows);
          backendRowsForTrace = forcedRows.slice();
        }
      }
      const bridgeFromLog = await memoryLogBuildBridgeByCursor(accessToken, projectId, uid, threadKey, rows, MEMORY_EXTRACTION_BRIDGE_MESSAGE_COUNT);
      bridgeMessagesFromLog = bridgeFromLog;
      // Reconstruct a full-ordered `fullMessages` from (bridge + slice) so
      // downstream packet builders that expect a flat chronological array
      // continue to work without changes.
      fullMessages = [...bridgeFromLog, ...sliceMessages];
    } catch (e) {
      // Honest degradation: on log failure, we fall back to client array so
      // chat learning is not fully blocked. Record the fallback reason.
      cursorAdvanceInfo.source = `log_failure_fallback:${String(e?.message || e).slice(0, 80)}`;
      backendRowsForTrace = [];
      fullMessages = Array.isArray(payload?.messages) ? payload.messages : [];
      sliceMessages = memoryProdGetUnprocessedMessageSlice(session, fullMessages);
    }
  } else {
    sliceMessages = memoryProdGetUnprocessedMessageSlice(session, fullMessages);
  }

  await writeMemoryLearningTrace(accessToken, projectId, uid, {
    nowMs,
    stage: 'backend_slice_loaded',
    status: sliceMessages.length ? 'ok' : 'empty',
    sourceTag: payload?.sourceTag,
    threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
    threadKey,
    sessionId: session.id,
    triggerReason: payload?.triggerReason || '',
    rowsProcessed: cursorAdvanceInfo.rowsProcessed,
    rowsLoaded: cursorAdvanceInfo.rowsProcessed,
    sliceMessages: sliceMessages.length,
    userRows: sliceMessages.filter((m) => String(m?.role || '').toLowerCase() === 'user').length,
    assistantRows: sliceMessages.filter((m) => String(m?.role || '').toLowerCase() === 'assistant').length,
    firstMsgId: Array.isArray(backendRowsForTrace) && backendRowsForTrace.length ? String(backendRowsForTrace[0]?.id || '') : '',
    lastMsgId: Array.isArray(backendRowsForTrace) && backendRowsForTrace.length ? String(backendRowsForTrace[backendRowsForTrace.length - 1]?.id || '') : cursorAdvanceInfo.newestMsgId,
    sliceChars: memoryProdEstimateSliceChars(sliceMessages, ''),
    note: cursorAdvanceInfo.source
  }).catch(() => null);

  if (!sliceMessages.length) {
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memorySessions/${session.id}`, {
      lastActivityAt: nowMs,
      updatedAt: nowMs,
      status: 'active',
      schemaVersion: MEMORY_SCHEMA_VERSION
    }).catch(() => null);
    // Debug log so operators can see honestly why we skipped.
    await writeMemoryDebugLog(accessToken, projectId, uid, {
      nowMs,
      sourceTag: payload?.sourceTag,
      threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
      sessionId: session?.id || '',
      lastProcessedAt: num(session?.lastProcessedAt, 0),
      checkpointNote: `checkpoint_no_new_slice (${cursorAdvanceInfo.source})`,
      messageLog: {
        threadKey,
        useBackendLog,
        cursorPriorMsgId: cursorAdvanceInfo.priorMsgId,
        cursorNewestMsgId: cursorAdvanceInfo.newestMsgId,
        rowsProcessed: cursorAdvanceInfo.rowsProcessed,
        source: cursorAdvanceInfo.source
      },
      trigger: { shouldExtract: false, reason: 'no_unprocessed_slice' },
      learned: { reinforce_labels: [], candidates: [], relation_hints: [] },
      candidateCreated: [],
      candidatePromoted: [],
      reinforcedNodes: [],
      skippedItems: [{ label: '(no-slice)', reason: 'no_unprocessed_messages' }],
      eventDocs: [],
      placedNodes: [],
      connectionResults: []
    }).catch(() => null);
    return { ok: true, skipped: true, reason: 'checkpoint_no_new_slice', sessionId: session.id, messageLog: cursorAdvanceInfo };
  }

  const extractionAssistantText = memoryProdShouldOmitAssistantTextForLogSlice(useBackendLog, sliceMessages, payload?.assistantText)
    ? ''
    : payload?.assistantText;
  const trigger = memoryProdClassifyExtractionTrigger(session, fullMessages, sliceMessages, extractionAssistantText, payload, cfg);
  await writeMemoryLearningTrace(accessToken, projectId, uid, {
    nowMs,
    stage: 'trigger_classified',
    status: trigger.shouldExtract ? 'extract' : 'defer',
    sourceTag: payload?.sourceTag,
    threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
    threadKey,
    sessionId: session.id,
    triggerReason: trigger.reason || '',
    decision: trigger.shouldExtract ? 'extract' : 'defer',
    rowsProcessed: cursorAdvanceInfo.rowsProcessed,
    rowsLoaded: cursorAdvanceInfo.rowsProcessed,
    sliceMessages: sliceMessages.length,
    sliceChars: memoryProdEstimateSliceChars(sliceMessages, extractionAssistantText)
  }).catch(() => null);

  const pendingPatch = {
    pendingSinceAt: num(session?.pendingSinceAt, 0) || nowMs,
    pendingSliceMessageCount: Array.isArray(sliceMessages) ? sliceMessages.length : 0,
    pendingSliceCharCount: memoryProdEstimateSliceChars(sliceMessages, extractionAssistantText),
    pendingTriggerReason: trimMemoryText(trigger.reason || '', 80),
    nextEligibleExtractAt: nowMs,
    lastActivityAt: nowMs,
    updatedAt: nowMs,
    status: 'active',
    schemaVersion: MEMORY_SCHEMA_VERSION
  };
  if (!trigger.shouldExtract) {
    // ARCH Â§5 â€” both 'trivial_user_only' and 'pure_utility_skip' are noise: advance the
    // cursor so the same packet is not re-classified next turn. No memory write occurs.
    const noiseSkipReasons = new Set(['trivial_user_only', 'pure_utility_skip']);
    const shouldAdvanceCursorForNoise = useBackendLog
      && noiseSkipReasons.has(trigger.reason)
      && cursorAdvanceInfo.newestMsgId
      && cursorAdvanceInfo.newestMsgId !== cursorAdvanceInfo.priorMsgId;
    const deferredPatch = shouldAdvanceCursorForNoise
      ? { ...pendingPatch, ...memoryLogBuildCursorCheckpointPatch(cursorAdvanceInfo.newestMsgId, cursorAdvanceInfo.priorMsgId, Math.max(0, num(session?.lastProcessedMessageCount, 0) + num(cursorAdvanceInfo.rowsProcessed, 0)), nowMs), pendingTriggerReason: trigger.reason }
      : pendingPatch;
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memorySessions/${session.id}`, deferredPatch).catch(() => null);
    if (shouldAdvanceCursorForNoise) cursorAdvanceInfo.cursorAdvancedForNoise = true;
    await writeMemoryDebugLog(accessToken, projectId, uid, {
      nowMs,
      sourceTag: payload?.sourceTag,
      threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
      sessionId: session?.id || '',
      lastProcessedAt: num(session?.lastProcessedAt, 0),
      checkpointNote: `deferred: ${trigger.reason}`,
      messageLog: {
        threadKey,
        useBackendLog,
        cursorPriorMsgId: cursorAdvanceInfo.priorMsgId,
        cursorNewestMsgId: cursorAdvanceInfo.newestMsgId,
        rowsProcessed: cursorAdvanceInfo.rowsProcessed,
        source: cursorAdvanceInfo.source,
        bridgeMsgsFromLog: bridgeMessagesFromLog.length,
        cursorAdvancedForNoise: !!cursorAdvanceInfo.cursorAdvancedForNoise,
        assistantTextOmittedAsDuplicate: !extractionAssistantText && !!payload?.assistantText
      },
      trigger,
      learned: { reinforce_labels: [], candidates: [], relation_hints: [] },
      candidateCreated: [],
      candidatePromoted: [],
      reinforcedNodes: [],
      skippedItems: [{ label: trimMemoryText(getLastUserMessageText(sliceMessages), 80), reason: trigger.reason }],
      eventDocs: [],
      placedNodes: [],
      connectionResults: [],
      packetPreview: trimMemoryText(summarizeMessagesForMemory((bridgeMessagesFromLog.length ? bridgeMessagesFromLog : memoryProdGetBridgeContextMessages(fullMessages, session, MEMORY_EXTRACTION_BRIDGE_MESSAGE_COUNT)).concat(sliceMessages), extractionAssistantText), MEMORY_EXTRACTION_PACKET_PREVIEW_CHARS)
    }).catch(() => null);
    return { ok: true, deferred: true, reason: trigger.reason, sessionId: session.id, trigger };
  }

  // ARCH Â§6, Â§12 â€” Hot/recent shortlist replaces the four full-collection scans here.
  // For bounded mode (nodeIndex populated), `existingNodes` is the top-N hottest nodes
  // hydrated from the index, not the full memoryNodes collection. Downstream code that
  // needs the full graph for write resolution still calls listMemoryNodes lazily; the
  // hot path no longer reads ~600 docs per turn. The fallback path (full scan) only
  // fires when nodeIndex is empty (fresh user / pre-bootstrap state).
  const _hotShortlist = await memoryProdLoadHotShortlist(accessToken, projectId, uid).catch((err) => {
    console.log(`[turn_hot_shortlist_error] uid=${uid}: ${String(err?.message || err)}`);
    return { nodes: [], candidates: [], connections: [], suppressions: [], mode: 'failed' };
  });
  const existingNodes = _hotShortlist.nodes;
  const existingConnections = _hotShortlist.connections;
  const existingCandidates = _hotShortlist.candidates;
  const existingSuppressions = _hotShortlist.suppressions;
  await memoryProdLogDebugStage(accessToken, projectId, uid, 'shortlist_built', {
    sessionId: session.id,
    jobId: payload?.jobId || '',
    threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
    userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
    decision: _hotShortlist.mode,
    reason: `nodes=${existingNodes.length} candidates=${existingCandidates.length} connections=${existingConnections.length}`,
    details: { mode: _hotShortlist.mode, nodeCount: existingNodes.length, candidateCount: existingCandidates.length, connectionCount: existingConnections.length, suppressionCount: existingSuppressions.length }
  });
  const existingView = buildUnifiedMemoryView(existingNodes, existingConnections);
  const workingConnections = Array.isArray(existingConnections) ? existingConnections.slice() : [];

  // Idempotency â€” never double-process the same packet (retry, race, or queue redelivery).
  const idempotencyKey = await memoryProdComputeIdempotencyKey(uid, session.id, sliceMessages, extractionAssistantText || '').catch(() => '');
  if (idempotencyKey && payload?.bypassIdempotency !== true) {
    const prior = await memoryProdCheckIdempotency(accessToken, projectId, uid, idempotencyKey).catch(() => null);
    if (prior) {
      return { ok: true, idempotent: true, reason: 'duplicate_packet_skipped', sessionId: session.id, priorKey: idempotencyKey };
    }
  }

  // Production packet builder â€” real semantic shortlist + buried off-topic + triage tags.
  await writeMemoryLearningTrace(accessToken, projectId, uid, {
    nowMs,
    stage: 'pass1_started',
    status: 'started',
    sourceTag: payload?.sourceTag,
    threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
    threadKey,
    sessionId: session.id,
    userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
    assistantMsgId: payload?.assistantMsgId || '',
    triggerReason: trigger.reason || '',
    rowsProcessed: cursorAdvanceInfo.rowsProcessed,
    sliceMessages: sliceMessages.length
  }).catch(() => null);
  let extractionPacket;
  let learned;
  try {
    extractionPacket = await memoryProdBuildExtractionPacketAsync(env, accessToken, projectId, uid, session, fullMessages, sliceMessages, extractionAssistantText, existingView.nodes, { ...(payload || {}), bridgeMessagesOverride: bridgeMessagesFromLog }, cfg, trigger);
    // ARCH Â§16 â€” Phase B debug stages around the proposal lanes. The packet has just been
    // built, so the backend rule lane and the four-layer match (best-effort) have run.
    // We emit explicit stages so admins can see each lane's contribution before the LLM call.
    try {
      const _packetUserText = trimMemoryText(getLastUserMessageText(sliceMessages) || '', 600);
      const _backendProposal = memoryProdBuildBackendRuleProposal(_packetUserText, existingView.nodes, []);
      await memoryProdLogDebugStage(accessToken, projectId, uid, 'backend_proposal_created', {
        sessionId: session.id,
        jobId: payload?.jobId || '',
        threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
        userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
        decision: _backendProposal?.kind || 'none',
        reason: _backendProposal?.reason || '',
        nodeLabel: _backendProposal?.primaryAnchor || '',
        details: _backendProposal ? { kind: _backendProposal.kind, primaryAnchor: _backendProposal.primaryAnchor, detailLabel: _backendProposal.detailLabel || '', action: _backendProposal.action || '' } : null
      });
      // ARCH Â§6 â€” Four-layer match: cheap pure call against the bounded shortlist already in
      // memory plus the semantic shortlist already produced by the packet builder.
      const _semanticItems = Array.isArray(extractionPacket?.relevantNodes) ? extractionPacket.relevantNodes : [];
      const _fl = memoryProdFourLayerMatchExisting({
        userText: _packetUserText,
        candidateLabels: _backendProposal?.primaryAnchor ? [_backendProposal.primaryAnchor] : [],
        hotNodes: existingNodes,
        hotCandidates: existingCandidates,
        semanticItems: _semanticItems
      });
      await memoryProdLogDebugStage(accessToken, projectId, uid, 'existing_match_checked', {
        sessionId: session.id,
        jobId: payload?.jobId || '',
        threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
        userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
        decision: _fl.bestMatch ? _fl.bestMatch.source : 'no_match',
        reason: _fl.bestMatch ? `match=${_fl.bestMatch.label}` : `exact=${_fl.exactHits.length} hot=${_fl.hotHits.length} semantic=${_fl.semanticHits.length}`,
        nodeId: _fl.bestMatch?.id || '',
        nodeLabel: _fl.bestMatch?.label || '',
        details: { exactCount: _fl.exactHits.length, hotCount: _fl.hotHits.length, semanticCount: _fl.semanticHits.length }
      });
      await memoryProdLogDebugStage(accessToken, projectId, uid, 'rrf_fusion_completed', {
        sessionId: session.id,
        jobId: payload?.jobId || '',
        threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
        userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
        decision: _fl.fused.length ? 'fused' : 'empty',
        reason: `lanes=${_fl.lanesUsed} fusedCount=${_fl.fused.length}`,
        details: { topThree: _fl.fused.slice(0, 3).map((f) => ({ key: f.key, label: f.label, score: Number(f.score.toFixed(4)) })) }
      });
    } catch (_packetDbgErr) {
      console.log(`[phase_b_packet_debug_error] sid=${session.id}: ${String(_packetDbgErr?.message || _packetDbgErr)}`);
    }
    learned = await memoryProdAnalyzeConversationForMemory(env, cfg, requestedMode, existingView.nodes, extractionPacket);
    // ARCH Â§16 â€” LLM proposal received. Counts only; the actual content is logged by Pass 1
    // upstream traces.
    await memoryProdLogDebugStage(accessToken, projectId, uid, 'llm_proposal_received', {
      sessionId: session.id,
      jobId: payload?.jobId || '',
      threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
      userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
      decision: learned?.extractionError ? 'fallback' : 'ok',
      reason: learned?.extractionError ? trimMemoryText(String(learned.extractionError), 180) : `candidates=${(learned?.candidates || []).length} relations=${(learned?.relation_hints || []).length}`,
      modelUsed: learned?.triage?.modelUsed || '',
      triageTier: learned?.triage?.tierUsed || '',
      details: { candidateCount: (learned?.candidates || []).length, relationCount: (learned?.relation_hints || []).length, reinforceCount: (learned?.reinforce_labels || []).length }
    });
    for (const check of Array.isArray(learned?.backendRechecks) ? learned.backendRechecks : []) {
      // ARCH Â§16 â€” Phase C: include four_layer_match_used and four_layer_match_resolves_anchor
      // recheck kinds so the arbiter's existing-memory feedback path is fully visible in the
      // debug log (not just the trace channel).
      if (!['arbiter_decision', 'detail_only_candidate_vetoed', 'candidate_preserved_for_existing_node_slice_event', 'four_layer_match_used', 'four_layer_match_resolves_anchor', 'generic_candidate_vetoed_by_anchor'].includes(check?.kind)) continue;
      // Phase B: emit detail_attached_to_anchor whenever the arbiter vetoed a detail-only
      // candidate in favor of an anchor (PDF Â§16). Otherwise emit the normal recheck stage.
      const _stage = check?.kind === 'detail_only_candidate_vetoed' ? 'detail_attached_to_anchor' : (check?.kind === 'arbiter_decision' ? 'arbiter_decision' : check?.kind);
      await memoryProdLogDebugStage(accessToken, projectId, uid, _stage, {
        sessionId: session.id,
        jobId: payload?.jobId || '',
        threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
        userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
        decision: check.decision || check.kind || '',
        reason: check.reason || '',
        nodeLabel: check.label || check.primaryAnchor || '',
        details: check,
        modelUsed: learned?.triage?.modelUsed || '',
        triageTier: learned?.triage?.tierUsed || ''
      });
    }
    await writeMemoryLearningTrace(accessToken, projectId, uid, {
      nowMs,
      stage: 'pass1_completed',
      status: learned?.extractionError ? 'fallback' : 'ok',
      sourceTag: payload?.sourceTag,
      threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
      threadKey,
      sessionId: session.id,
      userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
      assistantMsgId: payload?.assistantMsgId || '',
      triggerReason: trigger.reason || '',
      rowsProcessed: cursorAdvanceInfo.rowsProcessed,
      sliceMessages: sliceMessages.length,
      note: learned?.extractionError ? trimMemoryText(learned.extractionError, 180) : ''
    }).catch(() => null);
  } catch (err) {
    const errText = String(err?.message || err || 'pass1_failed');
    await writeMemoryLearningTrace(accessToken, projectId, uid, {
      nowMs,
      stage: 'pass1_failed',
      status: 'failed',
      sourceTag: payload?.sourceTag,
      threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
      threadKey,
      sessionId: session.id,
      userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
      assistantMsgId: payload?.assistantMsgId || '',
      triggerReason: trigger.reason || '',
      rowsProcessed: cursorAdvanceInfo.rowsProcessed,
      sliceMessages: sliceMessages.length,
      failedStep: 'pass1',
      error: errText
    }).catch(() => null);
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memorySessions/${session.id}`, {
      status: 'learning_failed',
      lastExtractionReason: trimMemoryText(`failed: pass1 ${errText}`, 120),
      updatedAt: nowMs,
      schemaVersion: MEMORY_SCHEMA_VERSION
    }).catch(() => null);
    throw err;
  }

  learned = memoryProdCoalesceCandidatesIntoNodeUpdates(learned, {
    userText: trimMemoryText(getLastUserMessageText(sliceMessages) || '', 1000),
    existingNodes: existingView.nodes,
    packet: extractionPacket
  });
  for (const check of Array.isArray(learned?.backendRechecks) ? learned.backendRechecks : []) {
    if (!['candidate_coalesced_into_node_update'].includes(check?.kind)) continue;
    await memoryProdLogDebugStage(accessToken, projectId, uid, 'candidate_coalesced_into_node_update', {
      sessionId: session.id,
      jobId: payload?.jobId || '',
      threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
      userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
      decision: 'coalesced',
      reason: check.reason || '',
      nodeLabel: check.primaryAnchor || '',
      details: check,
      modelUsed: learned?.triage?.modelUsed || '',
      triageTier: learned?.triage?.tierUsed || ''
    });
  }

  const candidateKeys = new Set((Array.isArray(learned?.candidates) ? learned.candidates : []).map((item) => normalizeMemoryKey(item?.label || '')).filter(Boolean));
  const filteredReinforceLabels = (Array.isArray(learned?.reinforce_labels) ? learned.reinforce_labels : []).filter((label) => !candidateKeys.has(normalizeMemoryKey(label || '')));
  learned.reinforce_labels = boundedUniqueIds(filteredReinforceLabels, 12);

  // ARCH Â§14 â€” Correction protocol. Runs BEFORE candidate writes so a tombstone or alias
  // redirect on the wrong node settles before downstream reinforcement / event writing.
  // Triage already detected `correctionCue`; here we parse explicit "X not Y" / "I meant X
  // not Y" / "It was X not Y" patterns and apply tombstone / redirect_alias / pending_review.
  // Pure detection: if no parse, this is a no-op. Never silently deletes evidence.
  const _correctionUserText = trimMemoryText(getLastUserMessageText(sliceMessages) || '', 600);
  const _correctionCueSeen = memoryProdDetectCorrectionCue(_correctionUserText);
  let _correctionResult = null;
  if (_correctionCueSeen) {
    const _parsed = memoryProdParseCorrectionTargets(_correctionUserText);
    if (_parsed) {
      _correctionResult = await memoryProdApplyCorrectionProtocol(accessToken, projectId, uid, {
        wrongLabel: _parsed.wrongLabel,
        rightLabel: _parsed.rightLabel,
        kind: _parsed.kind,
        existingNodes,
        nowMs,
        sessionId: session.id,
        jobId: payload?.jobId || '',
        userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
        threadId: payload?.threadId || payload?.chatId || payload?.conversationId || ''
      }).catch((err) => {
        console.log(`[correction_protocol_error] uid=${uid} sid=${session.id}: ${String(err?.message || err)}`);
        return { decision: 'failed', reason: 'correction_protocol_threw', error: String(err?.message || err) };
      });
      await memoryProdLogDebugStage(accessToken, projectId, uid, 'correction_applied', {
        sessionId: session.id,
        jobId: payload?.jobId || '',
        threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
        userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
        decision: _correctionResult?.decision || 'no_op',
        reason: _correctionResult?.reason || _parsed.kind,
        nodeId: _correctionResult?.wrongNodeId || '',
        nodeLabel: _parsed.wrongLabel || '',
        details: { wrongLabel: _parsed.wrongLabel, rightLabel: _parsed.rightLabel, kind: _parsed.kind, decision: _correctionResult?.decision }
      });
    }
  }

  await memoryProdIncrementMemoryNodesByLabels(accessToken, projectId, uid, requestedMode, learned.reinforce_labels || learned.increment_nodes || [], nowMs, session.id);

  const candidateCreated = [];
  const candidatePromoted = [];
  const reinforcedNodes = [];
  const skippedItems = [];
  const placedNodes = [];
  const connectionResults = [];
  const eventDocs = [];
  const candidateOutcomes = [];
  let workingNodes = Array.isArray(existingNodes) ? existingNodes.slice() : [];
  for (const item of Array.isArray(learned.candidates) ? learned.candidates : []) {
    // ARCH Â§9 â€” Required candidate-or-node write. Phase C wraps so a Firestore failure
    // here records a tracker entry and blocks the checkpoint. Note: outcomes that return
    // { skipped: true } (gate rejected, suppressed, etc.) are NOT failures â€” they are
    // intentional skips. Only thrown errors and null returns count as failures.
    const outcome = await requiredWrite(MEMORY_REQUIRED_WRITE_LABELS.CANDIDATE_OR_NODE, () =>
      memoryProdCreateOrPromoteMemoryTopic(accessToken, projectId, uid, cfg, {
        ...item,
        mode: MEMORY_SCOPE,
        group: item.roleGuess,
        sessionId: session.id,
        sourceType: 'learned',
        nowMs,
        existingNodes: workingNodes,
        existingCandidates,
        suppressions: existingSuppressions,
        existingConnections: workingConnections
      }),
      { itemLabel: trimMemoryText(item?.label || '', 80), kind: 'candidate_or_node_write' }
    );
    if (!outcome) continue;
    candidateOutcomes.push({ ...outcome, candidate: item });
    // ARCH Â§16 â€” Phase B per-outcome debug stages.
    //   candidate_decided    : emitted whenever the gate routed this label to a candidate.
    //   node_gate_passed     : emitted when the node gate allowed promotion or reinforcement.
    //   node_gate_rejected   : emitted on hard reject (blocked label / forced reject).
    //   lifecycle_detected   : emitted when the proposal carried a lifecycle action.
    try {
      const _stagePayload = {
        sessionId: session.id,
        jobId: payload?.jobId || '',
        threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
        userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
        nodeLabel: trimMemoryText(item?.label || outcome?.node?.label || outcome?.candidateDoc?.label || '', 80),
        nodeId: trimMemoryText(outcome?.node?.id || '', 160),
        candidateId: trimMemoryText(outcome?.candidateId || outcome?.candidateDoc?.id || '', 160),
        modelUsed: learned?.triage?.modelUsed || '',
        triageTier: learned?.triage?.tierUsed || ''
      };
      const _lifecycleAction = trimMemoryText(item?.eventHint?.action || item?.stateHint || '', 40);
      if (_lifecycleAction) {
        await memoryProdLogDebugStage(accessToken, projectId, uid, 'lifecycle_detected', {
          ..._stagePayload,
          decision: _lifecycleAction,
          reason: trimMemoryText(item?.eventHint?.eventType || item?._arbiterReason || '', 80)
        });
      }
      if (outcome?.candidate && outcome?.candidateDoc) {
        await memoryProdLogDebugStage(accessToken, projectId, uid, 'candidate_decided', {
          ..._stagePayload,
          decision: outcome?.reinforced ? 'reinforced' : 'created',
          reason: trimMemoryText(outcome?.candidateDoc?.arbiterReason || item?._arbiterReason || 'clear_but_shallow', 160)
        });
      } else if (outcome?.skipped && outcome?.reason && /^candidate_gate_rejected/.test(String(outcome.reason))) {
        // ARCH Â§8 â€” Candidate gate rejected this label as trivial / filler / pronoun-only /
        // blocked-vocabulary BEFORE any candidate doc was written.
        await memoryProdLogDebugStage(accessToken, projectId, uid, 'candidate_decided', {
          ..._stagePayload,
          decision: 'rejected',
          reason: trimMemoryText(outcome?.reason || 'candidate_gate_rejected', 160)
        });
      } else if (outcome?.skipped && outcome?.reason && /node_gate|blocked_label|generic_label|generic_scoped|clear_but_shallow|empty_label/.test(String(outcome.reason))) {
        await memoryProdLogDebugStage(accessToken, projectId, uid, 'node_gate_rejected', {
          ..._stagePayload,
          decision: 'rejected',
          reason: trimMemoryText(outcome?.reason || 'node_gate_rejected', 160)
        });
      } else if (outcome?.node) {
        await memoryProdLogDebugStage(accessToken, projectId, uid, 'node_gate_passed', {
          ..._stagePayload,
          decision: outcome?.promoted ? 'promoted' : 'reinforce_existing',
          reason: trimMemoryText(item?._arbiterReason || (outcome?.promoted ? 'durable_promotion' : 'reinforce_existing'), 160)
        });
      }
    } catch (_dbgErr) {
      console.log(`[phase_b_outcome_debug_error] sid=${session.id}: ${String(_dbgErr?.message || _dbgErr)}`);
    }
    if (outcome?.candidate && outcome?.candidateDoc) {
      candidateCreated.push({
        id: outcome.candidateDoc.id,
        label: outcome.candidateDoc.label,
        groupGuess: outcome.candidateDoc.groupGuess,
        sessionCount: num(outcome.candidateDoc.sessionCount, 0),
        mentionCount: num(outcome.candidateDoc.mentionCount, 0),
        expiresAt: num(outcome.candidateDoc.expiresAt, 0)
      });
    } else if (outcome?.promoted && outcome?.node) {
      candidatePromoted.push({
        id: outcome.node.id,
        label: outcome.node.label,
        group: outcome.node.group,
        currentState: outcome.node.currentState || ''
      });
      placedNodes.push({
        nodeId: outcome.node.id,
        label: outcome.node.label,
        parentId: outcome.node.parentId || 'root',
        clusterId: outcome.node.clusterId || 'general'
      });
    } else if (outcome?.node) {
      reinforcedNodes.push({
        id: outcome.node.id,
        label: outcome.node.label,
        group: outcome.node.group
      });
    } else if (outcome?.skipped) {
      skippedItems.push({
        label: trimMemoryText(item?.label || '', 80),
        reason: trimMemoryText(outcome?.reason || 'skipped', 80)
      });
    }
    if (outcome?.node) workingNodes = mergeNodeOutcomeIntoWorkingSet(workingNodes, outcome.node);
  }

  // NOTE â€” Pass 2 (narrative) is NOT run inline here. Summary refresh for promoted nodes
  // is enqueued via Cloudflare Queue after slice docs are written, so the user response is
  // not blocked by LLM summary latency and Pass 2 failure cannot corrupt structural truth.

  const connectionHints = [];
  for (const rel of Array.isArray(learned.relation_hints) ? learned.relation_hints : []) connectionHints.push(rel);
  for (const item of Array.isArray(learned.candidates) ? learned.candidates : []) {
    for (const rel of Array.isArray(item.relationHints) ? item.relationHints : []) {
      connectionHints.push({ from: item.label, to: rel?.to || rel?.label || '', type: rel?.type || 'related_to', reason: rel?.reason || '' });
    }
  }
  for (const update of Array.isArray(learned.node_updates) ? learned.node_updates : []) {
    for (const rel of Array.isArray(update.edgeHints) ? update.edgeHints : []) {
      connectionHints.push({
        from: update.anchorLabel || update.nodeLabel || '',
        to: rel?.to || rel?.label || '',
        type: rel?.type || 'related_to',
        reason: rel?.reason || update.summaryHint || '',
        provenance: 'llm_node_update'
      });
    }
  }
  // Edge upsert is intentionally deferred until after required slices/events.

  const updatedNodes = await listMemoryNodes(accessToken, projectId, uid);
  const nodeUpdateOutcomes = [];
  for (const update of Array.isArray(learned.node_updates) ? learned.node_updates : []) {
    const node = (update?.anchorNodeId ? updatedNodes.find((n) => n && !n.deleted && n.id === update.anchorNodeId) : null)
      || memoryProdFindExistingNodeByLabelLoose(updatedNodes, update?.anchorLabel || update?.label || '');
    if (!node?.id) {
      await memoryProdLogDebugStage(accessToken, projectId, uid, 'node_update_skipped', {
        sessionId: session.id,
        jobId: payload?.jobId || '',
        threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
        userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
        decision: 'skip',
        reason: 'approved_update_anchor_missing_at_write',
        nodeLabel: update?.anchorLabel || ''
      });
      continue;
    }
    nodeUpdateOutcomes.push({ node, update });
  }
  const createdEventIds = [];
  // v3.1.14 â€” emit node_written / node_reinforced debug stages from candidateOutcomes
  for (const outcome of candidateOutcomes) {
    if (!outcome?.node?.id) continue;
    await memoryProdLogDebugStage(accessToken, projectId, uid, outcome.promoted ? 'node_written' : 'node_reinforced', {
      sessionId: session.id,
      jobId: payload?.jobId || '',
      threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
      nodeId: outcome.node.id,
      nodeLabel: outcome.node.label || '',
      decision: outcome.promoted ? 'promoted' : 'reinforced',
      reason: outcome?.reason || (outcome.promoted ? 'durable_promotion' : 'reinforce_existing'),
      confidence: typeof outcome?.candidate?.confidence === 'number' ? outcome.candidate.confidence : null,
      modelUsed: learned?.triage?.modelUsed || '',
      triageTier: learned?.triage?.tierUsed || ''
    });
  }
  for (const outcome of candidateOutcomes) {
    if (!outcome?.node || !outcome?.candidate?.eventHint?.worthy) continue;
    // ARCH Â§8 â€” Event gate. Validates action present, primary durable node, user-evidence
    // msgIds, and dedupes against this turn's already-written events. The downstream writer
    // (memoryProdCreateOrUpdateConversationMemoryEvent) still does its own historical
    // ongoing-incident dedupe; the gate adds the up-front user-evidence enforcement.
    const _evGate = memoryProdEventGate({
      action: outcome.candidate.eventHint.action,
      lifecycleAction: outcome.candidate.eventHint.action,
      eventType: outcome.candidate.eventHint.eventType || '',
      primaryNodeId: outcome.node.id,
      userEvidenceMsgIds: Array.isArray(payload?.sliceMsgIds) && payload.sliceMsgIds.length
        ? payload.sliceMsgIds
        : (Array.isArray(sliceMessages) && sliceMessages.length
            ? sliceMessages.filter((m) => m && m.role === 'user').map((m, i) => trimMemoryText(m.id || m.msgId || `slice_${i}`, 160)).filter(Boolean)
            : []),
      recentEventsForNode: eventDocs.filter((e) => e?.primaryNodeId === outcome.node.id),
      nowMs
    });
    if (!_evGate.allow) {
      await memoryProdLogDebugStage(accessToken, projectId, uid, 'event_skipped', {
        sessionId: session.id,
        jobId: payload?.jobId || '',
        threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
        nodeId: outcome.node.id,
        nodeLabel: outcome.node.label || '',
        decision: 'skip',
        reason: trimMemoryText(_evGate.reason || 'event_gate_rejected', 160)
      });
      continue;
    }
    await memoryProdLogDebugStage(accessToken, projectId, uid, 'event_write_started', {
      sessionId: session.id,
      jobId: payload?.jobId || '',
      threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
      nodeId: outcome.node.id,
      nodeLabel: outcome.node.label || '',
      reason: outcome?.candidate?.eventHint?.action || 'lifecycle_or_milestone',
      decision: _evGate.decision || 'create',
      modelUsed: learned?.triage?.modelUsed || ''
    });
    const relatedNodeIds = [];
    for (const rel of Array.isArray(outcome.candidate.relationHints) ? outcome.candidate.relationHints : []) {
      const relatedNode = findMemoryNodeByLabel(updatedNodes, MEMORY_SCOPE, rel?.to || rel?.label || '');
      if (relatedNode) relatedNodeIds.push(relatedNode.id);
    }
    const eventDoc = await requiredWrite(MEMORY_REQUIRED_WRITE_LABELS.EVENT, () =>
      memoryProdCreateOrUpdateConversationMemoryEvent(accessToken, projectId, uid, cfg, {
        ...payload,
        messages: sliceMessages,
        session,
        node: updatedNodes.find((n) => n.id === outcome.node.id) || outcome.node,
        nodes: updatedNodes,
        relatedNodeIds,
        eventHint: outcome.candidate.eventHint,
        importanceHint: outcome.candidate.importanceHint,
        nowMs
      }),
      { nodeId: outcome.node.id, kind: 'primary_candidate_event' }
    );
    if (eventDoc?.id) {
      createdEventIds.push(eventDoc.id);
      eventDocs.push(eventDoc);
      await memoryProdLogDebugStage(accessToken, projectId, uid, 'event_written', {
        sessionId: session.id,
        jobId: payload?.jobId || '',
        threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
        nodeId: outcome.node.id,
        nodeLabel: outcome.node.label || '',
        eventId: eventDoc.id,
        decision: 'written',
        reason: eventDoc.lifecycleAction || eventDoc.eventType || 'event'
      });
      if (relatedNodeIds.length) {
        await memoryProdLogDebugStage(accessToken, projectId, uid, 'event_linked', {
          sessionId: session.id,
          jobId: payload?.jobId || '',
          threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
          nodeId: outcome.node.id,
          nodeLabel: outcome.node.label || '',
          eventId: eventDoc.id,
          decision: 'linked',
          reason: `connected_node_count=${relatedNodeIds.length}`,
          details: { connectedNodeIds: relatedNodeIds }
        });
      }
    }
  }

  // SURGICAL PATCH: Event-first on reinforce path.
  // If the user's last message carries a lifecycle verb (started/stopped/resumed/blocked/fixed/etc.)
  // and the model returned the topic in `reinforce_labels` (not as a new candidate),
  // force-create an event so the timeline reflects the change.
  const lastUserTextForEvents = trimMemoryText(getLastUserMessageText(sliceMessages), 600);
  const inferredLifecycleAction = memoryProdInferLifecycleActionFromText(lastUserTextForEvents);
  if (inferredLifecycleAction && Array.isArray(learned.reinforce_labels) && learned.reinforce_labels.length) {
    const alreadyEventedNodeIds = new Set(
      candidateOutcomes
        .filter((o) => o?.node?.id && o?.candidate?.eventHint?.worthy)
        .map((o) => o.node.id)
    );
    const forcedReinforceEventCap = 3; // bounded so one chatty message can't spam events
    let forcedEventsCreated = 0;
    for (const label of learned.reinforce_labels) {
      if (forcedEventsCreated >= forcedReinforceEventCap) break;
      const normKey = normalizeMemoryKey(label || '');
      if (!normKey) continue;
      const reinforcedNode = updatedNodes.find((n) => {
        if (!n || n.deleted) return false;
        const nKey = normalizeMemoryKey(n.normalizedKey || n.label || '');
        if (nKey === normKey) return true;
        const aliasKeys = Array.isArray(n.aliases) ? n.aliases.map((a) => normalizeMemoryKey(a || '')) : [];
        return aliasKeys.includes(normKey);
      });
      if (!reinforcedNode) continue;
      if (alreadyEventedNodeIds.has(reinforcedNode.id)) continue;
      const forcedEventHint = {
        worthy: true,
        action: inferredLifecycleAction,
        summary: trimMemoryText(`${capitalizeMemoryWord(inferredLifecycleAction)} ${reinforcedNode.label}`, 200),
        timeText: '',
        eventType: memoryProdEventTypeFromLifecycleAction(inferredLifecycleAction, reinforcedNode.group)
      };
      const forcedEventDoc = await requiredWrite(MEMORY_REQUIRED_WRITE_LABELS.EVENT, () =>
        memoryProdCreateOrUpdateConversationMemoryEvent(accessToken, projectId, uid, cfg, {
          ...payload,
          messages: sliceMessages,
          session,
          node: reinforcedNode,
          nodes: updatedNodes,
          relatedNodeIds: [],
          eventHint: forcedEventHint,
          importanceHint: reinforcedNode.importanceClass || 'ordinary',
          nowMs
        }),
        { nodeId: reinforcedNode.id, kind: 'forced_lifecycle_event' }
      );
      if (forcedEventDoc?.id) {
        createdEventIds.push(forcedEventDoc.id);
        eventDocs.push(forcedEventDoc);
        alreadyEventedNodeIds.add(reinforcedNode.id);
        forcedEventsCreated += 1;
      }
    }
  }

  // SURGICAL PATCH E5: Life-event forced path.
  // Life events (death, grief, diagnosis, trauma, breakup) often don't carry a lifecycle verb
  // like "started" / "stopped". Without this path, "my grandmother passed away" on an existing
  // grandmother node would miss the event entirely because inferredLifecycleAction was empty.
  // Here we detect life-memory text and force a life_event for any relevant existing node
  // (reinforce_label match OR candidate match) that hasn't already been evented this turn.
  if (memoryProdIsLifeMemoryText(lastUserTextForEvents)) {
    const alreadyEventedNodeIds = new Set(
      [
        ...candidateOutcomes.filter((o) => o?.node?.id && o?.candidate?.eventHint?.worthy).map((o) => o.node.id),
        ...eventDocs.map((e) => e?.primaryNodeId).filter(Boolean)
      ]
    );
    const lifeEventCap = 2;
    let lifeEventsCreated = 0;
    const lifeCandidateKeys = new Set(
      (Array.isArray(learned?.reinforce_labels) ? learned.reinforce_labels : [])
        .map((l) => normalizeMemoryKey(l || '')).filter(Boolean)
    );
    // Also consider candidate outcomes that ARE life-relevant but didn't carry eventHint.worthy
    for (const outcome of candidateOutcomes) {
      if (outcome?.node?.normalizedKey) lifeCandidateKeys.add(outcome.node.normalizedKey);
      else if (outcome?.node?.label) lifeCandidateKeys.add(normalizeMemoryKey(outcome.node.label));
    }
    for (const key of lifeCandidateKeys) {
      if (lifeEventsCreated >= lifeEventCap) break;
      if (!key) continue;
      const lifeNode = updatedNodes.find((n) => {
        if (!n || n.deleted) return false;
        const nKey = normalizeMemoryKey(n.normalizedKey || n.label || '');
        if (nKey === key) return true;
        const aliasKeys = Array.isArray(n.aliases) ? n.aliases.map((a) => normalizeMemoryKey(a || '')) : [];
        return aliasKeys.includes(key);
      });
      if (!lifeNode) continue;
      if (alreadyEventedNodeIds.has(lifeNode.id)) continue;
      // Decide life vs health
      const isHealth = /(diagnos|therapy|medication|medicine|surgery|hospital|injury|allerg|ocd|adhd|autis|anxiety|depress|ptsd|panic|chronic|condition|illness)/i.test(lastUserTextForEvents);
      const lifeEventType = isHealth ? 'health_update' : 'life_event';
      const lifeEventHint = {
        worthy: true,
        action: '', // life events don't use lifecycle actions
        summary: trimMemoryText(lastUserTextForEvents, 200),
        timeText: '',
        eventType: lifeEventType
      };
      const lifeEventDoc = await requiredWrite(MEMORY_REQUIRED_WRITE_LABELS.EVENT, () =>
        memoryProdCreateOrUpdateConversationMemoryEvent(accessToken, projectId, uid, cfg, {
          ...payload,
          messages: sliceMessages,
          session,
          node: lifeNode,
          nodes: updatedNodes,
          relatedNodeIds: [],
          eventHint: lifeEventHint,
          importanceHint: 'life_significant',
          nowMs
        }),
        { nodeId: lifeNode.id, kind: 'life_fast_lane_event' }
      );
      if (lifeEventDoc?.id) {
        createdEventIds.push(lifeEventDoc.id);
        eventDocs.push(lifeEventDoc);
        alreadyEventedNodeIds.add(lifeNode.id);
        lifeEventsCreated += 1;
      }
    }
  }

  // Pass 2 (narrative) enqueue happens AFTER slice docs are written, below. This replaces
  // the old inline refresh that blocked the user response on LLM summary latency.

  // Auto-edge inference is intentionally deferred until after required slices/events.

  // ----------------------------------------------------------------------
  // ARCH Â§9 â€” SAFE COMMIT ORDER (Phase C):
  //   1. candidate / node âœ… (already done above in candidate write loop)
  //   2. required slice
  //   3. required event âœ… (already done above in event write blocks)
  //   4. approved edge âœ… (already done above in edge upsert + auto-edge)
  //   5. node mirror fields (latestSliceSummary mirror happens inside writeNodeSlice)
  //   6. candidate promoted handling (happens inside createOrPromoteMemoryTopic)
  //   7. write extraction idempotency record
  //   8. mark processed messages (handled by checkpoint patch)
  //   9. ADVANCE CHECKPOINT LAST â€” only when all required writes succeeded.
  //
  // Failure rule: if any required slice/event/candidate-or-node write failed,
  // the checkpoint MUST NOT advance. We emit checkpoint_blocked instead and
  // return { ok: false, partial: true } so the next turn retries.
  // ----------------------------------------------------------------------

  // ----- (2) REQUIRED SLICE WRITES -----
  // Architecture-locked: every meaningful extraction update for a concept creates or
  // updates a slice doc (bounded readable node-facing history). Events live in the
  // separate events collection; slices are the node-level human-readable history.
  const writtenSliceIds = [];
  const pass2Jobs = [];
  // v3.3.5 â€” distinct-summary slice dedupe. The old guard allowed only one slice per
  // node per turn, which dropped same-batch updates like "started Kaka" + "core feature
  // is Graph". The new guard blocks duplicate summaries, not distinct meaningful updates.
  const _sliceGateWrittenForNodeTurn = new Set();
  // ARCH Â§8 â€” User evidence presence for the slice gate. A turn that contains zero user
  // messages cannot create user-memory slices (assistant-only claims do not write).
  const _sliceGateHasUserEvidence = Array.isArray(sliceMessages) && sliceMessages.some((m) => m && m.role === 'user' && trimMemoryText(m.content || '', 1) !== '');
  try {
    // 0) Universal Node Update slices: existing-anchor meaningful updates ("this app" â†’ Kaka).
    // These are slice-first by design: every approved meaningful update writes node history,
    // while eventWorthy updates get timeline events after the slice section.
    for (const outcome of nodeUpdateOutcomes) {
      if (!outcome?.node?.id || !outcome?.update) continue;
      const update = outcome.update;
      const lifecycleActionForGate = trimMemoryText(update?.eventHint?.action || update?.lifecycleAction || '', 40);
      const _sliceSummaryKey = `${outcome.node.id}|${normalizeMemoryKey(update.summaryHint || '')}`;
      const _sliceGate = memoryProdSliceGate({
        hasMeaningfulUpdate: true,
        hasUserEvidence: _sliceGateHasUserEvidence,
        alreadyWrittenForNodeTurn: _sliceGateWrittenForNodeTurn.has(_sliceSummaryKey),
        lifecycleAction: lifecycleActionForGate
      });
      if (!_sliceGate.allow) {
        await memoryProdLogDebugStage(accessToken, projectId, uid, 'slice_skipped', {
          sessionId: session.id,
          jobId: payload?.jobId || '',
          threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
          nodeId: outcome.node.id,
          nodeLabel: outcome.node.label || '',
          decision: 'skip',
          reason: trimMemoryText(_sliceGate.reason || 'node_update_slice_gate_rejected', 160),
          details: { updateKind: update.updateKind || '', resolvedFrom: update.resolvedFrom || '' }
        });
        continue;
      }
      await memoryProdLogDebugStage(accessToken, projectId, uid, 'slice_write_started', {
        sessionId: session.id,
        jobId: payload?.jobId || '',
        threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
        nodeId: outcome.node.id,
        nodeLabel: outcome.node.label || '',
        reason: 'approved_node_update',
        details: { updateKind: update.updateKind || '', resolvedFrom: update.resolvedFrom || '', eventWorthy: update?.eventHint?.worthy === true },
        triageTier: learned?.triage?.tierUsed || 'B',
        modelUsed: learned?.triage?.modelUsed || ''
      });
      const sliceDoc = await requiredWrite(MEMORY_REQUIRED_WRITE_LABELS.SLICE, () =>
        memoryProdWriteNodeSlice(accessToken, projectId, uid, outcome.node, {
          nowMs,
          sessionId: session.id,
          threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
          sliceMessages,
          summaryDraft: update.summaryHint || '',
          stateHint: update.stateHint || outcome.node.currentState || '',
          eventId: '',
          eventType: update?.eventHint?.eventType || '',
          lifecycleAction: update?.eventHint?.action || '',
          triageTier: learned?.triage?.tierUsed || 'B',
          triageModel: learned?.triage?.modelUsed || '',
          importanceClass: update.importanceHint || outcome.node.importanceClass || '',
          sourceJobId: payload?.jobId || '',
          sourceMsgIds: Array.isArray(payload?.sliceMsgIds) ? payload.sliceMsgIds : [],
          sourceEventIds: [],
          confidence: typeof update?.confidence === 'number' ? update.confidence : 0.78,
          triggerReason: trigger?.reason || 'node_update'
        }),
        { nodeId: outcome.node.id, kind: 'approved_node_update_slice' }
      );
      if (sliceDoc?.id) {
        writtenSliceIds.push(sliceDoc.id);
        _sliceGateWrittenForNodeTurn.add(_sliceSummaryKey);
        outcome.sliceId = sliceDoc.id;
        await memoryProdLogDebugStage(accessToken, projectId, uid, 'slice_written', {
          sessionId: session.id,
          jobId: payload?.jobId || '',
          threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
          nodeId: outcome.node.id,
          nodeLabel: outcome.node.label || '',
          sliceId: sliceDoc.id,
          decision: 'written',
          reason: 'approved_node_update',
          details: { updateKind: update.updateKind || '', resolvedFrom: update.resolvedFrom || '' },
          confidence: typeof sliceDoc?.confidence === 'number' ? sliceDoc.confidence : null
        });
        pass2Jobs.push({
          uid,
          nodeId: outcome.node.id,
          sliceId: sliceDoc.id,
          eventId: '',
          reason: 'approved_node_update_slice_written'
        });
      }
    }

    // 1) Slices for promoted/reinforced nodes driven by this turn's candidates.
    for (const outcome of candidateOutcomes) {
      if (!outcome?.node?.id) continue;
      const hasDetail = !!trimMemoryText(outcome?.candidate?.summaryHint || '', 60);
      const hasEvent = outcome?.candidate?.eventHint?.worthy === true;
      const promoted = !!outcome?.promoted;
      const lifecycleActionForGate = trimMemoryText(outcome?.candidate?.eventHint?.action || outcome?.candidate?.stateHint || '', 40);
      const _candidateSliceSummary = outcome?.candidate?.summaryHint || outcome?.candidate?.eventHint?.summary || outcome?.node?.label || '';
      const _sliceSummaryKey = `${outcome.node.id}|${normalizeMemoryKey(_candidateSliceSummary || '')}`;
      // ARCH Â§8 â€” Slice gate. Replaces the inline three-flag check with a named gate
      // that also enforces user-evidence and per-turn-per-node dedupe.
      const _sliceGate = memoryProdSliceGate({
        hasMeaningfulUpdate: hasDetail || hasEvent || promoted,
        hasUserEvidence: _sliceGateHasUserEvidence,
        alreadyWrittenForNodeTurn: _sliceGateWrittenForNodeTurn.has(_sliceSummaryKey),
        lifecycleAction: lifecycleActionForGate
      });
      if (!_sliceGate.allow) {
        await memoryProdLogDebugStage(accessToken, projectId, uid, 'slice_skipped', {
          sessionId: session.id,
          jobId: payload?.jobId || '',
          threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
          nodeId: outcome.node.id,
          nodeLabel: outcome.node.label || '',
          decision: 'skip',
          reason: trimMemoryText(_sliceGate.reason || 'slice_gate_rejected', 160)
        });
        continue;
      }
      await memoryProdLogDebugStage(accessToken, projectId, uid, 'slice_write_started', {
        sessionId: session.id,
        jobId: payload?.jobId || '',
        threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
        nodeId: outcome.node.id,
        nodeLabel: outcome.node.label || '',
        reason: hasEvent ? 'event_attached' : (hasDetail ? 'meaningful_detail' : 'fresh_promotion'),
        triageTier: learned?.triage?.tierUsed || 'B',
        modelUsed: learned?.triage?.modelUsed || ''
      });
      const matchedEvent = eventDocs.find((ed) => ed?.primaryNodeId === outcome.node.id) || null;
      // ARCH Â§9 â€” Required slice write. Phase C wraps this with requiredWrite() so a
      // failure is recorded and blocks the checkpoint (vs the legacy silent .catch path).
      const sliceDoc = await requiredWrite(MEMORY_REQUIRED_WRITE_LABELS.SLICE, () =>
        memoryProdWriteNodeSlice(accessToken, projectId, uid, outcome.node, {
          nowMs,
          sessionId: session.id,
          threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
          sliceMessages,
          summaryDraft: outcome?.candidate?.summaryHint || matchedEvent?.summary || '',
          stateHint: outcome?.candidate?.stateHint || outcome.node.currentState || '',
          eventId: matchedEvent?.id || '',
          eventType: matchedEvent?.eventType || outcome?.candidate?.eventHint?.eventType || '',
          lifecycleAction: matchedEvent?.lifecycleAction || outcome?.candidate?.eventHint?.action || '',
          triageTier: learned?.triage?.tierUsed || 'B',
          triageModel: learned?.triage?.modelUsed || '',
          importanceClass: outcome?.candidate?.importanceHint || outcome.node.importanceClass || '',
          sourceJobId: payload?.jobId || '',
          sourceMsgIds: Array.isArray(payload?.sliceMsgIds) ? payload.sliceMsgIds : [],
          sourceEventIds: matchedEvent?.id ? [matchedEvent.id] : [],
          confidence: typeof outcome?.candidate?.confidence === 'number' ? outcome.candidate.confidence : 0.78,
          triggerReason: trigger?.reason || ''
        }),
        { nodeId: outcome.node.id, kind: 'candidate_outcome_slice' }
      );
      if (sliceDoc?.id) {
        writtenSliceIds.push(sliceDoc.id);
        _sliceGateWrittenForNodeTurn.add(_sliceSummaryKey);
        await memoryProdLogDebugStage(accessToken, projectId, uid, 'slice_written', {
          sessionId: session.id,
          jobId: payload?.jobId || '',
          threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
          nodeId: outcome.node.id,
          nodeLabel: outcome.node.label || '',
          sliceId: sliceDoc.id,
          eventId: matchedEvent?.id || '',
          decision: 'written',
          reason: 'candidate_outcome',
          confidence: typeof sliceDoc?.confidence === 'number' ? sliceDoc.confidence : null
        });
        pass2Jobs.push({
          uid,
          nodeId: outcome.node.id,
          sliceId: sliceDoc.id,
          eventId: matchedEvent?.id || '',
          reason: 'structural_slice_written'
        });
      }
    }
    // 2) Slices for reinforce-only paths where an event was forced (life event, lifecycle verb).
    //    These nodes won't appear in candidateOutcomes but deserve a node-history entry.
    const alreadySlicedNodeIds = new Set(pass2Jobs.map((j) => j.nodeId));
    for (const ev of eventDocs) {
      if (!ev?.primaryNodeId) continue;
      if (alreadySlicedNodeIds.has(ev.primaryNodeId)) continue;
      const nodeRef = updatedNodes.find((n) => n.id === ev.primaryNodeId) || null;
      if (!nodeRef) continue;
      // ARCH Â§9 â€” Required slice write (forced path). Same requiredWrite wrapping.
      const sliceDoc = await requiredWrite(MEMORY_REQUIRED_WRITE_LABELS.SLICE, () =>
        memoryProdWriteNodeSlice(accessToken, projectId, uid, nodeRef, {
          nowMs,
          sessionId: session.id,
          threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
          sliceMessages,
          summaryDraft: ev.summary || '',
          stateHint: nodeRef.currentState || '',
          eventId: ev.id,
          eventType: ev.eventType || '',
          lifecycleAction: ev.lifecycleAction || '',
          triageTier: learned?.triage?.tierUsed || 'B',
          triageModel: learned?.triage?.modelUsed || '',
          importanceClass: ev.importanceClass || nodeRef.importanceClass || ''
        }),
        { nodeId: nodeRef.id, kind: 'forced_event_slice' }
      );
      if (sliceDoc?.id) {
        writtenSliceIds.push(sliceDoc.id);
        _sliceGateWrittenForNodeTurn.add(nodeRef.id);
        pass2Jobs.push({
          uid,
          nodeId: nodeRef.id,
          sliceId: sliceDoc.id,
          eventId: ev.id,
          reason: 'forced_event_slice_written'
        });
        alreadySlicedNodeIds.add(nodeRef.id);
      }
    }
  } catch (err) {
    // The slice writer's individual failures are already captured by requiredWrite.
    // This catch only fires for unexpected exceptions in the orchestration code itself.
    console.log(`[slice_write_orchestration_error] sid=${session.id}: ${String(err?.message || err)}`);
  }

  // ----- (3) REQUIRED EVENTS FOR UNIVERSAL NODE UPDATES -----
  // Slice-first: approved node_updates always write their Slice above first. If the update
  // is also a timeline/status happening, create the Event now and block checkpoint on failure.
  for (const outcome of nodeUpdateOutcomes) {
    if (!outcome?.node?.id || !outcome?.update?.eventHint?.worthy) continue;
    const update = outcome.update;
    const _evGate = memoryProdEventGate({
      action: update.eventHint.action,
      lifecycleAction: update.eventHint.action,
      eventType: update.eventHint.eventType || '',
      primaryNodeId: outcome.node.id,
      userEvidenceMsgIds: Array.isArray(payload?.sliceMsgIds) && payload.sliceMsgIds.length
        ? payload.sliceMsgIds
        : (Array.isArray(sliceMessages) && sliceMessages.length
            ? sliceMessages.filter((m) => m && m.role === 'user').map((m, i) => trimMemoryText(m.id || m.msgId || `slice_${i}`, 160)).filter(Boolean)
            : []),
      recentEventsForNode: eventDocs.filter((e) => e?.primaryNodeId === outcome.node.id),
      nowMs
    });
    if (!_evGate.allow) {
      await memoryProdLogDebugStage(accessToken, projectId, uid, 'event_skipped', {
        sessionId: session.id,
        jobId: payload?.jobId || '',
        threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
        nodeId: outcome.node.id,
        nodeLabel: outcome.node.label || '',
        decision: 'skip',
        reason: trimMemoryText(_evGate.reason || 'node_update_event_gate_rejected', 160),
        details: { updateKind: update.updateKind || '', resolvedFrom: update.resolvedFrom || '' }
      });
      continue;
    }
    await memoryProdLogDebugStage(accessToken, projectId, uid, 'event_write_started', {
      sessionId: session.id,
      jobId: payload?.jobId || '',
      threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
      nodeId: outcome.node.id,
      nodeLabel: outcome.node.label || '',
      reason: 'approved_node_update_event',
      decision: _evGate.decision || 'create',
      details: { updateKind: update.updateKind || '', resolvedFrom: update.resolvedFrom || '', sliceId: outcome.sliceId || '' },
      modelUsed: learned?.triage?.modelUsed || ''
    });
    const eventDoc = await requiredWrite(MEMORY_REQUIRED_WRITE_LABELS.EVENT, () =>
      memoryProdCreateOrUpdateConversationMemoryEvent(accessToken, projectId, uid, cfg, {
        ...payload,
        messages: sliceMessages,
        session,
        node: updatedNodes.find((n) => n.id === outcome.node.id) || outcome.node,
        nodes: updatedNodes,
        relatedNodeIds: [],
        eventHint: update.eventHint,
        importanceHint: update.importanceHint || outcome.node.importanceClass || 'ordinary',
        nowMs
      }),
      { nodeId: outcome.node.id, kind: 'approved_node_update_event' }
    );
    if (eventDoc?.id) {
      createdEventIds.push(eventDoc.id);
      eventDocs.push(eventDoc);
      outcome.eventId = eventDoc.id;
      await memoryProdLogDebugStage(accessToken, projectId, uid, 'event_written', {
        sessionId: session.id,
        jobId: payload?.jobId || '',
        threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
        nodeId: outcome.node.id,
        nodeLabel: outcome.node.label || '',
        eventId: eventDoc.id,
        decision: 'written',
        reason: eventDoc.lifecycleAction || eventDoc.eventType || 'approved_node_update_event',
        details: { sliceId: outcome.sliceId || '', updateKind: update.updateKind || '' }
      });
    }
  }

  // ----- (5) Node mirror fields are written inside memoryProdWriteNodeSlice itself.
  // ----- (6) Candidate promoted handling happens inside memoryProdCreateOrPromoteMemoryTopic.

  // ----- (7) IDEMPOTENCY STAMP â€” moved BEFORE checkpoint per PDF Â§9 step 7.
  // Stamping before checkpoint means a retry that arrives after a partial failure
  // (checkpoint blocked) still sees the idempotency record only when checkpoint also
  // succeeded â€” because if checkpoint blocks, we return early before this point.
  // Wait â€” actually we want the stamp BEFORE the checkpoint guard so the order is
  // canonical, but we ALSO want it gated on success. Solution: keep stamp here,
  // but only run it inside the success branch of the checkpoint guard below.

  // ----- (4) APPROVED EDGES (after required slices/events) -----
  // Edges are optional per architecture, but must run after core node/slice/event truth.
  // Only explicit relation_hints or backend-rule relation patterns are allowed through edge gates.
  try {
    const _userTextForEdgeGate = trimMemoryText(getLastUserMessageText(sliceMessages) || '', 600);
    const upsertOutcome = await memoryProdUpsertMemoryConnectionsFromLearned(accessToken, projectId, uid, requestedMode, connectionHints, nowMs, updatedNodes, workingConnections, existingCandidates, _userTextForEdgeGate);
    if (upsertOutcome && Array.isArray(upsertOutcome.created)) {
      for (const created of upsertOutcome.created) {
        connectionResults.push({
          from: trimMemoryText(created.from || '', 80),
          to: trimMemoryText(created.to || '', 80),
          type: trimMemoryText(created.type || '', 40),
          state: trimMemoryText(created.state || 'created', 40)
        });
        await memoryProdLogDebugStage(accessToken, projectId, uid, 'edge_written', {
          sessionId: session.id,
          jobId: payload?.jobId || '',
          threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
          userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
          decision: trimMemoryText(created.state || 'created', 40),
          reason: trimMemoryText(created.gateReason || 'edge_gate_passed', 160),
          details: { from: created.from, to: created.to, type: created.type }
        });
      }
    }
    if (upsertOutcome && Array.isArray(upsertOutcome.skipped)) {
      for (const skipped of upsertOutcome.skipped) {
        connectionResults.push({
          from: trimMemoryText(skipped.from || '', 80),
          to: trimMemoryText(skipped.to || '', 80),
          type: 'skipped',
          state: `skip:${skipped.reason || 'unknown'}`
        });
        await memoryProdLogDebugStage(accessToken, projectId, uid, 'edge_skipped', {
          sessionId: session.id,
          jobId: payload?.jobId || '',
          threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
          userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
          decision: 'skipped',
          reason: trimMemoryText(skipped.reason || 'unknown', 160),
          details: { from: skipped.from, to: skipped.to, type: skipped.type || '' }
        });
      }
    }
  } catch (edgeErr) {
    console.log(`[edge_upsert_error] sid=${session.id}: ${String(edgeErr?.message || edgeErr)}`);
  }

  // Auto-edge inference from user text (regex backup). Optional and still gate-checked.
  try {
    const inferredEdges = memoryProdInferConnectionsFromUserText(
      lastUserTextForEvents,
      Array.isArray(learned.candidates) ? learned.candidates : [],
      updatedNodes
    );
    if (inferredEdges.length) {
      const existingHintKeys = new Set(
        connectionHints
          .filter((h) => h && h.from && h.to)
          .map((h) => `${normalizeMemoryKey(h.from)}|${String(h.type || 'related_to').toLowerCase()}|${normalizeMemoryKey(h.to)}`)
      );
      const freshEdges = inferredEdges.filter((e) => {
        const key = `${normalizeMemoryKey(e.from)}|${String(e.type || 'related_to').toLowerCase()}|${normalizeMemoryKey(e.to)}`;
        return !existingHintKeys.has(key);
      }).map((e) => ({ ...e, provenance: 'backend_rule' }));
      if (freshEdges.length) {
        const inferredOutcome = await memoryProdUpsertMemoryConnectionsFromLearned(
          accessToken, projectId, uid, requestedMode, freshEdges, nowMs, updatedNodes, workingConnections, existingCandidates, lastUserTextForEvents
        ).catch((err) => { console.log(`[auto_edge_upsert_error] uid=${uid}: ${String(err?.message || err)}`); return null; });
        if (inferredOutcome && Array.isArray(inferredOutcome.created)) {
          for (const edge of inferredOutcome.created) {
            connectionResults.push({
              from: trimMemoryText(edge.from || '', 80),
              to: trimMemoryText(edge.to || '', 80),
              type: trimMemoryText(edge.type || '', 40),
              state: trimMemoryText(edge.state || 'created', 40),
              inferred: true
            });
            await memoryProdLogDebugStage(accessToken, projectId, uid, 'edge_written', {
              sessionId: session.id,
              jobId: payload?.jobId || '',
              threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
              userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
              decision: trimMemoryText(edge.state || 'created', 40),
              reason: 'inferred_via_backend_rule',
              details: { from: edge.from, to: edge.to, type: edge.type, inferred: true }
            });
          }
        }
        if (inferredOutcome && Array.isArray(inferredOutcome.skipped)) {
          for (const edge of inferredOutcome.skipped) {
            connectionResults.push({
              from: trimMemoryText(edge.from || '', 80),
              to: trimMemoryText(edge.to || '', 80),
              type: 'skipped',
              state: `skip:${edge.reason || 'unknown'}`,
              inferred: true
            });
            await memoryProdLogDebugStage(accessToken, projectId, uid, 'edge_skipped', {
              sessionId: session.id,
              jobId: payload?.jobId || '',
              threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
              userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
              decision: 'skipped',
              reason: trimMemoryText(edge.reason || 'unknown', 160),
              details: { from: edge.from, to: edge.to, type: edge.type || '', inferred: true }
            });
          }
        }
      }
    }
  } catch (_inferErr) { console.log(`[auto_edge_inference_error] sid=${session.id}: ${String(_inferErr?.message || _inferErr)}`); }

  // ----- (9) CHECKPOINT GUARD â€” advance LAST, only after required writes succeeded.
  const _failed = _failedRequiredWrites();
  if (_failed.length > 0) {
    // ARCH Â§1, Â§9 â€” Required write failed. Do NOT advance checkpoint. Emit
    // checkpoint_blocked debug + trace; the same packet will retry next turn.
    await memoryProdLogDebugStage(accessToken, projectId, uid, 'checkpoint_blocked', {
      sessionId: session.id,
      jobId: payload?.jobId || '',
      threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
      userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
      decision: 'blocked',
      reason: `required_write_failed:${_failed[0]?.label || 'unknown'}`,
      details: {
        failedCount: _failed.length,
        failed: _failed.map((f) => ({ label: f.label, error: trimMemoryText(f.error || '', 220), meta: f.meta || {} })),
        candidateCount: candidateOutcomes.length,
        eventCount: createdEventIds.length,
        sliceCount: writtenSliceIds.length
      }
    });
    await writeMemoryLearningTrace(accessToken, projectId, uid, {
      nowMs,
      stage: 'checkpoint_blocked',
      status: 'failed',
      sourceTag: payload?.sourceTag,
      threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
      threadKey,
      sessionId: session.id,
      userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
      assistantMsgId: payload?.assistantMsgId || '',
      triggerReason: trigger.reason || '',
      rowsProcessed: cursorAdvanceInfo.rowsProcessed,
      sliceMessages: sliceMessages.length,
      lastMsgId: cursorAdvanceInfo.newestMsgId,
      checkpointAdvanced: false,
      failedStep: _failed[0]?.label || 'required_write',
      error: trimMemoryText(_failed[0]?.error || '', 220),
      note: `required_writes_failed=${_failed.length}`
    }).catch((err) => {
      console.log(`[checkpoint_blocked_trace_error] sid=${session.id}: ${String(err?.message || err)}`);
    });
    // Mark session as having a partial failure but DO NOT update lastProcessedMsgId.
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memorySessions/${session.id}`, {
      lastExtractionReason: trimMemoryText(`partial_failure:${_failed[0]?.label || 'unknown'}`, 80),
      lastActivityAt: nowMs,
      updatedAt: nowMs,
      status: 'partial_failure',
      schemaVersion: MEMORY_SCHEMA_VERSION
    }).catch((err) => {
      console.log(`[checkpoint_blocked_session_patch_error] sid=${session.id}: ${String(err?.message || err)}`);
    });
    return {
      ok: false,
      partial: true,
      reason: 'checkpoint_blocked',
      sessionId: session.id,
      processedMessages: 0,
      candidateCount: candidateOutcomes.length,
      eventCount: createdEventIds.length,
      sliceCount: writtenSliceIds.length,
      failedRequiredWrites: _failed.map((f) => ({ label: f.label, error: f.error })),
      triage: learned?.triage || null,
      trigger
    };
  }

  // All required writes succeeded â€” proceed with idempotency stamp + checkpoint advance.
  if (idempotencyKey) {
    await memoryProdStampIdempotency(accessToken, projectId, uid, idempotencyKey, {
      sessionId: session.id,
      tier: learned?.triage?.tierUsed || '',
      decisionSummary: {
        candidates: (learned?.candidates || []).map((c) => c.label),
        reinforce: learned?.reinforce_labels || [],
        events: createdEventIds,
        slices: writtenSliceIds
      }
    }).catch((err) => {
      console.log(`[idempotency_stamp_error] sid=${session.id}: ${String(err?.message || err)}`);
    });
  }

  // ----------------------------------------------------------------------
  // CHECKPOINT ADVANCE â€” happens LAST, only after required writes succeeded.
  // ----------------------------------------------------------------------
  const legacyCheckpointPatch = memoryProdGetSessionCheckpointPayload(fullMessages);
  const stableLegacyProcessedCount = useBackendLog
    ? Math.max(0, num(session?.lastProcessedMessageCount, 0) + num(cursorAdvanceInfo?.rowsProcessed, 0))
    : legacyCheckpointPatch.lastProcessedMessageCount;
  legacyCheckpointPatch.lastProcessedMessageCount = stableLegacyProcessedCount;
  const cursorCheckpointPatch = useBackendLog && cursorAdvanceInfo.newestMsgId
    ? memoryLogBuildCursorCheckpointPatch(
        cursorAdvanceInfo.newestMsgId,
        cursorAdvanceInfo.priorMsgId,
        stableLegacyProcessedCount,
        nowMs
      )
    : { lastProcessedMsgId: trimMemoryText(session?.lastProcessedMsgId || '', 160), lastProcessedMsgIdPrev: trimMemoryText(session?.lastProcessedMsgIdPrev || '', 160), lastProcessedAt: nowMs };
  await fsPatchDoc(accessToken, projectId, `users/${uid}/memorySessions/${session.id}`, {
    ...legacyCheckpointPatch,
    ...cursorCheckpointPatch,
    checkpointExpiresAt: nowMs + MEMORY_CHECKPOINT_RETENTION_MS,
    countedTopicKeys: boundedUniqueIds([...(Array.isArray(session.countedTopicKeys) ? session.countedTopicKeys : []), ...memoryProdBuildSessionTopicKeys(learned)], MEMORY_SESSION_COUNTED_TOPIC_CAP),
    linkedEventIds: boundedUniqueIds([...(Array.isArray(session.linkedEventIds) ? session.linkedEventIds : []), ...createdEventIds], MEMORY_SESSION_EVENT_PREVIEW_CAP),
    lastEventId: createdEventIds[createdEventIds.length - 1] || trimMemoryText(session.lastEventId || '', 160),
    pendingSinceAt: 0,
    pendingSliceMessageCount: 0,
    pendingSliceCharCount: 0,
    pendingTriggerReason: '',
    lastExtractionReason: trimMemoryText(trigger.reason || 'processed', 80),
    nextEligibleExtractAt: nowMs,
    lastActivityAt: nowMs,
    updatedAt: nowMs,
    status: 'active',
    schemaVersion: MEMORY_SCHEMA_VERSION
  });
  // ARCH Â§16 â€” checkpoint_advanced debug stage. Phase C: emit to memoryDebugLogs in
  // addition to the trace channel so the Â§16 stage list is complete.
  await memoryProdLogDebugStage(accessToken, projectId, uid, 'checkpoint_advanced', {
    sessionId: session.id,
    jobId: payload?.jobId || '',
    threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
    userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
    decision: 'advanced',
    reason: trigger?.reason || 'processed',
    details: {
      priorMsgId: cursorAdvanceInfo.priorMsgId,
      newestMsgId: cursorAdvanceInfo.newestMsgId,
      rowsProcessed: cursorAdvanceInfo.rowsProcessed,
      sliceCount: writtenSliceIds.length,
      eventCount: createdEventIds.length,
      candidateCount: candidateOutcomes.length
    }
  });
  await writeMemoryLearningTrace(accessToken, projectId, uid, {
    nowMs,
    stage: 'checkpoint_advanced',
    status: 'ok',
    sourceTag: payload?.sourceTag,
    threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
    threadKey,
    sessionId: session.id,
    userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
    assistantMsgId: payload?.assistantMsgId || '',
    triggerReason: trigger.reason || '',
    rowsProcessed: cursorAdvanceInfo.rowsProcessed,
    sliceMessages: sliceMessages.length,
    lastMsgId: cursorAdvanceInfo.newestMsgId,
    checkpointAdvanced: true
  }).catch((err) => {
    console.log(`[checkpoint_advanced_trace_error] sid=${session.id}: ${String(err?.message || err)}`);
  });

  await writeMemoryDebugLog(accessToken, projectId, uid, {
    nowMs,
    sourceTag: payload?.sourceTag,
    threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
    sessionId: session?.id || '',
    lastProcessedAt: nowMs,
    checkpointNote: `latest conversation slice processed (${trigger.reason})`,
    messageLog: {
      threadKey,
      useBackendLog,
      cursorPriorMsgId: cursorAdvanceInfo.priorMsgId,
      cursorNewestMsgId: cursorAdvanceInfo.newestMsgId,
      cursorAdvanced: useBackendLog && cursorAdvanceInfo.newestMsgId && cursorAdvanceInfo.newestMsgId !== cursorAdvanceInfo.priorMsgId,
      rowsProcessed: cursorAdvanceInfo.rowsProcessed,
      bridgeMsgsFromLog: bridgeMessagesFromLog.length,
      source: cursorAdvanceInfo.source
    },
    trigger,
    packetPreview: extractionPacket.packetPreview,
    learned,
    candidateCreated,
    candidatePromoted,
    reinforcedNodes,
    skippedItems,
    eventDocs,
    placedNodes,
    connectionResults,
    extractionStatus: learned?.extractionError ? 'processed_with_fallback' : 'processed'
  }).catch((err) => {
    console.log(`[memory_debug_log_error] sid=${session.id}: ${String(err?.message || err)}`);
  });

  const quotaOptionalWorkSkipped = [];
  await syncMemoryNodeIndexes(accessToken, projectId, uid, updatedNodes.filter((node) => !node.deleted));
  if (MEMORY_QUOTA_SAFE_MODE || payload?.deferFinalSync === true) {
    quotaOptionalWorkSkipped.push('meta_refresh');
    await upsertMemoryStatsSnapshot(accessToken, projectId, uid, {
      lastLearningStatus: 'completed',
      lastLearningAt: nowMs,
      nodeCount: Math.max(updatedNodes.filter((node) => !node.deleted).length, num(candidatePromoted.length, 0) + num(reinforcedNodes.length, 0)),
      candidateCount: candidateCreated.length,
      eventCount: eventDocs.length,
      connectionCount: Array.isArray(connectionResults?.createdOrUpdated) ? connectionResults.createdOrUpdated.length : 0,
      autoLearnedCount: updatedNodes.filter((node) => !node.deleted && node.learned).length,
      optionalWorkSkipped: quotaOptionalWorkSkipped,
      metaRefreshSkipped: true,
      pass2Deferred: MEMORY_PASS2_DEFER_IN_QUOTA_SAFE,
      schemaVersion: MEMORY_SCHEMA_VERSION
    }).catch((err) => console.log(`[memory_stats_quota_safe_error] sid=${session.id}: ${String(err?.message || err)}`));
  } else {
    await refreshMemoryMetaCounts(accessToken, projectId, uid);
  }

  // ----------------------------------------------------------------------
  // PASS 2 ENQUEUE â€” happens AFTER checkpoint advance per PDF Â§10.
  // In quota-safe mode Pass 2 is deferred; Pass 1 structural truth is already durable.
  // ----------------------------------------------------------------------
  const pass2EnqueueResults = [];
  const pass2JobsToRun = (MEMORY_QUOTA_SAFE_MODE && MEMORY_PASS2_DEFER_IN_QUOTA_SAFE) ? [] : pass2Jobs;
  if (pass2JobsToRun.length !== pass2Jobs.length) {
    quotaOptionalWorkSkipped.push('pass2');
    for (const job of pass2Jobs) pass2EnqueueResults.push({ job, result: { enqueued: false, mode: 'deferred_quota_safe', deferred: true } });
  }
  for (const job of pass2JobsToRun) {
    const r = await memoryProdEnqueuePass2(env, job).catch((err) => {
      console.log(`[pass2_enqueue_error] sid=${session.id} nodeId=${job.nodeId}: ${String(err?.message || err)}`);
      return { enqueued: false, mode: 'enqueue_threw', error: String(err?.message || err) };
    });
    pass2EnqueueResults.push({ job, result: r });
    await memoryProdLogDebugStage(accessToken, projectId, uid, 'pass2_enqueued', {
      sessionId: session.id,
      jobId: payload?.jobId || '',
      threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
      nodeId: job.nodeId,
      sliceId: job.sliceId,
      eventId: job.eventId || '',
      decision: r?.enqueued ? 'enqueued' : 'fallback_inline',
      reason: r?.mode || 'unknown'
    });
    // ARCH Â§10 â€” Pass 2 inline fallback: only when MEMORY_PASS2_QUEUE binding is missing.
    // On failure, we emit pass2_failed but do NOT propagate the error â€” Pass 2 must never
    // corrupt structural truth.
    if (r && r.enqueued === false && r.mode === 'no_binding' && cfg?.memorySummaryEnabled !== false) {
      try {
        await memoryProdRunPass2Narrative(env, accessToken, projectId, uid, cfg, job);
      } catch (err) {
        const errText = String(err?.message || err);
        console.log(`[pass2_inline_fallback_error] sid=${session.id} nodeId=${job.nodeId}: ${errText}`);
        await memoryProdLogDebugStage(accessToken, projectId, uid, 'pass2_failed', {
          sessionId: session.id,
          jobId: payload?.jobId || '',
          threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
          nodeId: job.nodeId,
          sliceId: job.sliceId,
          decision: 'inline_failed',
          reason: trimMemoryText(errText, 220),
          details: { mode: 'inline_fallback', retryable: true }
        }).catch(() => null);
      }
    }
  }

  // v3.1.14 â€” Compute pass2Status and emit learning_job_finished
  const pass2Enqueued = pass2EnqueueResults.filter((x) => x.result?.enqueued).length;
  const pass2Inline = pass2EnqueueResults.filter((x) => x.result && x.result.enqueued === false && x.result.mode === 'no_binding').length;
  const pass2Deferred = pass2EnqueueResults.filter((x) => x.result && x.result.mode === 'deferred_quota_safe').length;
  const pass2Status = pass2EnqueueResults.length === 0
    ? 'no_jobs'
    : (pass2Enqueued > 0 ? 'enqueued' : (pass2Inline > 0 ? 'inline_fallback' : (pass2Deferred > 0 ? 'deferred_quota_safe' : 'failed')));
  await memoryProdLogDebugStage(accessToken, projectId, uid, 'learning_job_finished', {
    sessionId: session.id,
    jobId: payload?.jobId || '',
    threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
    decision: 'finished',
    reason: trigger?.reason || 'completed',
    details: {
      candidateCount: candidateOutcomes.length,
      eventCount: createdEventIds.length,
      sliceCount: writtenSliceIds.length,
      pass2Status,
      pass2Enqueued,
      pass2Inline,
      pass2Deferred,
      quotaSafeMode: MEMORY_QUOTA_SAFE_MODE,
      optionalWorkSkipped: quotaOptionalWorkSkipped,
      metaRefreshSkipped: MEMORY_QUOTA_SAFE_MODE || payload?.deferFinalSync === true,
      tier: learned?.triage?.tierUsed || '',
      model: learned?.triage?.modelUsed || ''
    }
  });

  return {
    ok: true,
    sessionId: session.id,
    processedMessages: sliceMessages.length,
    candidateCount: candidateOutcomes.length,
    eventCount: createdEventIds.length,
    sliceCount: writtenSliceIds.length,
    pass2Enqueued: pass2EnqueueResults.filter((x) => x.result?.enqueued).length,
    pass2Status,
    pass2Deferred,
    quotaSafeMode: MEMORY_QUOTA_SAFE_MODE,
    optionalWorkSkipped: quotaOptionalWorkSkipped,
    metaRefreshSkipped: MEMORY_QUOTA_SAFE_MODE || payload?.deferFinalSync === true,
    triage: learned?.triage || null,
    trigger
  };
}


async function memoryProdRunMemoryMaintenance(accessToken, projectId, uid, cfg) {
  const now = Date.now();
  const weekMs = 7 * 24 * 60 * 60 * 1000;
  const gapMs = Math.max(MEMORY_SESSION_GAP_MS, num(cfg?.memorySessionGapHours, 12) * 60 * 60 * 1000);
  const [nodes, candidates, suppressions, events, sessions, threads] = await Promise.all([
    listMemoryNodes(accessToken, projectId, uid),
    listMemoryCandidates(accessToken, projectId, uid),
    listMemorySuppressions(accessToken, projectId, uid),
    listMemoryEvents(accessToken, projectId, uid),
    listMemorySessions(accessToken, projectId, uid),
    listMemoryThreads(accessToken, projectId, uid)
  ]);
  for (const node of nodes) {
    if (node.deleted || node.isRoot) continue;
    const lastMentioned = num(node.lastMentioned, 0);
    if (lastMentioned && now - lastMentioned >= weekMs) {
      let nextHeat = Math.max(num(cfg.memoryHeatDecayFloor, 12), num(node.heat, 0) - num(cfg.memoryHeatDecayStep, 6));
      await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${node.id}`, { heat: nextHeat, schemaVersion: MEMORY_SCHEMA_VERSION });
    }
  }
  for (const cand of candidates) {
    if (cand.deleted) continue;
    const promotedExpired = String(cand.status || '') === 'promoted' && num(cand.cleanupAfterAt, 0) && num(cand.cleanupAfterAt, 0) < now;
    const fallbackExpiry = num(cand.lastSeenAt, 0) + memoryProdCandidateExpiryDays(cand.strength || 'medium', num(cand.sessionCount, 1)) * 24 * 60 * 60 * 1000;
    const staleExpired = num(cand.expiresAt || fallbackExpiry, 0) && num(cand.expiresAt || fallbackExpiry, 0) < now;
    if (promotedExpired || staleExpired) {
      await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryCandidates/${cand.id}`, {
        status: promotedExpired ? 'cleaned' : 'expired',
        deleted: true,
        deletedAt: now,
        schemaVersion: MEMORY_SCHEMA_VERSION
      });
    }
  }
  for (const sup of suppressions) {
    if (num(sup.suppressedUntil, 0) && num(sup.suppressedUntil, 0) < now) {
      await fsPatchDoc(accessToken, projectId, `users/${uid}/memorySuppressions/${sup.id}`, { deleted: true, deletedAt: now });
    }
  }
  for (const session of sessions) {
    if (session.deleted) continue;
    if (String(session.status || 'active') === 'active' && now - num(session.lastActivityAt, 0) > gapMs) {
      await fsPatchDoc(accessToken, projectId, `users/${uid}/memorySessions/${session.id}`, {
        status: 'closed',
        closedAt: now,
        checkpointExpiresAt: Math.max(num(session.checkpointExpiresAt, 0), now + MEMORY_CHECKPOINT_RETENTION_MS),
        updatedAt: now,
        schemaVersion: MEMORY_SCHEMA_VERSION
      });
    }
    const checkpointExpired = num(session.checkpointExpiresAt, 0) && num(session.checkpointExpiresAt, 0) < now;
    if (checkpointExpired && (num(session.lastProcessedMessageCount, 0) || session.lastProcessedLastUserHash || session.lastProcessedMessageSignature)) {
      await fsPatchDoc(accessToken, projectId, `users/${uid}/memorySessions/${session.id}`, {
        lastProcessedMessageCount: 0,
        lastProcessedLastUserHash: '',
        lastProcessedMessageSignature: '',
        checkpointClearedAt: now,
        updatedAt: now,
        schemaVersion: MEMORY_SCHEMA_VERSION
      });
    }
  }
  for (const thread of threads) {
    const activeSessionId = trimMemoryText(thread.activeSessionId || '', 120);
    if (!activeSessionId) continue;
    const activeSession = sessions.find((item) => item.id === activeSessionId);
    if (activeSession && String(activeSession.status || 'active') === 'closed') {
      await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryThreads/${thread.id}`, { activeSessionId: '', updatedAt: now }).catch(() => null);
    }
  }
  for (const event of events) {
    if (event.deleted) continue;
    const nextTier = computeMemoryTierFromTimestamps(event.updatedAt || event.createdAt || now, event.importanceClass, now);
    if (nextTier !== String(event.memoryTier || '')) {
      await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryEvents/${event.id}`, {
        memoryTier: nextTier,
        updatedAt: Math.max(num(event.updatedAt, 0), now),
        schemaVersion: MEMORY_SCHEMA_VERSION
      });
      await syncEventIndexDoc(accessToken, projectId, uid, { ...event, memoryTier: nextTier });
    }
  }
  await fsPatchDoc(accessToken, projectId, `users/${uid}/jobState/health_transition`, {
    status: 'idle',
    lastRunAt: now,
    lastSuccessAt: now,
    updatedAt: now,
    schemaVersion: MEMORY_SCHEMA_VERSION
  }).catch(() => null);
  await fsPatchDoc(accessToken, projectId, `users/${uid}`, {
    memoryLastDecayAt: now,
    memoryVersion: MEMORY_VERSION,
    memorySchemaVersion: MEMORY_SCHEMA_VERSION
  });
  await syncMemoryNodeIndexes(accessToken, projectId, uid, await listMemoryNodes(accessToken, projectId, uid));
  const counts = await refreshMemoryMetaCounts(accessToken, projectId, uid);
  return { ok: true, uid, maintenanceAt: now, counts };
}


async function runMemoryDebugProcessThread(env, accessToken, projectId, uid, cfg, body = {}) {
  const nowMs = Date.now();
  const stages = [];
  let failedStep = 'diagnostic_started';
  const sourceTag = trimMemoryText(String(body?.sourceTag || 'chat'), 40).toLowerCase() || 'chat';
  const rawThreadId = trimMemoryText(String(body?.threadId || body?.chatId || body?.conversationId || ''), 140);
  const threadKey = trimMemoryText(String(body?.threadKey || buildMemoryThreadKey(rawThreadId, sourceTag)), 100);
  const trace = async (stage, extra = {}) => {
    stages.push(stage);
    await writeMemoryLearningTrace(accessToken, projectId, uid, {
      nowMs: extra.nowMs || Date.now(),
      stage,
      status: extra.status || 'observed',
      sourceTag,
      threadId: rawThreadId,
      threadKey,
      sessionId: extra.sessionId || '',
      triggerReason: extra.triggerReason || 'manual_debug_process_thread',
      rowsProcessed: extra.rowsProcessed,
      rowsLoaded: extra.rowsLoaded,
      sliceMessages: extra.sliceMessages,
      userRows: extra.userRows,
      assistantRows: extra.assistantRows,
      firstMsgId: extra.firstMsgId,
      lastMsgId: extra.lastMsgId,
      sliceChars: extra.sliceChars,
      failedStep: extra.failedStep || '',
      error: extra.error || '',
      note: extra.note || '',
      decision: extra.decision || '',
      resultOk: extra.resultOk,
      checkpointAdvanced: extra.checkpointAdvanced
    }).catch(() => null);
  };

  if (!threadKey || (!rawThreadId && !body?.threadKey)) {
    return {
      ok: false,
      uid,
      error: 'threadId or threadKey required',
      failedStep: 'request_validation',
      needBody: ['threadId/threadKey', 'forceExtract', 'debug', 'sourceTag'],
      stages
    };
  }

  await trace('diagnostic_started', { status: 'started' });
  try {
    failedStep = 'bootstrap';
    await ensureMemoryBootstrap(accessToken, projectId, uid, cfg, { ensureOperationalDocs: false, ensureProfile: false, ensureRootIndex: false });

    failedStep = 'session_loaded';
    const session = await memoryProdCreateOrReuseMemorySession(accessToken, projectId, uid, cfg, {
      threadId: rawThreadId || threadKey,
      sourceTag,
      messages: [],
      nowMs
    });
    await trace('session_loaded', {
      status: 'ok',
      sessionId: session.id,
      rowsProcessed: num(session?.lastProcessedMessageCount, 0),
      note: `messageCount=${num(session?.messageCount, 0)} lastProcessedMsgId=${trimMemoryText(session?.lastProcessedMsgId || '', 80)} lastProcessedAt=${num(session?.lastProcessedAt, 0)}`
    });

    failedStep = 'backend_slice_loaded';
    const rows = await memoryLogListRecentMessages(accessToken, projectId, uid, threadKey, Math.max(2, Math.min(50, num(body?.limit, 30))));
    const rowsLoaded = Array.isArray(rows) ? rows.length : 0;
    const userRows = rows.filter((r) => String(r?.role || '').toLowerCase() === 'user').length;
    const assistantRows = rows.filter((r) => String(r?.role || '').toLowerCase() === 'assistant').length;
    const firstMsgId = rowsLoaded ? String(rows[0]?.id || '') : '';
    const lastMsgId = rowsLoaded ? String(rows[rowsLoaded - 1]?.id || '') : '';
    const stdRows = memoryLogToStandardMessages(rows);
    await trace('backend_slice_loaded', {
      status: rowsLoaded ? 'ok' : 'empty',
      sessionId: session.id,
      rowsLoaded,
      rowsProcessed: rowsLoaded,
      sliceMessages: stdRows.length,
      userRows,
      assistantRows,
      firstMsgId,
      lastMsgId,
      sliceChars: memoryProdEstimateSliceChars(stdRows, ''),
      note: 'diagnostic_preflight_recent_rows'
    });

    failedStep = 'learning_before_call';
    await trace('learning_before_call', { status: 'calling', sessionId: session.id, rowsLoaded, rowsProcessed: rowsLoaded, sliceMessages: stdRows.length });

    failedStep = 'processConversationMemoryTurn';
    const result = await processConversationMemoryTurn(env, accessToken, projectId, uid, cfg, {
      mode: MEMORY_SCOPE,
      sourceTag,
      threadId: rawThreadId || threadKey,
      threadKey,
      messages: [],
      assistantText: '',
      triggerReason: 'manual_debug_process_thread',
      forceExtract: body?.forceExtract !== false,
      forceLimit: Math.max(2, Math.min(30, num(body?.limit, 30))),
      bypassIdempotency: body?.bypassIdempotency !== false,
      useBackendLog: true,
      debug: true,
      memoryLearnInlineDebug: true,
      userMsgId: '',
      assistantMsgId: ''
    });

    const ok = !!result?.ok && !result?.failed;
    await trace('diagnostic_finished', {
      status: ok ? 'ok' : 'failed',
      sessionId: result?.sessionId || session.id,
      rowsLoaded,
      rowsProcessed: num(result?.processedMessages, rowsLoaded),
      sliceMessages: num(result?.processedMessages, stdRows.length),
      resultOk: ok,
      decision: result?.reason || result?.trigger?.reason || '',
      error: result?.error || '',
      failedStep: ok ? '' : 'processConversationMemoryTurn'
    });

    return {
      ok,
      uid,
      threadId: rawThreadId,
      threadKey,
      sessionId: result?.sessionId || session.id,
      stages,
      rowsLoaded,
      userRows,
      assistantRows,
      firstMsgId,
      lastMsgId,
      trigger: result?.trigger || null,
      result,
      error: ok ? null : (result?.error || result?.reason || 'learning_failed'),
      failedStep: ok ? null : 'processConversationMemoryTurn'
    };
  } catch (err) {
    const errText = String(err?.message || err || 'diagnostic_failed');
    await trace('diagnostic_failed', { status: 'failed', failedStep, error: errText });
    return {
      ok: false,
      uid,
      threadId: rawThreadId,
      threadKey,
      sessionId: '',
      stages,
      rowsLoaded: 0,
      trigger: null,
      result: null,
      error: errText,
      failedStep
    };
  }
}

export default {
  // Pass 2 narrative consumer for Cloudflare Queues (binding: MEMORY_PASS2_QUEUE).
  // Each message body is a Pass 2 job: { uid, nodeId, sliceId, eventId, reason }.
  // Failures retry with backoff and move to DLQ after max-retries per wrangler config.
  async queue(batch, env, ctx) {
    try {
      const messages = Array.isArray(batch?.messages) ? batch.messages : [];
      const learningMessages = messages.filter((msg) => (msg?.body || {})?.kind === 'memory_learning_job');
      const pass2Messages = messages.filter((msg) => (msg?.body || {})?.kind !== 'memory_learning_job');
      if (learningMessages.length) await memoryLearningQueueConsumer({ ...batch, messages: learningMessages }, env);
      if (pass2Messages.length) await memoryProdPass2QueueConsumer({ ...batch, messages: pass2Messages }, env);
    } catch (err) {
      console.log(`[queue_handler_fatal] ${String(err?.message || err)}`);
    }
  },
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, x-app-secret, Authorization',
    };

    if (request.method === 'OPTIONS') return new Response(null, {
      status: 204,
      headers: corsHeaders
    });
    if (url.pathname === '/health') return new Response('ok', {
      status: 200,
      headers: corsHeaders
    });

    const isMemoryProcessThreadDiagnostic = url.pathname === '/memory/debug/process-thread';
    const isMemoryInternalLearningJob = url.pathname === '/memory/internal/process-learning-job';
    const isMemoryDebugJsonRoute = isMemoryProcessThreadDiagnostic || isMemoryInternalLearningJob;
    const appSecret = request.headers.get('x-app-secret');
    const hasValidAppSecret = !!(env.APP_SECRET && appSecret && appSecret === env.APP_SECRET);

    // Normal app requests are protected by Firebase Authorization tokens.
    // APP_SECRET is kept only for internal/debug routes, never hardcoded in Flutter.
    if (isMemoryDebugJsonRoute && !hasValidAppSecret) {
      return json({ ok: false, error: 'unauthorized', needHeaders: ['authorization', 'x-app-secret', 'content-type'] }, 401, corsHeaders);
    }

    let uid;
    try {
      uid = await requireFirebaseUid(request, env.FIREBASE_PROJECT_ID);
    } catch (resp) {
      if (isMemoryDebugJsonRoute) {
        return json({ ok: false, error: 'unauthorized', needHeaders: ['authorization', 'x-app-secret', 'content-type'] }, 401, corsHeaders);
      }
      return withCors(resp, corsHeaders);
    }

    let accessToken;
    try {
      const sa = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON);
      accessToken = await getGoogleAccessToken(sa);
    } catch (e) {
      return json({
        ok: false,
        error: 'service account oauth failed',
        detail: String(e)
      }, 500, corsHeaders);
    }

    const cfg = await loadPublicConfig(accessToken, env.FIREBASE_PROJECT_ID);

    if (url.pathname === '/memory/debug/version' && request.method === 'GET') {
      try {
        // V3.1.12 production diagnostic: confirms queue-only memory learning build is deployed
        // AND reports the live queue binding state. Safe â€” no heavy subrequests.
        const queueBindingPresent = !!(env?.MEMORY_LEARNING_QUEUE && typeof env.MEMORY_LEARNING_QUEUE.send === 'function');
        const pass2BindingPresent = !!(env?.MEMORY_PASS2_QUEUE && typeof env.MEMORY_PASS2_QUEUE.send === 'function');
        return json({
          ok: true,
          uid,
          workerVersion: 'v3.1.13-empty-memory-bypass+profile-fastpath',
          memoryVersion: MEMORY_VERSION,
          memorySchemaVersion: MEMORY_SCHEMA_VERSION,
          queueBindingPresent,
          queueBindingName: 'MEMORY_LEARNING_QUEUE',
          dispatchModeExpected: queueBindingPresent ? 'cloudflare_queue' : 'queue_missing',
          selfFetchDispatchRemoved: true,
          inlineLearningDisabledForChat: true,
          hasQueueConsumer: true,
          hasMemoryLearningJobs: true,
          hasLearningJobs: true,
          hasEarlyDispatch: true,
          hasBatchedPointsDeduct: true,
          hasLightweightChatBootstrap: true,
          hasInlineWaitUntilDispatch: false,
          hasEmptyMemoryBypass: true,
          hasProfileFastPath: true,
          inlineLearningDisabled: true,
          queueOnlyAutoLearning: true,
          routes: {
            chat: true,
            internalProcessLearningJob: true,
            debugProcessThread: true,
            recallPreview: true,
            learnFlush: true,
            graph: true,
            debugStatus: true,
            debugFull: true,
            finalStatus: true,
            debugVersion: true
          },
          bindings: {
            MEMORY_LEARNING_QUEUE: queueBindingPresent,
            MEMORY_PASS2_QUEUE: pass2BindingPresent
          },
          utilityFilterActive: true,
          build: {
            label: 'gpmai-worker-v3.1.13-empty-memory-bypass',
            generatedAt: Date.now()
          }
        }, 200, corsHeaders);
      } catch (e) {
        return json({ ok: false, error: String(e?.message || e) }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/memory/debug/process-thread' && request.method === 'POST') {
      try {
        const body = await request.json().catch(() => ({}));
        const out = await runMemoryDebugProcessThread(env, accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, body || {});
        return json(out, out?.ok ? 200 : 500, corsHeaders);
      } catch (e) {
        return json({ ok: false, uid, error: String(e?.message || e || 'diagnostic_route_failed'), failedStep: 'diagnostic_route', needHeaders: ['authorization', 'x-app-secret', 'content-type'] }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/memory/internal/process-learning-job' && request.method === 'POST') {
      try {
        const body = await request.json().catch(() => ({}));
        const out = await runMemoryLearningJob(env, accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, body || {});
        return json(out, out?.ok ? 200 : 500, corsHeaders);
      } catch (e) {
        return json({ ok: false, uid, error: String(e?.message || e || 'learning_job_route_failed'), failedStep: 'learning_job_route', needHeaders: ['authorization', 'x-app-secret', 'content-type'] }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/models' && request.method === 'GET') {
      try {
        const category = (url.searchParams.get('category') || 'all').trim().toLowerCase();
        const provider = (url.searchParams.get('provider') || '').trim().toLowerCase();
        const sort = (url.searchParams.get('sort') || 'recommended').trim().toLowerCase();
        const q = (url.searchParams.get('q') || '').trim().toLowerCase();
        const idsOnly = (url.searchParams.get('idsOnly') || '0') === '1';
        const catalog = await getModelsCatalogCached(env);
        let list = catalog.all;
        if (category && category !== 'all') list = list.filter((m) => m.category === category);
        if (provider) list = list.filter((m) => m.provider === provider);
        if (q) list = list.filter((m) => `${m.name} ${m.id} ${m.providerLabel} ${m.provider}`.toLowerCase().includes(
          q));
        list = sortModels(list, sort);
        return json({
          ok: true,
          uid,
          ts: Date.now(),
          ttlMs: MODELS_TTL_MS,
          category,
          provider: provider || null,
          sort,
          q: q || null,
          total: list.length,
          ids: idsOnly ? list.map((m) => m.id) : undefined,
          providers: catalog.providers,
          categoriesCount: catalog.categoriesCount,
          ...(idsOnly ? {} : {
            all: list
          })
        }, 200, corsHeaders);
      } catch (e) {
        return json({
          ok: false,
          error: String(e)
        }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/me' && request.method === 'GET') {
      try {
        const out = await ensureUserAndDailyCredit(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
        const today = todayKeyIST();
        const monthKey = monthKeyIST();
        out.usage = {
          today: (await getUsageDoc(accessToken, env.FIREBASE_PROJECT_ID, `users/${uid}/usageDaily/${today}`)) || {
            dayKey: today,
            pointsSpent: 0,
            requests: 0
          },
          month: (await getUsageDoc(accessToken, env.FIREBASE_PROJECT_ID,
            `users/${uid}/usageMonthly/${monthKey}`)) || {
              monthKey,
              pointsSpent: 0,
              requests: 0
            },
        };
        return json(out, 200, corsHeaders);
      } catch (e) {
        return json({
          ok: false,
          error: String(e)
        }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/usage/daily' && request.method === 'GET') {
      try {
        const days = clampInt(url.searchParams.get('days'), 30, 1, 60);
        return json({
          ok: true,
          uid,
          days,
          series: await getDailyUsageSeries(accessToken, env.FIREBASE_PROJECT_ID, uid, days)
        }, 200, corsHeaders);
      } catch (e) {
        return json({
          ok: false,
          error: String(e)
        }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/usage/monthly' && request.method === 'GET') {
      try {
        const months = clampInt(url.searchParams.get('months'), 6, 1, 24);
        return json({
          ok: true,
          uid,
          months,
          series: await getMonthlyUsageSeries(accessToken, env.FIREBASE_PROJECT_ID, uid, months)
        }, 200, corsHeaders);
      } catch (e) {
        return json({
          ok: false,
          error: String(e)
        }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/memory/init' && (request.method === 'GET' || request.method === 'POST')) {
      try {
        const body = request.method === 'POST' ? await request.json().catch(() => ({})) : {};
        const requestedMode = normalizeMemoryMode(body?.mode || url.searchParams.get('mode') || MEMORY_SCOPE);
        await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
        return json(await getMemoryInitPayload(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, requestedMode), 200,
          corsHeaders);
      } catch (e) {
        return json({
          ok: false,
          error: String(e)
        }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/memory/profile' && request.method === 'GET') {
      try {
        const requestedMode = normalizeMemoryMode(url.searchParams.get('mode') || MEMORY_SCOPE);
        await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
        return json(await getMemoryProfilePayload(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, requestedMode), 200,
          corsHeaders);
      } catch (e) {
        return json({
          ok: false,
          error: String(e)
        }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/memory/profile/save' && request.method === 'POST') {
      try {
        const body = await request.json().catch(() => ({}));
        const requestedMode = normalizeMemoryMode(body?.mode || MEMORY_SCOPE);
        await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, { ensureOperationalDocs: false, ensureRootIndex: false, ensureProfile: false });
        return json(await saveMemoryProfileAndSeeds(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, requestedMode,
          body || {}), 200, corsHeaders);
      } catch (e) {
        return json({
          ok: false,
          error: String(e)
        }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/memory/profile/active-mode' && request.method === 'POST') {
      try {
        const body = await request.json().catch(() => ({}));
        const requestedMode = normalizeMemoryMode(body?.mode || MEMORY_SCOPE);
        await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
        await fsPatchDoc(accessToken, env.FIREBASE_PROJECT_ID, `users/${uid}`, {
          activeMemoryMode: MEMORY_SCOPE,
          lastRequestAt: Date.now()
        });
        const payload = await getMemoryProfilePayload(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, requestedMode);
        return json({
          ok: true,
          uid,
          activeMode: MEMORY_SCOPE,
          profile: payload.profile,
          memoryMeta: payload.memoryMeta
        }, 200, corsHeaders);
      } catch (e) {
        return json({
          ok: false,
          error: String(e)
        }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/memory/graph' && request.method === 'GET') {
      try {
        const requestedMode = normalizeMemoryMode(url.searchParams.get('mode') || MEMORY_SCOPE);
        await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
        return json(await getMemoryGraphPayload(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, requestedMode), 200,
          corsHeaders);
      } catch (e) {
        return json({
          ok: false,
          error: String(e)
        }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/memory/node/delete' && request.method === 'POST') {
      try {
        const body = await request.json().catch(() => ({}));
        const requestedMode = normalizeMemoryMode(body?.mode || MEMORY_SCOPE);
        const nodeId = String(body?.nodeId || '').trim();
        if (!nodeId) return json({
          ok: false,
          error: 'nodeId required'
        }, 400, corsHeaders);
        await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
        return json(await deleteMemoryNode(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, nodeId, requestedMode),
          200, corsHeaders);
      } catch (e) {
        return json({
          ok: false,
          error: String(e)
        }, 500, corsHeaders);
      }
    }
    if (url.pathname === '/memory/recall-preview' && request.method === 'POST') {
      try {
        const body = await request.json().catch(() => ({}));
        await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
        return json(await buildMemoryRecallPreviewPayload(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, body || {}, env), 200, corsHeaders);
      } catch (e) {
        return json({
          ok: false,
          error: String(e)
        }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/memory/consolidation/status' && request.method === 'GET') {
      try {
        await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
        return json(await getMemoryConsolidationStatus(accessToken, env.FIREBASE_PROJECT_ID, uid), 200, corsHeaders);
      } catch (e) {
        return json({ ok: false, error: String(e) }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/memory/consolidation/run' && request.method === 'POST') {
      try {
        const body = await request.json().catch(() => ({}));
        await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
        return json(await runMemoryConsolidation(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, body || {}), 200, corsHeaders);
      } catch (e) {
        return json({ ok: false, error: String(e) }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/memory/maintenance' && request.method === 'POST') {
      try {
        await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
        return json(await runMemoryMaintenance(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg), 200, corsHeaders);
      } catch (e) {
        return json({
          ok: false,
          error: String(e)
        }, 500, corsHeaders);
      }
    }


if (url.pathname === '/memory/learn/flush' && request.method === 'POST') {
  try {
    const body = await request.json().catch(() => ({}));
    const messages = Array.isArray(body?.messages) ? body.messages : [];
    const threadId = String(body?.threadId || body?.chatId || body?.conversationId || '').trim();
    const sourceTag = String(body?.sourceTag || 'chat').trim().toLowerCase();
    // Accept either: (a) threadId-only (pull from backend log), or (b) messages array (legacy fallback).
    if (!messages.length && !threadId) {
      return json({ ok: false, error: 'threadId or messages required' }, 400, corsHeaders);
    }
    await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
    const useBackendLog = !!threadId; // prefer log when we have a threadId
    return json(await processConversationMemoryTurn(env, accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, {
      mode: MEMORY_SCOPE,
      sourceTag,
      threadId,
      threadKey: threadId ? buildMemoryThreadKey(threadId, sourceTag) : '',
      messages,
      assistantText: String(body?.assistantText || '').trim(),
      triggerReason: String(body?.triggerReason || 'manual_flush').trim().toLowerCase() || 'manual_flush',
      forceExtract: body?.forceExtract !== false,
      bypassIdempotency: body?.bypassIdempotency !== false,
      useBackendLog
    }), 200, corsHeaders);
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500, corsHeaders);
  }
}

    if (url.pathname === '/memory/debug/status' && request.method === 'GET') {
      try {
        await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
        return json(await getMemoryDebugStatusPayload(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg), 200, corsHeaders);
      } catch (e) {
        return json({ ok: false, error: String(e) }, 500, corsHeaders);
      }
    }


if (url.pathname === '/memory/debug/full' && request.method === 'GET') {
  try {
    await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
    return json(await getMemoryDebugStatusPayload(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg), 200, corsHeaders);
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500, corsHeaders);
  }
}

if (url.pathname === '/memory/final-status' && request.method === 'GET') {
  try {
    await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
    return json(await getMemoryFinalStatusPayload(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg), 200, corsHeaders);
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500, corsHeaders);
  }
}

if (url.pathname === '/memory/chat-preview' && request.method === 'POST') {
  try {
    const body = await request.json().catch(() => ({}));
    await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
    return json(await buildMemoryChatPreview(env, accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, MEMORY_SCOPE, body || {}), 200, corsHeaders);
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500, corsHeaders);
  }
}

if (url.pathname === '/memory/write-preview' && request.method === 'POST') {
  try {
    const body = await request.json().catch(() => ({}));
    await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
    return json(await buildMemoryWritePreviewPayload(env, accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, body || {}), 200, corsHeaders);
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500, corsHeaders);
  }
}

if (url.pathname === '/memory/simulate-learn' && request.method === 'POST') {
  try {
    await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
    return json(await simulateMemoryLearn(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, MEMORY_SCOPE), 200, corsHeaders);
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500, corsHeaders);
  }
}

if (url.pathname === '/memory/reset-learned' && request.method === 'POST') {
  try {
    const body = await request.json().catch(() => ({}));
    await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
    const cleared = await clearLearnedMemoryForMode(accessToken, env.FIREBASE_PROJECT_ID, uid, MEMORY_SCOPE, {
      keepProfile: body?.keepProfile !== false,
    });
    const finalStatus = await getMemoryFinalStatusPayload(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
    return json({ ok: true, uid, activeMode: MEMORY_SCOPE, cleared, finalStatus }, 200, corsHeaders);
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500, corsHeaders);
  }
}

if (url.pathname === '/memory/bootstrap' && request.method === 'POST') {
  try {
    const body = await request.json().catch(() => ({}));
    await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
    return json(await processMemoryBootstrapImport(env, accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, body || {}), 200, corsHeaders);
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500, corsHeaders);
  }
}

if (url.pathname === '/memory/test/import-dated-history' && request.method === 'POST') {
  try {
    const body = await request.json().catch(() => ({}));
    await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
    return json(await importSyntheticDatedHistory(env, accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, body || {}), 200, corsHeaders);
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500, corsHeaders);
  }
}

    if (url.pathname === '/chat' && request.method === 'POST') {
      try {
        const body = await request.json();
        const messages = Array.isArray(body?.messages) ? body.messages : null;
        const model = String(body?.model || cfg.defaultModel || 'openai/gpt-4o-mini');
        const max_tokens = body?.max_tokens;
        const temperature = body?.temperature;
        const requestedMode = normalizeMemoryMode(body?.memoryMode || body?.activeMemoryMode || MEMORY_SCOPE);
        const sourceTag = String(body?.sourceTag || 'chat').trim().toLowerCase();
        const memoryEligibleSource = !isUtilityMemorySourceTag(sourceTag);
        const threadId = String(body?.threadId || body?.chatId || body?.conversationId || '').trim();
        const clientMsgId = String(body?.clientMsgId || body?.client_msg_id || '').trim();
        if (!messages || !messages.length) return json({
          ok: false,
          error: 'messages required'
        }, 400, corsHeaders);

        const me = await ensureUserAndDailyCredit(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
        if (me?.wallet?.monthlyBlocked) return json({
          ok: false,
          code: 'BLOCKED',
          message: 'Unavailable'
        }, 402, corsHeaders);
        if (num(me?.wallet?.pointsBalance, 0) < cfg.minGatePoints) {
          return json({
            ok: false,
            code: 'LOW_POINTS',
            message: 'Not enough points to start request',
            wallet: me.wallet
          }, 402, corsHeaders);
        }

        if (memoryEligibleSource) await ensureMemoryBootstrap(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, {
          ensureOperationalDocs: false, // 3 jobState writes belong in /memory/init, not every chat turn
          ensureProfile: false,         // readUnifiedMemoryProfile runs again in getInjectedMemoryContext anyway
          ensureRootIndex: false        // root-index re-sync belongs in /memory/init
        });

        // ------------------------------------------------------------------
        // BACKEND-OWNED MESSAGE LOG â€” APPEND USER MESSAGE
        // ------------------------------------------------------------------
        // Architecture: Flutter sends only the current turn. The worker stores
        // the message in its own append-only log BEFORE running recall, so that
        // (a) recall can pull bridge context from the log, and (b) the learning
        // pipeline later reads from the log (not client array) when deciding
        // slice + cursor advance. If clientMsgId is absent, we still append
        // using a worker-generated msgId (with a honest debug note).
        const threadKey = memoryEligibleSource ? buildMemoryThreadKey(threadId, sourceTag) : '';
        const currentUserMsgText = getLastUserMessageText(messages);
        let userAppend = { ok: false, skipped: true };
        if (memoryEligibleSource && currentUserMsgText && threadKey) {
          try {
            userAppend = await memoryLogAppendMessage(accessToken, env.FIREBASE_PROJECT_ID, uid, {
              threadKey,
              role: 'user',
              content: currentUserMsgText,
              sourceTag,
              clientMsgId,
              nowMs: Date.now()
            });
          } catch (e) {
            userAppend = { ok: false, error: String(e?.message || e) };
          }
        }
        const linkedUserMsgId = userAppend?.msgId || '';

        // ============================================================================
        // V3.1.6: LEARNING JOB â€” CREATE & DISPATCH EARLY
        // ----------------------------------------------------------------------------
        // Rationale: v3.1.5 created the learning job at the END of /chat, AFTER recall,
        // openrouter, deduct, and assistant append had already burned ~35â€“40 subrequests.
        // On Cloudflare free tier (50/invocation) this put the job creation right at the
        // edge: the session was created, the status-patch and job-upsert failed silently,
        // and nothing reached the dispatched invocation.
        //
        // v3.1.8 creates + queue-dispatches the job IMMEDIATELY after the user msg is logged.
        // At this point we've burned ~10 subrequests. The job upsert + dispatch easily
        // fit in budget. The Cloudflare Queue consumer runs learning separately and
        // does the heavy extraction. If the queue binding is missing, the job stays visible
        // as queued_waiting_for_queue; /chat must not run extraction inline. Even if recall/openrouter/deduct later fail, the
        // job is already queued and will process the user's message.
        //
        // Note: assistantMsgId is passed as empty here. The dispatched worker reads the
        // backend message log fresh, so by the time it runs (typically a few hundred ms
        // later) the assistant message has already been appended.
        // ============================================================================
        let learningResult = null;
        let earlyJobDoc = null;
        if (memoryEligibleSource && cfg.memoryAutoLearnEnabled && threadKey && currentUserMsgText) {
          const shouldForceExtract = body?.memoryLearnInlineDebug === true
            || body?.forceMemoryLearn === true
            || body?.debugLearning === true
            || memoryProdIsLifeMemoryText(currentUserMsgText)
            || memoryProdHasHighSignalCue(currentUserMsgText);
          // V3.1.12: deterministic early-stage traces so Firestore shows the FULL chatâ†’queue
          // decision path even if anything else later fails.
          await writeMemoryLearningTrace(accessToken, env.FIREBASE_PROJECT_ID, uid, {
            stage: 'chat_learning_decision',
            status: 'ok',
            sourceTag, threadId, threadKey,
            userMsgId: linkedUserMsgId,
            assistantMsgId: '',
            triggerReason: 'chat_turn_complete',
            note: `forceExtract=${shouldForceExtract}`,
            resultOk: true
          }).catch(() => null);
          try {
            await writeMemoryLearningTrace(accessToken, env.FIREBASE_PROJECT_ID, uid, {
              stage: 'learning_job_create_started',
              status: 'pending',
              sourceTag, threadId, threadKey,
              userMsgId: linkedUserMsgId,
              assistantMsgId: '',
              triggerReason: 'chat_turn_complete',
              resultOk: true
            }).catch(() => null);
            earlyJobDoc = await createMemoryLearningJob(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, {
              mode: MEMORY_SCOPE,
              sourceTag,
              threadId,
              threadKey,
              messages,
              triggerReason: 'chat_turn_complete',
              useBackendLog: true,
              userMsgId: linkedUserMsgId,
              assistantMsgId: '', // will be visible via backend log when dispatched worker runs
              linkedUserMsgId,
              forceExtract: shouldForceExtract,
              bypassIdempotency: false,
              debug: body?.debugLearning === true || body?.memoryLearnInlineDebug === true,
              nowMs: Date.now()
            });
            await writeMemoryLearningTrace(accessToken, env.FIREBASE_PROJECT_ID, uid, {
              stage: 'learning_job_created',
              status: 'queued',
              sourceTag, threadId, threadKey,
              sessionId: earlyJobDoc?.sessionId || '',
              userMsgId: linkedUserMsgId,
              assistantMsgId: '',
              triggerReason: 'chat_turn_complete',
              note: `jobId=${earlyJobDoc?.id}`,
              resultOk: true
            }).catch(() => null);
            const dispatch = await dispatchMemoryLearningJob(env, request, ctx, accessToken, env.FIREBASE_PROJECT_ID, uid, earlyJobDoc, cfg);
            await writeMemoryLearningTrace(accessToken, env.FIREBASE_PROJECT_ID, uid, {
              stage: 'learning_split_scheduled',
              status: dispatch?.dispatched ? 'scheduled' : 'dispatch_failed',
              sourceTag, threadId, threadKey,
              sessionId: earlyJobDoc.sessionId || '',
              userMsgId: linkedUserMsgId,
              assistantMsgId: '',
              triggerReason: 'chat_turn_complete',
              note: `jobId=${earlyJobDoc.id} dispatch=${dispatch?.dispatchMode || 'unknown'} stage=early`,
              error: dispatch?.error || '',
              resultOk: !!dispatch?.dispatched
            }).catch(() => null);
            learningResult = {
              ok: !!dispatch?.dispatched,
              queued: true,
              deferred: true,
              failed: !dispatch?.dispatched,
              reason: dispatch?.dispatched ? 'learning_job_queued' : 'learning_job_dispatch_failed',
              jobId: earlyJobDoc.id,
              sessionId: earlyJobDoc.sessionId || '',
              dispatchMode: dispatch?.dispatchMode || '',
              error: dispatch?.error || '',
              stage: 'early'
            };
          } catch (err) {
            const errText = String(err?.message || err || 'learning_job_create_failed');
            await writeMemoryLearningTrace(accessToken, env.FIREBASE_PROJECT_ID, uid, {
              stage: 'learning_job_create_failed',
              status: 'failed',
              sourceTag, threadId, threadKey,
              userMsgId: linkedUserMsgId,
              assistantMsgId: '',
              triggerReason: 'chat_turn_complete',
              failedStep: 'create_or_dispatch_learning_job_early',
              error: errText
            }).catch(() => null);
            learningResult = { ok: false, queued: false, deferred: false, failed: true, reason: 'learning_job_create_failed', error: errText, sessionId: '', stage: 'early' };
          }
        }

        const memoryCtx = memoryEligibleSource
          ? await getInjectedMemoryContext(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg,
              requestedMode, { messages, sourceTag, threadId, threadKey }, env)
          : { prompt: '', recall: { mode: 'none', confidence: '', entryNodes: [], events: [] } };
        const chatMessagesForModel = memoryEligibleSource
          ? await memoryLogBuildRecentChatMessagesForModel(accessToken, env.FIREBASE_PROJECT_ID, uid, threadKey, messages, 18)
          : messages;
        const finalMessages = prependSystemContext(chatMessagesForModel, memoryCtx.prompt);

        const openrouterRes = await fetch('https://openrouter.ai/api/v1/chat/completions', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://gpmai.app',
            'X-Title': 'GPMai',
          },
          body: JSON.stringify({
            model,
            messages: finalMessages,
            ...(max_tokens != null ? {
              max_tokens
            } : {}),
            ...(temperature != null ? {
              temperature
            } : {})
          }),
        });
        const data = await openrouterRes.json();
        if (!openrouterRes.ok) {
          data._gpmai = {
            uid,
            memoryMode: requestedMode,
            threadKey,
            userMsgAppend: userAppend?.ok ? { msgId: userAppend.msgId, deduped: !!userAppend.deduped } : { error: userAppend?.error || 'append_failed' }
          };
          return new Response(JSON.stringify(data), {
            status: openrouterRes.status,
            headers: {
              ...corsHeaders,
              'content-type': 'application/json'
            }
          });
        }

        const usdCost = num(data?.usage?.cost, 0);
        const pointsCost = computePointsCost(usdCost, cfg);
        const after = await deductPointsAndUpdateStats(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, {
          provider: 'openrouter',
          category: 'chat',
          model,
          usdCost,
          pointsCost,
          predictionId: null,
          pricingSource: 'provider_returned_cost',
          pricingVersion: 'chat-openrouter',
          nowMs: Date.now(),
        });

        const assistantText = String(data?.choices?.[0]?.message?.content || '').trim();

        // ------------------------------------------------------------------
        // BACKEND-OWNED MESSAGE LOG â€” APPEND ASSISTANT MESSAGE
        // ------------------------------------------------------------------
        let assistantAppend = { ok: false, skipped: true };
        if (memoryEligibleSource && assistantText && threadKey) {
          try {
            assistantAppend = await memoryLogAppendMessage(accessToken, env.FIREBASE_PROJECT_ID, uid, {
              threadKey,
              role: 'assistant',
              content: assistantText,
              sourceTag,
              provider: 'openrouter',
              model,
              linkedUserMsgId,
              nowMs: Date.now()
            });
          } catch (e) {
            assistantAppend = { ok: false, error: String(e?.message || e) };
          }
        }

        // V3.1.6: learning job was already created+dispatched BEFORE recall/openrouter.
        // Now that the assistant msg is appended, link its msgId back to the job doc so
        // the dispatched worker can see provenance. This is a single fire-and-forget patch.
        if (earlyJobDoc?.id && assistantAppend?.msgId) {
          try {
            await patchMemoryLearningJob(accessToken, env.FIREBASE_PROJECT_ID, uid, earlyJobDoc.id, {
              assistantMsgId: assistantAppend.msgId
            });
            if (learningResult) learningResult.assistantMsgId = assistantAppend.msgId;
          } catch (_) { /* best effort; learning still works without this link */ }
        }

        data._gpmai = {
          uid,
          usdCost,
          pointsCost,
          memoryMode: requestedMode,
          recallMode: memoryCtx?.recall?.mode || 'none',
          recallConfidence: memoryCtx?.recall?.confidence || '',
          recallEntryNodes: Array.isArray(memoryCtx?.recall?.entryNodes) ? memoryCtx.recall.entryNodes.slice(0, 3) : [],
          recallEventIds: Array.isArray(memoryCtx?.recall?.events) ? memoryCtx.recall.events.map((x) => x.id).slice(0, 3) : [],
          memoryLog: {
            threadKey,
            userMsgId: userAppend?.msgId || '',
            userMsgDeduped: !!userAppend?.deduped,
            assistantMsgId: assistantAppend?.msgId || '',
            assistantMsgDeduped: !!assistantAppend?.deduped,
            chatContextMessages: Array.isArray(chatMessagesForModel) ? chatMessagesForModel.length : 0
          },
          learningResult: learningResult ? {
            ok: !!learningResult.ok,
            skipped: !!learningResult.skipped,
            deferred: !!learningResult.deferred,
            failed: !!learningResult.failed,
            reason: learningResult.reason || '',
            sessionId: learningResult.sessionId || '',
            jobId: learningResult.jobId || '',
            dispatchMode: learningResult.dispatchMode || '',
            queued: !!learningResult.queued,
            stage: learningResult.stage || '',
            assistantMsgId: learningResult.assistantMsgId || '',
            processedMessages: num(learningResult.processedMessages, 0),
            candidateCount: num(learningResult.candidateCount, 0),
            eventCount: num(learningResult.eventCount, 0),
            sliceCount: num(learningResult.sliceCount, 0),
            error: trimMemoryText(learningResult.error || '', 240),
            debugStages: (body?.memoryLearnInlineDebug === true || body?.debugLearning === true) && Array.isArray(learningResult.debugStages) ? learningResult.debugStages.slice(0, 20) : undefined
          } : null,
          walletAfter: {
            pointsBalance: after.pointsBalance
          }
        };
        return new Response(JSON.stringify(data), {
          status: 200,
          headers: {
            ...corsHeaders,
            'content-type': 'application/json'
          }
        });
      } catch (e) {
        return json({
          ok: false,
          error: String(e)
        }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/prompt/chips' && request.method === 'POST') {
      try {
        const body = await request.json();
        const inputText = String(body?.inputText || body?.text || '').trim();
        const screenContext = normalizeScreenContext(body?.screenContext || 'chat');
        const chipType = normalizeChipType(body?.chipType || 'fix_send');
        const requestedModel = String(body?.model || '').trim();
        if (!inputText) return json({
          ok: false,
          error: 'inputText required'
        }, 400, corsHeaders);

        const me = await ensureUserAndDailyCredit(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
        if (me?.wallet?.monthlyBlocked) return json({
          ok: false,
          code: 'BLOCKED',
          message: 'Unavailable'
        }, 402, corsHeaders);
        if (num(me?.wallet?.pointsBalance, 0) < cfg.minGatePoints) {
          return json({
            ok: false,
            code: 'LOW_POINTS',
            message: 'Not enough points to start request',
            wallet: me.wallet
          }, 402, corsHeaders);
        }

        const prep = analyzePromptForRewrite(inputText, cfg);
        const model = requestedModel || cfg.promptChipModel || 'google/gemini-2.5-flash-lite';
        const chipResult = await runPromptChipTransform(env, {
          model,
          inputText,
          screenContext,
          chipType,
          prep
        });
        const usdCost = num(chipResult?.usage?.cost, 0);
        const pointsCost = computePointsCost(usdCost, cfg);
        const after = await deductPointsAndUpdateStats(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, {
          provider: 'openrouter',
          category: 'prompt_chips',
          model,
          usdCost,
          pointsCost,
          predictionId: null,
          pricingSource: 'provider_returned_cost',
          pricingVersion: 'prompt-chips-openrouter-v2',
          nowMs: Date.now(),
        });

        return json({
          ok: true,
          feature: 'prompt_chips',
          uid,
          screenContext,
          chipType,
          model,
          rewriteMode: prep.rewriteMode,
          inputMetrics: {
            lineCount: prep.lineCount,
            charCount: prep.charCount,
            protectedDetected: prep.protectedDetected
          },
          originalText: inputText,
          transformedText: chipResult.transformedText,
          preview: {
            before: inputText,
            after: chipResult.transformedText
          },
          _gpmai: {
            uid,
            usdCost,
            pointsCost,
            walletAfter: {
              pointsBalance: after.pointsBalance
            }
          }
        }, 200, corsHeaders);
      } catch (e) {
        return json({
          ok: false,
          error: String(e)
        }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/media/generate' && request.method === 'POST') {
      try {
        const body = await request.json();
        const category = String(body?.category || '').trim().toLowerCase();
        const model = String(body?.model || body?.modelId || '').trim();
        const prompt = String(body?.prompt || '').trim();
        const input = body?.input && typeof body.input === 'object' ? body.input : {};
        const inputUrls = Array.isArray(body?.inputUrls) ? body.inputUrls.map((x) => String(x || '').trim()).filter(
          Boolean) : [];
        if (!['image', 'audio', 'video'].includes(category)) return json({
          ok: false,
          error: 'invalid category'
        }, 400, corsHeaders);
        if (!model) return json({
          ok: false,
          error: 'model required'
        }, 400, corsHeaders);
        if (!prompt) return json({
          ok: false,
          error: 'prompt required'
        }, 400, corsHeaders);

        const me = await ensureUserAndDailyCredit(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg);
        if (me?.wallet?.monthlyBlocked) return json({
          ok: false,
          code: 'BLOCKED',
          message: 'Unavailable'
        }, 402, corsHeaders);

        const pricing = await resolveMediaPricing(accessToken, env.FIREBASE_PROJECT_ID, model);
        if (!pricing || !pricing.isActive) return json({
          ok: false,
          error: 'model not enabled'
        }, 400, corsHeaders);
        if (pricing.category !== category) return json({
          ok: false,
          error: 'model/category mismatch'
        }, 400, corsHeaders);

        const gatePoints = gatePointsForCategory(cfg, category);
        if (num(me?.wallet?.pointsBalance, 0) < gatePoints) {
          return json({
            ok: false,
            code: 'LOW_POINTS',
            message: 'Not enough points to start request',
            requiredGatePoints: gatePoints,
            wallet: me.wallet
          }, 402, corsHeaders);
        }

        const wantsImageInput = inputUrls.length > 0 || !!input.image || !!input.input_image || !!input
          .reference_image || !!input.start_image;
        const wantsAudioInput = !!input.audio || !!input.audio_url || !!input.reference_audio || (category ===
          'video' && inputUrls.length > 1);
        const mode = String(input?.mode || body?.mode || '').trim().toLowerCase();
        if (category === 'image' && wantsAudioInput) return json({
          ok: false,
          error: 'audio input not supported for image generation'
        }, 400, corsHeaders);
        if (wantsImageInput && !(pricing.supportsImageInput || pricing.supportsEdit || pricing
          .supportsReferenceImage)) {
          return json({
            ok: false,
            error: 'selected model does not support image input',
            code: 'IMAGE_INPUT_UNSUPPORTED'
          }, 400, corsHeaders);
        }
        if (category === 'video' && wantsAudioInput && !pricing.supportsAudioInput) {
          return json({
            ok: false,
            error: 'selected video model does not support audio input',
            code: 'AUDIO_INPUT_UNSUPPORTED'
          }, 400, corsHeaders);
        }
        if (category === 'video' && mode === 'image_audio_to_video' && !(pricing.supportsImageInput && pricing
            .supportsAudioInput)) {
          return json({
            ok: false,
            error: 'selected model does not support image + audio guided video',
            code: 'MULTIMODAL_VIDEO_UNSUPPORTED'
          }, 400, corsHeaders);
        }
        if (!env.REPLICATE_API_TOKEN) return json({
          ok: false,
          error: 'replicate secret missing'
        }, 500, corsHeaders);

        const replicateInput = buildReplicateInput(category, prompt, input, inputUrls, pricing, model);
        const startRes = await fetch(`https://api.replicate.com/v1/models/${model}/predictions`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${env.REPLICATE_API_TOKEN}`,
            'Content-Type': 'application/json',
            Prefer: 'wait=5'
          },
          body: JSON.stringify({
            input: replicateInput
          }),
        });
        const startData = await startRes.json();
        if (!startRes.ok) {
          return new Response(JSON.stringify({
            ok: false,
            provider: 'replicate',
            error: startData?.detail || startData?.error || 'replicate start failed',
            raw: startData
          }), {
            status: startRes.status,
            headers: {
              ...corsHeaders,
              'content-type': 'application/json'
            }
          });
        }

        const predictionId = String(startData?.id || '');
        if (!predictionId) return json({
          ok: false,
          error: 'replicate prediction id missing'
        }, 500, corsHeaders);

        const usdCost = computeReplicateUsdCost(pricing, startData, prompt, input);
        const pointsCost = computePointsCost(usdCost, cfg);
        const after = await deductPointsAndUpdateStats(accessToken, env.FIREBASE_PROJECT_ID, uid, cfg, {
          provider: 'replicate',
          category,
          model,
          usdCost,
          pointsCost,
          predictionId,
          pricingSource: pricing.pricingSource,
          pricingVersion: pricing.pricingVersion,
          predictTime: 0,
          nowMs: Date.now(),
        });

        const status = String(startData?.status || '').toLowerCase();
        const terminal = isTerminalReplicateStatus(status);
        if (terminal && status === 'succeeded') {
          return new Response(JSON.stringify({
            ok: true,
            provider: 'replicate',
            category,
            model,
            predictionId,
            status,
            processing: false,
            output: startData?.output ?? null,
            metrics: startData?.metrics ?? null,
            _gpmai: {
              uid,
              usdCost,
              pointsCost,
              pricingSource: pricing.pricingSource,
              pricingVersion: pricing.pricingVersion,
              walletAfter: {
                pointsBalance: after.pointsBalance
              }
            }
          }), {
            status: 200,
            headers: {
              ...corsHeaders,
              'content-type': 'application/json'
            }
          });
        }
        if (terminal && status !== 'succeeded') {
          return new Response(JSON.stringify({
            ok: false,
            provider: 'replicate',
            category,
            model,
            predictionId,
            status,
            processing: false,
            error: startData?.error || 'generation failed',
            raw: startData,
            _gpmai: {
              uid,
              usdCost,
              pointsCost,
              pricingSource: pricing.pricingSource,
              pricingVersion: pricing.pricingVersion,
              walletAfter: {
                pointsBalance: after.pointsBalance
              }
            }
          }), {
            status: 502,
            headers: {
              ...corsHeaders,
              'content-type': 'application/json'
            }
          });
        }
        return new Response(JSON.stringify({
          ok: true,
          provider: 'replicate',
          category,
          model,
          predictionId,
          status: status || 'processing',
          processing: true,
          output: null,
          metrics: startData?.metrics ?? null,
          pollUrl: `/media/status?predictionId=${encodeURIComponent(predictionId)}&category=${encodeURIComponent(category)}&model=${encodeURIComponent(model)}`,
          _gpmai: {
            uid,
            usdCost,
            pointsCost,
            pricingSource: pricing.pricingSource,
            pricingVersion: pricing.pricingVersion,
            walletAfter: {
              pointsBalance: after.pointsBalance
            }
          }
        }), {
          status: 200,
          headers: {
            ...corsHeaders,
            'content-type': 'application/json'
          }
        });
      } catch (e) {
        return json({
          ok: false,
          error: String(e)
        }, 500, corsHeaders);
      }
    }

    if (url.pathname === '/media/status' && request.method === 'GET') {
      try {
        const predictionId = String(url.searchParams.get('predictionId') || '').trim();
        const category = String(url.searchParams.get('category') || '').trim().toLowerCase();
        const model = String(url.searchParams.get('model') || '').trim();
        if (!predictionId) return json({
          ok: false,
          error: 'predictionId required'
        }, 400, corsHeaders);
        if (!env.REPLICATE_API_TOKEN) return json({
          ok: false,
          error: 'replicate secret missing'
        }, 500, corsHeaders);

        const predRes = await fetch(`https://api.replicate.com/v1/predictions/${predictionId}`, {
          headers: {
            Authorization: `Bearer ${env.REPLICATE_API_TOKEN}`,
            'Content-Type': 'application/json'
          }
        });
        const predData = await predRes.json();
        if (!predRes.ok) {
          return new Response(JSON.stringify({
            ok: false,
            provider: 'replicate',
            error: predData?.detail || predData?.error || 'replicate status failed',
            raw: predData
          }), {
            status: predRes.status,
            headers: {
              ...corsHeaders,
              'content-type': 'application/json'
            }
          });
        }

        const status = String(predData?.status || '').toLowerCase();
        const terminal = isTerminalReplicateStatus(status);
        if (!terminal) return json({
          ok: true,
          provider: 'replicate',
          category: category || null,
          model: model || null,
          predictionId,
          status,
          processing: true,
          output: null,
          metrics: predData?.metrics ?? null
        }, 200, corsHeaders);
        if (status !== 'succeeded') {
          return new Response(JSON.stringify({
            ok: false,
            provider: 'replicate',
            category: category || null,
            model: model || null,
            predictionId,
            status,
            processing: false,
            error: predData?.error || 'generation failed',
            raw: predData
          }), {
            status: 502,
            headers: {
              ...corsHeaders,
              'content-type': 'application/json'
            }
          });
        }
        return json({
          ok: true,
          provider: 'replicate',
          category: category || null,
          model: model || null,
          predictionId,
          status,
          processing: false,
          output: predData?.output ?? null,
          metrics: predData?.metrics ?? null
        }, 200, corsHeaders);
      } catch (e) {
        return json({
          ok: false,
          error: String(e)
        }, 500, corsHeaders);
      }
    }

    return new Response('Not found', {
      status: 404,
      headers: corsHeaders
    });
  },
};

function json(obj, status, corsHeaders) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      ...corsHeaders,
      'content-type': 'application/json'
    }
  });
}

function withCors(resp, corsHeaders) {
  const h = new Headers(resp.headers);
  for (const [k, v] of Object.entries(corsHeaders)) h.set(k, v);
  return new Response(resp.body, {
    status: resp.status,
    headers: h
  });
}

function num(v, d) {
  const n = Number(v);
  return Number.isFinite(n) ? n : d;
}

function clampInt(raw, def, min, max) {
  const n = Number(raw);
  if (!Number.isFinite(n)) return def;
  const i = Math.floor(n);
  return Math.max(min, Math.min(max, i));
}

function isTerminalReplicateStatus(status) {
  return ['succeeded', 'failed', 'canceled'].includes(String(status || '').toLowerCase());
}

function countLines(text) {
  return text ? String(text).replace(/\r\n/g, '\n').split('\n').length : 0;
}

function normalizeScreenContext(value) {
  const v = String(value || 'chat').trim().toLowerCase();
  return ['chat', 'debate', 'canvas', 'map'].includes(v) ? v : 'chat';
}

function normalizeChipType(value) {
  const v = String(value || 'fix_send').trim().toLowerCase();
  if (v === 'make_detailed') return 'research_mode';
  return ['fix_send', 'research_mode', 'run_debate', 'canvas_section'].includes(v) ? v : 'fix_send';
}

function looksLikeCodeOrLogs(line) {
  const s = String(line || '').trim();
  if (!s) return false;
  if (/^(Exception|Error:|TypeError:|Unhandled exception|Stack trace|Traceback|Caused by:)/i.test(s)) return true;
  if (/^at\s+.+\(.+\)$/i.test(s)) return true;
  if (/^(import |from |class |const |final |var |let |function |def |public |private |SELECT |INSERT |UPDATE |DELETE )/i
    .test(s)) return true;
  if (/package:/i.test(s)) return true;
  if ((s.match(/[{};<>]/g) || []).length >= 3) return true;
  if (/=>|::|\bvoid\b|\breturn\b|\basync\b/.test(s)) return true;
  return false;
}

function countCodeLikeLines(block) {
  const lines = String(block || '').replace(/\r\n/g, '\n').split('\n');
  let nonEmpty = 0,
    codeLike = 0;
  for (const line of lines) {
    if (!String(line).trim()) continue;
    nonEmpty += 1;
    if (looksLikeCodeOrLogs(line)) codeLike += 1;
  }
  return {
    nonEmpty,
    codeLike,
    ratio: nonEmpty ? codeLike / nonEmpty : 0
  };
}

function isLikelyRequestText(text) {
  const s = String(text || '').trim().toLowerCase();
  return !!s &&
    /(\bplease\b|\bi need\b|\bi want\b|\bcan you\b|\bhelp\b|\bfix\b|\bexplain\b|\bimprove\b|\brewrite\b|\bmake\b|\bdetailed\b|\banalyze\b|\breview\b|\bcompare\b|\bstructure\b|\bpacing\b|\bclarity\b|\bsummary\b|\bstory\b|\bcode\b|\blog\b|\berror\b|\bissue\b|\bbug\b|\bquestion\b|\bhow\b|\bwhat\b|\bwhy\b|\bshould\b|\bbest\b|\bdont\b|\bdo not\b|\bwithout\b|\bkeep\b|\bpreserve\b)/
    .test(s);
}

function normalizeChunkSeparators(text) {
  return String(text || '').replace(/\r\n/g, '\n');
}

function buildSmartPatchSegments(inputText) {
  const text = normalizeChunkSeparators(inputText);
  const segments = [];
  const codeFenceRe = /```[\s\S]*?```/g;
  let last = 0,
    match;
  while ((match = codeFenceRe.exec(text)) !== null) {
    const before = text.slice(last, match.index);
    pushNonCodeSegments(before, segments);
    segments.push({
      id: `seg_${segments.length + 1}`,
      kind: 'preserve',
      raw: match[0],
      reason: 'code_fence'
    });
    last = codeFenceRe.lastIndex;
  }
  pushNonCodeSegments(text.slice(last), segments);
  let rewriteCount = segments.filter((s) => s.kind === 'rewrite').length;
  if (!rewriteCount) {
    const firstTextIdx = segments.findIndex((s) => s.kind === 'preserve' && s.reason === 'natural_text');
    if (firstTextIdx >= 0) {
      segments[firstTextIdx].kind = 'rewrite';
      segments[firstTextIdx].reason = 'fallback_text';
      rewriteCount += 1;
    }
  }
  if (!rewriteCount && segments.length) {
    const idx = segments.findIndex((s) => s.raw && String(s.raw).trim());
    if (idx >= 0) {
      segments[idx].kind = 'rewrite';
      segments[idx].reason = 'fallback_any';
    }
  }
  return segments;
}

function pushNonCodeSegments(block, segments) {
  if (!block) return;
  const parts = normalizeChunkSeparators(block).split(/(\n\s*\n+)/);
  for (const part of parts) {
    if (!part) continue;
    if (/^\n\s*\n+$/.test(part)) {
      segments.push({
        id: `seg_${segments.length + 1}`,
        kind: 'preserve',
        raw: part,
        reason: 'separator'
      });
      continue;
    }
    const metrics = countCodeLikeLines(part);
    const trimmed = String(part).trim();
    if (!trimmed) {
      segments.push({
        id: `seg_${segments.length + 1}`,
        kind: 'preserve',
        raw: part,
        reason: 'separator'
      });
      continue;
    }
    const isMostlyCodeLike = metrics.ratio >= 0.6 || (metrics.nonEmpty >= 3 && metrics.codeLike >= 2 && metrics.ratio >=
      0.35);
    const isMixed = !isMostlyCodeLike && metrics.codeLike > 0 && metrics.ratio >= 0.18;
    if (isMostlyCodeLike) {
      segments.push({
        id: `seg_${segments.length + 1}`,
        kind: 'preserve',
        raw: part,
        reason: 'code_or_logs'
      });
      continue;
    }
    if (isMixed) {
      pushMixedLineSegments(part, segments);
      continue;
    }
    const natural = classifyNaturalSegment(part);
    segments.push({
      id: `seg_${segments.length + 1}`,
      kind: natural.kind,
      raw: part,
      reason: natural.reason
    });
  }
}

function pushMixedLineSegments(block, segments) {
  const lines = String(block || '').match(/.*(?:\n|$)/g) || [];
  let current = '',
    currentType = null;
  const flush = () => {
    if (!current) return;
    if (currentType === 'code') segments.push({
      id: `seg_${segments.length + 1}`,
      kind: 'preserve',
      raw: current,
      reason: 'code_or_logs'
    });
    else {
      const natural = classifyNaturalSegment(current);
      segments.push({
        id: `seg_${segments.length + 1}`,
        kind: natural.kind,
        raw: current,
        reason: natural.reason
      });
    }
    current = '';
    currentType = null;
  };
  for (const line of lines) {
    if (!line) continue;
    const stripped = line.replace(/\n$/, '');
    const trimmed = stripped.trim();
    let type;
    if (!trimmed) type = 'blank';
    else type = looksLikeCodeOrLogs(stripped) ? 'code' : 'text';
    if (type === 'blank') {
      flush();
      segments.push({
        id: `seg_${segments.length + 1}`,
        kind: 'preserve',
        raw: line,
        reason: 'separator'
      });
      continue;
    }
    if (currentType && currentType !== type) flush();
    currentType = type;
    current += line;
  }
  flush();
}

function classifyNaturalSegment(text) {
  const trimmed = String(text || '').trim();
  const metrics = countCodeLikeLines(text);
  const charCount = trimmed.length;
  const isBulletLike = /^(?:[-*â€¢]|\d+[.)])\s/m.test(trimmed);
  const requestLike = isLikelyRequestText(trimmed);
  const extremelyLong = charCount > 3500 || metrics.nonEmpty > 45;
  return {
    kind: (requestLike || isBulletLike || !extremelyLong) ? 'rewrite' : 'preserve',
    reason: (requestLike || isBulletLike || !extremelyLong) ? 'rewrite_text' : 'natural_text'
  };
}

function analyzePromptForRewrite(inputText, cfg) {
  const text = normalizeChunkSeparators(inputText);
  const lineCount = countLines(text),
    charCount = text.length;
  const hardLineLimit = num(cfg.promptHardMaxLines, 150),
    hardCharLimit = num(cfg.promptHardMaxChars, 10000);
  const mediumLineLimit = num(cfg.promptMediumMaxLines, 80),
    mediumCharLimit = num(cfg.promptMediumMaxChars, 5000);
  const isLarge = lineCount > mediumLineLimit || charCount > mediumCharLimit;
  const forceSafe = lineCount > hardLineLimit || charCount > hardCharLimit;
  if (!isLarge) return {
    rewriteMode: 'rewrite_all',
    lineCount,
    charCount,
    protectedDetected: false,
    explanationText: text,
    untouchedTail: '',
    forceSafe,
    sourceSections: [],
    segments: []
  };
  const segments = buildSmartPatchSegments(text);
  const protectedDetected = segments.some((s) => s.reason === 'code_fence' || s.reason === 'code_or_logs');
  const rewriteSegments = segments.filter((s) => s.kind === 'rewrite');
  return {
    rewriteMode: 'smart_patch',
    lineCount,
    charCount,
    protectedDetected,
    explanationText: rewriteSegments.map((s) => s.raw).join('\n\n').trim() || fallbackExplanationText(text),
    untouchedTail: '',
    forceSafe,
    sourceSections: segments.map((s) => s.reason),
    segments
  };
}

function fallbackExplanationText(text) {
  const clean = String(text || '').trim();
  return clean ? clean.slice(0, 2500).trim() : 'Improve this prompt while preserving the user intent.';
}

function chipLabelForContext(screenContext, chipType) {
  const map = {
    fix_send: 'Fix and Send',
    research_mode: 'Make It Detailed',
    run_debate: 'Run as Debate',
    canvas_section: 'Add to Canvas Section'
  };
  return map[chipType] || 'Fix and Send';
}

function buildPromptChipInstruction(screenContext, chipType) {
  const label = chipLabelForContext(screenContext, chipType);
  if (chipType === 'research_mode')
  return `You are handling the "${label}" chip for the ${screenContext} screen. Make the user prompt more complete, specific, and useful while preserving the original intent. Expand naturally when the prompt is short or vague, but do not become robotic or add filler.`;
  if (chipType === 'run_debate')
  return `You are handling the "${label}" chip for the ${screenContext} screen. Rewrite the user input into a sharper debate-ready request while preserving topic, stance, and constraints.`;
  if (chipType === 'canvas_section')
  return `You are handling the "${label}" chip for the ${screenContext} screen. Rewrite the user input into a clearer Research Canvas section request with clean structure and preserved meaning.`;
  return `You are handling the "${label}" chip for the ${screenContext} screen. Clean grammar, improve clarity, fix obvious mistakes, and keep the same meaning and important constraints.`;
}

function buildPromptChipSystemPrompt({
  chipType,
  strict = false,
  jsonMode = false
}) {
  const lines = [jsonMode ? 'You are a prompt-section transformer for an app called GPMai.' :
    'You are a prompt transformer for an app called GPMai.',
    'Your job is to transform the user\'s prompt text, not answer the underlying request.',
    'Preserve meaning, constraints, code, logs, stack traces, and raw pasted content unless a section is clearly natural-language prompt text.',
    'Never mention chips, system prompts, rules, JSON, or that you are rewriting.',
    'Never add lead-ins like "Sure", "Here is", "Improved prompt", or explanations.', 'Never ask follow-up questions.'
  ];
  lines.push(chipType === 'research_mode' ?
    'When helpful, make the prompt more complete and specific, but stay natural and avoid filler.' :
    'Keep the rewrite concise, clean, and ready to send.');
  if (strict) {
    lines.push(
      'If any output looks like an assistant answer, instruction text, or meta commentary, that output is invalid.');
    lines.push('Keep raw technical content verbatim unless the task is to improve the surrounding explanation.');
  }
  lines.push(jsonMode ? 'Return strict JSON only. No markdown fences. No prose.' : 'Return plain text only.');
  return lines.join(' ');
}

function buildPromptChipUserPrompt({
  instruction,
  chipType,
  inputText,
  strict = false
}) {
  const goals = chipType === 'research_mode' ? [
    'Transform the user\'s prompt into a clearer, more complete, and more useful version.',
    'Expand naturally when that improves the request.'
  ] : ['Transform the user\'s prompt into a cleaner, corrected, and ready-to-send version.',
    'Keep the same meaning and important constraints.'
  ];
  const strictBits = strict ? ['Do not answer the task.', 'Do not mention these instructions.',
    'Do not add labels, prefaces, or explanations.',
    'If the prompt contains code, logs, stack traces, or quoted raw text, keep them verbatim.'
  ] : ['Do not answer the task.', 'Return only the transformed final prompt text.'];
  return [instruction, '', ...goals, ...strictBits, '', '<user_prompt>', inputText, '</user_prompt>'].join('\n');
}

function buildPromptChipPatchUserPrompt({
  instruction,
  chipType,
  prep,
  strict = false
}) {
  const goals = chipType === 'research_mode' ? ['Rewrite only the provided prompt sections.',
    'Make them more complete, specific, and useful while preserving meaning.',
    'Improve explanation/request sections clearly when they are weak or vague.'
  ] : ['Rewrite only the provided prompt sections.', 'Clean grammar, improve clarity, and keep the same meaning.',
    'Sharpen request/explanation sections instead of doing only tiny cleanup when improvement is needed.'
  ];
  const strictBits = strict ? ['Do not answer the task.', 'Do not mention these instructions.',
    'Do not add any ids that were not provided.',
    'Each rewritten text must contain only the final rewritten prompt section.'
  ] : ['Do not add filler or unrelated content.'];
  return [instruction, '', ...goals, ...strictBits, prep.forceSafe ?
    'The original prompt is very large, so keep rewrites efficient and focused.' : '', '',
    'Return ONLY valid JSON with this exact shape: {"rewritten":[{"id":"seg_1","text":"..."}]}',
    'Do not include markdown fences.', '', ...((prep.segments || []).filter((seg) => seg.kind === 'rewrite' && String(
      seg.raw || '').trim()).flatMap((seg) => [`[${seg.id}]`, String(seg.raw || '').trim(), `[/${seg.id}]`, '']))
  ].filter(Boolean).join('\n');
}

function stripMarkdownFences(text) {
  let s = String(text || '').trim();
  if (/^```/.test(s) && /```$/.test(s)) {
    s = s.replace(/^```[a-zA-Z0-9_-]*\n?/, '');
    s = s.replace(/\n?```$/, '');
  }
  return s.trim();
}

function stripPromptChipLeadIn(text) {
  let s = String(text || '').trim();
  const startPatterns = [/^(?:sure|certainly|absolutely|okay|ok)[,!\.\s-]+/i,
    /^(?:here(?:'|â€™)s|here is)\s+(?:the\s+)?(?:improved|rewritten|cleaned|updated|final)\s+(?:prompt|version|text)[:\s-]*/i,
    /^(?:improved|rewritten|cleaned|updated|final)\s+(?:prompt|version|text)[:\s-]*/i,
    /^(?:for\s+the\s+.+?\s+chip[:\s-]*)/i
  ];
  let changed = true;
  while (changed) {
    changed = false;
    for (const re of startPatterns) {
      const next = s.replace(re, '').trimStart();
      if (next !== s) {
        s = next;
        changed = true;
      }
    }
  }
  const lines = s.split('\n');
  while (lines.length > 1 &&
    /^(?:return only|do not include|valid json|you are handling|you improve user prompts|rewrite only|transform only)/i
    .test(lines[0].trim())) lines.shift();
  return lines.join('\n').trim();
}

function sanitizePromptChipText(rawText) {
  let text = stripMarkdownFences(rawText);
  text = stripPromptChipLeadIn(text);
  text = text.replace(/^\s*"([\s\S]*)"\s*$/, '$1').trim();
  return text.replace(/\n{3,}/g, '\n\n').trim();
}

function normalizeComparableText(text) {
  return String(text || '').toLowerCase().replace(/```[\s\S]*?```/g, ' CODEBLOCK ').replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ').trim();
}

function containsPromptChipLeak(text) {
  const s = String(text || '').toLowerCase();
  return [/please rewrite the following prompt/, /return only the improved final prompt/, /return only valid json/,
    /you are handling the/, /you improve user prompts/, /rewrite only the provided prompt sections/,
    /do not include markdown fences/, /this exact shape/, /for the .* chip/, /prompt transformer/, /system prompt/
  ].some((re) => re.test(s));
}

function looksLikeAssistantAnswer(text) {
  const first = String(text || '').trim().split(/\n+/)[0] || '';
  return !!first && ([/^sure\b/, /^certainly\b/, /^absolutely\b/, /^here(?:'|â€™)s\b/, /^here is\b/, /^i can\b/, /^i'd\b/,
    /^let(?:'|â€™)s\b/, /^please provide\b/, /^please share\b/, /^could you\b/, /^can you share\b/,
    /^thanks for sharing\b/, /^the issue is\b/, /^to fix this\b/, /^this means\b/
  ].some((re) => re.test(first.toLowerCase())) || /^(?:question|answer|response)[:\s-]/i.test(first));
}

function looksLikeJsonMeta(text) {
  return /^\s*[\[{]/.test(String(text || '').trim());
}

function isSameMeaningShape(originalText, candidateText) {
  const a = normalizeComparableText(originalText),
    b = normalizeComparableText(candidateText);
  return !!a && a === b;
}

function validatePromptChipCandidate(originalText, candidateText, {
  allowJson = false
} = {}) {
  const sanitized = sanitizePromptChipText(candidateText);
  if (!sanitized) return {
    ok: false,
    reason: 'empty',
    text: ''
  };
  if (!allowJson && looksLikeJsonMeta(sanitized)) return {
    ok: false,
    reason: 'json_meta',
    text: sanitized
  };
  if (containsPromptChipLeak(sanitized)) return {
    ok: false,
    reason: 'instruction_leak',
    text: sanitized
  };
  if (looksLikeAssistantAnswer(sanitized)) return {
    ok: false,
    reason: 'assistant_answer',
    text: sanitized
  };
  if (originalText && sanitized.length < 4 && String(originalText).trim().length > 12) return {
    ok: false,
    reason: 'too_short',
    text: sanitized
  };
  return {
    ok: true,
    reason: 'ok',
    text: sanitized
  };
}

function normalizeRewrittenTextAgainstOriginal(originalText, rewrittenText) {
  const validated = validatePromptChipCandidate(originalText, rewrittenText);
  return validated.ok ? validated.text : null;
}

function mergePromptChipSegments(segments, rewrittenMap) {
  return (segments || []).map((seg) => seg.kind === 'rewrite' ? (rewrittenMap.get(seg.id) ?? seg.raw) : seg.raw).join(
    '');
}

function minimalPromptChipFallback(inputText) {
  const normalized = normalizeChunkSeparators(inputText).trim();
  if (!normalized) return '';
  if (!normalized.includes('\n')) {
    const compact = normalized.replace(/\s+/g, ' ').trim();
    const first = compact.charAt(0).toUpperCase() + compact.slice(1);
    return /[.!?]$/.test(first) ? first : `${first}.`;
  }
  return normalized;
}
async function runPromptChipTransform(env, {
  model,
  inputText,
  screenContext,
  chipType,
  prep
}) {
  const instruction = buildPromptChipInstruction(screenContext, chipType);
  if (prep.rewriteMode !== 'smart_patch') {
    const attempts = [false, true];
    let lastGood = null,
      lastUsage = null,
      lastRaw = null;
    for (const strict of attempts) {
      const data = await callOpenRouterChat(env, {
        model,
        messages: [{
          role: 'system',
          content: buildPromptChipSystemPrompt({
            chipType,
            strict,
            jsonMode: false
          })
        }, {
          role: 'user',
          content: buildPromptChipUserPrompt({
            instruction,
            chipType,
            inputText,
            strict
          })
        }],
        temperature: chipType === 'research_mode' ? (strict ? 0.35 : 0.5) : (strict ? 0.2 : 0.3),
        max_tokens: 1000
      });
      lastUsage = data?.usage || lastUsage;
      lastRaw = data;
      const candidate = String(data?.choices?.[0]?.message?.content || '').trim();
      const validated = validatePromptChipCandidate(inputText, candidate);
      if (!validated.ok) continue;
      lastGood = validated.text;
      if (chipType === 'research_mode' || !isSameMeaningShape(inputText, lastGood)) return {
        transformedText: lastGood,
        usage: lastUsage,
        raw: lastRaw
      };
    }
    const fallback = lastGood || minimalPromptChipFallback(inputText);
    if (!fallback) throw new Error('prompt chip model returned empty text');
    return {
      transformedText: fallback,
      usage: lastUsage,
      raw: lastRaw
    };
  }
  const rewriteSegments = (prep.segments || []).filter((s) => s.kind === 'rewrite' && String(s.raw || '').trim());
  if (!rewriteSegments.length) return {
    transformedText: inputText,
    usage: {
      cost: 0
    },
    raw: null
  };
  const attempts = [false, true];
  let bestMap = new Map(),
    lastUsage = null,
    lastRaw = null;
  for (const strict of attempts) {
    const data = await callOpenRouterChat(env, {
      model,
      messages: [{
        role: 'system',
        content: buildPromptChipSystemPrompt({
          chipType,
          strict,
          jsonMode: true
        })
      }, {
        role: 'user',
        content: buildPromptChipPatchUserPrompt({
          instruction,
          chipType,
          prep,
          strict
        })
      }],
      temperature: chipType === 'research_mode' ? (strict ? 0.28 : 0.45) : (strict ? 0.18 : 0.28),
      max_tokens: 1800
    });
    lastUsage = data?.usage || lastUsage;
    lastRaw = data;
    const parsed = safeParseJsonObject(String(data?.choices?.[0]?.message?.content || '').trim());
    const rewrittenMap = normalizeRewrittenSegmentMap(parsed?.rewritten || [], rewriteSegments);
    if (!rewrittenMap.size) continue;
    bestMap = rewrittenMap;
    const merged = mergePromptChipSegments(prep.segments || [], rewrittenMap);
    const validatedMerged = validatePromptChipCandidate(inputText, merged);
    if (!validatedMerged.ok) continue;
    if (chipType === 'research_mode' || !isSameMeaningShape(inputText, validatedMerged.text)) return {
      transformedText: validatedMerged.text,
      usage: lastUsage,
      raw: lastRaw
    };
  }
  const mergedFallback = bestMap.size ? mergePromptChipSegments(prep.segments || [], bestMap) : inputText;
  const validatedFallback = validatePromptChipCandidate(inputText, mergedFallback);
  if (!validatedFallback.ok) throw new Error('prompt chip smart patch returned invalid text');
  return {
    transformedText: validatedFallback.text,
    usage: lastUsage,
    raw: lastRaw
  };
}

function safeParseJsonObject(rawText) {
  const stripped = stripMarkdownFences(rawText);
  if (!stripped) return null;
  try {
    return JSON.parse(stripped);
  } catch {}
  const start = stripped.indexOf('{'),
    end = stripped.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) return null;
  try {
    return JSON.parse(stripped.slice(start, end + 1));
  } catch {
    return null;
  }
}

function normalizeRewrittenSegmentMap(items, rewriteSegments = []) {
  const map = new Map(),
    allowed = new Map((rewriteSegments || []).map((seg) => [seg.id, seg.raw]));
  for (const item of Array.isArray(items) ? items : []) {
    const id = String(item?.id || '').trim();
    if (!id || !allowed.has(id)) continue;
    const text = normalizeRewrittenTextAgainstOriginal(allowed.get(id), item.text || '');
    if (text) map.set(id, text);
  }
  return map;
}
async function callOpenRouterChat(env, payload) {
  const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://gpmai.app',
      'X-Title': 'GPMai'
    },
    body: JSON.stringify(payload)
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data?.error?.message || data?.error || data?.detail ||
    `OpenRouter failed (${res.status})`);
  return data;
}

// ===== GPMAI CORE LEARNING ENGINE INJECTION (two-pass + triage + embeddings) =====
// This block is the locked Option 3 production engine:
//   - Real semantic layer (OpenAI text-embedding-3-small)
//   - Three-tier triage (A hard pre-escalate, B medium, C confidence fallback)
//   - Pass 1 structural writes + Pass 2 async narrative via Cloudflare Queues
//   - Backend recheck layer + idempotency + slice collection + rollup
// See `_core_engine_module.js` for the untouched source.

// ============================================================================
// GPMai CORE LEARNING ENGINE â€” Two-Pass Async + Three-Tier Triage + Embeddings
// ============================================================================
// This block implements the locked architecture:
//   - Pass 1 (structural truth, blocking): reinforce / candidate / durable / reject
//     + event hints + backend rechecks + slice write + checkpoint advance.
//   - Pass 2 (narrative, queue-based async): slice summary + node summary refresh
//     + rollup compression. Failure is survivable because Pass 1 already persisted
//     structural truth.
//   - Triage router:
//       Tier A (hard pre-escalate â†’ strong model):
//         correction cues, contradictions with existing state, very large slices,
//         high action density, embedding-detected buried off-topic, 3+ competing
//         concepts, Life Fast Lane signals.
//       Tier B (default â†’ medium model).
//       Tier C (confidence fallback â†’ strong model):
//         triggered by medium model's self-reported low confidence / ambiguity /
//         competing concepts / explicit escalation request.
//   - Real semantic layer via OpenAI text-embedding-3-small:
//       node shortlist, off-topic sentence detection, competing-concept count.
//       No heuristic substitution as the main semantic path.
//   - Idempotency: SHA-256 over (uid + sessionId + slice signature + assistant sig)
//     checked before Pass 1; short TTL doc in memoryExtractionIdempotency.
//   - Slice collection (NEW): memoryNodeSlices, rollup every 10 â†’ 1 compressed.
// ============================================================================

const MEMORY_EMBEDDING_MODEL_DEFAULT = 'text-embedding-3-small';
const MEMORY_EMBEDDING_DIM_DEFAULT = 1536;
const MEMORY_EMBEDDING_OFFTOPIC_SIM = 0.72;
const MEMORY_EMBEDDING_SHORTLIST_SIM_FLOOR = 0.30;
const MEMORY_EMBEDDING_COMPETING_SIM = 0.55;
const MEMORY_EMBEDDING_SHORTLIST_TOP_N = 8;
const MEMORY_TRIAGE_LARGE_SLICE_CHARS = 1500;
const MEMORY_TRIAGE_ACTION_DENSITY_LIMIT = 3;
const MEMORY_TRIAGE_COMPETING_CONCEPTS_LIMIT = 3;
const MEMORY_SLICE_ROLLUP_EVERY = 10;
const MEMORY_SLICE_PER_NODE_LIVE_CAP = 50;
const MEMORY_SLICE_PREVIEW_CHARS = 260;
const MEMORY_IDEMPOTENCY_TTL_MS = 30 * 60 * 1000;
const MEMORY_PASS2_QUEUE_BINDING = 'MEMORY_PASS2_QUEUE';
// ARCH Â§11 â€” Session learning lock TTL. Holder gets this much wall time before another
// job may steal an expired lock. Tuned for typical Pass 1 latency (~5-30s) plus headroom.
const MEMORY_LEARNING_LOCK_TTL_MS = 60 * 1000;
const MEMORY_LEARNING_LOCK_MAX_ACQUIRE_RETRIES = 2;
// ARCH Â§3.1, Â§6, Â§8, Â§14 â€” Phase B: matching / gates / candidate evidence / correction.
const MEMORY_HOT_SHORTLIST_CAP = 50;
const MEMORY_HOT_SHORTLIST_CAND_CAP = 30;
const MEMORY_HOT_SHORTLIST_CONN_CAP = 80;
const MEMORY_FOURLAYER_RRF_K = 60;
const MEMORY_CANDIDATE_EVIDENCE_CAP = 6;
const MEMORY_EVENT_DEDUP_WINDOW_MS = 24 * 60 * 60 * 1000;
const MEMORY_CORRECTION_TOMBSTONE_AGE_MS = 24 * 60 * 60 * 1000;
// ARCH Â§9, Â§10 â€” Phase C: write order / checkpoint safety / Pass 2 hardening.
// Importance-weighted rollup thresholds (Â§10): trigger when count >= 10 OR weight >= threshold.
const MEMORY_SLICE_ROLLUP_WEIGHT_THRESHOLD = 18;
// Per-failure-class messages we use in checkpoint_blocked / failed_step debug emissions.
const MEMORY_REQUIRED_WRITE_LABELS = Object.freeze({
  CANDIDATE_OR_NODE: 'candidate_or_node',
  SLICE: 'slice',
  EVENT: 'event'
});

// ---------------------------------------------------------------------------
// SECTION A â€” OpenAI embedding client + cosine + hash
// ---------------------------------------------------------------------------

async function callOpenAIEmbedding(env, texts, model = MEMORY_EMBEDDING_MODEL_DEFAULT) {
  if (!env?.OPENAI_API_KEY) {
    throw new Error('OPENAI_API_KEY missing â€” embeddings require the OpenAI secret to be bound on the worker.');
  }
  const input = Array.isArray(texts) ? texts.filter((t) => typeof t === 'string' && t.trim().length > 0) : [];
  if (!input.length) return [];
  // OpenAI accepts a string or array. Batch up to 96 inputs per call for headroom.
  const BATCH = 64;
  const out = [];
  for (let i = 0; i < input.length; i += BATCH) {
    const chunk = input.slice(i, i + BATCH);
    const res = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ model, input: chunk, encoding_format: 'float' })
    });
    const data = await res.json().catch(() => null);
    if (!res.ok) {
      const msg = data?.error?.message || data?.error || `openai_embedding_failed_${res.status}`;
      throw new Error(`OpenAI embedding call failed: ${msg}`);
    }
    const items = Array.isArray(data?.data) ? data.data : [];
    for (const item of items) {
      if (Array.isArray(item?.embedding)) out.push(item.embedding);
      else out.push(null);
    }
  }
  return out;
}

function memoryProdCosineSimilarity(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b) || a.length === 0 || a.length !== b.length) return 0;
  let dot = 0;
  let na = 0;
  let nb = 0;
  for (let i = 0; i < a.length; i++) {
    const x = a[i];
    const y = b[i];
    dot += x * y;
    na += x * x;
    nb += y * y;
  }
  if (na === 0 || nb === 0) return 0;
  return dot / (Math.sqrt(na) * Math.sqrt(nb));
}

async function memoryProdHashText(text) {
  const buf = new TextEncoder().encode(String(text || ''));
  const digest = await crypto.subtle.digest('SHA-256', buf);
  const bytes = new Uint8Array(digest);
  let hex = '';
  for (let i = 0; i < bytes.length; i++) hex += bytes[i].toString(16).padStart(2, '0');
  return hex;
}

// ---------------------------------------------------------------------------
// SECTION B â€” Node-embedding store (users/{uid}/memoryNodeEmbeddings/{nodeId})
// ---------------------------------------------------------------------------

async function memoryProdFetchNodeEmbeddingDoc(accessToken, projectId, uid, nodeId) {
  const safeId = String(nodeId || '').replace(/[^a-zA-Z0-9_:-]/g, '_');
  if (!safeId) return null;
  const raw = await fsGetDoc(accessToken, projectId, `users/${uid}/memoryNodeEmbeddings/${safeId}`).catch(() => null);
  if (!raw?.fields) return null;
  const parsed = parseFirestoreFields(raw.fields) || {};
  return {
    nodeId: parsed.nodeId || safeId,
    labelSnapshot: parsed.labelSnapshot || '',
    summarySnapshot: parsed.summarySnapshot || '',
    textHash: parsed.textHash || '',
    model: parsed.model || '',
    dim: num(parsed.dim, 0),
    embedding: Array.isArray(parsed.embedding) ? parsed.embedding : [],
    updatedAt: num(parsed.updatedAt, 0)
  };
}

async function memoryProdWriteNodeEmbeddingDoc(accessToken, projectId, uid, nodeId, record) {
  const safeId = String(nodeId || '').replace(/[^a-zA-Z0-9_:-]/g, '_');
  if (!safeId) return;
  await fsCreateOrPatchDoc(accessToken, projectId, `users/${uid}/memoryNodeEmbeddings/${safeId}`, {
    nodeId: safeId,
    labelSnapshot: trimMemoryText(record?.labelSnapshot || '', 160),
    summarySnapshot: trimMemoryText(record?.summarySnapshot || '', 400),
    textHash: trimMemoryText(record?.textHash || '', 80),
    model: trimMemoryText(record?.model || MEMORY_EMBEDDING_MODEL_DEFAULT, 80),
    dim: num(record?.dim, Array.isArray(record?.embedding) ? record.embedding.length : 0),
    embedding: Array.isArray(record?.embedding) ? record.embedding : [],
    updatedAt: Date.now(),
    schemaVersion: MEMORY_SCHEMA_VERSION
  }).catch(() => null);
}

function memoryProdBuildNodeEmbeddingText(node) {
  const label = trimMemoryText(node?.label || '', 120);
  const aliases = Array.isArray(node?.aliases) ? node.aliases.filter(Boolean).slice(0, 8).join(', ') : '';
  const summary = trimMemoryText(node?.info || '', 400);
  return `${label}\n${aliases}\n${summary}`.trim();
}

async function memoryProdEnsureNodeEmbeddings(env, accessToken, projectId, uid, nodes, cfg) {
  const model = String(cfg?.memoryEmbeddingModel || MEMORY_EMBEDDING_MODEL_DEFAULT);
  const safeNodes = (Array.isArray(nodes) ? nodes : []).filter((n) => n && !n.deleted && !n.isRoot && n.id);
  if (!safeNodes.length) return new Map();
  // Load existing embedding docs in parallel.
  const existingDocs = await Promise.all(safeNodes.map((n) => memoryProdFetchNodeEmbeddingDoc(accessToken, projectId, uid, n.id)));
  const embeddingMap = new Map();
  const toCompute = [];
  for (let i = 0; i < safeNodes.length; i++) {
    const node = safeNodes[i];
    const doc = existingDocs[i];
    const desiredText = memoryProdBuildNodeEmbeddingText(node);
    const desiredHash = await memoryProdHashText(`${model}::${desiredText}`);
    const stale = !doc || !Array.isArray(doc.embedding) || !doc.embedding.length || doc.textHash !== desiredHash || doc.model !== model;
    if (!stale) {
      embeddingMap.set(node.id, { nodeId: node.id, embedding: doc.embedding, dim: doc.dim, model: doc.model });
    } else {
      toCompute.push({ node, desiredText, desiredHash });
    }
  }
  if (toCompute.length) {
    try {
      const vectors = await callOpenAIEmbedding(env, toCompute.map((x) => x.desiredText), model);
      for (let i = 0; i < toCompute.length; i++) {
        const { node, desiredText, desiredHash } = toCompute[i];
        const emb = vectors[i];
        if (!Array.isArray(emb) || !emb.length) continue;
        embeddingMap.set(node.id, { nodeId: node.id, embedding: emb, dim: emb.length, model });
        await memoryProdWriteNodeEmbeddingDoc(accessToken, projectId, uid, node.id, {
          labelSnapshot: trimMemoryText(node.label || '', 160),
          summarySnapshot: trimMemoryText(node.info || '', 400),
          textHash: desiredHash,
          model,
          dim: emb.length,
          embedding: emb
        });
      }
    } catch (err) {
      // Embedding failure must not kill learning; downgrade to whatever embeddings we already have.
      // The triage layer will treat this as "semantic unavailable" and rely on heuristic fallbacks
      // only for hard-escalation detection, never as the primary semantic decision layer.
      console.log(`[memory_embedding_error] ${String(err?.message || err)}`);
    }
  }
  return embeddingMap;
}

// ---------------------------------------------------------------------------
// SECTION C â€” Semantic shortlist (real embeddings)
// ---------------------------------------------------------------------------

async function memoryProdSemanticShortlistNodes(env, accessToken, projectId, uid, cfg, userText, bridgeText, nodes, topN = MEMORY_EMBEDDING_SHORTLIST_TOP_N) {
  const safeNodes = (Array.isArray(nodes) ? nodes : []).filter((n) => n && !n.deleted && !n.isRoot && n.id);
  if (!safeNodes.length) return { items: [], sliceEmbedding: null, embeddingMap: new Map(), available: false };
  const sliceText = `${userText || ''}\n${bridgeText || ''}`.trim();
  if (!sliceText) return { items: [], sliceEmbedding: null, embeddingMap: new Map(), available: false };
  const model = String(cfg?.memoryEmbeddingModel || MEMORY_EMBEDDING_MODEL_DEFAULT);
  const embeddingMap = await memoryProdEnsureNodeEmbeddings(env, accessToken, projectId, uid, safeNodes, cfg);
  let sliceEmbedding = null;
  try {
    const vectors = await callOpenAIEmbedding(env, [sliceText], model);
    sliceEmbedding = Array.isArray(vectors) && Array.isArray(vectors[0]) ? vectors[0] : null;
  } catch (err) {
    console.log(`[memory_slice_embedding_error] ${String(err?.message || err)}`);
    sliceEmbedding = null;
  }
  if (!sliceEmbedding) {
    // Semantic path unavailable this turn. Return empty shortlist so the heuristic
    // fallback used by the packet builder remains the only signal â€” the architecture
    // does not silently pretend it has semantic coverage when it does not.
    return { items: [], sliceEmbedding: null, embeddingMap, available: false };
  }
  const scored = [];
  for (const node of safeNodes) {
    const rec = embeddingMap.get(node.id);
    if (!rec || !Array.isArray(rec.embedding) || !rec.embedding.length) continue;
    const sim = memoryProdCosineSimilarity(sliceEmbedding, rec.embedding);
    if (sim < MEMORY_EMBEDDING_SHORTLIST_SIM_FLOOR) continue;
    scored.push({ node, sim });
  }
  scored.sort((a, b) => b.sim - a.sim);
  const limit = Math.max(1, Math.min(12, topN));
  const items = scored.slice(0, limit).map(({ node, sim }) => ({
    id: trimMemoryText(node.id || '', 160),
    label: trimMemoryText(node.label || '', 80),
    aliases: boundedUniqueIds(Array.isArray(node.aliases) ? node.aliases : [], 6),
    group: trimMemoryText(node.group || '', 40),
    clusterId: trimMemoryText(node.clusterId || '', 40),
    currentState: trimMemoryText(node.currentState || '', 24),
    importanceClass: trimMemoryText(node.importanceClass || '', 40),
    summary: trimMemoryText(node.info || '', 180),
    semanticScore: Number(sim.toFixed(4))
  }));
  return { items, sliceEmbedding, embeddingMap, available: true };
}

// ---------------------------------------------------------------------------
// SECTION D â€” Sentence splitter + buried off-topic detection
// ---------------------------------------------------------------------------

function memoryProdSplitIntoSentences(text) {
  const raw = String(text || '').trim();
  if (!raw) return [];
  // Conservative sentence splitter: splits on .!? followed by space/newline, preserves numerals.
  const parts = raw
    .replace(/\s+/g, ' ')
    .split(/(?<=[.!?])\s+(?=[A-Z0-9"'])/g)
    .map((s) => s.trim())
    .filter((s) => s.length >= 12);
  return parts.slice(0, 16);
}

async function memoryProdDetectOffTopicSentences(env, accessToken, projectId, uid, cfg, sentences, nodes, embeddingMap) {
  if (!Array.isArray(sentences) || sentences.length < 2) return [];
  const safeNodes = (Array.isArray(nodes) ? nodes : []).filter((n) => n && !n.deleted && !n.isRoot && n.id);
  if (!safeNodes.length) return [];
  const model = String(cfg?.memoryEmbeddingModel || MEMORY_EMBEDDING_MODEL_DEFAULT);
  let sentenceVectors = [];
  try {
    sentenceVectors = await callOpenAIEmbedding(env, sentences, model);
  } catch (err) {
    console.log(`[memory_sentence_embedding_error] ${String(err?.message || err)}`);
    return [];
  }
  if (!Array.isArray(sentenceVectors) || !sentenceVectors.length) return [];
  // For each sentence, find the best-matching node across the full graph.
  const perSentenceTop = [];
  for (let i = 0; i < sentences.length; i++) {
    const sv = sentenceVectors[i];
    if (!Array.isArray(sv) || !sv.length) continue;
    let best = null;
    let bestSim = 0;
    for (const node of safeNodes) {
      const rec = embeddingMap?.get ? embeddingMap.get(node.id) : null;
      if (!rec || !Array.isArray(rec.embedding) || !rec.embedding.length) continue;
      const sim = memoryProdCosineSimilarity(sv, rec.embedding);
      if (sim > bestSim) { bestSim = sim; best = node; }
    }
    perSentenceTop.push({ sentence: sentences[i], sentenceIndex: i, bestNodeId: best?.id || '', bestNodeLabel: best?.label || '', sim: bestSim });
  }
  // Determine dominant nodes for this slice (top 2 by count of matches above threshold).
  const nodeMatchCounts = new Map();
  for (const row of perSentenceTop) {
    if (row.sim < MEMORY_EMBEDDING_COMPETING_SIM) continue;
    nodeMatchCounts.set(row.bestNodeId, (nodeMatchCounts.get(row.bestNodeId) || 0) + 1);
  }
  const sortedDominant = Array.from(nodeMatchCounts.entries()).sort((a, b) => b[1] - a[1]);
  const dominantNodeIds = new Set(sortedDominant.slice(0, 2).map(([id]) => id));
  // Off-topic = sentence that strongly matches a node OUTSIDE the dominant set.
  const offTopic = [];
  for (const row of perSentenceTop) {
    if (row.sim < MEMORY_EMBEDDING_OFFTOPIC_SIM) continue;
    if (!row.bestNodeId) continue;
    if (dominantNodeIds.has(row.bestNodeId)) continue;
    offTopic.push({
      sentence: trimMemoryText(row.sentence, 220),
      sentenceIndex: row.sentenceIndex,
      matchedNodeId: row.bestNodeId,
      matchedNodeLabel: row.bestNodeLabel,
      similarity: Number(row.sim.toFixed(4))
    });
  }
  return offTopic;
}

// ---------------------------------------------------------------------------
// SECTION E â€” Triage cue detectors
// ---------------------------------------------------------------------------

function memoryProdDetectCorrectionCue(text) {
  const hay = String(text || '').toLowerCase().replace(/['\u2019]/g, "'");
  if (!hay) return false;
  // Correction phrases at or near the start of a sentence, or standalone clauses.
  return /(^|[.!?]\s+|\n)\s*(no[,.\s]|nope[,.\s]|actually[,.\s]|wait[,.\s]|i meant|i didn't|i did not|you got that wrong|you're wrong|you are wrong|that's wrong|not quite|to be clear|correction[,:])/i.test(hay)
    || /\b(i meant|scratch that|let me clarify|i was wrong earlier|i said wrong)\b/i.test(hay);
}

// ARCH Â§14 â€” Parse a correction phrase into { wrongLabel, rightLabel, kind }.
// Handles three common shapes:
//   "I meant X, not Y"          / "Wait no, I meant X not Y"
//   "Not Y, I use X now"        / "Not Y, X now"
//   "That was not Y, it was X"  / "That wasn't Y, it was X"
// Conservative: only returns a result when both wrong and right names look like
// proper nouns or capitalised tokens (3+ chars). Pure function: no I/O.
function memoryProdParseCorrectionTargets(userText = '') {
  const text = String(userText || '').replace(/[\u2019]/g, "'").trim();
  if (!text) return null;
  // Patterns are evaluated in priority order; first match wins. The /i flag is required
  // because the user's text often starts a sentence (so "I meant" is capitalised) but the
  // initial "i\s+meant" anchor is lowercase in our pattern.
  const patterns = [
    // I meant X, not Y  /  I meant X not Y
    { re: /\bi\s+meant\s+([A-Z][A-Za-z0-9 _-]{2,40})(?:\s*,)?\s+not\s+([A-Z][A-Za-z0-9 _-]{2,40})\b/i, rightIdx: 1, wrongIdx: 2, kind: 'i_meant_x_not_y' },
    // Not Y, I meant X  /  Not Y I meant X
    { re: /\bnot\s+([A-Z][A-Za-z0-9 _-]{2,40})(?:\s*,)?\s+i\s+meant\s+([A-Z][A-Za-z0-9 _-]{2,40})\b/i, wrongIdx: 1, rightIdx: 2, kind: 'not_y_i_meant_x' },
    // Not Y, I use X now  /  Not Y, X now
    { re: /\bnot\s+([A-Z][A-Za-z0-9 _-]{2,40})(?:\s*,)?\s+(?:i\s+(?:use|prefer|like|do|am using|switched to)\s+)?([A-Z][A-Za-z0-9 _-]{2,40})\s+now\b/i, wrongIdx: 1, rightIdx: 2, kind: 'not_y_x_now' },
    // It was X, not Y
    { re: /\bit\s+was\s+([A-Z][A-Za-z0-9 _-]{2,40})(?:\s*,)?\s+not\s+([A-Z][A-Za-z0-9 _-]{2,40})\b/i, rightIdx: 1, wrongIdx: 2, kind: 'it_was_x_not_y' },
    // That was not Y, it was X  /  That wasn't Y, it was X
    { re: /\bthat\s+(?:was\s+not|wasn't|was n't)\s+([A-Z][A-Za-z0-9 _-]{2,40})(?:\s*,)?\s+it\s+was\s+([A-Z][A-Za-z0-9 _-]{2,40})\b/i, wrongIdx: 1, rightIdx: 2, kind: 'that_wasnt_y_it_was_x' }
  ];
  for (const p of patterns) {
    const m = text.match(p.re);
    if (!m) continue;
    const wrongLabel = trimMemoryText(m[p.wrongIdx], 80).trim();
    const rightLabel = trimMemoryText(m[p.rightIdx], 80).trim();
    if (!wrongLabel || !rightLabel) continue;
    if (normalizeMemoryKey(wrongLabel) === normalizeMemoryKey(rightLabel)) continue;
    return { wrongLabel, rightLabel, kind: p.kind };
  }
  return null;
}

// ARCH Â§14 â€” Apply the correction protocol. Decides one of:
//   'tombstone'      â€” wrong node was created very recently, very thin, single-event;
//                      mark deleted=true with a tombstone reason; redirect alias to right.
//   'redirect_alias' â€” wrong node has aliases or substantial state; do not delete; add
//                      `correctionRedirectsTo` and append wrongLabel to right node aliases
//                      (so future references resolve correctly).
//   'pending_review' â€” life-significant or rich nodes; never auto-mutate. Write a row to
//                      consolidationQueue for human review. Audit trail is the source of truth.
// Always preserves evidence; never deletes silently. Patches no slices/events directly.
//
// Inputs:
//   { wrongLabel, rightLabel, kind }
//   existingNodes (the working set passed in by the caller; we do not list all nodes here)
//   nowMs, sessionId, jobId, userMsgId, threadId
// Returns:
//   { decision, wrongNodeId, rightNodeId?, reason, tombstoneId? }
async function memoryProdApplyCorrectionProtocol(accessToken, projectId, uid, params = {}) {
  const wrongLabel = trimMemoryText(params?.wrongLabel || '', 80);
  const rightLabel = trimMemoryText(params?.rightLabel || '', 80);
  const kind = trimMemoryText(params?.kind || 'unknown', 60);
  const existingNodes = Array.isArray(params?.existingNodes) ? params.existingNodes : [];
  const nowMs = num(params?.nowMs, Date.now());
  const sessionId = trimMemoryText(params?.sessionId || '', 160);
  if (!wrongLabel || !rightLabel) return { decision: 'no_op', reason: 'missing_targets' };

  const findByLabel = (lbl) => {
    const k = normalizeMemoryKey(lbl);
    if (!k) return null;
    return existingNodes.find((n) => !n?.deleted && (
      normalizeMemoryKey(n?.normalizedKey || n?.label || '') === k
      || (Array.isArray(n?.aliases) && n.aliases.some((a) => normalizeMemoryKey(a) === k))
    )) || null;
  };
  const wrongNode = findByLabel(wrongLabel);
  const rightNode = findByLabel(rightLabel);

  if (!wrongNode) {
    // Nothing to correct. Cue is informational only.
    return { decision: 'no_op', reason: 'wrong_node_not_found', wrongLabel, rightLabel, kind };
  }

  // Heuristic: tombstone-eligible only if the wrong node is very fresh, very thin,
  // single-event/session, and not life-significant. Otherwise route to pending_review.
  const ageMs = nowMs - num(wrongNode?.dateAdded || wrongNode?.createdAt, nowMs);
  const eventCount = num(wrongNode?.eventCount, 0);
  const sessionCount = num(wrongNode?.sessionCount, 1);
  const importance = String(wrongNode?.importanceClass || '').toLowerCase();
  const isLifeSignificant = importance === 'life_significant';
  const isThinAndFresh = !isLifeSignificant && eventCount <= 1 && sessionCount <= 1 && ageMs <= MEMORY_CORRECTION_TOMBSTONE_AGE_MS;

  if (isThinAndFresh && rightNode) {
    // Tombstone wrong node and add wrongLabel as alias on right node.
    const tombstonePatch = {
      deleted: true,
      deletedAt: nowMs,
      tombstoneReason: trimMemoryText(`correction:${kind}:redirect_to:${rightNode.id}`, 220),
      correctionRedirectsTo: trimMemoryText(rightNode.id || '', 160),
      correctedAt: nowMs,
      updatedAt: nowMs,
      schemaVersion: MEMORY_SCHEMA_VERSION
    };
    try {
      await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${wrongNode.id}`, tombstonePatch);
    } catch (err) {
      console.log(`[correction_tombstone_error] uid=${uid} node=${wrongNode.id}: ${String(err?.message || err)}`);
      return { decision: 'failed', reason: 'tombstone_patch_failed', wrongNodeId: wrongNode.id };
    }
    const newAliases = boundedUniqueIds([...(Array.isArray(rightNode.aliases) ? rightNode.aliases : []), wrongLabel], 12);
    try {
      await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${rightNode.id}`, {
        aliases: newAliases,
        correctedFromNodeId: trimMemoryText(wrongNode.id || '', 160),
        correctedAt: nowMs,
        updatedAt: nowMs
      });
    } catch (err) {
      console.log(`[correction_alias_redirect_error] uid=${uid} node=${rightNode.id}: ${String(err?.message || err)}`);
    }
    return { decision: 'tombstone', wrongNodeId: wrongNode.id, rightNodeId: rightNode.id, tombstoneId: wrongNode.id, reason: 'thin_and_fresh', kind };
  }

  if (rightNode && !isLifeSignificant) {
    // Redirect alias only â€” do not delete the wrong node, but mark it corrected and
    // make sure the right node accepts wrongLabel as an alias for future matching.
    const redirectPatch = {
      correctionRedirectsTo: trimMemoryText(rightNode.id || '', 160),
      correctedAt: nowMs,
      correctionKind: kind,
      updatedAt: nowMs,
      schemaVersion: MEMORY_SCHEMA_VERSION
    };
    try {
      await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${wrongNode.id}`, redirectPatch);
    } catch (err) {
      console.log(`[correction_redirect_error] uid=${uid} node=${wrongNode.id}: ${String(err?.message || err)}`);
      return { decision: 'failed', reason: 'redirect_patch_failed', wrongNodeId: wrongNode.id };
    }
    const newAliases = boundedUniqueIds([...(Array.isArray(rightNode.aliases) ? rightNode.aliases : []), wrongLabel], 12);
    try {
      await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${rightNode.id}`, {
        aliases: newAliases,
        correctedFromNodeId: trimMemoryText(wrongNode.id || '', 160),
        correctedAt: nowMs,
        updatedAt: nowMs
      });
    } catch (err) {
      console.log(`[correction_alias_attach_error] uid=${uid} node=${rightNode.id}: ${String(err?.message || err)}`);
    }
    return { decision: 'redirect_alias', wrongNodeId: wrongNode.id, rightNodeId: rightNode.id, reason: 'rich_or_aged_redirect', kind };
  }

  // Otherwise: pending_review. Life-significant or no right-node-yet â€” never auto-mutate.
  // Write a row to consolidationQueue so an admin/operator can review and decide.
  const queueId = `correction_${trimMemoryText(wrongNode.id || '', 60)}_${nowMs}`;
  try {
    await fsUpsertDoc(accessToken, projectId, `users/${uid}/consolidationQueue/${queueId}`, {
      id: queueId,
      kind: 'correction_pending_review',
      wrongNodeId: trimMemoryText(wrongNode.id || '', 160),
      wrongLabel,
      rightLabel,
      correctionKind: kind,
      sessionId,
      importanceClass: importance,
      eventCount,
      sessionCount,
      ageMs,
      createdAt: nowMs,
      updatedAt: nowMs,
      outcome: 'pendingReview',
      deleted: false,
      schemaVersion: MEMORY_SCHEMA_VERSION
    });
  } catch (err) {
    console.log(`[correction_pending_review_error] uid=${uid} queueId=${queueId}: ${String(err?.message || err)}`);
    return { decision: 'failed', reason: 'pending_review_write_failed', wrongNodeId: wrongNode.id };
  }
  return { decision: 'pending_review', wrongNodeId: wrongNode.id, rightNodeId: rightNode?.id || '', reason: isLifeSignificant ? 'life_significant_protected' : 'right_node_missing', kind };
}

function memoryProdCountActionDensity(text) {
  const hay = String(text || '').toLowerCase();
  if (!hay) return 0;
  const verbPatterns = [
    /\bstarted\b/, /\bstopped\b/, /\bquit\b/, /\bpaused\b/, /\bresumed\b/,
    /\bfinished\b/, /\bcompleted\b/, /\blaunched\b/, /\bshipped\b/, /\breleased\b/,
    /\bfixed\b/, /\bsolved\b/, /\brecovered\b/, /\bbegan\b/, /\bbegun\b/,
    /\brestarted\b/, /\bgave up\b/, /\bpicked up\b/, /\bdropped\b/, /\bswitched\b/, /\bpivoted\b/,
    /\bblocked\b/, /\bdiagnosed\b/, /\bgot injured\b/, /\bdied\b/, /\bpassed away\b/
  ];
  let count = 0;
  for (const re of verbPatterns) if (re.test(hay)) count += 1;
  return count;
}

function memoryProdDetectStateContradiction(userText, existingNodes) {
  const hay = String(userText || '').toLowerCase();
  if (!hay) return null;
  const safeNodes = Array.isArray(existingNodes) ? existingNodes : [];
  for (const node of safeNodes) {
    const labelLower = String(node?.label || '').toLowerCase().trim();
    if (!labelLower || labelLower.length < 3) continue;
    if (!hay.includes(labelLower)) continue;
    const state = String(node?.currentState || '').toLowerCase();
    if (state === 'active' && /\b(stopped|quit|gave up|no longer|don't do|dont do|not doing)\b/.test(hay)) {
      return { nodeId: node.id, nodeLabel: node.label, kind: 'active_but_user_says_stopped' };
    }
    if ((state === 'inactive' || state === 'paused') && /\b(resumed|started again|back to|getting back into|picked back up)\b/.test(hay)) {
      return { nodeId: node.id, nodeLabel: node.label, kind: 'inactive_but_user_says_resumed' };
    }
    if (state === 'completed' && /\b(still working on|not done|in progress)\b/.test(hay)) {
      return { nodeId: node.id, nodeLabel: node.label, kind: 'completed_but_user_says_ongoing' };
    }
  }
  return null;
}

function memoryProdCountCompetingConcepts(shortlistItems) {
  if (!Array.isArray(shortlistItems)) return 0;
  return shortlistItems.filter((it) => num(it?.semanticScore, 0) >= MEMORY_EMBEDDING_COMPETING_SIM).length;
}

// ---------------------------------------------------------------------------
// SECTION F â€” Triage router (returns { tier, model, reasons })
// ---------------------------------------------------------------------------

function memoryProdClassifyTriageTier(cfg, triageSignals) {
  const mediumModel = String(cfg?.memoryMediumModel || cfg?.memoryLearnModel || 'google/gemini-2.5-flash');
  const strongModel = String(cfg?.memoryStrongModel || 'anthropic/claude-sonnet-4.6');
  const reasons = [];
  const s = triageSignals || {};
  if (s.correctionCue) reasons.push('correction_cue');
  if (s.stateContradiction) reasons.push(`state_contradiction:${s.stateContradiction.kind}`);
  if (s.actionDensity >= MEMORY_TRIAGE_ACTION_DENSITY_LIMIT) reasons.push(`high_action_density:${s.actionDensity}`);
  if (s.sliceChars >= MEMORY_TRIAGE_LARGE_SLICE_CHARS) reasons.push(`large_slice:${s.sliceChars}`);
  if (Array.isArray(s.offTopicSentences) && s.offTopicSentences.length) reasons.push(`off_topic_detected:${s.offTopicSentences.length}`);
  if (s.competingConceptCount >= MEMORY_TRIAGE_COMPETING_CONCEPTS_LIMIT) reasons.push(`competing_concepts:${s.competingConceptCount}`);
  if (s.lifeFastLane) reasons.push('life_fast_lane');
  if (reasons.length) return { tier: 'A', model: strongModel, reasons };
  return { tier: 'B', model: mediumModel, reasons: ['default_medium'] };
}

// ---------------------------------------------------------------------------
// SECTION G â€” Idempotency (users/{uid}/memoryExtractionIdempotency/{key})
// ---------------------------------------------------------------------------

async function memoryProdComputeIdempotencyKey(uid, sessionId, sliceMessages, assistantText) {
  const sliceSig = (Array.isArray(sliceMessages) ? sliceMessages : [])
    .map((m) => `${String(m?.role || '')}::${String(m?.text || m?.content || '').trim()}`)
    .join('\u241F');
  const payload = `${uid || ''}\u241E${sessionId || ''}\u241E${sliceSig}\u241E${String(assistantText || '').trim()}`;
  const hash = await memoryProdHashText(payload);
  return `idem_${hash.slice(0, 40)}`;
}

async function memoryProdCheckIdempotency(accessToken, projectId, uid, key) {
  const safeKey = String(key || '').replace(/[^a-zA-Z0-9_:-]/g, '_');
  if (!safeKey) return null;
  const raw = await fsGetDoc(accessToken, projectId, `users/${uid}/memoryExtractionIdempotency/${safeKey}`).catch(() => null);
  if (!raw?.fields) return null;
  const parsed = parseFirestoreFields(raw.fields) || {};
  const expiresAt = num(parsed.expiresAt, 0);
  if (expiresAt > 0 && expiresAt < Date.now()) return null; // expired â†’ treat as new
  return parsed;
}

async function memoryProdStampIdempotency(accessToken, projectId, uid, key, outcome) {
  const safeKey = String(key || '').replace(/[^a-zA-Z0-9_:-]/g, '_');
  if (!safeKey) return;
  const nowMs = Date.now();
  await fsCreateOrPatchDoc(accessToken, projectId, `users/${uid}/memoryExtractionIdempotency/${safeKey}`, {
    key: safeKey,
    sessionId: trimMemoryText(outcome?.sessionId || '', 160),
    tier: trimMemoryText(outcome?.tier || '', 4),
    decisionSummary: trimMemoryText(JSON.stringify(outcome?.decisionSummary || {}), 2000),
    createdAt: nowMs,
    expiresAt: nowMs + MEMORY_IDEMPOTENCY_TTL_MS,
    schemaVersion: MEMORY_SCHEMA_VERSION
  }).catch(() => null);
}

// ---------------------------------------------------------------------------
// SECTION H â€” Pass 1 prompt (structural only, with self-report fields)
// ---------------------------------------------------------------------------

function memoryProdBuildPass1Prompt(mode, packet) {
  const relevantNodesJson = JSON.stringify(Array.isArray(packet?.relevantNodes) ? packet.relevantNodes : []);
  const activeAnchorHintsJson = JSON.stringify(Array.isArray(packet?.activeAnchorHints) ? packet.activeAnchorHints : []);
  const plannedAnchorHintsJson = JSON.stringify(Array.isArray(packet?.plannedAnchorHints) ? packet.plannedAnchorHints : []);
  const triageTagsJson = JSON.stringify(packet?.triageTags || {});
  const offTopicJson = JSON.stringify(Array.isArray(packet?.offTopicSentences) ? packet.offTopicSentences : []);
  return [
    'You are the GPMai production memory extraction engine (Pass 1: STRUCTURAL TRUTH).',
    'You return ONLY valid JSON. No markdown. No prose. No commentary outside the JSON.',
    'Pass 1 MUST NOT write narrative summaries. A separate Pass 2 will do that. Keep summaryHint and eventHint.summary as short dense fragments (<=160 chars) used as writing seeds, never polished prose.',
    'STRICT SCOPE: extract new memory ONLY from <extract_from_new_slice_only>. Use <bridge_context_reference_only> only to resolve pronouns/references. Do not summarize, repeat, or re-extract bridge-only facts.',
    '',
    'Required JSON shape (every field is required â€” do not omit any):',
    '{',
    '  "reinforce_labels": ["label"],',
    '  "node_updates": [',
    '    {',
    '      "anchorLabel": "EXACT existing node label, not a pronoun",',
    '      "anchorNodeId": "optional existing node id from relevant_nodes/active_anchor_hints",',
    '      "resolvedFrom": "direct label|this app|it|kaka app|the backend|the UI|...",',
    '      "resolutionReason": "why the reference maps to this anchor",',
    '      "resolutionConfidence": 0.92,',
    '      "ambiguous": false,',
    '      "alternativeAnchors": [],',
    '      "detailDisposition": "attach_to_anchor|standalone_candidate|ambiguous_skip",',
    '      "summaryHint": "complete meaningful update attached to the existing/planned node",',
    '      "meaningful": true,',
    '      "eventWorthy": false,',
    '      "updateKind": "feature_detail|technical_detail|progress|blocker|fix|lifecycle|decision|preference|other",',
    '      "lifecycleAction": "started|paused|resumed|stopped|blocked|fixed|completed|launched|changed_plan|",',
    '      "eventType": "project_progress|project_blocker|lifecycle_stopped|... or empty",',
    '      "confidence": 0.92,',
    '      "edgeHints": [{"to":"...","type":"uses|depends_on|part_of|supports|improves|drives|related_to","reason":"explicit relation only"}]',
    '    }',
    '  ],',
    '  "candidates": [',
    '    {',
    '      "label": "canonical concept noun",',
    '      "roleGuess": "identity|goal|project|skill|habit|interest|preference|reserve",',
    '      "strength": "weak|medium|strong",',
    '      "clusterHint": "work|learning|health|sports|finance|relationships|personal|general",',
    '      "parentHint": "optional parent node label",',
    '      "importanceHint": "ordinary|important|life_significant",',
    '      "summaryHint": "short dense fragment of meaningful detail",',
    '      "stateHint": "active|paused|inactive|completed|blocked",',
    '      "eventHint": {',
    '        "worthy": true,',
    '        "action": "started|paused|resumed|stopped|blocked|fixed|completed|launched|changed_plan",',
    '        "summary": "what happened, short",',
    '        "timeText": "yesterday|today|last week|...",',
    '        "eventType": "lifecycle_started|life_event|health_update|progress|blocker|fix|...",',
    '        "sameOngoingIncident": true,',
    '        "reuseHint": "if this is the SAME incident/timeline as an earlier event for this node, describe briefly; else empty string"',
    '      },',
    '      "relationHints": [{"to":"...","type":"part_of|uses|depends_on|drives|supports|improves|related_to","reason":"..."}]',
    '    }',
    '  ],',
    '  "relation_hints": [{"from":"...","to":"...","type":"...","reason":"..."}],',
    '  "self_report": {',
    '    "confidence": "high|medium|low",',
    '    "ambiguous_references": true,',
    '    "competing_concepts_detected": true,',
    '    "escalation_required": true,',
    '    "reason_for_uncertainty": "short reason or empty string",',
    '    "off_topic_acknowledged": true',
    '  }',
    '}',
    '',
    '===== DECISION HIERARCHY =====',
    '1. If the main concept already matches a node in <relevant_nodes> or <existing_memory>, put its EXACT existing label in reinforce_labels. Do NOT paraphrase into a new candidate.',
    '2. Candidate = (a) genuinely unclear/fuzzy/ambiguous, OR (b) clear concept but no meaningful detail yet.',
    '3. Durable-ready = clear concept + at least one meaningful detail (named technique, blocker, reason, injury, milestone, cause, useful fact). Express as a strong candidate with strength="strong" and the meaningful detail in summaryHint.',
    '4. Reject junk/filler/meta-chatter/broken fragments.',
    '5. If something HAPPENED to the concept (lifecycle change, life event, progress, blocker, fix), set eventHint.worthy=true and fill action + summary.',
    '6. node_updates is the preferred output when the current slice contains meaningful information about an EXISTING node OR a SAME-BATCH PLANNED anchor from <planned_anchor_hints>. Every meaningful node_update can become a Slice after backend approval.',
    '7. Resolve pronouns/references using <planned_anchor_hints>, <active_anchor_hints>, <relevant_nodes>, and <bridge_context_reference_only>. Examples: "this app", "it", "kaka app", "the backend", "the UI", "this feature". If context shows Kaka, write anchorLabel="Kaka" â€” never anchorLabel="this app" or "Kaka app". Bridge text is not extractable memory; it only explains references in the new slice.',
    '8. For every reference resolution, explicitly fill resolutionReason, resolutionConfidence, ambiguous, alternativeAnchors, and detailDisposition. If two anchors are plausible and you are not confident, set ambiguous=true and do NOT guess. 9. Internal details such as Graph feature, Brain Graph, login bug, screen, UI page, Firebase auth issue, backend part, or one-off feature should NOT become candidates/nodes from one sentence when described as part/feature/detail of an anchor. Attach them through node_updates.summaryHint.',
    '',
    '===== EVENT CREATE vs UPDATE (CRITICAL) =====',
    'Not every mention should create a new event. Decide:',
    '  - NEW event: a distinct happening not already captured (e.g. "I stopped football because of leg injury" when no recent injury event exists).',
    '  - UPDATE (sameOngoingIncident=true): a later mention about the SAME ongoing incident / timeline ("still working on the monitor issue", "doctor said rest two more weeks" when an injury event already exists).',
    '  - Slice-only (eventHint.worthy=false): meaningful concept reinforcement that does not describe a new happening ("I also like tennis in general").',
    'If you set sameOngoingIncident=true, fill reuseHint to describe which earlier incident this continues.',
    '',
    '===== LIFECYCLE ACTION SEMANTIC GROUPS =====',
    '  started   := started, began, got into, joined, signed up, picked up, took up, learning, now doing',
    '  stopped   := stopped, quit, gave up, no longer, don\'t do anymore, ended, dropped, walked away',
    '  paused    := paused, on hold, taking a break, postponed, stepping back',
    '  resumed   := resumed, started again, restarted, back to, getting back into, picked back up',
    '  blocked   := blocked, stuck, hit a wall, bug, injury, pain, failed, setback',
    '  fixed     := fixed, resolved, healed, recovered, sorted out, solved, got over',
    '  completed := completed, finished, done with, wrapped up',
    '  launched  := launched, released, shipped, went live, pushed out',
    '  changed_plan := changed, switched, pivoted, changed my mind, rethinking',
    '',
    '===== LIFE-MEMORY RULE =====',
    'Death, grief, loss, diagnosis, medical condition, trauma, abuse, breakup, divorce, family crisis, major injury, surgery â†’ DIRECT DURABLE.',
    '  strength="strong", importanceHint="life_significant", eventHint.worthy=true.',
    '  eventType="life_event" for death/grief/loss/trauma; "health_update" for diagnosis/medication/surgery/injury.',
    '  clusterHint="relationships" for family loss, "health" for medical, "personal" otherwise.',
    '',
    '===== ANCHOR RULE =====',
    'Prefer the durable user-life concept noun over scoped detail phrases.',
    '  "I started boxing and want to practice every day" â†’ candidate="boxing" (NOT "practice everyday"); eventHint.action="started".',
    '  "I\'m trying to fix my sleep routine" â†’ candidate="sleep routine" (valid durable concept).',
    '  Reject motivational filler ("improve myself", "work hard", "stay focused", "be consistent") unless it is the ONLY anchor.',
    '',
    '===== CONNECTION / relation_hints RULES =====',
    'type âˆˆ {part_of, uses, depends_on, drives, supports, improves, related_to}.',
    'Emit only when the user explicitly states a directional semantic relationship.',
    'Do NOT emit because two concepts share a cluster or appear in the same message.',
    'Do NOT use related_to as a junk drawer.',
    '  OK: "I use Flutter for GPMai" â†’ {"from":"GPMai","to":"Flutter","type":"uses","reason":"..."}',
    '  NOT OK: user mentions boxing and football â†’ no edge.',
    '',
    '===== SELF-REPORT (MANDATORY) =====',
    'Be honest about your own uncertainty. The backend uses self_report to decide whether to escalate this extraction to a stronger model.',
    '  confidence="low" if you are not sure what the main concept is, or if multiple interpretations are plausible.',
    '  ambiguous_references=true if the slice contains "it", "that", "them", "this app", etc. whose referent is unclear. If active_anchor_hints clearly resolve it, set confidence high and ambiguous_references=false.',
    '  competing_concepts_detected=true if two or more concepts could each be the main extraction.',
    '  escalation_required=true if you genuinely cannot produce a reliable extraction (e.g. heavy pronouns, corrections, contradiction signals).',
    '  off_topic_acknowledged=true if the slice contains an important update about a DIFFERENT concept from the slice\'s main topic (check <off_topic_sentences> for backend-detected off-topic lines and incorporate them as candidates if real).',
    '',
    '===== INPUT CONTEXT =====',
    '<session>', JSON.stringify(packet?.session || {}), '</session>',
    '<checkpoint>', JSON.stringify(packet?.checkpoint || {}), '</checkpoint>',
    '<trigger>', JSON.stringify(packet?.trigger || {}), '</trigger>',
    '<triage_tags>', triageTagsJson, '</triage_tags>',
    '<off_topic_sentences>', offTopicJson, '</off_topic_sentences>',
    '<planned_anchor_hints>', plannedAnchorHintsJson, '</planned_anchor_hints>',
    '<active_anchor_hints>', activeAnchorHintsJson, '</active_anchor_hints>',
    '<relevant_nodes>', relevantNodesJson, '</relevant_nodes>',
    '<existing_memory>', packet?.existingSummary || '', '</existing_memory>',
    '<scope_rule>', 'Extract ONLY from extract_from_new_slice_only. Bridge and assistant context are reference-only and must not become new memory.', '</scope_rule>',
    packet?.conversationText || '',
    '',
    'Return only the JSON object specified above.'
  ].join('\n');
}

// ---------------------------------------------------------------------------
// SECTION I â€” Pass 1 runner + confidence-fallback escalation (Tier B â†’ C)
// ---------------------------------------------------------------------------

async function memoryProdCallPass1Model(env, cfg, packet, model) {
  const prompt = memoryProdBuildPass1Prompt(MEMORY_SCOPE, packet);
  const data = await callOpenRouterChat(env, {
    model,
    messages: [{
      role: 'system',
      content: 'You are the GPMai production memory extraction engine (Pass 1). Return strict JSON only.'
    }, {
      role: 'user',
      content: prompt
    }],
    temperature: 0.05,
    max_tokens: 2200,
    response_format: { type: 'json_object' }
  });
  const raw = String(data?.choices?.[0]?.message?.content || '').trim();
  const parsed = safeParseJsonObject(stripMarkdownFences(raw)) || {};
  return { model, rawParsed: parsed, rawText: raw };
}

function memoryProdShouldEscalateFromSelfReport(parsed) {
  const sr = parsed?.self_report || {};
  const reasons = [];
  if (String(sr.confidence || '').toLowerCase() === 'low') reasons.push('self_report_low_confidence');
  if (sr.ambiguous_references === true) reasons.push('self_report_ambiguous_references');
  if (sr.competing_concepts_detected === true) reasons.push('self_report_competing_concepts');
  if (sr.escalation_required === true) reasons.push('self_report_escalation_required');
  return reasons;
}

async function memoryProdRunPass1WithTriage(env, cfg, mode, nodes, packet, triageDecision) {
  const mediumModel = String(cfg?.memoryMediumModel || cfg?.memoryLearnModel || 'google/gemini-2.5-flash');
  const strongModel = String(cfg?.memoryStrongModel || 'anthropic/claude-sonnet-4.6');
  const plannedTier = triageDecision?.tier === 'A' ? 'A' : 'B';
  const plannedModel = triageDecision?.model || (plannedTier === 'A' ? strongModel : mediumModel);
  let tierUsed = plannedTier;
  let modelUsed = plannedModel;
  let pass1Result = null;
  let escalationChain = [{ stage: 'initial', tier: plannedTier, model: plannedModel, reasons: triageDecision?.reasons || [] }];
  let extractionError = '';
  try {
    pass1Result = await memoryProdCallPass1Model(env, cfg, packet, plannedModel);
  } catch (err) {
    extractionError = String(err?.message || err || 'pass1_call_failed');
    escalationChain.push({ stage: 'initial_failed', error: extractionError });
  }
  // Tier C: confidence fallback (only when we started on Tier B medium).
  if (pass1Result && plannedTier === 'B') {
    const fallbackReasons = memoryProdShouldEscalateFromSelfReport(pass1Result.rawParsed);
    if (fallbackReasons.length) {
      try {
        const escalated = await memoryProdCallPass1Model(env, cfg, packet, strongModel);
        pass1Result = escalated;
        tierUsed = 'C';
        modelUsed = strongModel;
        escalationChain.push({ stage: 'tier_c_escalation', tier: 'C', model: strongModel, reasons: fallbackReasons });
      } catch (err) {
        escalationChain.push({ stage: 'tier_c_failed', error: String(err?.message || err) });
      }
    }
  }
  // Hard failure fallback: use heuristic candidates so the turn does not silently drop signal.
  if (!pass1Result) {
    const userText = trimMemoryText(getLastUserMessageText(packet?.sliceMessages || []), 220);
    return {
      tierUsed,
      modelUsed,
      escalationChain,
      extractionError: extractionError || 'pass1_unavailable',
      rawParsed: {
        candidates: memoryProdBuildHeuristicCandidatesFromUserText(userText),
        relation_hints: [],
        reinforce_labels: [],
        self_report: { confidence: 'low', ambiguous_references: false, competing_concepts_detected: false, escalation_required: true, reason_for_uncertainty: 'pass1_model_unavailable' }
      }
    };
  }
  return {
    tierUsed,
    modelUsed,
    escalationChain,
    extractionError: '',
    rawParsed: pass1Result.rawParsed
  };
}

// ---------------------------------------------------------------------------
// SECTION J â€” Backend recheck layer (independent safety net)
// ---------------------------------------------------------------------------

function memoryProdHasMeaningfulDetail(candidate, userText) {
  const summary = trimMemoryText(candidate?.summaryHint || '', 220).toLowerCase();
  const label = trimMemoryText(candidate?.label || '', 80).toLowerCase();
  const hay = `${summary} ${label} ${String(userText || '').toLowerCase()}`;
  if (!hay.trim()) return false;
  // Life Fast Lane and arbiter-proven detail/project anchors are meaningful by construction.
  if (candidate?.directDurable) return true;
  if (candidate?._hasMeaningfulDetail === true || candidate?._namedProjectAnchor === true) return true;
  if (candidate?.importanceHint === 'life_significant') return true;
  // Event-worthy alone is not meaningful enough. Lifecycle-only phrases like
  // "started learning X" must remain candidate unless the event carries detail.
  if (candidate?.eventHint?.worthy === true && trimMemoryText(candidate?.eventHint?.detailLabel || '', 80)) return true;
  if (candidate?.eventHint?.worthy === true && /life_event|health_update|skill_milestone|project_progress/i.test(String(candidate?.eventHint?.eventType || ''))) return true;
  // Named-detail patterns: technique, specific skill, blocker, cause, injury, milestone.
  const meaningfulPatterns = [
    /\b(learned|technique|skill|trick|move|routine|method|approach|strategy)\b/,
    /\b(because|due to|reason|caused by|blocker|stuck on|blocked by|issue|bug|problem)\b/,
    /\b(injury|pain|hurt|sprain|strain|fracture|surgery|diagnosis|medication|allergy)\b/,
    /\b(milestone|achieved|finished|launched|shipped|released|completed)\b/,
    /\b(started using|switched to|migrated to|replaced|adopted)\b/
  ];
  for (const re of meaningfulPatterns) if (re.test(hay)) return true;
  // Named tool/person/place tokens longer than 3 chars and capitalized (from original userText).
  if (/\b([A-Z][a-zA-Z]{3,})\b/.test(String(userText || ''))) return true;
  return false;
}

function memoryProdBackendRecheckPass1(learned, userText, existingNodes, triageContext) {
  const safe = { ...(learned || {}) };
  const candidates = Array.isArray(safe.candidates) ? safe.candidates.slice() : [];
  const reinforceLabels = Array.isArray(safe.reinforce_labels) ? safe.reinforce_labels.slice() : [];
  const relationHints = Array.isArray(safe.relation_hints) ? safe.relation_hints.slice() : [];
  const rechecks = Array.isArray(safe.backend_rechecks) ? safe.backend_rechecks.slice() : [];

  // V3.3.3: second-line canonicalization / abstract-veto defense.
  const canonicalCandidates = [];
  for (const c of candidates) {
    const canon = memoryProdCanonicalizeLabel(c?.label || '', userText);
    if (canon.vetoSignal === 'abstract_ambition') {
      rechecks.push({ kind: 'candidate_vetoed_abstract_ambition', label: c?.label || '', source: 'backend_recheck' });
      continue;
    }
    if (canon.canonical && canon.wasModified) {
      c._rawLabel = c.label;
      c.label = canon.canonical;
      c._canonicalized = canon;
      c.aliases = boundedUniqueIds([...(Array.isArray(c.aliases) ? c.aliases : []), canon.raw], 12);
      rechecks.push({ kind: 'label_canonicalized', raw: canon.raw, canonical: canon.canonical, source: 'backend_recheck' });
    }
    canonicalCandidates.push(c);
  }
  candidates.length = 0;
  candidates.push(...canonicalCandidates);
  if (MEMORY_CONCRETE_AMBITION_RE.test(userText) && /\b(something|anything|things?|stuff)\b/i.test(userText)) {
    for (let i = candidates.length - 1; i >= 0; i--) {
      const k = normalizeMemoryKey(candidates[i]?.label || '');
      if (k === 'science' || k === 'research' || memoryProdIsAbstractAmbitionLabel(candidates[i]?.label || '')) candidates.splice(i, 1);
    }
    if (!candidates.some((c) => normalizeMemoryKey(c?.label || '') === normalizeMemoryKey('Science Research Goal'))) {
      candidates.unshift({ label: 'Science Research Goal', roleGuess: 'goal', group: 'goal', strength: 'medium', summaryHint: trimMemoryText(userText, 220), _forceCandidate: true, _arbiterReason: 'concrete_ambition_anchor_salvaged' });
    }
    rechecks.push({ kind: 'abstract_ambition_concrete_anchor_salvaged', label: 'Science Research Goal', source: 'backend_recheck' });
  }

  // R1 â€” Meaningful detail rule: downgrade strong candidates to medium when detail is missing.
  for (const c of candidates) {
    if (c?.strength === 'strong' && !memoryProdHasMeaningfulDetail(c, userText)) {
      c.strength = 'medium';
      rechecks.push({ kind: 'downgrade_strong_to_medium', label: c.label, reason: 'no_meaningful_detail' });
    }
  }
  // R2 â€” Reinforce target validity: reinforce_labels must correspond to existing node labels/aliases.
  const validReinforceLabels = [];
  const existingLabelKeys = new Set();
  const labelToNode = new Map();
  for (const node of Array.isArray(existingNodes) ? existingNodes : []) {
    if (!node || node.deleted) continue;
    for (const key of memoryProdNodeAliasKeys(node)) {
      if (key) { existingLabelKeys.add(key); labelToNode.set(key, node); }
    }
  }
  for (const lbl of reinforceLabels) {
    const keys = memoryProdEntityAliasKeys(lbl);
    const hitKey = keys.find((k) => existingLabelKeys.has(k));
    if (hitKey) validReinforceLabels.push(labelToNode.get(hitKey)?.label || lbl);
    else rechecks.push({ kind: 'reinforce_label_dropped', label: lbl, reason: 'no_matching_existing_node' });
  }
  safe.reinforce_labels = boundedUniqueIds(validReinforceLabels, 12);
  // R3 â€” Alias dedup: candidates whose label already matches an existing node should become reinforce, not new candidate.
  const survivingCandidates = [];
  for (const c of candidates) {
    const keys = memoryProdEntityAliasKeys(c?.label || '');
    const k = keys.find((x) => existingLabelKeys.has(x)) || normalizeMemoryKey(c?.label || '');
    if (!k) continue;
    if (existingLabelKeys.has(k)) {
      const existingNode = labelToNode.get(k);
      const preserveForEventOrSlice = c?.eventHint?.worthy === true || !!c?._arbiterDecision || !!c?._detailLabel || !!trimMemoryText(c?.summaryHint || '', 40);
      if (preserveForEventOrSlice) {
        c.label = existingNode?.label || c.label;
        c.roleGuess = memoryProdNormalizeMemoryGroup(existingNode?.group || c.roleGuess || c.group || 'interest');
        c.clusterHint = memoryProdSanitizeClusterHint(existingNode?.clusterId || c.clusterHint || '', c.label, c.roleGuess, c.summaryHint || existingNode?.info || '');
        survivingCandidates.push(c);
        rechecks.push({ kind: 'candidate_preserved_for_existing_node_slice_event', label: c.label });
      } else {
        safe.reinforce_labels = boundedUniqueIds([existingNode?.label || c.label, ...safe.reinforce_labels], 12);
        rechecks.push({ kind: 'candidate_collapsed_into_reinforce', label: c.label });
      }
      continue;
    }
    survivingCandidates.push(c);
  }
  // R4 â€” Contradiction flag forwarded into triage context for caller visibility.
  if (triageContext?.stateContradiction) {
    rechecks.push({ kind: 'state_contradiction_flagged', detail: triageContext.stateContradiction });
  }
  safe.candidates = survivingCandidates;
  // R5 â€” Relation hints sanity: drop related_to fallback if both sides unknown.
  const cleanedRels = [];
  for (const r of relationHints) {
    const t = String(r?.type || '').toLowerCase();
    const fromKeys = memoryProdEntityAliasKeys(r?.from || '');
    const toKeys = memoryProdEntityAliasKeys(r?.to || '');
    const fromK = fromKeys[0] || normalizeMemoryKey(r?.from || '');
    const toK = toKeys[0] || normalizeMemoryKey(r?.to || '');
    if (!fromK || !toK) continue;
    if (t === 'related_to') {
      const eitherKnown = fromKeys.some((k) => existingLabelKeys.has(k)) || toKeys.some((k) => existingLabelKeys.has(k)) || survivingCandidates.some((c) => memoryProdLabelsAliasEquivalent(c.label, r?.from || '') || memoryProdLabelsAliasEquivalent(c.label, r?.to || ''));
      if (!eitherKnown) { rechecks.push({ kind: 'relation_dropped_weak_related_to', from: r.from, to: r.to }); continue; }
    }
    cleanedRels.push(r);
  }
  safe.relation_hints = cleanedRels;
  safe.backend_rechecks = rechecks;
  return safe;
}

// ---------------------------------------------------------------------------
// SECTION K â€” Node slice writer + rollup compression (memoryNodeSlices/*)
// ---------------------------------------------------------------------------

function memoryProdBuildSliceId(nodeId, nowMs) {
  return `slice_${String(nodeId || 'node').slice(-24)}_${nowMs}_${Math.random().toString(36).slice(2, 6)}`.replace(/[^a-zA-Z0-9_:-]/g, '_');
}

async function memoryProdWriteNodeSlice(accessToken, projectId, uid, node, context) {
  if (!node?.id) return null;
  const nowMs = num(context?.nowMs, Date.now());
  const sliceId = memoryProdBuildSliceId(node.id, nowMs);
  const userText = trimMemoryText(getLastUserMessageText(context?.sliceMessages || []), MEMORY_SLICE_PREVIEW_CHARS);
  const summaryDraft = trimMemoryText(context?.summaryDraft || context?.eventSummary || userText, MEMORY_SLICE_PREVIEW_CHARS);
  // v3.1.14 â€” extra provenance fields the architecture asks for. Cheap, non-breaking.
  const sourceMsgIds = Array.isArray(context?.sourceMsgIds) ? context.sourceMsgIds.slice(0, 8) : [];
  const sourceJobId = trimMemoryText(context?.sourceJobId || '', 160);
  const sourceEventIds = Array.isArray(context?.sourceEventIds)
    ? context.sourceEventIds.slice(0, 4)
    : (context?.eventId ? [trimMemoryText(context.eventId, 160)] : []);
  const confidence = typeof context?.confidence === 'number'
    ? Math.max(0, Math.min(1, context.confidence))
    : (context?.rollup ? 0.85 : 0.78);
  const triggerReason = trimMemoryText(context?.triggerReason || (context?.rollup ? 'rollup' : 'meaningful_update'), 80);
  const doc = {
    id: sliceId,
    nodeId: node.id,
    nodeLabel: trimMemoryText(node.label || '', 80),
    sessionId: trimMemoryText(context?.sessionId || '', 160),
    threadId: trimMemoryText(context?.threadId || '', 160),
    kind: context?.rollup ? 'rollup' : 'live',
    userSnippet: userText,
    summaryDraft,
    stateHintAtWrite: trimMemoryText(context?.stateHint || node.currentState || '', 24),
    eventId: trimMemoryText(context?.eventId || '', 160),
    eventType: trimMemoryText(context?.eventType || '', 60),
    lifecycleAction: trimMemoryText(context?.lifecycleAction || '', 40),
    triageTier: trimMemoryText(context?.triageTier || '', 4),
    triageModel: trimMemoryText(context?.triageModel || '', 120),
    importanceClass: trimMemoryText(context?.importanceClass || node.importanceClass || '', 40),
    coversSliceIds: Array.isArray(context?.coversSliceIds) ? context.coversSliceIds.slice(0, 20) : [],
    sourceMsgIds,
    sourceJobId,
    sourceEventIds,
    confidence,
    triggerReason,
    summaryRefreshedAt: 0,
    narrativeSummary: '',
    createdAt: nowMs,
    updatedAt: nowMs,
    schemaVersion: MEMORY_SCHEMA_VERSION
  };
  // Required structural write: do NOT swallow failures. requiredWrite() upstream must see
  // thrown errors so checkpoint advancement is blocked when a slice is missing.
  await fsCreateOrPatchDoc(accessToken, projectId, `users/${uid}/memoryNodeSlices/${sliceId}`, doc);
  // Update node counters + mirror latest slice summary so the Flutter UI can render it
  // directly off the node doc without a separate slice fetch.
  await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${node.id}`, {
    lastSliceId: sliceId,
    lastSliceAt: nowMs,
    sliceCount: num(node?.sliceCount, 0) + 1,
    latestSliceSummary: trimMemoryText(summaryDraft, MEMORY_SLICE_PREVIEW_CHARS),
      info: memoryProdMergeStableNodeInfo(node?.info || '', summaryDraft, node?.label || '', 520),
    meaningfulUpdateCount: num(node?.meaningfulUpdateCount, 0) + (context?.rollup ? 0 : 1),
    updatedAt: nowMs,
    schemaVersion: MEMORY_SCHEMA_VERSION
  }).catch((err) => {
    // Mirror patch is useful for UI but the slice document above is the required truth.
    // Log mirror failures without pretending the slice write failed.
    console.log(`[memory_slice_mirror_patch_error] uid=${uid} node=${node.id}: ${String(err?.message || err)}`);
  });
  return doc;
}

async function memoryProdListLiveSlicesForNode(accessToken, projectId, uid, nodeId) {
  // Unindexed scan: list the collection and filter client-side. Firestore returns up to 300 per call
  // via listDocuments; we keep it bounded because MEMORY_SLICE_PER_NODE_LIVE_CAP caps growth.
  try {
    const path = `users/${uid}/memoryNodeSlices`;
    const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${path}?pageSize=300`;
    const res = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
    if (!res.ok) return [];
    const data = await res.json().catch(() => null);
    const docs = Array.isArray(data?.documents) ? data.documents : [];
    const out = [];
    for (const d of docs) {
      const parsed = parseFirestoreFields(d.fields || {}) || {};
      if (parsed.nodeId !== nodeId) continue;
      out.push({ ...parsed, id: parsed.id || (d.name || '').split('/').pop() });
    }
    out.sort((a, b) => num(a.createdAt, 0) - num(b.createdAt, 0));
    return out;
  } catch (_) { return []; }
}

async function memoryProdRollupNodeSlicesIfNeeded(env, accessToken, projectId, uid, cfg, node) {
  if (!node?.id) return null;
  const slices = await memoryProdListLiveSlicesForNode(accessToken, projectId, uid, node.id);
  const liveSlices = slices.filter((s) => s.kind === 'live');
  // ARCH Â§10 â€” Importance-weighted rollup. Trigger when count >= 10 OR cumulative
  // importance weight of old live slices crosses MEMORY_SLICE_ROLLUP_WEIGHT_THRESHOLD.
  // Weights per Â§10: +5 life-significant, +3 lifecycle/skill milestone, +2 blocker/cause/
  // injury, +1 routine reinforcement.
  const sliceWeight = (s) => {
    const importance = String(s?.importanceClass || '').toLowerCase();
    if (importance === 'life_significant') return 5;
    const lifecycle = String(s?.lifecycleAction || '').toLowerCase();
    const eventType = String(s?.eventType || '').toLowerCase();
    if (lifecycle && ['started', 'stopped', 'paused', 'resumed', 'completed', 'launched'].includes(lifecycle)) return 3;
    if (eventType && /skill_milestone|project_start|project_complete|project_launch|milestone/.test(eventType)) return 3;
    if (eventType && /blocker|injury|incident|cause|problem/.test(eventType)) return 2;
    if (importance === 'important') return 2;
    return 1;
  };
  const cumulativeWeight = liveSlices.reduce((acc, s) => acc + sliceWeight(s), 0);
  const countTrigger = liveSlices.length >= MEMORY_SLICE_ROLLUP_EVERY;
  const weightTrigger = cumulativeWeight >= MEMORY_SLICE_ROLLUP_WEIGHT_THRESHOLD;
  if (!countTrigger && !weightTrigger) return null;
  const toRoll = liveSlices.slice(0, MEMORY_SLICE_ROLLUP_EVERY);
  const combined = toRoll.map((s, idx) => `(${idx + 1}) [${s.lifecycleAction || s.eventType || 'update'}] ${s.summaryDraft || s.userSnippet || ''}`).join('\n');
  let rollupText = '';
  try {
    const summaryModel = String(cfg?.memorySummaryModel || 'google/gemini-2.5-flash-lite');
  const cleanedPreviousNodeInfo = memoryProdCleanNodeInfoForPrompt(node.info || '', node.label || '');
    const data = await callOpenRouterChat(env, {
      model: summaryModel,
      messages: [
        { role: 'system', content: 'You compress 10 GPMai memory slices into a single, faithful rollup summary. Preserve important state changes, skills learned, blockers, reasons, milestones, injuries, timeline shifts. Do not flatten into a vague sentence. Return 3-5 short bullet-style lines (no markdown bullets), concrete and specific.' },
        { role: 'user', content: `Node: ${node.label}\nSlices to compress (chronological):\n${combined}\n\nWrite the rollup.` }
      ],
      temperature: 0.1,
      max_tokens: 400
    });
    rollupText = trimMemoryText(String(data?.choices?.[0]?.message?.content || '').trim(), 1200);
  } catch (err) {
    // If the rollup model fails, fall back to deterministic concatenation so history is not lost.
    rollupText = trimMemoryText(combined, 1200);
  }
  const rollupDoc = await memoryProdWriteNodeSlice(accessToken, projectId, uid, node, {
    nowMs: Date.now(),
    sessionId: toRoll[toRoll.length - 1]?.sessionId || '',
    threadId: toRoll[toRoll.length - 1]?.threadId || '',
    rollup: true,
    summaryDraft: rollupText,
    stateHint: node.currentState || '',
    coversSliceIds: toRoll.map((s) => s.id),
    triageTier: '-',
    triageModel: cfg?.memorySummaryModel || ''
  });
  // Delete the rolled-up live slices (keep rollup doc).
  const writes = toRoll.map((s) => makeFirestoreDeleteWrite(projectId, `users/${uid}/memoryNodeSlices/${s.id}`));
  try { await fsCommitWritesInChunks(accessToken, projectId, writes); } catch (_) {}
  return rollupDoc;
}

// ---------------------------------------------------------------------------
// SECTION L â€” Pass 2 narrative (async, queue-consumed)
// ---------------------------------------------------------------------------

async function memoryProdRunPass2Narrative(env, accessToken, projectId, uid, cfg, jobPayload) {
  if (cfg?.memorySummaryEnabled === false) return { ok: true, skipped: 'summary_disabled' };
  const nodeId = trimMemoryText(jobPayload?.nodeId || '', 160);
  if (!nodeId) return { ok: false, reason: 'no_node_id' };
  const nodeDoc = await fsGetDoc(accessToken, projectId, `users/${uid}/memoryNodes/${nodeId}`).catch(() => null);
  if (!nodeDoc?.fields) return { ok: false, reason: 'node_missing' };
  const node = { ...parseFirestoreFields(nodeDoc.fields), id: nodeId };
  const sliceId = trimMemoryText(jobPayload?.sliceId || '', 160);
  const eventId = trimMemoryText(jobPayload?.eventId || '', 160);
  let slice = null;
  let eventDoc = null;
  if (sliceId) {
    const sRaw = await fsGetDoc(accessToken, projectId, `users/${uid}/memoryNodeSlices/${sliceId}`).catch(() => null);
    if (sRaw?.fields) slice = { ...parseFirestoreFields(sRaw.fields), id: sliceId };
  }
  if (eventId) {
    const eRaw = await fsGetDoc(accessToken, projectId, `users/${uid}/memoryEvents/${eventId}`).catch(() => null);
    if (eRaw?.fields) eventDoc = { ...parseFirestoreFields(eRaw.fields), id: eventId };
  }
  const summaryModel = String(cfg?.memorySummaryModel || 'google/gemini-2.5-flash-lite');
  // L1 â€” latest slice narrative summary (short, human-readable).
  if (slice && slice.kind === 'live' && !slice.narrativeSummary) {
    try {
      const data = await callOpenRouterChat(env, {
        model: summaryModel,
        messages: [
          { role: 'system', content: 'You write a single concise sentence (<=220 chars) summarising one GPMai memory slice. No markdown, no quotes, no preamble. Plain factual sentence.' },
          { role: 'user', content: `Node: ${node.label}\nUser snippet: ${slice.userSnippet || ''}\nEvent: ${eventDoc ? `${eventDoc.lifecycleAction || ''} â€” ${eventDoc.summary || ''}` : '(none)'}\nDraft fragment: ${slice.summaryDraft || ''}` }
        ],
        temperature: 0.15,
        max_tokens: 180
      });
      const narrative = trimMemoryText(String(data?.choices?.[0]?.message?.content || '').trim(), 260);
      if (narrative) {
        await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodeSlices/${slice.id}`, {
          narrativeSummary: narrative,
          summaryRefreshedAt: Date.now(),
          schemaVersion: MEMORY_SCHEMA_VERSION
        }).catch(() => null);
      }
    } catch (err) {
      console.log(`[pass2_slice_summary_error] ${String(err?.message || err)}`);
    }
  }
  // L2 â€” node summary refresh (living summary).
  try {
    const data = await callOpenRouterChat(env, {
      model: summaryModel,
      messages: [
        { role: 'system', content: 'You rewrite a compact 2-3 sentence living profile summary of a GPMai memory node from scratch. Do not append. Do not preserve pipe-separated fragments. Remove duplicate facts and transcript-like wording. No markdown. No bullets. No quotes.' },
        { role: 'user', content: `Node: ${node.label}\nRole: ${node.group || ''}\nCluster: ${node.clusterId || ''}\nCurrent state: ${node.currentState || ''}\nPrevious summary: ${cleanedPreviousNodeInfo || ''}\nLatest slice: ${slice?.summaryDraft || slice?.userSnippet || ''}\nLatest event: ${eventDoc ? `[${eventDoc.lifecycleAction || eventDoc.eventType || 'update'}] ${eventDoc.summary || ''}` : '(none)'}` }
      ],
      temperature: 0.15,
      max_tokens: 240
    });
    const updatedRaw = trimMemoryText(String(data?.choices?.[0]?.message?.content || '').trim(), 520);
    const updated = memoryProdMergeStableNodeInfo(cleanedPreviousNodeInfo || '', updatedRaw, node.label || '', 520);
    if (updated) {
      await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${node.id}`, {
        info: updated,
        summaryRefreshedAt: Date.now(),
        updatedAt: Date.now(),
        schemaVersion: MEMORY_SCHEMA_VERSION
      }).catch(() => null);
    }
  } catch (err) {
    console.log(`[pass2_node_summary_error] ${String(err?.message || err)}`);
  }
  // L3 â€” check rollup condition.
  try {
    await memoryProdRollupNodeSlicesIfNeeded(env, accessToken, projectId, uid, cfg, node);
  } catch (err) {
    console.log(`[pass2_rollup_error] ${String(err?.message || err)}`);
  }
  return { ok: true, nodeId: node.id, sliceId: slice?.id || '', eventId: eventDoc?.id || '' };
}

async function memoryProdEnqueuePass2(env, jobPayload) {
  const queue = env?.[MEMORY_PASS2_QUEUE_BINDING];
  if (queue && typeof queue.send === 'function') {
    try {
      await queue.send(jobPayload);
      return { enqueued: true, mode: 'cloudflare_queue' };
    } catch (err) {
      console.log(`[pass2_queue_send_error] ${String(err?.message || err)}`);
      return { enqueued: false, mode: 'cloudflare_queue', error: String(err?.message || err) };
    }
  }
  // Queue binding missing â€” last-resort: return not enqueued so caller can decide on inline fallback.
  return { enqueued: false, mode: 'no_binding' };
}

// Queue consumer â€” exported via the default export's queue() handler.
async function memoryProdPass2QueueConsumer(batch, env) {
  if (!batch || !Array.isArray(batch.messages)) return;
  const accessToken = await getGoogleAccessToken(parseFirebaseServiceAccountFromEnv(env));
  const projectId = env.FIREBASE_PROJECT_ID;
  const cfg = await loadPublicConfig(accessToken, projectId).catch(() => ({}));
  for (const msg of batch.messages) {
    try {
      const body = msg.body || {};
      if (!body?.uid || !body?.nodeId) { msg.ack(); continue; }
      await memoryProdRunPass2Narrative(env, accessToken, projectId, body.uid, cfg, body);
      msg.ack();
    } catch (err) {
      const errText = String(err?.message || err);
      console.log(`[pass2_consumer_error] ${errText}`);
      // ARCH Â§10 â€” Pass 2 failure must never corrupt structural truth (it never reads it).
      // We still need failure visibility: emit pass2_failed debug so admins can see this
      // node's narrative refresh is lagging. Cloudflare retry semantics handle re-delivery.
      const body = msg.body || {};
      if (body?.uid) {
        try {
          await memoryProdLogDebugStage(accessToken, projectId, body.uid, 'pass2_failed', {
            sessionId: trimMemoryText(body.sessionId || '', 160),
            jobId: trimMemoryText(body.jobId || '', 160),
            nodeId: trimMemoryText(body.nodeId || '', 160),
            sliceId: trimMemoryText(body.sliceId || '', 160),
            decision: 'queue_consumer_failed',
            reason: trimMemoryText(errText, 220),
            details: { mode: 'queue_consumer', retryable: true }
          });
        } catch (logErr) {
          console.log(`[pass2_failed_debug_error] uid=${body.uid}: ${String(logErr?.message || logErr)}`);
        }
      }
      // Retry with backoff; after max retries Cloudflare moves it to DLQ.
      try { msg.retry({ delaySeconds: 30 }); } catch (retryErr) {
        console.log(`[pass2_retry_error] ${String(retryErr?.message || retryErr)}`);
        try { msg.ack(); } catch (ackErr) {
          console.log(`[pass2_ack_after_retry_fail_error] ${String(ackErr?.message || ackErr)}`);
        }
      }
    }
  }
}


// ===== END CORE LEARNING ENGINE INJECTION =====

function isStrongEditImageModel(model) {
  return ['black-forest-labs/flux-kontext-pro', 'google/nano-banana', 'ideogram-ai/ideogram-v2', 'qwen/qwen-image-2',
    'bytedance/seedream-5-lite', 'bytedance/seedream-4.5'
  ].includes(String(model || '').toLowerCase());
}

function isReferenceImageModel(model) {
  return ['minimax/image-01'].includes(String(model || '').toLowerCase());
}

function isControlImageModel(model) {
  return ['jagilley/controlnet-scribble'].includes(String(model || '').toLowerCase());
}

function isImageToVideoModel(model) {
  return ['google/veo-3.1', 'kwaivgi/kling-v2.6', 'kwaivgi/kling-v2.1', 'wan-video/wan-2.5-i2v',
    'wan-video/wan-2.5-i2v-fast', 'lightricks/ltx-2.3-fast', 'lightricks/ltx-2.3-pro'
  ].includes(String(model || '').toLowerCase());
}

function isImageAudioVideoModel(model) {
  return ['lightricks/ltx-2.3-fast', 'lightricks/ltx-2.3-pro'].includes(String(model || '').toLowerCase());
}

function normalizeMemoryMode(_value) {
  return MEMORY_SCOPE;
}


function memoryScopeFromMode(_) {
  return MEMORY_SCOPE;
}

function normalizeMemoryGroup(value) {
  return memoryProdNormalizeMemoryGroup(value);
}

function normalizeMemoryConnectionType(value) {
  const raw = String(value || '').trim();
  const lower = raw.toLowerCase();
  const legacy = {
    is_a: 'related_to',
    builds: 'part_of',
    uses: 'uses',
    has: 'part_of',
    pursuing: 'drives',
    related: 'related_to',
    compares: 'related_to',
    learned: 'supports',
    prefers: 'related_to',
    context: 'related_to',
  };
  const normalized = legacy[lower] || lower;
  return MEMORY_CONNECTION_TYPES.has(normalized) ? normalized : 'related_to';
}

function normalizeMemoryKey(value) {
  return String(value || '').normalize('NFKD').toLowerCase().replace(/[^a-z0-9\s_-]/g, ' ').replace(/\b(the|a|an)\b/g,
    ' ').replace(/\s+/g, ' ').trim().replace(/\s/g, '_').slice(0, 80);
}

function trimMemoryText(value, maxLen = 500) {
  return String(value || '').replace(/\r\n/g, '\n').replace(/[ \t]+/g, ' ').trim().slice(0, maxLen);
}

function splitMemoryItems(value, maxItems = 8) {
  const raw = String(value || '').trim();
  if (!raw) return [];
  let parts = raw.split(/\n|;/g).map((x) => x.trim()).filter(Boolean);
  if (parts.length <= 1) parts = raw.split(/,(?=(?:[^"]*"[^"]*")*[^"]*$)/g).map((x) => x.trim()).filter(Boolean);
  if (parts.length <= 1) parts = [raw];
  const out = [],
    seen = new Set();
  for (const part of parts) {
    const cleaned = trimMemoryText(part, 120),
      key = normalizeMemoryKey(cleaned);
    if (!cleaned || !key || seen.has(key)) continue;
    seen.add(key);
    out.push(cleaned);
    if (out.length >= maxItems) break;
  }
  return out;
}

function buildCompressedMemoryPrompt(profile, _mode, cfg) {
  const lines = [];
  const focus = trimMemoryText(profile?.focus || profile?.currentFocus || profile?.role, 140);
  const preferences = trimMemoryText(profile?.preferences || profile?.responsePreferences || profile?.style, 180);
  if (profile?.name) lines.push(`Name: ${trimMemoryText(profile.name, 60)}`);
  if (focus) lines.push(`Current focus: ${focus}`);
  if (profile?.projects) lines.push(`Current projects: ${trimMemoryText(profile.projects, 220)}`);
  if (profile?.stack) lines.push(`Tech stack: ${trimMemoryText(profile.stack, 180)}`);
  if (profile?.goals) lines.push(`Current goals: ${trimMemoryText(profile.goals, 220)}`);
  if (preferences) lines.push(`Response preferences: ${preferences}`);
  let prompt = lines.join('\n');
  const maxChars = Math.max(320, num(cfg.memoryPromptMaxChars, 950));
  if (prompt.length > maxChars) prompt = prompt.slice(0, maxChars).trim();
  return prompt;
}


function buildInjectedMemoryPromptFromProfile(profile, mode, cfg) {
  if (!profile) return '';
  const compressed = String(profile.compressedPrompt || buildCompressedMemoryPrompt(profile, mode, cfg)).trim();
  if (!compressed) return '';
  return `${compressed}\n\nUse this as persistent context for the user across the whole app. Reference their projects, goals, stack, and preferences when relevant. Avoid asking for context already captured here unless it is genuinely required.`;
}

function capitalizeMemoryWord(value) {
  const s = String(value || '');
  return s ? s.charAt(0).toUpperCase() + s.slice(1) : '';
}

function prependSystemContext(messages, memoryPrompt) {
  const safeMessages = Array.isArray(messages) ? messages.map((m) => ({
    role: String(m?.role || 'user'),
    content: typeof m?.content === 'string' ? m.content : String(m?.content || '')
  })) : [];
  if (!memoryPrompt) return safeMessages;
  if (safeMessages.length && safeMessages[0].role === 'system') return [{
    role: 'system',
    content: `${memoryPrompt}\n\n${safeMessages[0].content}`
  }, ...safeMessages.slice(1)];
  return [{
    role: 'system',
    content: memoryPrompt
  }, ...safeMessages];
}
async function fsListDocs(accessToken, projectId, collectionPath, pageSize = 500) {
  let pageToken = '',
    out = [];
  for (let i = 0; i < 10; i++) {
    const u = new URL(
      `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collectionPath}`);
    u.searchParams.set('pageSize', String(pageSize));
    if (pageToken) u.searchParams.set('pageToken', pageToken);
    const res = await fetch(u.toString(), {
      headers: {
        Authorization: `Bearer ${accessToken}`
      }
    });
    if (res.status === 404) return [];
    if (!res.ok) throw new Error(`fsListDocs failed: ${res.status} ${await res.text()}`);
    const j = await res.json();
    out.push(...(Array.isArray(j.documents) ? j.documents : []));
    pageToken = String(j.nextPageToken || '');
    if (!pageToken) break;
  }
  return out;
}

// V3.3.2 â€” one-page Firestore list for quota-safe UI/admin previews.
// Unlike fsListDocs(), this never paginates beyond the requested cap.
async function fsListDocsOnePage(accessToken, projectId, collectionPath, pageSize = 50) {
  const safeSize = Math.max(1, Math.min(200, num(pageSize, 50)));
  const u = new URL(`https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collectionPath}`);
  u.searchParams.set('pageSize', String(safeSize));
  const res = await fetch(u.toString(), { headers: { Authorization: `Bearer ${accessToken}` } });
  if (res.status === 404) return [];
  if (!res.ok) throw new Error(`fsListDocsOnePage failed: ${res.status} ${await res.text()}`);
  const j = await res.json();
  return Array.isArray(j.documents) ? j.documents : [];
}

// SURGICAL PATCH: Bounded Firestore structured query helper.
// Enables indexed recall queries (WHERE + ORDER BY + LIMIT) instead of scanning entire collections.
// Keep parentPath short form like `users/${uid}`; collectionId is the subcollection name.
async function fsRunQuery(accessToken, projectId, parentPath, collectionId, options = {}) {
  const cleanParent = String(parentPath || '').replace(/^\/+|\/+$/g, '');
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents${cleanParent ? '/' + cleanParent : ''}:runQuery`;
  const filters = Array.isArray(options.filters) ? options.filters : [];
  const orderBy = Array.isArray(options.orderBy) ? options.orderBy : [];
  const limit = Math.max(1, Math.min(500, num(options.limit, 50)));

  const structuredQuery = { from: [{ collectionId: String(collectionId) }], limit };
  if (filters.length === 1) {
    structuredQuery.where = { fieldFilter: filters[0] };
  } else if (filters.length > 1) {
    structuredQuery.where = {
      compositeFilter: {
        op: 'AND',
        filters: filters.map((f) => ({ fieldFilter: f }))
      }
    };
  }
  if (orderBy.length) {
    structuredQuery.orderBy = orderBy.map((ob) => ({
      field: { fieldPath: ob.field },
      direction: ob.direction === 'DESCENDING' ? 'DESCENDING' : 'ASCENDING'
    }));
  }
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ structuredQuery })
  });
  if (res.status === 404) return [];
  if (!res.ok) throw new Error(`fsRunQuery failed: ${res.status} ${await res.text()}`);
  const rows = await res.json();
  const out = [];
  for (const row of Array.isArray(rows) ? rows : []) {
    if (row && row.document) out.push(row.document);
  }
  return out;
}

// SURGICAL PATCH: Bounded list helpers for nodeIndex + eventIndex.
// Falls back to unbounded list+client-side filter if the structured query fails
// (e.g., composite index not yet provisioned in Firestore).
async function listNodeIndexDocsBounded(accessToken, projectId, uid, { minHeat = 0, limit = 50 } = {}) {
  try {
    const docs = await fsRunQuery(accessToken, projectId, `users/${uid}`, 'nodeIndex', {
      filters: [
        { field: { fieldPath: 'deleted' }, op: 'EQUAL', value: { booleanValue: false } },
        { field: { fieldPath: 'heat' }, op: 'GREATER_THAN_OR_EQUAL', value: { integerValue: String(minHeat) } }
      ],
      orderBy: [
        { field: 'heat', direction: 'DESCENDING' }
      ],
      limit
    });
    if (Array.isArray(docs) && docs.length) {
      return docs.map((doc) => ({
        ...parseFirestoreFields(doc.fields || {}),
        id: parseFirestoreFields(doc.fields || {}).id || docIdFromFsDoc(doc)
      }));
    }
  } catch (_) { /* fall through */ }
  const all = await listNodeIndexDocs(accessToken, projectId, uid);
  return all
    .filter((d) => !d.deleted && num(d.heat, 0) >= minHeat)
    .sort((a, b) => num(b.heat, 0) - num(a.heat, 0))
    .slice(0, limit);
}

async function listEventIndexDocsBounded(accessToken, projectId, uid, { tiers = ['hot', 'permanent'], limit = 50 } = {}) {
  // Firestore "IN" filtering via runQuery requires a compositeFilter of OR clauses (REST supports only AND).
  // Fall back to client-side tier filtering with a DESC orderBy + bounded limit.
  try {
    const docs = await fsRunQuery(accessToken, projectId, `users/${uid}`, 'eventIndex', {
      filters: [
        { field: { fieldPath: 'deleted' }, op: 'EQUAL', value: { booleanValue: false } }
      ],
      orderBy: [
        { field: 'updatedAt', direction: 'DESCENDING' }
      ],
      limit: Math.max(limit, 100)
    });
    const tierSet = new Set(Array.isArray(tiers) ? tiers : ['hot', 'permanent']);
    if (Array.isArray(docs) && docs.length) {
      return docs
        .map((doc) => ({
          ...parseFirestoreFields(doc.fields || {}),
          id: parseFirestoreFields(doc.fields || {}).id || docIdFromFsDoc(doc)
        }))
        .filter((d) => tierSet.has(d.memoryTier || 'hot'))
        .slice(0, limit);
    }
  } catch (_) { /* fall through */ }
  const all = await listEventIndexDocs(accessToken, projectId, uid);
  const tierSet = new Set(Array.isArray(tiers) ? tiers : ['hot', 'permanent']);
  return all
    .filter((d) => !d.deleted && tierSet.has(d.memoryTier || 'hot'))
    .sort((a, b) => num(b.updatedAt || b.createdAt, 0) - num(a.updatedAt || a.createdAt, 0))
    .slice(0, limit);
}

// ARCH Â§6, Â§12 â€” Hot/recent shortlist for the learning hot path.
// Returns a bounded working set so a normal extraction never scans all nodes.
//   { nodes, candidates, connections, suppressions, mode }
// `mode` = 'bounded' when nodeIndex returned at least one row; 'full' when we fell back to
// listMemoryNodes because the index was empty (fresh user / pre-bootstrap state).
async function memoryProdLoadHotShortlist(accessToken, projectId, uid, { nodeLimit = MEMORY_HOT_SHORTLIST_CAP, candidateLimit = MEMORY_HOT_SHORTLIST_CAND_CAP, connectionLimit = MEMORY_HOT_SHORTLIST_CONN_CAP } = {}) {
  let nodes = [];
  let mode = 'bounded';
  try {
    const indexDocs = await listNodeIndexDocsBounded(accessToken, projectId, uid, { minHeat: 0, limit: nodeLimit });
    if (Array.isArray(indexDocs) && indexDocs.length) {
      // nodeIndex docs carry a subset of node fields; for the hot path we hydrate only ones
      // the caller actually reads. Keep this light â€” full hydration is the caller's job
      // when (and only when) it needs it (e.g. embedding refresh).
      nodes = indexDocs.map((d) => ({
        id: trimMemoryText(d.nodeId || d.id || '', 160),
        label: trimMemoryText(d.label || d.normalizedKey || '', 80),
        normalizedKey: trimMemoryText(d.normalizedKey || normalizeMemoryKey(d.label || ''), 80),
        aliases: Array.isArray(d.aliases) ? d.aliases.slice(0, 12) : [],
        group: trimMemoryText(d.group || '', 40),
        clusterId: trimMemoryText(d.clusterId || '', 40),
        currentState: trimMemoryText(d.currentState || '', 24),
        info: trimMemoryText(d.info || '', 220),
        heat: num(d.heat, 0),
        importanceClass: trimMemoryText(d.importanceClass || '', 40),
        deleted: !!d.deleted,
        sourceType: trimMemoryText(d.sourceType || 'index', 40),
        _hotShortlistSource: 'nodeIndex'
      })).filter((n) => n.id && n.label && !n.deleted);
    }
  } catch (err) {
    console.log(`[hot_shortlist_index_error] uid=${uid}: ${String(err?.message || err)}`);
  }
  if (!nodes.length) {
    // Fallback: index empty (fresh user) or query failed. Use the existing full path so we
    // do not lock out new users. Caller still gets a bounded slice.
    mode = 'full';
    const all = await listMemoryNodes(accessToken, projectId, uid);
    nodes = (all || []).filter((n) => !n.deleted).slice(0, nodeLimit);
  }
  // Candidates and connections are naturally smaller; we still cap them.
  let candidates = [];
  try {
    const allCands = await listMemoryCandidates(accessToken, projectId, uid);
    candidates = (allCands || []).slice(0, candidateLimit);
  } catch (err) {
    console.log(`[hot_shortlist_candidates_error] uid=${uid}: ${String(err?.message || err)}`);
    candidates = [];
  }
  let connections = [];
  try {
    const allConn = await listMemoryConnections(accessToken, projectId, uid);
    // Bias toward connections involving any of our hot nodes (drops cold edges).
    const hotIds = new Set(nodes.map((n) => n.id).filter(Boolean));
    const hot = (allConn || []).filter((c) => !c.deleted && (hotIds.has(c.fromNodeId) || hotIds.has(c.toNodeId)));
    connections = (hot.length ? hot : (allConn || [])).slice(0, connectionLimit);
  } catch (err) {
    console.log(`[hot_shortlist_connections_error] uid=${uid}: ${String(err?.message || err)}`);
    connections = [];
  }
  let suppressions = [];
  try {
    suppressions = await listMemorySuppressions(accessToken, projectId, uid);
  } catch (err) {
    console.log(`[hot_shortlist_suppressions_error] uid=${uid}: ${String(err?.message || err)}`);
    suppressions = [];
  }
  return { nodes, candidates, connections, suppressions, mode };
}

// ARCH Â§6 â€” Unified four-layer existing-memory match.
// Composes (1) exact normalizedKey lookup, (2) hot/fuzzy substring on the bounded shortlist,
// (3) optional embedding/semantic shortlist (already provided by caller), (4) RRF fusion.
// Returns { exactHits, hotHits, semanticHits, fused, bestMatch }.
// Pure: no I/O. Caller owns the lists. Hard rules and gates still win downstream.
function memoryProdFourLayerMatchExisting(input = {}) {
  const userText = trimMemoryText(input?.userText || '', 600);
  const labels = Array.isArray(input?.candidateLabels) ? input.candidateLabels.filter(Boolean).slice(0, 12) : [];
  const hotNodes = Array.isArray(input?.hotNodes) ? input.hotNodes : [];
  const hotCandidates = Array.isArray(input?.hotCandidates) ? input.hotCandidates : [];
  const semanticItems = Array.isArray(input?.semanticItems) ? input.semanticItems : [];
  const k = num(input?.rrfK, MEMORY_FOURLAYER_RRF_K);
  // 1) Exact: normalize each candidate label and the userText itself, look up in hot sets.
  const norms = new Set();
  for (const l of labels) {
    for (const k1 of memoryProdEntityAliasKeys(l)) if (k1) norms.add(k1);
  }
  // Pull capitalised tokens from the userText (project-name-shaped) as additional probes.
  const capProbes = (String(userText).match(/\b[A-Z][a-zA-Z0-9]{2,}\b/g) || []).slice(0, 6);
  for (const p of capProbes) {
    const k1 = normalizeMemoryKey(p);
    if (k1) norms.add(k1);
  }
  const exactHits = [];
  for (const n of hotNodes) {
    const keys = memoryProdNodeAliasKeys(n);
    if (!keys.length) continue;
    if (keys.some((k1) => norms.has(k1))) exactHits.push({ kind: 'node', id: n.id, label: n.label, score: 1, source: 'exact_alias' });
  }
  for (const c of hotCandidates) {
    const k1 = normalizeMemoryKey(c?.normalizedKey || c?.label || '');
    if (!k1) continue;
    if (norms.has(k1)) exactHits.push({ kind: 'candidate', id: c.id, label: c.label, score: 1, source: 'exact_candidate' });
  }
  // 2) Hot/fuzzy: substring containment on hotNodes (typo-friendly, label-only).
  const lowerUser = String(userText || '').toLowerCase();
  const hotHits = [];
  for (const n of hotNodes) {
    const lbl = String(n?.label || '').toLowerCase();
    if (!lbl || lbl.length < 3) continue;
    if (norms.has(normalizeMemoryKey(n.label))) continue; // already in exact
    if (lowerUser.includes(lbl)) {
      hotHits.push({ kind: 'node', id: n.id, label: n.label, score: 0.8, source: 'hot_substring' });
    }
  }
  // 3) Semantic: caller-provided shortlist. We accept items shaped { id, label, semanticScore }.
  const semanticHits = (semanticItems || [])
    .filter((it) => it && it.id && it.label)
    .map((it) => ({ kind: 'node', id: it.id, label: it.label, score: num(it.semanticScore, 0), source: 'semantic' }));
  // 4) RRF fuse the three lanes by node id.
  const lanes = [
    { source: 'exact', anchors: exactHits.map((h) => ({ label: h.label, _id: h.id })) },
    { source: 'hot', anchors: hotHits.map((h) => ({ label: h.label, _id: h.id })) },
    { source: 'semantic', anchors: semanticHits.map((h) => ({ label: h.label, _id: h.id })) }
  ];
  const fused = memoryProdRrfFuseAnchorRanks(lanes, k);
  // Pick best match: prefer any exact hit; otherwise top fused by score that resolves to a node.
  let bestMatch = null;
  if (exactHits.length) {
    bestMatch = exactHits[0];
  } else if (fused.length) {
    const top = fused[0];
    const topKey = top.key;
    const node = hotNodes.find((n) => normalizeMemoryKey(n.label) === topKey || normalizeMemoryKey(n.normalizedKey || '') === topKey);
    if (node) bestMatch = { kind: 'node', id: node.id, label: node.label, score: top.score, source: 'rrf' };
  }
  return { exactHits, hotHits, semanticHits, fused, bestMatch, lanesUsed: lanes.length };
}

// ARCH Â§6, Â§12 â€” Targeted single-doc probes for canonical-key resolution. These exist so the
// hot path can stay bounded (top-N nodes from nodeIndex) without ever missing a match: when
// the hot shortlist does not contain a label, one direct fsGetDoc on the deterministic node id
// answers "does this exact concept already exist?" with a single read instead of a full scan.
async function memoryProdProbeNodeByLabel(accessToken, projectId, uid, label) {
  const key = normalizeMemoryKey(label || '');
  if (!key) return null;
  const nodeId = buildMemoryNodeId(MEMORY_SCOPE, label);
  try {
    const raw = await fsGetDoc(accessToken, projectId, `users/${uid}/memoryNodes/${nodeId}`);
    if (!raw) return null;
    const fields = parseFirestoreFields(raw.fields || {});
    if (fields.deleted) return null;
    return { ...fields, id: fields.id || nodeId };
  } catch (err) {
    console.log(`[probe_node_error] uid=${uid} label="${label}": ${String(err?.message || err)}`);
    return null;
  }
}

async function memoryProdProbeCandidateByLabel(accessToken, projectId, uid, label) {
  const key = normalizeMemoryKey(label || '');
  if (!key) return null;
  const candidateId = buildMemoryCandidateId(MEMORY_SCOPE, label);
  try {
    const raw = await fsGetDoc(accessToken, projectId, `users/${uid}/memoryCandidates/${candidateId}`);
    if (!raw) return null;
    const fields = parseFirestoreFields(raw.fields || {});
    if (fields.deleted || String(fields.status || '').toLowerCase() === 'promoted') return null;
    return { ...fields, id: fields.id || candidateId };
  } catch (err) {
    console.log(`[probe_candidate_error] uid=${uid} label="${label}": ${String(err?.message || err)}`);
    return null;
  }
}

function docIdFromFsDoc(doc) {
  return String(doc?.name || '').split('/').pop() || '';
}
async function fsUpsertDoc(accessToken, projectId, docPath, plainObj) {
  return (await fsGetDoc(accessToken, projectId, docPath)) ? fsPatchDoc(accessToken, projectId, docPath, plainObj) :
    fsCreateDoc(accessToken, projectId, docPath, plainObj);
}

function uniqCsvFields(...values) {
  const items = [],
    seen = new Set();
  for (const value of values) {
    for (const item of splitMemoryItems(value, 16)) {
      const key = normalizeMemoryKey(item);
      if (!key || seen.has(key)) continue;
      seen.add(key);
      items.push(item);
    }
  }
  return items.join(', ');
}

function mergeProfileValue(...values) {
  for (const value of values) {
    const clean = trimMemoryText(value, 320);
    if (clean) return clean;
  }
  return '';
}

function mergeUnifiedProfile(profiles, cfg) {
  const valid = (profiles || []).filter(Boolean);
  const merged = {
    mode: MEMORY_SCOPE,
    name: mergeProfileValue(...valid.map((p) => p.name)),
    focus: mergeProfileValue(...valid.map((p) => p.focus || p.currentFocus || p.role)),
    projects: uniqCsvFields(...valid.map((p) => p.projects)),
    stack: uniqCsvFields(...valid.map((p) => p.stack)),
    goals: uniqCsvFields(...valid.map((p) => p.goals)),
    preferences: mergeProfileValue(...valid.map((p) => p.preferences || p.responsePreferences || p.style)),
    updatedAt: Math.max(0, ...valid.map((p) => num(p.updatedAt, 0))),
  };
  merged.role = merged.focus || '';
  merged.style = merged.preferences || '';
  merged.level = '';
  merged.avoid = '';
  merged.compressedPrompt = buildCompressedMemoryPrompt(merged, MEMORY_SCOPE, cfg);
  return merged;
}


function responseProfileForMode(profile, _requestedMode) {
  const focus = trimMemoryText(profile?.focus || profile?.currentFocus || profile?.role, 140);
  const preferences = trimMemoryText(profile?.preferences || profile?.responsePreferences || profile?.style, 180);
  return {
    ...profile,
    mode: MEMORY_SCOPE,
    activeMode: MEMORY_SCOPE,
    focus,
    preferences,
    role: focus,
    style: preferences,
    level: '',
    avoid: '',
  };
}

async function readUnifiedMemoryProfile(accessToken, projectId, uid, cfg) {
  const globalPath = `users/${uid}/memoryProfiles/${MEMORY_SCOPE}`;
  const globalDoc = await fsGetDoc(accessToken, projectId, globalPath);
  const globalProfile = parseFirestoreFields(globalDoc?.fields || {});

  if (globalDoc && Object.keys(globalProfile).length) {
    const normalized = mergeUnifiedProfile([globalProfile], cfg);
    if (JSON.stringify(responseProfileForMode(globalProfile, MEMORY_SCOPE)) !== JSON.stringify(responseProfileForMode(normalized, MEMORY_SCOPE))) {
      await fsPatchDoc(accessToken, projectId, globalPath, {
        ...normalized,
        mode: MEMORY_SCOPE,
        updatedAt: Date.now(),
      });
      normalized.updatedAt = Date.now();
    }
    return normalized;
  }

  // V3.1.13: cheap-empty-profile fast path.
  // Without this, EVERY chat turn for a new user does 3 parallel Firestore reads
  // (work/personal/study legacy profiles) + 1 upsert = 4-5 subrequests, even
  // when there is nothing to migrate. We write a minimal global profile
  // immediately so the next call returns from the early branch above.
  const minimalProfile = mergeUnifiedProfile([], cfg);
  await fsUpsertDoc(accessToken, projectId, globalPath, {
    ...minimalProfile,
    mode: MEMORY_SCOPE,
    bootstrapped: true,
    updatedAt: Date.now()
  }).catch(() => null);
  minimalProfile.updatedAt = Date.now();
  return minimalProfile;
}

function activeNodeScope(node) {
  const scope = String(node?.modeScope || '').trim().toLowerCase();
  return MEMORY_SCOPE_COMPAT.includes(scope) ? scope : MEMORY_SCOPE;
}

function activeConnectionScope(edge) {
  const scope = String(edge?.modeScope || '').trim().toLowerCase();
  return MEMORY_SCOPE_COMPAT.includes(scope) ? scope : MEMORY_SCOPE;
}

function canonicalConnectionKey(fromId, toId, type) {
  const t = normalizeMemoryConnectionType(type);
  if (MEMORY_BIDIRECTIONAL_TYPES.has(t)) {
    const [a, b] = [String(fromId), String(toId)].sort();
    return `${t}:${a}:${b}`;
  }
  return `${t}:${fromId}:${toId}`;
}

function buildUnifiedMemoryView(nodes, connections) {
  const nowMs = Date.now();
  const activeNodes = (nodes || []).filter((n) => !n.deleted);
  const rootSource = activeNodes.find((n) => n.isRoot) || {
    id: 'root',
    label: 'You',
    normalizedKey: '__root__',
    aliases: [],
    group: 'identity',
    level: 0,
    parentId: '',
    count: 100,
    heat: 100,
    info: 'Root identity node for the user.',
    learned: false,
    isRoot: true,
    identityDefining: true,
    modeScope: MEMORY_SCOPE,
    sourceType: 'system',
    deleted: false,
    dateAdded: nowMs,
    lastMentioned: nowMs,
    suppressedUntil: 0
  };
  const groups = new Map();
  for (const node of activeNodes) {
    const key = node.isRoot ? '__root__' : (node.normalizedKey || normalizeMemoryKey(node.label) || node.id);
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(node);
  }
  if (!groups.has('__root__')) groups.set('__root__', [rootSource]);
  const unifiedNodes = [];
  const nodeIdToCanonicalId = {};
  const keyToCanonicalId = {};
  for (const [key, list] of groups.entries()) {
    const sorted = list.slice().sort((a, b) => {
      if (!!b.isRoot !== !!a.isRoot) return Number(!!b.isRoot) - Number(!!a.isRoot);
      if (activeNodeScope(b) === MEMORY_SCOPE && activeNodeScope(a) !== MEMORY_SCOPE) return 1;
      if (activeNodeScope(a) === MEMORY_SCOPE && activeNodeScope(b) !== MEMORY_SCOPE) return -1;
      return num(b.count, 0) - num(a.count, 0);
    });
    const canonical = sorted[0];
    const aliases = [];
    const seenAlias = new Set();
    for (const item of list) {
      for (const alias of [item.label, ...(Array.isArray(item.aliases) ? item.aliases : [])]) {
        const clean = trimMemoryText(alias, 100),
          aliasKey = normalizeMemoryKey(clean);
        if (!clean || !aliasKey || seenAlias.has(aliasKey)) continue;
        seenAlias.add(aliasKey);
        aliases.push(clean);
      }
    }
    const unified = {
      ...canonical,
      id: canonical.isRoot ? 'root' : canonical.id,
      normalizedKey: key === '__root__' ? '__root__' : key,
      label: canonical.label || aliases[0] || 'Topic',
      aliases,
      group: canonical.group || 'interest',
      level: canonical.isRoot ? 0 : Math.max(1, Math.min(4, Math.min(...list.map((item) => clampInt(item.level, 4, 1,
        4))))),
      count: canonical.isRoot ? 100 : list.reduce((sum, item) => sum + Math.max(1, num(item.count, 0)), 0),
      heat: Math.max(...list.map((item) => num(item.heat, 0)), canonical.isRoot ? 100 : 0),
      info: list.map((item) => trimMemoryText(item.info || '', 220)).find(Boolean) || '',
      learned: list.some((item) => !!item.learned),
      isRoot: !!canonical.isRoot,
      identityDefining: list.some((item) => !!item.identityDefining),
      modeScope: MEMORY_SCOPE,
      dateAdded: Math.min(...list.map((item) => Math.max(1, num(item.dateAdded, Date.now())))),
      lastMentioned: Math.max(...list.map((item) => num(item.lastMentioned, 0))),
      visualSize: memoryNodeSizeForCount(canonical.isRoot ? 100 : list.reduce((sum, item) => sum + Math.max(1, num(
        item.count, 0)), 0)),
    };
    unifiedNodes.push(unified);
    keyToCanonicalId[key] = unified.id;
    for (const item of list) nodeIdToCanonicalId[item.id] = unified.id;
  }
  const unifiedConnectionsMap = new Map();
  for (const edge of (connections || []).filter((c) => !c.deleted)) {
    const fromId = nodeIdToCanonicalId[edge.fromNodeId],
      toId = nodeIdToCanonicalId[edge.toNodeId];
    if (!fromId || !toId || fromId === toId) continue;
    const type = normalizeMemoryConnectionType(edge.type || 'RELATED');
    const key = canonicalConnectionKey(fromId, toId, type);
    const current = unifiedConnectionsMap.get(key);
    const normalized = {
      id: current?.id || buildMemoryConnectionId(MEMORY_SCOPE, fromId, toId, type),
      fromNodeId: MEMORY_BIDIRECTIONAL_TYPES.has(type) && fromId > toId ? toId : fromId,
      toNodeId: MEMORY_BIDIRECTIONAL_TYPES.has(type) && fromId > toId ? fromId : toId,
      type,
      coCount: (current?.coCount || 0) + Math.max(1, num(edge.coCount, 0)),
      reason: trimMemoryText(current?.reason || edge.reason || '', 180),
      modeScope: MEMORY_SCOPE,
      deleted: false,
      createdAt: current?.createdAt || num(edge.createdAt, Date.now()),
      lastUpdated: Math.max(num(current?.lastUpdated, 0), num(edge.lastUpdated, 0), Date.now()),
    };
    unifiedConnectionsMap.set(key, normalized);
  }
  const unifiedConnections = Array.from(unifiedConnectionsMap.values());
  return {
    nodes: unifiedNodes.sort((a, b) => (a.isRoot ? -1 : b.isRoot ? 1 : num(b.count, 0) - num(a.count, 0))),
    connections: unifiedConnections,
    nodeIdToCanonicalId,
    keyToCanonicalId
  };
}
async function ensureMemoryBootstrap(accessToken, projectId, uid, cfg, options = {}) {
  const userPath = `users/${uid}`;
  const userDoc = await fsGetDoc(accessToken, projectId, userPath);
  const user = parseFirestoreFields(userDoc?.fields || {});
  const patch = {};

  if (user.memoryEnabled == null) patch.memoryEnabled = !!cfg.memoryEnabledDefault;
  if (user.activeMemoryMode !== MEMORY_SCOPE) patch.activeMemoryMode = MEMORY_SCOPE;
  if (user.memoryNodeCount == null) patch.memoryNodeCount = 0;
  if (user.memoryConnectionCount == null) patch.memoryConnectionCount = 0;
  if (user.memoryEventCount == null) patch.memoryEventCount = 0;
  if (user.memorySessionCount == null) patch.memorySessionCount = 0;
  if (user.memoryAutoLearnedCount == null) patch.memoryAutoLearnedCount = 0;
  if (user.memoryLastProcessedAt == null) patch.memoryLastProcessedAt = 0;
  if (user.memoryLastDecayAt == null) patch.memoryLastDecayAt = 0;
  // SURGICAL PATCH: Track previous schema version so we can trigger a one-time
  // all-nodes migration when a new version rolls out.
  const priorSchemaVersion = num(user.memorySchemaVersion, 0);
  const needsNodeMigration = priorSchemaVersion > 0 && priorSchemaVersion < MEMORY_SCHEMA_VERSION;
  if (user.memorySchemaVersion == null || priorSchemaVersion < MEMORY_SCHEMA_VERSION) patch.memorySchemaVersion = MEMORY_SCHEMA_VERSION;
  if (!user.memoryVersion || String(user.memoryVersion).startsWith('memory-v1') || String(user.memoryVersion).startsWith('memory-v2')) patch.memoryVersion = MEMORY_VERSION;

  if (Object.keys(patch).length) {
    await fsPatchDoc(accessToken, projectId, userPath, patch);
  }

  const shouldEnsureProfile = options.ensureProfile !== false;
  const shouldEnsureRootIndex = options.ensureRootIndex !== false;
  const shouldEnsureOperationalDocs = options.ensureOperationalDocs !== false;

  if (shouldEnsureProfile) {
    await readUnifiedMemoryProfile(accessToken, projectId, uid, cfg);
  }

  const rootPath = `users/${uid}/memoryNodes/root`;
  let rootNode = parseFirestoreFields((await fsGetDoc(accessToken, projectId, rootPath))?.fields || {});
  if (!rootNode || !Object.keys(rootNode).length) {
    rootNode = {
      id: 'root',
      label: 'You',
      normalizedKey: '__root__',
      aliases: [],
      group: 'identity',
      level: 0,
      parentId: '',
      count: 100,
      heat: 100,
      info: 'Root identity node for the user.',
      learned: false,
      isRoot: true,
      identityDefining: true,
      modeScope: MEMORY_SCOPE,
      sourceType: 'system',
      deleted: false,
      dateAdded: Date.now(),
      lastMentioned: Date.now(),
      suppressedUntil: 0,
      linkedEventIds: [],
      eventCount: 0,
      lastEventAt: 0,
      schemaVersion: MEMORY_SCHEMA_VERSION,
    };
    await fsCreateDoc(accessToken, projectId, rootPath, rootNode);
  } else if (num(rootNode.schemaVersion, 0) < MEMORY_SCHEMA_VERSION) {
    await fsPatchDoc(accessToken, projectId, rootPath, {
      schemaVersion: MEMORY_SCHEMA_VERSION,
      linkedEventIds: Array.isArray(rootNode.linkedEventIds) ? rootNode.linkedEventIds : [],
      eventCount: num(rootNode.eventCount, 0),
      lastEventAt: num(rootNode.lastEventAt, 0)
    });
    rootNode = { ...rootNode, schemaVersion: MEMORY_SCHEMA_VERSION };
  }
  if (shouldEnsureRootIndex) {
    await syncNodeIndexDoc(accessToken, projectId, uid, rootNode);
  }
  if (shouldEnsureOperationalDocs) {
    await syncMemoryOperationalDocs(accessToken, projectId, uid);
  }

  // SURGICAL PATCH: One-time schema-aware migration of all existing memory nodes.
  // Only fires on a full bootstrap (not on lightweight /chat turns which pass
  // ensureOperationalDocs:false) AND only when the user's schema version was just bumped.
  // Bounded to 100 nodes per run so huge graphs migrate progressively without blowing subrequest budget.
  if (needsNodeMigration && shouldEnsureOperationalDocs) {
    try {
      const allNodes = await listMemoryNodes(accessToken, projectId, uid);
      const writes = [];
      for (const node of allNodes) {
        if (!node || node.deleted || node.isRoot) continue;
        if (num(node.schemaVersion, 0) >= MEMORY_SCHEMA_VERSION) continue;
        const migrPatch = {
          schemaVersion: MEMORY_SCHEMA_VERSION,
          linkedEventIds: Array.isArray(node.linkedEventIds) ? node.linkedEventIds : [],
          eventCount: num(node.eventCount, 0),
          lastEventAt: num(node.lastEventAt, 0),
          suppressedUntil: num(node.suppressedUntil, 0),
          aliases: Array.isArray(node.aliases) ? node.aliases : []
        };
        writes.push(makeFirestoreUpdateWrite(projectId, `users/${uid}/memoryNodes/${node.id}`, migrPatch));
        if (writes.length >= 100) break;
      }
      if (writes.length) {
        await fsCommitWritesInChunks(accessToken, projectId, writes, 100).catch(() => null);
      }
    } catch (_) {
      // Migration is best-effort; never block bootstrap on migration errors.
    }
  }
}

async function getMemoryInitPayload(accessToken, projectId, uid, cfg, _requestedMode) {
  const userDoc = await fsGetDoc(accessToken, projectId, `users/${uid}`);
  const user = parseFirestoreFields(userDoc?.fields || {});
  const profile = responseProfileForMode(await readUnifiedMemoryProfile(accessToken, projectId, uid, cfg), MEMORY_SCOPE);
  return {
    ok: true,
    uid,
    activeMode: MEMORY_SCOPE,
    memoryMeta: {
      memoryEnabled: user.memoryEnabled !== false,
      memoryNodeCount: num(user.memoryNodeCount, 0),
      memoryConnectionCount: num(user.memoryConnectionCount, 0),
      memoryAutoLearnedCount: num(user.memoryAutoLearnedCount, 0),
      memoryEventCount: num(user.memoryEventCount, 0),
      memorySessionCount: num(user.memorySessionCount, 0),
      memoryVersion: user.memoryVersion || MEMORY_VERSION,
      memorySchemaVersion: num(user.memorySchemaVersion, MEMORY_SCHEMA_VERSION),
      memoryLastProcessedAt: num(user.memoryLastProcessedAt, 0),
      memoryLastDecayAt: num(user.memoryLastDecayAt, 0),
    },
    profile,
  };
}

async function getMemoryProfilePayload(accessToken, projectId, uid, cfg, _requestedMode) {
  const userDoc = await fsGetDoc(accessToken, projectId, `users/${uid}`);
  const user = parseFirestoreFields(userDoc?.fields || {});
  const profile = responseProfileForMode(await readUnifiedMemoryProfile(accessToken, projectId, uid, cfg), MEMORY_SCOPE);
  return {
    ok: true,
    uid,
    activeMode: MEMORY_SCOPE,
    profile,
    memoryMeta: {
      memoryEnabled: user.memoryEnabled !== false,
      memoryNodeCount: num(user.memoryNodeCount, 0),
      memoryConnectionCount: num(user.memoryConnectionCount, 0),
      memoryAutoLearnedCount: num(user.memoryAutoLearnedCount, 0),
      memoryEventCount: num(user.memoryEventCount, 0),
      memorySessionCount: num(user.memorySessionCount, 0),
      memoryVersion: user.memoryVersion || MEMORY_VERSION,
      memorySchemaVersion: num(user.memorySchemaVersion, MEMORY_SCHEMA_VERSION),
    },
  };
}


function normalizeMemoryProfileInput(_mode, body, cfg) {
  const profile = {
    mode: MEMORY_SCOPE,
    name: trimMemoryText(body?.name, 60),
    focus: trimMemoryText(body?.focus || body?.currentFocus || body?.role, 160),
    projects: trimMemoryText(body?.projects || body?.currentProjects, 320),
    stack: trimMemoryText(body?.stack || body?.techStack, 220),
    goals: trimMemoryText(body?.goals || body?.currentGoals, 320),
    preferences: trimMemoryText(body?.preferences || body?.responsePreferences || body?.style || body?.communicationStyle, 220),
  };
  profile.role = profile.focus || '';
  profile.style = profile.preferences || '';
  profile.level = '';
  profile.avoid = '';
  profile.compressedPrompt = buildCompressedMemoryPrompt(profile, MEMORY_SCOPE, cfg);
  profile.updatedAt = Date.now();
  return profile;
}


function buildMemoryNodeId(modeScope, label) {
  return `n_${modeScope}_${normalizeMemoryKey(label) || Date.now()}`;
}

function buildMemoryCandidateId(modeScope, label) {
  return `c_${modeScope}_${normalizeMemoryKey(label) || Date.now()}`;
}

function buildMemoryConnectionId(modeScope, fromNodeId, toNodeId, type) {
  const t = normalizeMemoryConnectionType(type);
  if (MEMORY_BIDIRECTIONAL_TYPES.has(t)) {
    const [a, b] = [String(fromNodeId), String(toNodeId)].sort();
    return `e_${modeScope}_${t}_${a}_${b}`.replace(/[^a-zA-Z0-9_:-]/g, '_');
  }
  return `e_${modeScope}_${t}_${fromNodeId}_${toNodeId}`.replace(/[^a-zA-Z0-9_:-]/g, '_');
}

function memoryNodeSizeForCount(count) {
  const c = num(count, 0);
  if (c >= 16) return 40;
  if (c >= 9) return 32;
  if (c >= 4) return 26;
  if (c >= 1) return 20;
  return 16;
}
async function listMemoryNodes(accessToken, projectId, uid) {
  const docs = await fsListDocs(accessToken, projectId, `users/${uid}/memoryNodes`);
  return docs.map((doc) => ({
    ...parseFirestoreFields(doc.fields || {}),
    id: parseFirestoreFields(doc.fields || {}).id || docIdFromFsDoc(doc)
  }));
}
async function listMemoryConnections(accessToken, projectId, uid) {
  const docs = await fsListDocs(accessToken, projectId, `users/${uid}/memoryConnections`);
  return docs.map((doc) => ({
    ...parseFirestoreFields(doc.fields || {}),
    id: parseFirestoreFields(doc.fields || {}).id || docIdFromFsDoc(doc)
  }));
}
async function listMemoryCandidates(accessToken, projectId, uid) {
  const docs = await fsListDocs(accessToken, projectId, `users/${uid}/memoryCandidates`);
  return docs.map((doc) => ({
    ...parseFirestoreFields(doc.fields || {}),
    id: parseFirestoreFields(doc.fields || {}).id || docIdFromFsDoc(doc)
  })).filter((doc) => !doc.deleted && String(doc.status || '').toLowerCase() !== 'promoted');
}
async function listMemorySuppressions(accessToken, projectId, uid) {
  const docs = await fsListDocs(accessToken, projectId, `users/${uid}/memorySuppressions`);
  return docs.map((doc) => ({
    ...parseFirestoreFields(doc.fields || {}),
    id: parseFirestoreFields(doc.fields || {}).id || docIdFromFsDoc(doc)
  }));
}


function parseMemoryFsDocs(docs) {
  return (Array.isArray(docs) ? docs : []).map((doc) => ({
    ...parseFirestoreFields(doc.fields || {}),
    id: parseFirestoreFields(doc.fields || {}).id || docIdFromFsDoc(doc)
  }));
}

// ARCH Â§16 / V3.3.2 â€” quota-safe reads: capped list helpers are for UI/admin
// preview routes only. Core write-path helpers remain unchanged for correctness.
async function listMemoryCollectionCapped(accessToken, projectId, uid, collectionId, { limit = 50, orderField = 'updatedAt' } = {}) {
  const safeLimit = Math.max(1, Math.min(200, num(limit, 50)));
  try {
    const docs = await fsRunQuery(accessToken, projectId, `users/${uid}`, collectionId, {
      orderBy: [{ field: orderField, direction: 'DESCENDING' }],
      limit: safeLimit
    });
    const parsed = parseMemoryFsDocs(docs).filter((doc) => !doc.deleted);
    if (parsed.length) return parsed.slice(0, safeLimit);
  } catch (err) {
    console.log(`[quota_capped_query_fallback] collection=${collectionId}: ${String(err?.message || err).slice(0, 180)}`);
  }
  try {
    const docs = await fsListDocsOnePage(accessToken, projectId, `users/${uid}/${collectionId}`, safeLimit);
    return parseMemoryFsDocs(docs).filter((doc) => !doc.deleted).slice(0, safeLimit);
  } catch (err) {
    console.log(`[quota_capped_list_failed] collection=${collectionId}: ${String(err?.message || err).slice(0, 180)}`);
    return [];
  }
}

async function listMemoryNodesCapped(accessToken, projectId, uid, limit = MEMORY_GRAPH_NODE_LIMIT) {
  return listMemoryCollectionCapped(accessToken, projectId, uid, 'memoryNodes', { limit, orderField: 'updatedAt' });
}
async function listMemoryConnectionsCapped(accessToken, projectId, uid, limit = MEMORY_GRAPH_EDGE_LIMIT) {
  return listMemoryCollectionCapped(accessToken, projectId, uid, 'memoryConnections', { limit, orderField: 'lastUpdated' });
}
async function listMemoryEventsCapped(accessToken, projectId, uid, limit = MEMORY_GRAPH_EVENT_LIMIT) {
  return listMemoryCollectionCapped(accessToken, projectId, uid, 'memoryEvents', { limit, orderField: 'updatedAt' });
}
async function listMemoryCandidatesCapped(accessToken, projectId, uid, limit = MEMORY_CANDIDATE_LOAD_LIMIT) {
  const docs = await listMemoryCollectionCapped(accessToken, projectId, uid, 'memoryCandidates', { limit, orderField: 'lastSeenAt' });
  return docs.filter((doc) => String(doc.status || '').toLowerCase() !== 'promoted').slice(0, limit);
}
async function listMemorySessionsCapped(accessToken, projectId, uid, limit = MEMORY_GRAPH_SESSION_LIMIT) {
  return listMemoryCollectionCapped(accessToken, projectId, uid, 'memorySessions', { limit, orderField: 'lastActivityAt' });
}
async function listMemoryDebugLogsCapped(accessToken, projectId, uid, limit = MEMORY_DEBUG_LOG_LOAD_LIMIT) {
  return listMemoryCollectionCapped(accessToken, projectId, uid, 'memoryDebugLogs', { limit, orderField: 'createdAt' });
}
async function listMemoryLearningJobsCapped(accessToken, projectId, uid, limit = MEMORY_JOB_LOG_LIMIT) {
  return listMemoryCollectionCapped(accessToken, projectId, uid, 'memoryLearningJobs', { limit, orderField: 'updatedAt' });
}
async function listConsolidationQueueDocsCapped(accessToken, projectId, uid, limit = MEMORY_FINAL_STATUS_QUEUE_LIMIT) {
  return listMemoryCollectionCapped(accessToken, projectId, uid, 'consolidationQueue', { limit, orderField: 'updatedAt' });
}
async function listMergeAuditDocsCapped(accessToken, projectId, uid, limit = MEMORY_FINAL_STATUS_AUDIT_LIMIT) {
  return listMemoryCollectionCapped(accessToken, projectId, uid, 'mergeAudit', { limit, orderField: 'updatedAt' });
}
async function readMemoryStatsDoc(accessToken, projectId, uid) {
  const doc = await fsGetDoc(accessToken, projectId, `users/${uid}/memoryStats/global`).catch(() => null);
  return doc ? { ...parseFirestoreFields(doc.fields || {}), id: 'global' } : {};
}
async function upsertMemoryStatsSnapshot(accessToken, projectId, uid, patch = {}) {
  const nowMs = Date.now();
  const clean = {
    id: 'global',
    quotaSafeMode: MEMORY_QUOTA_SAFE_MODE,
    ...patch,
    updatedAt: patch.updatedAt || nowMs,
    schemaVersion: MEMORY_SCHEMA_VERSION
  };
  await fsUpsertDoc(accessToken, projectId, `users/${uid}/memoryStats/global`, clean);
  return clean;
}
function memoryStatsCount(stats, user, field, fallback) {
  return num(stats?.[field], num(user?.[field], fallback));
}

function findMemoryNodeByLabel(nodes, _mode, label) {
  const key = normalizeMemoryKey(label);
  if (!key) return null;
  return (nodes || []).find((n) => !n.deleted && ((n.normalizedKey || normalizeMemoryKey(n.label)) === key || (Array
    .isArray(n.aliases) && n.aliases.map(normalizeMemoryKey).includes(key)))) || null;
}

function graphModeFilter(item, _mode) {
  return !item.deleted && MEMORY_SCOPE_COMPAT.includes(activeNodeScope(item));
}

async function refreshMemoryMetaCounts(accessToken, projectId, uid) {
  const [nodes, connections, events, sessions] = await Promise.all([
    listMemoryNodes(accessToken, projectId, uid),
    listMemoryConnections(accessToken, projectId, uid),
    listMemoryEvents(accessToken, projectId, uid),
    listMemorySessions(accessToken, projectId, uid)
  ]);
  const unified = buildUnifiedMemoryView(nodes, connections);
  const autoLearnedCount = unified.nodes.filter((n) => n.learned && !n.deleted).length;
  const activeEvents = events.filter((e) => !e.deleted).length;
  const activeSessions = sessions.filter((s) => !s.deleted).length;
  await fsPatchDoc(accessToken, projectId, `users/${uid}`, {
    memoryNodeCount: unified.nodes.length,
    memoryConnectionCount: unified.connections.length,
    memoryEventCount: activeEvents,
    memorySessionCount: activeSessions,
    memoryAutoLearnedCount: autoLearnedCount,
    memoryLastProcessedAt: Date.now(),
    memoryVersion: MEMORY_VERSION,
    memorySchemaVersion: MEMORY_SCHEMA_VERSION
  });
  return {
    nodeCount: unified.nodes.length,
    connectionCount: unified.connections.length,
    eventCount: activeEvents,
    sessionCount: activeSessions,
    autoLearnedCount
  };
}

async function refreshMemoryStructureCounts(accessToken, projectId, uid) {
  const [nodes, connections] = await Promise.all([
    listMemoryNodes(accessToken, projectId, uid),
    listMemoryConnections(accessToken, projectId, uid)
  ]);
  const unified = buildUnifiedMemoryView(nodes, connections);
  const autoLearnedCount = unified.nodes.filter((n) => n.learned && !n.deleted).length;
  await fsPatchDoc(accessToken, projectId, `users/${uid}`, {
    memoryNodeCount: unified.nodes.length,
    memoryConnectionCount: unified.connections.length,
    memoryAutoLearnedCount: autoLearnedCount,
    memoryLastProcessedAt: Date.now(),
    memoryVersion: MEMORY_VERSION,
    memorySchemaVersion: MEMORY_SCHEMA_VERSION
  });
  return {
    nodeCount: unified.nodes.length,
    connectionCount: unified.connections.length,
    autoLearnedCount
  };
}


function buildDesiredProfileSeedSpecs(profile, _mode) {
  const specs = [];
  const focus = trimMemoryText(profile?.focus || profile?.currentFocus || profile?.role, 120);
  const preferences = trimMemoryText(profile?.preferences || profile?.responsePreferences || profile?.style, 140);

  if (focus) specs.push({
    label: focus,
    group: 'goal',
    relation: 'CONTEXT',
    level: 1,
    info: 'Current focus from unified memory profile.',
  });

  for (const label of splitMemoryItems(profile.projects, 8)) specs.push({
    label,
    group: 'project',
    relation: 'BUILDS',
    level: 2,
    info: 'Current project from unified memory profile.',
  });

  for (const label of splitMemoryItems(profile.stack, 10)) specs.push({
    label,
    group: 'skill',
    relation: 'USES',
    level: 3,
    info: 'Tech stack item from unified memory profile.',
  });

  for (const label of splitMemoryItems(profile.goals, 8)) specs.push({
    label,
    group: 'goal',
    relation: 'PURSUING',
    level: 2,
    info: 'Current goal from unified memory profile.',
  });

  if (preferences) specs.push({
    label: preferences,
    group: 'preference',
    relation: 'PREFERS',
    level: 1,
    info: 'Preferred response style from unified memory profile.',
  });

  return specs;
}

async function saveMemoryProfileAndSeeds(accessToken, projectId, uid, cfg, _requestedMode, body) {
  const unifiedProfile = normalizeMemoryProfileInput(MEMORY_SCOPE, body, cfg);
  await fsUpsertDoc(accessToken, projectId, `users/${uid}/memoryProfiles/${MEMORY_SCOPE}`, unifiedProfile);
  await fsPatchDoc(accessToken, projectId, `users/${uid}`, {
    activeMemoryMode: MEMORY_SCOPE,
    memoryEnabled: true,
    memoryVersion: MEMORY_VERSION,
    lastRequestAt: Date.now(),
  });

  if (unifiedProfile.name) {
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/root`, {
      label: unifiedProfile.name,
      info: `Root identity node for ${unifiedProfile.name}.`,
      lastMentioned: Date.now(),
    });
  }

  const nodes = await listMemoryNodes(accessToken, projectId, uid);
  const connections = await listMemoryConnections(accessToken, projectId, uid);
  const desired = buildDesiredProfileSeedSpecs(unifiedProfile, MEMORY_SCOPE);
  const desiredKeys = new Set(desired.map((x) => normalizeMemoryKey(x.label)));
  const touchedNodes = [];

  for (const spec of desired) {
    const key = normalizeMemoryKey(spec.label);
    const existing = nodes.find((n) => !n.deleted && normalizeMemoryKey(n.normalizedKey || n.label) === key) || null;
    const finalNodeId = existing?.id || buildMemoryNodeId(MEMORY_SCOPE, spec.label);

    const nodeDoc = {
      id: finalNodeId,
      label: spec.label,
      normalizedKey: key,
      aliases: [spec.label],
      group: spec.group,
      level: spec.level,
      parentId: 'root',
      count: Math.max(1, num(existing?.count, 0) || 1),
      heat: Math.max(45, num(existing?.heat, 0) || 55),
      info: spec.info,
      learned: false,
      isRoot: false,
      identityDefining: spec.group === 'preference',
      modeScope: MEMORY_SCOPE,
      sourceType: 'profile',
      deleted: false,
      dateAdded: num(existing?.dateAdded, Date.now()),
      lastMentioned: Date.now(),
      suppressedUntil: 0,
      linkedEventIds: Array.isArray(existing?.linkedEventIds) ? existing.linkedEventIds : [],
      eventCount: num(existing?.eventCount, 0),
      lastEventAt: num(existing?.lastEventAt, 0),
      schemaVersion: MEMORY_SCHEMA_VERSION,
    };
    await fsUpsertDoc(accessToken, projectId, `users/${uid}/memoryNodes/${finalNodeId}`, nodeDoc);
    touchedNodes.push(nodeDoc);

    const connId = buildMemoryConnectionId(MEMORY_SCOPE, 'root', finalNodeId, spec.relation);
    const existingConn = connections.find((c) => c.id === connId);
    await fsUpsertDoc(accessToken, projectId, `users/${uid}/memoryConnections/${connId}`, {
      id: connId,
      fromNodeId: 'root',
      toNodeId: finalNodeId,
      type: spec.relation,
      coCount: Math.max(1, num(existingConn?.coCount, 0) || 1),
      reason: 'Derived from saved unified memory profile.',
      modeScope: MEMORY_SCOPE,
      deleted: false,
      createdAt: num(existingConn?.createdAt, Date.now()),
      lastUpdated: Date.now(),
    });
  }

  // SURGICAL PATCH: Non-destructive profile save.
  // When a previously profile-sourced node is no longer listed in the new profile spec,
  // DO NOT delete it (users lost real memory that way when they edited their profile).
  // Instead, re-tag it as 'legacy_profile' so it stays in the graph, keeps all linked events,
  // and continues to surface in recall when relevant.
  for (const node of nodes) {
    if (node.isRoot) continue;
    if (node.sourceType !== 'profile') continue;
    if (node.deleted) continue;
    if (!desiredKeys.has(normalizeMemoryKey(node.normalizedKey || node.label))) {
      await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${node.id}`, {
        sourceType: 'legacy_profile',
        legacyFromProfileAt: Date.now(),
        lastMentioned: Date.now(),
      });
    }
  }

  // SURGICAL PATCH: Connection handling matches the non-destructive node rule above.
  // Profile->node edges for nodes that were re-tagged as legacy_profile are marked
  // 'historical' (a valid edge state from the architecture doctrine) instead of deleted.
  for (const conn of connections) {
    if (conn.deleted) continue;
    const targetNode = nodes.find((n) => n.id === conn.toNodeId);
    if (targetNode && targetNode.sourceType === 'profile' && !desiredKeys.has(normalizeMemoryKey(targetNode.normalizedKey || targetNode.label))) {
      await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryConnections/${conn.id}`, {
        state: 'historical',
        legacyFromProfileAt: Date.now(),
        lastUpdated: Date.now(),
      });
    }
  }

  for (const node of touchedNodes) {
    await syncNodeIndexDoc(accessToken, projectId, uid, node);
  }
  const counts = await refreshMemoryStructureCounts(accessToken, projectId, uid);
  return {
    ok: true,
    uid,
    activeMode: MEMORY_SCOPE,
    profile: responseProfileForMode(unifiedProfile, MEMORY_SCOPE),
    counts,
  };
}


function extractRecallTokens(text) {
  const clean = String(text || '').toLowerCase().replace(/[^a-z0-9\s_-]/g, ' ');
  return clean.split(/\s+/).map((x) => x.trim()).filter((x) => x && x.length >= 3 && !MEMORY_STOPWORDS.has(x));
}

function overlapScore(aTokens, bTokens) {
  const a = new Set(Array.isArray(aTokens) ? aTokens : []);
  const b = new Set(Array.isArray(bTokens) ? bTokens : []);
  if (!a.size || !b.size) return 0;
  let hits = 0;
  for (const token of a) if (b.has(token)) hits += 1;
  return hits ? hits / Math.max(1, Math.min(a.size, b.size)) : 0;
}

function inferRecallMode(messages, sourceTag = 'chat') {
  const userText = trimMemoryText(getLastUserMessageText(messages || []), 500);
  if (!userText) return 'none';
  const lower = userText.toLowerCase();
  if (MEMORY_RECALL_DEEP_CUES.some((cue) => lower.includes(cue))) {
    if (MEMORY_RECALL_UPDATE_CUES.some((cue) => lower.includes(cue))) return 'update';
    return 'deep';
  }
  const tokens = extractRecallTokens(userText);
  if (tokens.length < 2 && !/(project|goal|plan|build|memory|flutter|app)/.test(lower)) return 'none';
  return 'light';
}

function scoreNodeIndexCandidate(userTokens, profile, node) {
  const labelTokens = extractRecallTokens(`${node.label || ''} ${(Array.isArray(node.aliases) ? node.aliases.join(' ') : '')}`);
  const overlap = overlapScore(userTokens, labelTokens);
  const focusTokens = extractRecallTokens(`${profile?.focus || ''} ${profile?.projects || ''} ${profile?.goals || ''}`);
  const focusBonus = overlapScore(focusTokens, labelTokens) * 0.18;
  const heatBonus = Math.min(0.18, num(node.heat, 0) / 100 * 0.18);
  const activityBonus = Math.min(0.12, num(node.eventCount, 0) / 20 * 0.12);
  const exactBonus = userTokens.some((t) => normalizeMemoryKey(node.label || '').includes(t)) ? 0.22 : 0;
  return Number((overlap * 0.48 + focusBonus + heatBonus + activityBonus + exactBonus).toFixed(4));
}

function scoreEventIndexCandidate(userTokens, entryNodeIds, activeClusters, eventIndex) {
  const summaryTokens = extractRecallTokens(`${eventIndex.summary || ''} ${(Array.isArray(eventIndex.connectedNodeIds) ? eventIndex.connectedNodeIds.join(' ') : '')}`);
  const overlap = overlapScore(userTokens, summaryTokens);
  const nodeBonus = (Array.isArray(entryNodeIds) && entryNodeIds.includes(eventIndex.primaryNodeId)) ? 0.24 : ((Array.isArray(eventIndex.connectedNodeIds) && eventIndex.connectedNodeIds.some((id) => entryNodeIds.includes(id))) ? 0.14 : 0);
  const clusterBonus = (Array.isArray(eventIndex.clusterIds) ? eventIndex.clusterIds : []).some((id) => activeClusters.includes(id)) ? 0.12 : 0;
  const importance = String(eventIndex.importanceClass || 'ordinary').toLowerCase();
  const importanceBonus = importance === 'life_significant' ? 0.22 : importance === 'important' ? 0.14 : 0.04;
  const tier = String(eventIndex.memoryTier || 'warm').toLowerCase();
  const tierBonus = tier === 'hot' ? 0.16 : tier === 'permanent' ? 0.16 : tier === 'warm' ? 0.08 : 0.02;
  const confidenceBonus = Math.min(0.1, num(eventIndex.confidence, 0) * 0.1);
  return Number((overlap * 0.4 + nodeBonus + clusterBonus + importanceBonus + tierBonus + confidenceBonus).toFixed(4));
}

function buildRecallModeCaps(mode) {
  if (mode === 'deep' || mode === 'update') {
    return { maxNodes: MEMORY_RECALL_DEEP_NODE_CAP, maxEvents: MEMORY_RECALL_DEEP_EVENT_CAP };
  }
  return { maxNodes: MEMORY_RECALL_LIGHT_NODE_CAP, maxEvents: MEMORY_RECALL_LIGHT_EVENT_CAP };
}

function computeRelativeTimeLabel(ms) {
  const ts = num(ms, 0);
  if (!ts) return '';
  const days = Math.max(0, Math.floor((Date.now() - ts) / (24 * 60 * 60 * 1000)));
  if (days <= 1) return 'recently';
  if (days <= 7) return `${days}d ago`;
  if (days <= 30) return `${Math.round(days / 7)}w ago`;
  if (days <= 365) return `${Math.round(days / 30)}mo ago`;
  return `${Math.round(days / 365)}y ago`;
}

function buildRecallMemoryNote(profile, mode, rankedNodes, rankedEvents) {
  const lines = [];
  if (profile?.focus) lines.push(`Current focus: ${trimMemoryText(profile.focus, 140)}`);
  if (rankedNodes.length) {
    const nodeText = rankedNodes.map((item) => `${item.label} (${item.group || 'topic'})`).join(', ');
    lines.push(`Related nodes: ${trimMemoryText(nodeText, 240)}`);
  }
  if (rankedEvents.length) {
    lines.push('Relevant past context:');
    for (const event of rankedEvents) {
      const dateLabel = computeRelativeTimeLabel(event.updatedAt || event.endAt || event.createdAt);
      const prefix = [dateLabel, event.importanceClass === 'important' ? 'important' : '', event.status || 'recorded'].filter(Boolean).join(' â€¢ ');
      lines.push(`- ${prefix}: ${trimMemoryText(event.summary || '', 180)}`);
    }
  }
  let note = lines.join('\n');
  if (!note) return '';
  if (note.length > MEMORY_RECALL_MAX_NOTE_CHARS) note = note.slice(0, MEMORY_RECALL_MAX_NOTE_CHARS).trim();
  return `${note}\n\nUse only if directly relevant to this turn. Do not force memory references.`;
}

async function buildMemoryRecallRuntime(accessToken, projectId, uid, cfg, profile, payload = {}) {
  const messages = Array.isArray(payload?.messages) ? payload.messages : [];
  const sourceTag = trimMemoryText(payload?.sourceTag || 'chat', 40) || 'chat';
  const userText = trimMemoryText(getLastUserMessageText(messages), 500);
  const mode = inferRecallMode(messages, sourceTag);
  if (!userText || mode === 'none') {
    return { mode: 'none', prompt: '', note: '', entryNodes: [], nodes: [], events: [], activeClusters: [] };
  }

  const userTokens = extractRecallTokens(userText);
  const [nodeIndexDocs, eventIndexDocs, nodes, events] = await Promise.all([
    listNodeIndexDocs(accessToken, projectId, uid),
    listEventIndexDocs(accessToken, projectId, uid),
    listMemoryNodes(accessToken, projectId, uid),
    listMemoryEvents(accessToken, projectId, uid)
  ]);

  const rankedNodeIndexes = nodeIndexDocs
    .map((node) => ({ ...node, _score: scoreNodeIndexCandidate(userTokens, profile, node) }))
    .filter((node) => node._score >= 0.12)
    .sort((a, b) => num(b._score, 0) - num(a._score, 0))
    .slice(0, MEMORY_RECALL_NODE_CANDIDATE_CAP);

  const entryNodeIds = rankedNodeIndexes.slice(0, MEMORY_RECALL_ENTRY_NODE_CAP).map((node) => node.nodeId || node.id);
  const activeClusters = boundedUniqueIds(rankedNodeIndexes.map((node) => trimMemoryText(node.clusterId || node.type || '', 40)).filter(Boolean), 3);

  const rankedEventIndexes = eventIndexDocs
    .map((eventIndex) => ({ ...eventIndex, _score: scoreEventIndexCandidate(userTokens, entryNodeIds, activeClusters, eventIndex) }))
    .filter((eventIndex) => eventIndex._score >= 0.14)
    .sort((a, b) => num(b._score, 0) - num(a._score, 0))
    .slice(0, MEMORY_RECALL_EVENT_CANDIDATE_CAP);

  const caps = buildRecallModeCaps(mode);
  const chosenNodes = rankedNodeIndexes
    .slice(0, caps.maxNodes)
    .map((ranked) => nodes.find((node) => node.id === (ranked.nodeId || ranked.id)) || null)
    .filter(Boolean);

  const chosenEvents = rankedEventIndexes
    .slice(0, caps.maxEvents)
    .map((ranked) => events.find((event) => event.id === (ranked.eventId || ranked.id)) || null)
    .filter(Boolean);

  const note = buildRecallMemoryNote(profile, mode, chosenNodes, chosenEvents);
  const prompt = note ? `Relevant memory for this turn:\n${note}` : '';
  return {
    mode,
    prompt,
    note,
    entryNodes: rankedNodeIndexes.slice(0, MEMORY_RECALL_ENTRY_NODE_CAP).map((node) => ({
      nodeId: node.nodeId || node.id,
      label: node.label,
      score: node._score,
      clusterId: node.clusterId || node.type || 'general'
    })),
    activeClusters,
    nodes: chosenNodes.map((node) => ({
      id: node.id,
      label: node.label,
      group: node.group,
      heat: num(node.heat, 0),
      eventCount: num(node.eventCount, 0)
    })),
    events: chosenEvents.map((event) => ({
      id: event.id || event.eventId,
      summary: event.summary,
      importanceClass: event.importanceClass,
      status: event.status,
      memoryTier: event.memoryTier,
      absoluteDate: event.absoluteDate,
      updatedAt: event.updatedAt || event.createdAt,
      primaryNodeId: event.primaryNodeId
    }))
  };
}

// ============================================================================
// HYBRID RECALL ENGINE v2 (state-aware, event-aware, structured injection)
// ----------------------------------------------------------------------------
// Upgrade over buildMemoryRecallRuntime (v1 kept as fallback/preview):
//   * Hybrid entry detection: RRF fusion of lexical (nodeIndex) + vector
//     (memoryNodeEmbeddings) + bridge-context boost (pronoun resolution).
//   * Recall gate: none | light | deep | update decision.
//   * State-aware selection: prefers node.currentState + latest state-changing
//     event over older activity slices ("stopped boxing" overrides "trains boxing").
//   * Event-aware: surfaces life-significant + state-change events alongside nodes.
//   * Family competition: avoids dumping parent+child+sibling of the same concept;
//     picks the specific best target and its strongest supporting neighbor.
//   * Structured [MEMORY RECALL] block output with strict char caps for injection.
//   * Honest debug payload describing every selection step.
// ============================================================================

const MEMORY_RECALL_V2_RRF_K = 60;
const MEMORY_RECALL_V2_VECTOR_MIN_SCORE = 0.45;
const MEMORY_RECALL_V2_LEXICAL_MIN_SCORE = 0.12;
const MEMORY_RECALL_V2_ALIAS_EXACT_BONUS = 0.35;
const MEMORY_RECALL_V2_BRIDGE_BOOST = 0.20;
const MEMORY_RECALL_V2_ACTIVE_STATE_BONUS = 0.08;
const MEMORY_RECALL_V2_BLOCK_MAX_CHARS = 1400;
const MEMORY_RECALL_V2_LIGHT_NODE_CAP = 2;
const MEMORY_RECALL_V2_LIGHT_EVENT_CAP = 1;
const MEMORY_RECALL_V2_LIGHT_SLICE_CAP = 2;
const MEMORY_RECALL_V2_DEEP_NODE_CAP = 4;
const MEMORY_RECALL_V2_DEEP_EVENT_CAP = 3;
const MEMORY_RECALL_V2_DEEP_SLICE_CAP = 3;
const MEMORY_RECALL_V2_UPDATE_NODE_CAP = 2;
const MEMORY_RECALL_V2_UPDATE_EVENT_CAP = 2;
const MEMORY_RECALL_V2_UPDATE_SLICE_CAP = 2;
const MEMORY_RECALL_STATE_CHANGE_STATUSES = new Set(['started','stopped','paused','resumed','completed','blocked','fixed','launched','changed','cancelled','abandoned']);
const MEMORY_RECALL_UPDATE_STRONG_CUES = [
  'actually', 'i stopped', 'i paused', 'i resumed', 'i finished', 'i completed',
  'i changed', 'i moved to', 'i switched to', 'i now use', 'now im using', "now i'm using",
  'update this', 'update my', 'no longer', 'not anymore', "isn't working", 'fixed it', 'resolved'
];

function memoryRecallV2InferMode(userText, bridgeText = '', sourceTag = 'chat') {
  const raw = trimMemoryText(String(userText || ''), 600).toLowerCase().replace(/['\u2019]/g, "'");
  if (!raw) return { mode: 'none', reason: 'empty_user_text' };
  // Trivial chatter â†’ skip recall entirely.
  if (MEMORY_BLOCKED_CANDIDATE_REGEX.test(raw.trim())) return { mode: 'none', reason: 'trivial_chatter' };
  if (raw.length < 6 && !/\?/.test(raw)) return { mode: 'none', reason: 'too_short_no_question' };

  // Update mode: user correcting / changing known memory.
  for (const cue of MEMORY_RECALL_UPDATE_STRONG_CUES) {
    if (raw.includes(cue)) return { mode: 'update', reason: `update_cue:${cue}` };
  }
  // Deep mode: explicit history/review/compare questions.
  for (const cue of MEMORY_RECALL_DEEP_CUES) {
    if (raw.includes(cue)) return { mode: 'deep', reason: `deep_cue:${cue}` };
  }
  // Pronoun/reference-heavy turn â†’ light recall required for resolution.
  if (/\b(it|this|that|same|again|still|they|he|she|those|these|we)\b/.test(raw) || /\bthis (app|project|issue|thing|plan|goal|idea)\b/.test(raw)) {
    return { mode: 'light', reason: 'referential_cues' };
  }
  // Generic tokens that usually call for light recall.
  const toks = extractRecallTokens(raw);
  if (toks.length >= 2) return { mode: 'light', reason: 'token_density' };
  return { mode: 'none', reason: 'no_signal' };
}

function memoryRecallV2ModeCaps(mode) {
  if (mode === 'deep') return { nodes: MEMORY_RECALL_V2_DEEP_NODE_CAP, events: MEMORY_RECALL_V2_DEEP_EVENT_CAP, slices: MEMORY_RECALL_V2_DEEP_SLICE_CAP };
  if (mode === 'update') return { nodes: MEMORY_RECALL_V2_UPDATE_NODE_CAP, events: MEMORY_RECALL_V2_UPDATE_EVENT_CAP, slices: MEMORY_RECALL_V2_UPDATE_SLICE_CAP };
  return { nodes: MEMORY_RECALL_V2_LIGHT_NODE_CAP, events: MEMORY_RECALL_V2_LIGHT_EVENT_CAP, slices: MEMORY_RECALL_V2_LIGHT_SLICE_CAP };
}

function memoryRecallV2ExactAliasHit(nodeOrIndex, userText) {
  const labelTokens = new Set([
    normalizeMemoryKey(nodeOrIndex?.label || ''),
    ...(Array.isArray(nodeOrIndex?.aliases) ? nodeOrIndex.aliases.map((a) => normalizeMemoryKey(a || '')) : [])
  ].filter(Boolean));
  if (!labelTokens.size) return false;
  const userNorm = normalizeMemoryKey(String(userText || '')).split(/[^a-z0-9]+/).filter(Boolean);
  for (const tok of labelTokens) {
    if (!tok) continue;
    if (userNorm.includes(tok)) return true;
    if (tok.length > 3 && normalizeMemoryKey(String(userText || '')).includes(tok)) return true;
  }
  return false;
}

function memoryRecallV2BridgeHit(node, bridgeText) {
  if (!bridgeText) return false;
  const bridgeNorm = normalizeMemoryKey(String(bridgeText || ''));
  const labels = [node?.label || '', ...(Array.isArray(node?.aliases) ? node.aliases : [])].map((s) => normalizeMemoryKey(s || '')).filter((s) => s.length >= 3);
  for (const lbl of labels) {
    if (bridgeNorm.includes(lbl)) return true;
  }
  return false;
}

/**
 * Reciprocal Rank Fusion across three signal sources.
 * score(nodeId) = sum over sources s of 1 / (RRF_K + rank_in_source_s)
 * Each source returns an ordered list (best first).
 */
function memoryRecallV2FuseRankings({ lexical = [], vector = [], bridgeHits = [] }) {
  const scores = new Map();
  const addSource = (list) => {
    list.forEach((item, idx) => {
      const id = String(item?.nodeId || item?.id || '');
      if (!id) return;
      const prev = scores.get(id) || { id, score: 0, signals: [], refs: [] };
      prev.score += 1 / (MEMORY_RECALL_V2_RRF_K + idx + 1);
      if (!prev.signals.includes(item.source)) prev.signals.push(item.source);
      prev.refs.push({ source: item.source, rank: idx + 1, raw: num(item.score, 0) });
      scores.set(id, prev);
    });
  };
  addSource(lexical.map((x, i) => ({ ...x, source: 'lex', score: x._score })));
  addSource(vector.map((x, i) => ({ ...x, source: 'vec', score: x.similarity || x.score })));
  addSource(bridgeHits.map((x, i) => ({ ...x, source: 'bridge' })));
  return Array.from(scores.values()).sort((a, b) => b.score - a.score);
}

/**
 * Family competition: when results include generic parent (e.g., "Sports") and
 * specific child (e.g., "Football"), prefer the child when it has a comparable
 * or higher score. Avoids dumping the whole taxonomy.
 */
function memoryRecallV2SuppressFamilyDuplicates(fusedList, nodes) {
  const nodeById = new Map(nodes.map((n) => [String(n.id || ''), n]));
  const kept = [];
  const suppressedIds = new Set();
  for (const item of fusedList) {
    if (suppressedIds.has(item.id)) continue;
    const node = nodeById.get(item.id);
    if (!node) { kept.push(item); continue; }
    // If a descendant also present with comparable score, suppress parent.
    const myChildrenIds = new Set(Array.isArray(node.childIds) ? node.childIds : []);
    for (const other of fusedList) {
      if (other.id === item.id) continue;
      if (myChildrenIds.has(other.id) && other.score >= item.score * 0.75) {
        // This is a parent; defer to the more specific child.
        suppressedIds.add(item.id);
        break;
      }
    }
    if (!suppressedIds.has(item.id)) kept.push(item);
  }
  return kept;
}

/**
 * Pick the latest state-changing event for a given node, if any.
 * Prefers events whose status is a state-change verb, otherwise falls back to
 * the most-recently updated event.
 */
function memoryRecallV2EventStateToken(ev) {
  if (!ev) return '';
  const lifecycle = memoryProdNormalizeLifecycleAction(ev.lifecycleAction || '');
  if (lifecycle) return lifecycle;
  const type = String(ev.eventType || '').toLowerCase();
  for (const status of MEMORY_RECALL_STATE_CHANGE_STATUSES) {
    if (type === `lifecycle_${status}` || type.includes(status)) return status;
  }
  const status = String(ev.status || '').toLowerCase();
  return MEMORY_RECALL_STATE_CHANGE_STATUSES.has(status) ? status : '';
}

function memoryRecallV2PickLatestStateEventForNode(node, events) {
  if (!node || !Array.isArray(events) || !events.length) return null;
  const linked = events.filter((ev) => {
    if (!ev || ev.deleted) return false;
    if (String(ev.primaryNodeId || '') === String(node.id || '')) return true;
    const connected = Array.isArray(ev.connectedNodeIds) ? ev.connectedNodeIds : [];
    return connected.includes(node.id);
  });
  if (!linked.length) return null;
  const stateChange = linked.filter((ev) => !!memoryRecallV2EventStateToken(ev));
  const pool = stateChange.length ? stateChange : linked;
  pool.sort((a, b) => num(b.updatedAt || b.endAt || b.createdAt, 0) - num(a.updatedAt || a.endAt || a.createdAt, 0));
  return pool[0] || null;
}

/** Build the structured recall block that is injected into the model prompt. */
function memoryRecallV2BuildStructuredBlock({
  mode,
  confidence,
  selectedNodes = [],
  nodeStateEventMap = new Map(),
  relevantEvents = [],
  relevantSlices = [],
  entryNodes = []
}) {
  const lines = [];
  lines.push('[MEMORY RECALL]');
  lines.push(`Mode: ${mode}`);
  lines.push(`Confidence: ${confidence}`);
  lines.push('');

  // CURRENT STATE â€” node.currentState and a compact summary per selected node.
  const currentStateLines = [];
  for (const node of selectedNodes) {
    if (!node) continue;
    const state = trimMemoryText(String(node.currentState || ''), 50) || 'active';
    const summary = trimMemoryText(String(node.summary || ''), 160);
    currentStateLines.push(`- ${node.label}: ${state}${summary ? ` â€” ${summary}` : ''}`);
  }
  if (currentStateLines.length) {
    lines.push('[CURRENT STATE]');
    for (const l of currentStateLines) lines.push(l);
    lines.push('');
  }

  // RELEVANT EVENT(S) â€” prefer state-change events.
  if (relevantEvents.length) {
    lines.push('[RELEVANT EVENT]');
    for (const ev of relevantEvents) {
      const status = trimMemoryText(String(memoryRecallV2EventStateToken(ev) || ev.status || ev.eventType || ''), 40);
      const timeLabel = computeRelativeTimeLabel(num(ev.updatedAt || ev.endAt || ev.createdAt, 0));
      const impClass = String(ev.importanceClass || '').toLowerCase();
      const impLabel = impClass === 'life_significant' ? 'life-significant' : (impClass === 'important' ? 'important' : '');
      const prefix = [timeLabel, impLabel, status].filter(Boolean).join(' â€¢ ');
      const text = trimMemoryText(String(ev.summary || ''), 180);
      lines.push(`- ${prefix ? prefix + ': ' : ''}${text}`);
    }
    lines.push('');
  }

  // RELEVANT SLICES â€” compact readable history excerpts.
  if (relevantSlices.length) {
    lines.push('[RELEVANT SLICES]');
    for (const sl of relevantSlices) {
      const text = trimMemoryText(String(sl.summaryHint || sl.narrativeSummary || sl.text || ''), 160);
      if (!text) continue;
      lines.push(`- ${text}`);
    }
    lines.push('');
  }

  lines.push('[INSTRUCTION]');
  lines.push('Use current state and latest state-changing events as highest-priority truth.');
  lines.push('Do not assume older activity slices are still current if a later state change supersedes them.');
  lines.push('If memory confidence is weak, phrase cautiously and ask a clarifying question instead of guessing.');

  let block = lines.join('\n').trim();
  if (block.length > MEMORY_RECALL_V2_BLOCK_MAX_CHARS) {
    block = block.slice(0, MEMORY_RECALL_V2_BLOCK_MAX_CHARS - 3) + '...';
  }
  return block;
}

/**
 * Main v2 recall runtime.
 * Inputs: { userText, bridgeText, messages[], threadKey, sourceTag }
 * Uses: nodeIndex (lexical), node embeddings (vector), bridge text (pronoun),
 * events, existing profile, existing node docs.
 * Returns: { mode, prompt, confidence, entryNodes, nodes, events, debug }.
 */
async function buildMemoryRecallRuntimeV2(env, accessToken, projectId, uid, cfg, profile, payload = {}) {
  const nowMs = Date.now();
  const messages = Array.isArray(payload?.messages) ? payload.messages : [];
  const sourceTag = trimMemoryText(payload?.sourceTag || 'chat', 40) || 'chat';
  const threadKey = trimMemoryText(payload?.threadKey || buildMemoryThreadKey(payload?.threadId || '', sourceTag), 100);

  // 1. Derive user text & bridge text.
  let userText = trimMemoryText(getLastUserMessageText(messages), 500);
  let bridgeText = '';
  let bridgeMessagesForDebug = [];
  if (threadKey) {
    try {
      const bridgeRows = await memoryLogListRecentMessages(accessToken, projectId, uid, threadKey, MEMORY_LOG_RECALL_CONTEXT_WINDOW);
      const standardized = memoryLogToStandardMessages(bridgeRows);
      bridgeMessagesForDebug = standardized;
      if (!userText) {
        // Fall back to the latest user message in the backend log.
        const lastUser = [...standardized].reverse().find((m) => m.role === 'user');
        userText = trimMemoryText(lastUser?.content || '', 500);
      }
      // Bridge text excludes the current user message if the log happens to include it.
      bridgeText = standardized
        .filter((m) => m.content.trim() !== userText.trim())
        .slice(-MEMORY_LOG_RECALL_CONTEXT_WINDOW)
        .map((m) => `${m.role}: ${trimMemoryText(m.content, 240)}`)
        .join('\n');
    } catch (_) { /* bridge is optional; proceed */ }
  }

  // 2. Recall gate.
  const modeDecision = memoryRecallV2InferMode(userText, bridgeText, sourceTag);
  const mode = modeDecision.mode;
  if (mode === 'none') {
    return {
      mode: 'none',
      prompt: '',
      note: '',
      confidence: 'none',
      entryNodes: [],
      nodes: [],
      events: [],
      slices: [],
      activeClusters: [],
      debug: {
        version: 'v2',
        threadKey,
        userTextLen: userText.length,
        bridgeMessagesCount: bridgeMessagesForDebug.length,
        gate: modeDecision,
        lexicalCandidates: [],
        vectorCandidates: [],
        bridgeHits: [],
        fused: [],
        selected: [],
        stateEvents: [],
        injected: false
      }
    };
  }

  // V3.1.13: empty-memory bypass.
  // For brand-new users (no learned nodes yet), the 4-list parallel fetch +
  // embeddings call burns 10-15 subrequests for no recall benefit (there is
  // nothing to recall). The recall path was contributing to "Too many
  // subrequests" failures. We use the user doc's stable counters to check;
  // if ANY of them is > 0 we proceed normally. The check uses the profile
  // we already loaded, so it is FREE (no extra fetch).
  const learnedNodeCount = num(profile?.memoryAutoLearnedCount, 0)
                          + num(profile?.memoryNodeCount, 0)
                          + num(profile?.memoryEventCount, 0)
                          + num(profile?.memoryConnectionCount, 0);
  if (learnedNodeCount === 0) {
    return {
      mode: 'none',
      prompt: '',
      note: '',
      confidence: 'none',
      entryNodes: [],
      nodes: [],
      events: [],
      slices: [],
      activeClusters: [],
      debug: {
        version: 'v2',
        threadKey,
        userTextLen: userText.length,
        bridgeMessagesCount: bridgeMessagesForDebug.length,
        gate: { ...modeDecision, bypass: 'empty_memory_no_recall_needed' },
        lexicalCandidates: [],
        vectorCandidates: [],
        bridgeHits: [],
        fused: [],
        selected: [],
        stateEvents: [],
        injected: false
      }
    };
  }

  // 3. Gather recall material.
  const [nodeIndexDocs, eventIndexDocs, nodes, events] = await Promise.all([
    listNodeIndexDocs(accessToken, projectId, uid).catch(() => []),
    listEventIndexDocs(accessToken, projectId, uid).catch(() => []),
    listMemoryNodes(accessToken, projectId, uid).catch(() => []),
    listMemoryEvents(accessToken, projectId, uid).catch(() => [])
  ]);

  // 3a. Lexical ranking over nodeIndex (keyword/alias/BM25-style overlap).
  const userTokens = extractRecallTokens(userText);
  const lexicalRanked = nodeIndexDocs
    .map((node) => {
      const score = scoreNodeIndexCandidate(userTokens, profile, node);
      const aliasExact = memoryRecallV2ExactAliasHit(node, userText);
      return {
        nodeId: String(node.nodeId || node.id || ''),
        id: String(node.nodeId || node.id || ''),
        label: node.label,
        _score: score + (aliasExact ? MEMORY_RECALL_V2_ALIAS_EXACT_BONUS : 0),
        aliasExact
      };
    })
    .filter((n) => n.nodeId && n._score >= MEMORY_RECALL_V2_LEXICAL_MIN_SCORE)
    .sort((a, b) => b._score - a._score)
    .slice(0, 12);

  // 3b. Vector ranking via existing embeddings infra.
  // memoryProdSemanticShortlistNodes returns { items, available, ... }, not a raw array.
  // V3 treated that object as an array, so vector recall stayed empty.
  let vectorRanked = [];
  try {
    const semanticResult = await memoryProdSemanticShortlistNodes(
      env, accessToken, projectId, uid, cfg, userText, bridgeText, nodes, 8
    ).catch(() => ({ items: [], available: false }));
    const semanticHits = Array.isArray(semanticResult?.items) ? semanticResult.items : [];
    vectorRanked = semanticHits
      .map((h) => {
        const similarity = num(h?.semanticScore ?? h?.similarity ?? h?.score, 0);
        return {
          nodeId: String(h.nodeId || h.id || ''),
          id: String(h.nodeId || h.id || ''),
          label: h.label,
          similarity
        };
      })
      .filter((h) => h.nodeId && h.similarity >= MEMORY_RECALL_V2_VECTOR_MIN_SCORE);
  } catch (_) { vectorRanked = []; }

  // 3c. Bridge-context hits: nodes whose labels appear in the bridge text.
  const bridgeHits = nodes
    .filter((n) => n && !n.deleted && memoryRecallV2BridgeHit(n, bridgeText))
    .map((n) => ({ nodeId: String(n.id || ''), id: String(n.id || ''), label: n.label }))
    .slice(0, 6);

  // 4. RRF fusion.
  const fused = memoryRecallV2FuseRankings({ lexical: lexicalRanked, vector: vectorRanked, bridgeHits });
  // Additive boosts: active currentState, bridge hit, exact alias (already applied to lexical).
  const nodeById = new Map(nodes.map((n) => [String(n.id || ''), n]));
  for (const item of fused) {
    const n = nodeById.get(item.id);
    if (!n) continue;
    if (String(n.currentState || 'active').toLowerCase() === 'active') item.score += MEMORY_RECALL_V2_ACTIVE_STATE_BONUS;
    if (bridgeHits.some((b) => b.id === item.id)) item.score += MEMORY_RECALL_V2_BRIDGE_BOOST;
  }
  fused.sort((a, b) => b.score - a.score);

  // 5. Family competition.
  const deduped = memoryRecallV2SuppressFamilyDuplicates(fused, nodes);

  // 6. Apply caps + state-aware selection.
  const caps = memoryRecallV2ModeCaps(mode);
  const selectedFused = deduped.slice(0, caps.nodes);
  const selectedNodes = selectedFused.map((it) => nodeById.get(it.id)).filter(Boolean);

  // Per-node: latest state-change event.
  const nodeStateEventMap = new Map();
  const stateEventList = [];
  for (const n of selectedNodes) {
    const ev = memoryRecallV2PickLatestStateEventForNode(n, events);
    if (ev) {
      nodeStateEventMap.set(n.id, ev);
      stateEventList.push(ev);
    }
  }

  // Rank events: prefer state-change events for selected nodes, then top-scoring event index hits.
  const entryNodeIds = selectedNodes.map((n) => n.id);
  const activeClusters = boundedUniqueIds(
    selectedNodes.map((n) => trimMemoryText(n.clusterId || n.group || '', 40)).filter(Boolean),
    3
  );
  const rankedEventIndexes = eventIndexDocs
    .map((ei) => ({ ...ei, _score: scoreEventIndexCandidate(userTokens, entryNodeIds, activeClusters, ei) }))
    .filter((ei) => ei._score >= 0.14)
    .sort((a, b) => b._score - a._score)
    .slice(0, caps.events * 3);

  // Compose final event list: state-change events first, then top-ranked index hits, dedupe.
  const eventsSeen = new Set();
  const chosenEvents = [];
  for (const ev of stateEventList) {
    if (chosenEvents.length >= caps.events) break;
    const id = String(ev.id || '');
    if (!id || eventsSeen.has(id)) continue;
    eventsSeen.add(id);
    chosenEvents.push(ev);
  }
  for (const ei of rankedEventIndexes) {
    if (chosenEvents.length >= caps.events) break;
    const eid = String(ei.eventId || ei.id || '');
    if (!eid || eventsSeen.has(eid)) continue;
    const full = events.find((e) => String(e.id || '') === eid || String(e.eventId || '') === eid);
    if (!full) continue;
    eventsSeen.add(eid);
    chosenEvents.push(full);
  }

  // 7. Slice selection (deep/update only).
  const chosenSlices = [];
  if (caps.slices > 0 && selectedNodes.length) {
    try {
      const topNode = selectedNodes[0];
      const liveSlices = await memoryProdListLiveSlicesForNode(accessToken, projectId, uid, topNode.id).catch(() => []);
      const sortedSlices = (Array.isArray(liveSlices) ? liveSlices : [])
        .filter((s) => s && !s.rolledUp)
        .sort((a, b) => num(b.updatedAt || b.createdAt, 0) - num(a.updatedAt || a.createdAt, 0));
      for (const sl of sortedSlices.slice(0, caps.slices)) {
        chosenSlices.push({
          id: sl.id,
          nodeId: sl.nodeId,
          summaryHint: sl.summaryHint,
          narrativeSummary: sl.narrativeSummary,
          text: sl.summaryHint || sl.narrativeSummary || sl.text,
          updatedAt: sl.updatedAt || sl.createdAt
        });
      }
    } catch (_) { /* slice fetch is best-effort */ }
  }

  // 8. Confidence estimation.
  let confidence = 'medium';
  if (selectedFused[0]?.score >= 0.06 && (selectedFused[0]?.signals || []).length >= 2) confidence = 'high';
  else if (!selectedNodes.length) confidence = 'low';
  else if ((selectedFused[0]?.signals || []).length <= 1 && selectedFused[0]?.score < 0.03) confidence = 'low';

  // 9. Build structured block.
  const block = memoryRecallV2BuildStructuredBlock({
    mode,
    confidence,
    selectedNodes,
    nodeStateEventMap,
    relevantEvents: chosenEvents,
    relevantSlices: chosenSlices,
    entryNodes: selectedNodes.map((n) => ({ id: n.id, label: n.label }))
  });

  const entryNodes = selectedNodes.map((n) => ({
    nodeId: n.id,
    label: n.label,
    clusterId: n.clusterId || n.group || 'general',
    currentState: n.currentState || 'active',
    score: (selectedFused.find((f) => f.id === n.id) || {}).score || 0,
    signals: (selectedFused.find((f) => f.id === n.id) || {}).signals || []
  }));

  return {
    mode,
    prompt: selectedNodes.length ? block : '',
    note: block,
    confidence,
    entryNodes,
    activeClusters,
    nodes: selectedNodes.map((n) => ({
      id: n.id,
      label: n.label,
      group: n.group,
      currentState: n.currentState || 'active',
      summary: trimMemoryText(n.summary || '', 200),
      heat: num(n.heat, 0),
      eventCount: num(n.eventCount, 0)
    })),
    events: chosenEvents.map((ev) => ({
      id: ev.id || ev.eventId,
      summary: ev.summary,
      status: ev.status,
      importanceClass: ev.importanceClass,
      memoryTier: ev.memoryTier,
      absoluteDate: ev.absoluteDate,
      updatedAt: ev.updatedAt || ev.createdAt,
      primaryNodeId: ev.primaryNodeId
    })),
    slices: chosenSlices,
    debug: {
      version: 'v2',
      threadKey,
      userTextLen: userText.length,
      bridgeTextLen: bridgeText.length,
      bridgeMessagesCount: bridgeMessagesForDebug.length,
      gate: modeDecision,
      lexicalCandidates: lexicalRanked.slice(0, 8).map((x) => ({ id: x.id, label: x.label, score: num(x._score, 0), aliasExact: x.aliasExact })),
      vectorCandidates: vectorRanked.slice(0, 8).map((x) => ({ id: x.id, label: x.label, similarity: x.similarity })),
      bridgeHits: bridgeHits.map((x) => ({ id: x.id, label: x.label })),
      fused: deduped.slice(0, 8).map((f) => ({ id: f.id, score: Number(f.score.toFixed(5)), signals: f.signals })),
      selected: entryNodes,
      stateEvents: stateEventList.map((ev) => ({ id: ev.id, status: ev.status, lifecycleAction: ev.lifecycleAction || '', eventType: ev.eventType || '', stateToken: memoryRecallV2EventStateToken(ev), importanceClass: ev.importanceClass })),
      injected: !!selectedNodes.length,
      blockChars: block.length,
      caps,
      elapsedMs: Date.now() - nowMs
    }
  };
}

async function buildMemoryRecallPreviewPayload(accessToken, projectId, uid, cfg, payload = {}, env = null) {
  await ensureMemoryBootstrap(accessToken, projectId, uid, cfg);
  const profile = await readUnifiedMemoryProfile(accessToken, projectId, uid, cfg);
  // Prefer V2 when env is available (needed for embeddings). Fall back to V1 otherwise.
  const runtime = env
    ? await buildMemoryRecallRuntimeV2(env, accessToken, projectId, uid, cfg, profile, payload || {}).catch(async () => buildMemoryRecallRuntime(accessToken, projectId, uid, cfg, profile, payload || {}))
    : await buildMemoryRecallRuntime(accessToken, projectId, uid, cfg, profile, payload || {});
  return {
    ok: true,
    uid,
    activeMode: MEMORY_SCOPE,
    profile: responseProfileForMode(profile, MEMORY_SCOPE),
    recall: runtime
  };
}

async function getInjectedMemoryContext(accessToken, projectId, uid, cfg, _requestedMode, payload = {}, env = null) {
  const userDoc = await fsGetDoc(accessToken, projectId, `users/${uid}`);
  const user = parseFirestoreFields(userDoc?.fields || {});
  if (user.memoryEnabled === false) {
    return { mode: MEMORY_SCOPE, prompt: '', profile: null, recall: { mode: 'none', prompt: '', note: '' } };
  }
  const profile = await readUnifiedMemoryProfile(accessToken, projectId, uid, cfg);
  const profilePrompt = buildInjectedMemoryPromptFromProfile(profile, MEMORY_SCOPE, cfg);
  let recall;
  if (env) {
    try {
      recall = await buildMemoryRecallRuntimeV2(env, accessToken, projectId, uid, cfg, profile, payload || {});
    } catch (e) {
      // Safe degradation: fall back to v1 runtime if v2 fails; never crash /chat.
      console.log(`[recall_v2_failed_fallback_v1] ${String(e?.message || e)}`);
      recall = await buildMemoryRecallRuntime(accessToken, projectId, uid, cfg, profile, payload || {});
    }
  } else {
    recall = await buildMemoryRecallRuntime(accessToken, projectId, uid, cfg, profile, payload || {});
  }
  const prompt = [profilePrompt, recall.prompt].filter(Boolean).join('\n\n');
  return {
    mode: MEMORY_SCOPE,
    prompt,
    profile,
    recall
  };
}


async function getMemoryGraphPayload(accessToken, projectId, uid, cfg, _requestedMode) {
  const quotaSafe = MEMORY_QUOTA_SAFE_MODE;
  const [nodes, connections, events, sessions, userDoc, statsDoc, profile] = await Promise.all([
    quotaSafe ? listMemoryNodesCapped(accessToken, projectId, uid, MEMORY_GRAPH_NODE_LIMIT) : listMemoryNodes(accessToken, projectId, uid),
    quotaSafe ? listMemoryConnectionsCapped(accessToken, projectId, uid, MEMORY_GRAPH_EDGE_LIMIT) : listMemoryConnections(accessToken, projectId, uid),
    quotaSafe ? listMemoryEventsCapped(accessToken, projectId, uid, MEMORY_GRAPH_EVENT_LIMIT) : listMemoryEvents(accessToken, projectId, uid),
    quotaSafe ? listMemorySessionsCapped(accessToken, projectId, uid, MEMORY_GRAPH_SESSION_LIMIT) : listMemorySessions(accessToken, projectId, uid),
    fsGetDoc(accessToken, projectId, `users/${uid}`),
    readMemoryStatsDoc(accessToken, projectId, uid),
    readUnifiedMemoryProfile(accessToken, projectId, uid, cfg),
  ]);
  const unified = buildUnifiedMemoryView(nodes, connections);
  const user = parseFirestoreFields(userDoc?.fields || {});
  const activeNodes = (nodes || []).filter((n) => !n.deleted);
  const activeConnections = (connections || []).filter((c) => !c.deleted);
  const activeEvents = (events || []).filter((e) => !e.deleted);
  const activeSessions = (sessions || []).filter((s) => !s.deleted);
  const previewCounts = {
    nodeCount: activeNodes.length,
    connectionCount: activeConnections.length,
    eventCount: activeEvents.length,
    sessionCount: activeSessions.length,
    autoLearnedCount: activeNodes.filter((n) => n.learned).length,
  };
  const memoryMetaCounts = {
    nodeCount: memoryStatsCount(statsDoc, user, 'nodeCount', previewCounts.nodeCount),
    connectionCount: memoryStatsCount(statsDoc, user, 'connectionCount', previewCounts.connectionCount),
    eventCount: memoryStatsCount(statsDoc, user, 'eventCount', previewCounts.eventCount),
    sessionCount: memoryStatsCount(statsDoc, user, 'sessionCount', previewCounts.sessionCount),
    autoLearnedCount: memoryStatsCount(statsDoc, user, 'autoLearnedCount', previewCounts.autoLearnedCount),
  };
  const limited = quotaSafe && (
    activeNodes.length >= MEMORY_GRAPH_NODE_LIMIT ||
    activeConnections.length >= MEMORY_GRAPH_EDGE_LIMIT ||
    activeEvents.length >= MEMORY_GRAPH_EVENT_LIMIT ||
    activeSessions.length >= MEMORY_GRAPH_SESSION_LIMIT
  );

  return {
    ok: true,
    uid,
    mode: MEMORY_SCOPE,
    activeMode: MEMORY_SCOPE,
    quotaSafeMode: quotaSafe,
    limited,
    limits: { nodes: MEMORY_GRAPH_NODE_LIMIT, connections: MEMORY_GRAPH_EDGE_LIMIT, events: MEMORY_GRAPH_EVENT_LIMIT, sessions: MEMORY_GRAPH_SESSION_LIMIT },
    hasMore: limited,
    profile: responseProfileForMode(profile, MEMORY_SCOPE),
    stats: {
      nodes: memoryMetaCounts.nodeCount,
      connections: memoryMetaCounts.connectionCount,
      events: memoryMetaCounts.eventCount,
      sessions: memoryMetaCounts.sessionCount,
      autoLearned: memoryMetaCounts.autoLearnedCount,
      previewNodes: unified.nodes.length,
      previewConnections: unified.connections.length,
      previewEvents: activeEvents.length,
    },
    nodes: unified.nodes.map((n) => ({
      ...n,
      visualSize: n.isRoot ? 48 : memoryNodeSizeForCount(n.count),
      modeScope: MEMORY_SCOPE,
    })),
    connections: unified.connections,
    recentEventPreview: activeEvents.sort((a, b) => num(b.updatedAt || b.createdAt, 0) - num(a.updatedAt || a.createdAt, 0)).slice(0, 12).map((e) => ({
      id: e.id,
      summary: trimMemoryText(e.summary || '', 180),
      eventType: trimMemoryText(e.eventType || '', 60),
      lifecycleAction: trimMemoryText(e.lifecycleAction || '', 40),
      primaryNodeId: trimMemoryText(e.primaryNodeId || '', 160),
      connectedNodeIds: boundedUniqueIds(e.connectedNodeIds || [], 8),
      evidencePreview: Array.isArray(e.evidence) ? e.evidence.slice(0, 2).map((item) => trimMemoryText(item?.snippet || '', 120)).filter(Boolean) : [],
      updatedAt: num(e.updatedAt || e.createdAt, 0)
    })),
    recentConnectionPreview: activeConnections.sort((a, b) => num(b.lastUpdated || 0, 0) - num(a.lastUpdated || 0, 0)).slice(0, 16).map((c) => ({
      id: c.id, fromNodeId: c.fromNodeId, toNodeId: c.toNodeId, type: c.type, coCount: num(c.coCount, 0), state: trimMemoryText(c.state || '', 40), lastUpdated: num(c.lastUpdated || 0, 0)
    })),
    memoryMeta: {
      activeMode: MEMORY_SCOPE,
      memoryEnabled: user.memoryEnabled !== false,
      memoryNodeCount: memoryMetaCounts.nodeCount,
      memoryConnectionCount: memoryMetaCounts.connectionCount,
      memoryEventCount: memoryMetaCounts.eventCount,
      memorySessionCount: memoryMetaCounts.sessionCount,
      memoryAutoLearnedCount: memoryMetaCounts.autoLearnedCount,
      memoryVersion: user.memoryVersion || MEMORY_VERSION,
      memorySchemaVersion: num(user.memorySchemaVersion, MEMORY_SCHEMA_VERSION),
    },
  };
}

async function getMemoryFinalStatusPayload(accessToken, projectId, uid, cfg) {
  const quotaSafe = MEMORY_QUOTA_SAFE_MODE;
  const [userDoc, profile, nodes, connections, events, sessions, queueDocs, auditDocs, jobDocs, candidates, logs, statsDoc] = await Promise.all([
    fsGetDoc(accessToken, projectId, `users/${uid}`),
    readUnifiedMemoryProfile(accessToken, projectId, uid, cfg),
    quotaSafe ? listMemoryNodesCapped(accessToken, projectId, uid, MEMORY_GRAPH_NODE_LIMIT) : listMemoryNodes(accessToken, projectId, uid),
    quotaSafe ? listMemoryConnectionsCapped(accessToken, projectId, uid, MEMORY_GRAPH_EDGE_LIMIT) : listMemoryConnections(accessToken, projectId, uid),
    quotaSafe ? listMemoryEventsCapped(accessToken, projectId, uid, MEMORY_GRAPH_EVENT_LIMIT) : listMemoryEvents(accessToken, projectId, uid),
    quotaSafe ? listMemorySessionsCapped(accessToken, projectId, uid, MEMORY_GRAPH_SESSION_LIMIT) : listMemorySessions(accessToken, projectId, uid),
    quotaSafe ? listConsolidationQueueDocsCapped(accessToken, projectId, uid, MEMORY_FINAL_STATUS_QUEUE_LIMIT) : listConsolidationQueueDocs(accessToken, projectId, uid),
    quotaSafe ? listMergeAuditDocsCapped(accessToken, projectId, uid, MEMORY_FINAL_STATUS_AUDIT_LIMIT) : listMergeAuditDocs(accessToken, projectId, uid),
    quotaSafe ? listMemoryLearningJobsCapped(accessToken, projectId, uid, MEMORY_JOB_LOG_LIMIT) : listJobStateDocs(accessToken, projectId, uid),
    quotaSafe ? listMemoryCandidatesCapped(accessToken, projectId, uid, MEMORY_CANDIDATE_LOAD_LIMIT) : listMemoryCandidates(accessToken, projectId, uid),
    quotaSafe ? listMemoryDebugLogsCapped(accessToken, projectId, uid, MEMORY_DEBUG_LOG_LOAD_LIMIT) : listMemoryDebugLogs(accessToken, projectId, uid),
    readMemoryStatsDoc(accessToken, projectId, uid),
  ]);

  const user = parseFirestoreFields(userDoc?.fields || {});
  const unified = buildUnifiedMemoryView(nodes, connections);
  const activeNodes = unified.nodes.filter((n) => !n.deleted);
  const activeEvents = (events || []).filter((e) => !e.deleted);
  const activeSessions = (sessions || []).filter((s) => !s.deleted);
  const activeCandidates = (candidates || []).filter((c) => !c.deleted && String(c.status || '').toLowerCase() !== 'promoted');
  const clusterSummary = buildClusterSummaryFromNodes(activeNodes);
  const recentLogs = (logs || []).sort((a, b) => num(b.createdAt, 0) - num(a.createdAt, 0)).slice(0, quotaSafe ? MEMORY_DEBUG_LOG_LOAD_LIMIT : 8);
  const latestPipeline = buildLatestPipelineFromLogs(recentLogs);

  const tierCounts = { hot: 0, warm: 0, cold: 0, permanent: 0 };
  for (const node of activeNodes) {
    const importanceClass = node.importanceClass || (node.identityDefining ? 'important' : 'ordinary');
    const tier = computeMemoryTierFromTimestamps(node.lastMentioned || node.dateAdded || Date.now(), importanceClass);
    if (tierCounts[tier] != null) tierCounts[tier] += 1;
  }
  const eventTierCounts = { hot: 0, warm: 0, cold: 0, permanent: 0 };
  for (const event of activeEvents) {
    const tier = String(event.memoryTier || computeMemoryTierFromTimestamps(event.updatedAt || event.createdAt || Date.now(), event.importanceClass)).toLowerCase();
    if (eventTierCounts[tier] != null) eventTierCounts[tier] += 1;
  }
  const pendingReviewCount = (queueDocs || []).filter((q) => !q.deleted && (String(q.outcome || '').toLowerCase() === 'pendingreview' || String(q.outcome || '').toLowerCase() === 'pending_review' || String(q.status || '').toLowerCase() === 'pending_review')).length;
  const activeJobCount = (jobDocs || []).filter((j) => !j.deleted).length;
  const metaCounts = { nodeCount: memoryStatsCount(statsDoc, user, 'nodeCount', activeNodes.length), connectionCount: memoryStatsCount(statsDoc, user, 'connectionCount', unified.connections.length), candidateCount: memoryStatsCount(statsDoc, user, 'candidateCount', activeCandidates.length), eventCount: memoryStatsCount(statsDoc, user, 'eventCount', activeEvents.length), sessionCount: memoryStatsCount(statsDoc, user, 'sessionCount', activeSessions.length), autoLearnedCount: memoryStatsCount(statsDoc, user, 'autoLearnedCount', activeNodes.filter((n) => n.learned).length) };

  return {
    ok: true, uid, activeMode: MEMORY_SCOPE, quotaSafeMode: quotaSafe, limited: quotaSafe,
    limits: { nodes: MEMORY_GRAPH_NODE_LIMIT, connections: MEMORY_GRAPH_EDGE_LIMIT, candidates: MEMORY_CANDIDATE_LOAD_LIMIT, events: MEMORY_GRAPH_EVENT_LIMIT, sessions: MEMORY_GRAPH_SESSION_LIMIT, queue: MEMORY_FINAL_STATUS_QUEUE_LIMIT, audits: MEMORY_FINAL_STATUS_AUDIT_LIMIT, jobs: MEMORY_JOB_LOG_LIMIT, debugLogs: MEMORY_DEBUG_LOG_LOAD_LIMIT },
    profile: responseProfileForMode(profile, MEMORY_SCOPE),
    memoryMeta: { memoryEnabled: user.memoryEnabled !== false, memoryNodeCount: metaCounts.nodeCount, memoryConnectionCount: metaCounts.connectionCount, memoryCandidateCount: metaCounts.candidateCount, memoryEventCount: metaCounts.eventCount, memorySessionCount: metaCounts.sessionCount, memoryAutoLearnedCount: metaCounts.autoLearnedCount, memoryVersion: user.memoryVersion || MEMORY_VERSION, memorySchemaVersion: num(user.memorySchemaVersion, MEMORY_SCHEMA_VERSION), memoryLastProcessedAt: num(user.memoryLastProcessedAt || statsDoc.lastLearningAt, 0), memoryLastDecayAt: num(user.memoryLastDecayAt, 0) },
    stats: { nodes: metaCounts.nodeCount, connections: metaCounts.connectionCount, candidates: metaCounts.candidateCount, events: metaCounts.eventCount, sessions: metaCounts.sessionCount, clusters: clusterSummary.total, hot: tierCounts.hot, warm: tierCounts.warm, cold: tierCounts.cold, permanent: tierCounts.permanent, pendingReview: pendingReviewCount, audits: (auditDocs || []).filter((a) => !a.deleted).length, jobs: activeJobCount, debugLogs: recentLogs.length, previewNodes: activeNodes.length, previewConnections: unified.connections.length, previewEvents: activeEvents.length },
    tiers: tierCounts,
    eventTiers: eventTierCounts,
    clusterSummary,
    latestPipeline,
    candidatesPreview: activeCandidates.sort((a, b) => num(b.lastSeenAt || b.updatedAt || b.createdAt, 0) - num(a.lastSeenAt || a.updatedAt || a.createdAt, 0)).slice(0, 10).map((c) => ({ id: c.id, label: c.label || '', status: c.status || 'candidate', strength: c.strength || '', evidenceCount: Array.isArray(c.evidence) ? c.evidence.length : 0, expiresAt: num(c.expiresAt, 0), updatedAt: num(c.updatedAt || c.lastSeenAt || c.createdAt, 0) })),
    recentEvents: activeEvents.sort((a, b) => num(b.updatedAt || b.createdAt, 0) - num(a.updatedAt || a.createdAt, 0)).slice(0, 8).map((e) => ({ id: e.id, summary: trimMemoryText(e.summary || '', 180), eventType: trimMemoryText(e.eventType || '', 60), lifecycleAction: trimMemoryText(e.lifecycleAction || '', 40), primaryNodeId: trimMemoryText(e.primaryNodeId || '', 160), updatedAt: num(e.updatedAt || e.createdAt, 0) })),
    recentLogs,
  };
}

async function deleteMemoryNode(accessToken, projectId, uid, cfg, nodeId, mode) {
  const nodes = await listMemoryNodes(accessToken, projectId, uid);
  const target = nodes.find((n) => n.id === nodeId);
  if (!target) throw new Error('node not found');
  if (target.isRoot) throw new Error('root node cannot be deleted');
  const key = target.normalizedKey || normalizeMemoryKey(target.label);
  const matches = nodes.filter((n) => !n.deleted && !n.isRoot && ((n.normalizedKey || normalizeMemoryKey(n.label)) ===
    key));
  for (const node of matches) {
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${node.id}`, {
      deleted: true,
      deletedAt: Date.now(),
      suppressedUntil: Date.now() + num(cfg.memorySuppressionDays, 45) * 24 * 60 * 60 * 1000
    });
  }
  const connections = await listMemoryConnections(accessToken, projectId, uid);
  const matchIds = new Set(matches.map((n) => n.id));
  for (const conn of connections) {
    if (conn.deleted) continue;
    if (matchIds.has(conn.fromNodeId) || matchIds.has(conn.toNodeId)) {
      await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryConnections/${conn.id}`, {
        deleted: true,
        lastUpdated: Date.now()
      });
    }
  }
  const suppressionId = `sup_${MEMORY_SCOPE}_${key}`;
  await fsUpsertDoc(accessToken, projectId, `users/${uid}/memorySuppressions/${suppressionId}`, {
    id: suppressionId,
    normalizedKey: key,
    label: target.label,
    modeScope: MEMORY_SCOPE,
    suppressedUntil: Date.now() + num(cfg.memorySuppressionDays, 45) * 24 * 60 * 60 * 1000,
    createdAt: Date.now(),
    reason: 'user_deleted_node'
  });
  await syncMemoryNodeIndexes(accessToken, projectId, uid, await listMemoryNodes(accessToken, projectId, uid));
  const counts = await refreshMemoryMetaCounts(accessToken, projectId, uid);
  return {
    ok: true,
    uid,
    mode,
    deletedNodeId: nodeId,
    counts
  };
}
const MEMORY_SIMULATION_BANK = {
  global: [{
    label: 'Play Store Launch',
    group: 'goal',
    parentLabel: 'GPMai',
    type: 'PURSUING',
    level: 3,
    info: 'Launch milestone for the app.'
  }, {
    label: 'Prompt Chips',
    group: 'project',
    parentLabel: 'GPMai',
    type: 'HAS',
    level: 3,
    info: 'Prompt helper feature in GPMai.'
  }, {
    label: 'Pricing',
    group: 'interest',
    parentLabel: 'GPMai',
    type: 'RELATED',
    level: 4,
    info: 'Pricing and monetization topic.'
  }, ],
  personal_legacy: [{
    label: 'Fitness',
    group: 'personal',
    parentLabel: 'root',
    type: 'RELATED',
    level: 3,
    info: 'Personal lifestyle topic.'
  }, {
    label: 'Routine',
    group: 'goal',
    parentLabel: 'root',
    type: 'PURSUING',
    level: 3,
    info: 'Consistency and habits.'
  }, ],
  study_legacy: [{
    label: 'System Design',
    group: 'skill',
    parentLabel: 'root',
    type: 'USES',
    level: 3,
    info: 'Learning systems and architecture.'
  }, {
    label: 'TypeScript',
    group: 'skill',
    parentLabel: 'root',
    type: 'USES',
    level: 4,
    info: 'Learning topic in study mode.'
  }, ],
};
async function simulateMemoryLearn(accessToken, projectId, uid, cfg, mode) {
  const bank = MEMORY_SIMULATION_BANK.global || MEMORY_SIMULATION_BANK.work;
  const pick = bank[Math.floor(Math.random() * bank.length)];
  const out = await createOrPromoteMemoryTopic(accessToken, projectId, uid, cfg, {
    mode,
    label: pick.label,
    group: pick.group,
    parentLabel: pick.parentLabel,
    type: pick.type,
    suggestedLevel: pick.level,
    info: pick.info,
    strength: 'strong',
    sourceType: 'simulated'
  });
  await syncMemoryNodeIndexes(accessToken, projectId, uid, await listMemoryNodes(accessToken, projectId, uid));
  const counts = await refreshMemoryMetaCounts(accessToken, projectId, uid);
  return {
    ok: true,
    uid,
    mode,
    newMemory: out.node || null,
    counts,
    toast: `ðŸ§  New memory: ${pick.label} (Level ${pick.level} â€” linked)`
  };
}
async function buildMemoryChatPreview(env, accessToken, projectId, uid, cfg, _mode, body) {
  const profile = await readUnifiedMemoryProfile(accessToken, projectId, uid, cfg);
  const question = trimMemoryText(body?.question || 'What should I build first?', 160) || 'What should I build first?';
  const name = profile.name || 'you';
  const project = splitMemoryItems(profile.projects, 1)[0] || 'your project';
  const stack = splitMemoryItems(profile.stack, 2).join(', ') || 'your stack';
  const goal = splitMemoryItems(profile.goals, 1)[0] || 'your next goal';
  const focus = trimMemoryText(profile.focus || profile.role, 120) || 'your main priority';
  // Prefer V2 recall when env is available; fall back to V1 on any error.
  let recallPreview;
  try {
    recallPreview = await buildMemoryRecallRuntimeV2(env, accessToken, projectId, uid, cfg, profile, {
      messages: [{ role: 'user', content: question }],
      sourceTag: trimMemoryText(body?.sourceTag || 'chat', 40) || 'chat',
      threadId: trimMemoryText(body?.threadId || '', 120),
      threadKey: body?.threadId ? buildMemoryThreadKey(body.threadId, body?.sourceTag || 'chat') : ''
    });
  } catch (e) {
    recallPreview = await buildMemoryRecallRuntime(accessToken, projectId, uid, cfg, profile, {
      messages: [{ role: 'user', content: question }],
      sourceTag: trimMemoryText(body?.sourceTag || 'chat', 40) || 'chat'
    });
  }

  const withMemory = `${name}, based on your current memory profile, prioritize the next highest-leverage step for ${project}. Keep the answer aligned with your current focus on ${focus}, your stack of ${stack}, and your goal of ${goal}. Start with the smallest move that creates visible product momentum, then harden onboarding, usage tracking, and pricing.`;
  const withoutMemory = `Before deciding what to build first, I need more context about your project, current goals, timeline, and tech stack. What are you building, who is it for, and what matters most right now?`;

  return {
    ok: true,
    uid,
    mode: MEMORY_SCOPE,
    question,
    memoryActive: true,
    withMemory,
    withoutMemory,
    profileSummary: profile.compressedPrompt || buildCompressedMemoryPrompt(profile, MEMORY_SCOPE, cfg),
    recallPreview
  };
}



async function buildMemoryWritePreviewPayload(env, accessToken, projectId, uid, cfg, body = {}) {
  const rawMessages = Array.isArray(body?.messages) ? body.messages : [];
  const question = trimMemoryText(body?.question || body?.userText || '', 600);
  const messages = rawMessages.length ? rawMessages : (question ? [{ role: 'user', content: question }] : []);
  if (!messages.length) return { ok: false, error: 'messages required' };

  const sourceTag = trimMemoryText(body?.sourceTag || 'chat', 40).toLowerCase() || 'chat';
  const threadId = trimMemoryText(body?.threadId || body?.chatId || body?.conversationId || '', 120);
  const assistantText = trimMemoryText(body?.assistantText || '', 1000);
  const nowMs = Date.now();
  const threadKey = buildMemoryThreadKey(threadId, sourceTag);
  const threadDoc = parseFirestoreFields((await fsGetDoc(accessToken, projectId, `users/${uid}/memoryThreads/${threadKey}`).catch(() => null))?.fields || {});
  const activeSessionId = trimMemoryText(threadDoc?.activeSessionId || '', 120);
  const activeSession = activeSessionId
    ? parseFirestoreFields((await fsGetDoc(accessToken, projectId, `users/${uid}/memorySessions/${activeSessionId}`).catch(() => null))?.fields || {})
    : null;
  const session = activeSession && Object.keys(activeSession).length
    ? activeSession
    : {
        id: buildMemorySessionId(threadKey, nowMs),
        threadKey,
        sourceTag,
        threadId,
        startedAt: nowMs,
        lastActivityAt: 0,
        turnCount: 0,
        messageCount: 0,
        countedTopicKeys: [],
        linkedEventIds: [],
        lastEventId: '',
        lastProcessedMessageCount: 0,
        lastProcessedLastUserHash: '',
        lastProcessedMessageSignature: '',
        lastProcessedAt: 0,
        checkpointExpiresAt: 0,
        pendingSinceAt: 0,
        pendingSliceMessageCount: 0,
        pendingSliceCharCount: 0,
        pendingTriggerReason: '',
        lastExtractionReason: '',
        nextEligibleExtractAt: 0,
        modeScope: MEMORY_SCOPE,
      };

  const sliceMessages = memoryProdGetUnprocessedMessageSlice(session, messages);
  const nodes = await listMemoryNodes(accessToken, projectId, uid);
  const connections = await listMemoryConnections(accessToken, projectId, uid);
  const candidates = await listMemoryCandidates(accessToken, projectId, uid);
  const suppressions = await listMemorySuppressions(accessToken, projectId, uid);
  const view = buildUnifiedMemoryView(nodes, connections);
  const trigger = memoryProdClassifyExtractionTrigger(session, messages, sliceMessages, assistantText, body || {}, cfg);
  // Use async packet builder so preview reflects the real production triage + semantic layer.
  const packet = await memoryProdBuildExtractionPacketAsync(env, accessToken, projectId, uid, session, messages, sliceMessages, assistantText, view.nodes, body || {}, cfg, trigger);
  const learned = trigger.shouldExtract
    ? await memoryProdAnalyzeConversationForMemory(env, cfg, MEMORY_SCOPE, view.nodes, packet)
    : { reinforce_labels: [], candidates: [], relation_hints: [], new_nodes: [], new_connections: [], packetPreview: packet.packetPreview };

  const predictions = [];
  for (const item of Array.isArray(learned?.candidates) ? learned.candidates : []) {
    const existingNode = memoryProdFindBestExistingNodeMatch(view.nodes, item) || findMemoryNodeByLabel(view.nodes, MEMORY_SCOPE, item?.label || '');
    if (existingNode && !existingNode.deleted) {
      predictions.push({ label: item.label, outcome: 'reinforce_existing', nodeId: existingNode.id, nodeLabel: existingNode.label });
      continue;
    }
    const key = normalizeMemoryKey(item?.label || '');
    const existingCandidate = candidates.find((c) => c.id === buildMemoryCandidateId(MEMORY_SCOPE, item?.label || '') || normalizeMemoryKey(c.normalizedKey || c.label) === key);
    const suppression = suppressions.find((s) => !s.deleted && normalizeMemoryKey(s.normalizedKey || s.label) === key && num(s.suppressedUntil, 0) > nowMs);
    if (suppression) {
      predictions.push({ label: item.label, outcome: 'suppressed', reason: 'suppression_window_active' });
      continue;
    }
    const sameSession = !!session?.id && trimMemoryText(existingCandidate?.lastSessionId || '', 120) === trimMemoryText(session?.id || '', 120);
    const nextSessionCount = existingCandidate ? Math.max(1, num(existingCandidate.sessionCount, 1) + (sameSession ? 0 : 1)) : 1;
    const threshold = memoryProdGroupPromotionThreshold(item?.roleGuess, cfg, item?.strength);
    const willPromote = nextSessionCount >= threshold || (memoryProdShouldFastPromoteGroup(item?.roleGuess) && memoryProdNormalizeStrength(item?.strength) === 'strong');
    predictions.push({
      label: item.label,
      outcome: willPromote ? 'promote_node' : 'candidate_only',
      sessionCountPreview: nextSessionCount,
      threshold,
      group: item?.roleGuess || '',
      strength: item?.strength || ''
    });
  }

  return {
    ok: true,
    uid,
    activeMode: MEMORY_SCOPE,
    session: {
      id: trimMemoryText(session?.id || '', 160),
      threadKey: trimMemoryText(session?.threadKey || threadKey, 120),
      sourceTag,
      lastProcessedMessageCount: Math.max(0, num(session?.lastProcessedMessageCount, 0)),
      lastProcessedAt: num(session?.lastProcessedAt, 0),
      linkedEventIds: boundedUniqueIds(session?.linkedEventIds || [], 8),
      pendingSliceMessageCount: Array.isArray(sliceMessages) ? sliceMessages.length : 0,
    },
    trigger,
    packetPreview: packet.packetPreview,
    profileSummary: responseProfileForMode(await readUnifiedMemoryProfile(accessToken, projectId, uid, cfg), MEMORY_SCOPE).compressedPrompt || '',
    extraction: {
      incrementNodes: Array.isArray(learned?.reinforce_labels) ? learned.reinforce_labels.slice(0, 12) : [],
      newNodes: Array.isArray(learned?.candidates) ? learned.candidates.slice(0, 12) : [],
      relationHints: Array.isArray(learned?.relation_hints) ? learned.relation_hints.slice(0, 12) : [],
    },
    predictions,
    counts: {
      currentNodes: view.nodes.filter((n) => !n.deleted).length,
      currentConnections: view.connections.filter((e) => !e.deleted).length,
      activeCandidates: candidates.filter((c) => !c.deleted && String(c.status || '').toLowerCase() !== 'promoted').length,
    }
  };
}


function shouldQueueMemoryLearning(messages, assistantText, sourceTag) {
  const src = String(sourceTag || 'chat').toLowerCase();
  if (!/(chat|debate|canvas|research|orb|screen|voice)/.test(src)) return false;
  const userText = trimMemoryText(getLastUserMessageText(messages), 400);
  if (!userText) return false;
  const wordCount = userText.split(/\s+/).filter(Boolean).length;
  const userMessageCount = (Array.isArray(messages) ? messages : []).filter((m) => String(m?.role || '').toLowerCase() === 'user').length;
  if (memoryProdHasHighSignalCue(userText) || memoryProdIsLifeMemoryText(userText) || memoryProdHasPreferenceCue(userText)) return true;
  if (memoryProdUserTextLooksTrivial(userText)) return false;
  if (userMessageCount <= 1 && wordCount >= 3 && userText.length >= 18) return true;
  if (wordCount < 5) return false;
  if (userText.length < 35) return false;
  return true;
}


function getLastUserMessageText(messages) {
  const safe = Array.isArray(messages) ? messages : [];
  for (let i = safe.length - 1; i >= 0; i--)
    if (String(safe[i]?.role || '').toLowerCase() === 'user') return typeof safe[i]?.content === 'string' ? safe[i]
      .content : String(safe[i]?.content || '');
  return '';
}

function summarizeMessagesForMemory(messages, assistantText) {
  const safe = Array.isArray(messages) ? messages.slice(-12) : [];
  const chunks = [];
  for (const m of safe) {
    const role = String(m?.role || 'user').toLowerCase();
    const content = trimMemoryText(typeof m?.content === 'string' ? m.content : String(m?.content || ''), 800);
    if (content) chunks.push(`${role.toUpperCase()}: ${content}`);
  }
  const assistant = trimMemoryText(assistantText, 1000);
  if (assistant) chunks.push(`ASSISTANT: ${assistant}`);
  return chunks.join('\n\n').slice(0, 7000);
}


function memoryProdSliceHasOnlyTrivialUserContent(messages) {
  const userTexts = (Array.isArray(messages) ? messages : [])
    .filter((m) => String(m?.role || '').toLowerCase() === 'user')
    .map((m) => trimMemoryText(typeof m?.content === 'string' ? m.content : String(m?.content || ''), 400))
    .filter(Boolean);
  if (!userTexts.length) return false;
  return userTexts.every((text) => memoryProdUserTextLooksTrivial(text));
}

function memoryProdShouldOmitAssistantTextForLogSlice(useBackendLog, sliceMessages, assistantText) {
  const assistant = trimMemoryText(assistantText || '', 1000);
  if (!useBackendLog || !assistant) return false;
  return (Array.isArray(sliceMessages) ? sliceMessages : []).some((m) => {
    if (String(m?.role || '').toLowerCase() !== 'assistant') return false;
    const content = trimMemoryText(typeof m?.content === 'string' ? m.content : String(m?.content || ''), 1000);
    return content && content === assistant;
  });
}

async function memoryLogBuildRecentChatMessagesForModel(accessToken, projectId, uid, threadKey, fallbackMessages = [], limit = 18) {
  const fallback = Array.isArray(fallbackMessages) ? fallbackMessages.map((m) => ({
    role: String(m?.role || 'user'),
    content: typeof m?.content === 'string' ? m.content : String(m?.content || '')
  })).filter((m) => m.content.trim()) : [];
  if (!threadKey) return fallback;
  try {
    const rows = await memoryLogListRecentMessages(accessToken, projectId, uid, threadKey, limit);
    const logMessages = memoryLogToStandardMessages(rows)
      .filter((m) => ['user', 'assistant', 'system'].includes(String(m.role || '').toLowerCase()));
    if (!logMessages.length) return fallback;
    const clientSystem = fallback.filter((m) => String(m.role || '').toLowerCase() === 'system');
    return [...clientSystem, ...logMessages];
  } catch (_) {
    return fallback;
  }
}
function buildExistingMemorySummary(nodes, _mode) {
  return memoryProdBuildExistingMemorySummary(nodes, _mode);
}

function buildMemoryLearningUserPrompt(_mode, packet) {
  return memoryProdBuildMemoryLearningUserPrompt(_mode, packet);
}

async function analyzeConversationForMemory(env, cfg, mode, nodes, packet) {
  return memoryProdAnalyzeConversationForMemory(env, cfg, mode, nodes, packet);
}

function groupPromotionThreshold(group, cfg, strength = 'medium') {
  return memoryProdGroupPromotionThreshold(group, cfg, strength);
}

async function createOrPromoteMemoryTopic(accessToken, projectId, uid, cfg, item) {
  return memoryProdCreateOrPromoteMemoryTopic(accessToken, projectId, uid, cfg, item);
}

function inferConnectionTypeForGroup(group) {
  const g = normalizeMemoryGroup(group);
  if (g === 'project') return 'part_of';
  if (g === 'skill') return 'uses';
  if (g === 'goal') return 'drives';
  if (g === 'habit') return 'supports';
  if (g === 'preference') return 'related_to';
  return 'related_to';
}

function inferImportanceForLabel(label, group = '', info = '') {
  const hay = `${label || ''} ${group || ''} ${info || ''}`.toLowerCase();
  if (/(death|died|funeral|bereav|grief|surgery|injury|hospital|breakup|divorce|migration|moved country|serious accident|trauma|abuse|ptsd|family crisis|parents are getting divorced|grandfather died|grandmother died|mother died|father died)/.test(hay)) return 'life_significant';
  if (/(launch|production|ship|shipping|release|deadline|play store|income|career|project|goal|exam|business|startup|worker|firestore|diagnos|disorder|therapy|medicine|medication|allerg|migraine|asthma|diabetes|ocd|adhd|autis|anxiety|depress|panic)/.test(hay)) return 'important';
  return ['identity', 'goal', 'project', 'preference'].includes(normalizeMemoryGroup(group)) ? 'important' : 'ordinary';
}

function inferClusterIdForNode(label, group = '', info = '') {
  const labelHay = String(label || '').toLowerCase();
  const hay = `${label || ''} ${group || ''} ${info || ''}`.toLowerCase();
  // V3.3.3: primary-domain labels win before cross-cutting condition words.
  if (/(flutter|worker|firestore|play store|habitflow|gpmai|app|backend|frontend|code|debug|launch|product|project|startup|business|career|income|ai brain|architecture|api|repo)/.test(hay)) return 'work';
  if (/(football|soccer|sports|match|team|boxing|jab|hook punch|sparring|kickboxing|tennis|gym|running|swimming|athlete|training)/.test(labelHay)) return 'sports';
  if (/(family|friend|relationship|girlfriend|wife|parent|mother|father|grandfather|grandmother|brother|sister|divorce|breakup|grief|death|died|funeral)/.test(hay)) return 'relationships';
  if (/(learn|learning|study|course|reading|practice|skill|exam|lesson|technique)/.test(hay)) return 'learning';
  if (/(health|sleep|diet|workout|injury|pain|recovery|medicine|medication|therapy|diagnos|disorder|anxiety|depress|ocd|adhd|autis|migraine|asthma|diabetes|allerg|stroke|surgery|hospital|rehab|physio|chronic)/.test(hay)) return 'health';
  if (/(money|finance|saving|budget|income|salary|invoice|expense|debt|loan)/.test(hay)) return 'finance';
  return normalizeMemoryGroup(group) === 'identity' ? 'personal' : 'general';
}
async function incrementMemoryNodesByLabels(accessToken, projectId, uid, mode, labels, nowMs = Date.now(), sessionId = '') {
  return memoryProdIncrementMemoryNodesByLabels(accessToken, projectId, uid, mode, labels, nowMs, sessionId);
}

async function upsertMemoryConnectionsFromLearned(accessToken, projectId, uid, mode, learnedConnections, nowMs = Date.now(), existingNodes = null) {
  return memoryProdUpsertMemoryConnectionsFromLearned(accessToken, projectId, uid, mode, learnedConnections, nowMs, existingNodes);
}

async function processConversationMemoryTurn(env, accessToken, projectId, uid, cfg, payload) {
  const debugStages = Array.isArray(payload?._debugStages) ? payload._debugStages : [];
  const pushStage = (stage) => {
    try { debugStages.push(stage); } catch (_) {}
  };
  const nowMs = Date.now();
  const traceBase = {
    nowMs,
    sourceTag: payload?.sourceTag,
    threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
    threadKey: payload?.threadKey || buildMemoryThreadKey(payload?.threadId || payload?.chatId || payload?.conversationId || '', payload?.sourceTag || 'chat'),
    userMsgId: payload?.userMsgId || payload?.linkedUserMsgId || '',
    assistantMsgId: payload?.assistantMsgId || '',
    triggerReason: payload?.triggerReason || 'chat_turn_complete'
  };
  pushStage('learning_call_entered');
  await writeMemoryLearningTrace(accessToken, projectId, uid, {
    ...traceBase,
    stage: 'learning_call_entered',
    status: 'entered',
    note: payload?.useBackendLog ? 'backend_log_mode' : 'legacy_message_mode'
  }).catch(() => null);
  try {
    const result = await memoryProdProcessConversationMemoryTurn(env, accessToken, projectId, uid, cfg, payload);
    pushStage('learning_call_completed');
    await writeMemoryLearningTrace(accessToken, projectId, uid, {
      ...traceBase,
      nowMs: Date.now(),
      stage: 'learning_call_completed',
      status: result?.failed ? 'failed' : 'completed',
      sessionId: result?.sessionId || '',
      rowsProcessed: num(result?.processedMessages, 0),
      sliceMessages: num(result?.processedMessages, 0),
      decision: result?.reason || result?.trigger?.reason || '',
      error: result?.error || '',
      resultOk: !!result?.ok
    }).catch(() => null);
    if (Array.isArray(debugStages)) result.debugStages = debugStages.slice(0, 40);
    return result;
  } catch (err) {
    pushStage('learning_call_failed');
    const failNowMs = Date.now();
    const session = await memoryProdCreateOrReuseMemorySession(accessToken, projectId, uid, cfg, {
      threadId: payload?.threadId,
      chatId: payload?.chatId,
      conversationId: payload?.conversationId,
      sourceTag: payload?.sourceTag,
      messages: payload?.messages,
      nowMs: failNowMs
    }).catch(() => null);
    const errText = String(err?.message || err || 'memory_turn_exception');
    if (session?.id) {
      await fsPatchDoc(accessToken, projectId, `users/${uid}/memorySessions/${session.id}`, {
        status: 'learning_failed',
        lastExtractionReason: trimMemoryText(`failed: ${errText}`, 120),
        pendingTriggerReason: 'memory_turn_exception',
        updatedAt: failNowMs,
        schemaVersion: MEMORY_SCHEMA_VERSION
      }).catch(() => null);
    }
    await writeMemoryLearningTrace(accessToken, projectId, uid, {
      ...traceBase,
      nowMs: failNowMs,
      stage: 'learning_call_failed',
      status: 'failed',
      sessionId: trimMemoryText(session?.id || '', 160),
      failedStep: 'processConversationMemoryTurn',
      error: errText
    }).catch(() => null);
    await writeMemoryLearningTrace(accessToken, projectId, uid, {
      nowMs: failNowMs,
      stage: 'memory_turn_exception_trace',
      status: 'failed',
      sourceTag: payload?.sourceTag,
      threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
      threadKey: payload?.threadKey || buildMemoryThreadKey(payload?.threadId || payload?.chatId || payload?.conversationId || '', payload?.sourceTag || 'chat'),
      sessionId: trimMemoryText(session?.id || '', 160),
      triggerReason: payload?.triggerReason || 'chat_turn_complete',
      failedStep: 'processConversationMemoryTurn',
      error: errText
    }).catch(() => null);
    await writeMemoryDebugLog(accessToken, projectId, uid, {
      nowMs: failNowMs,
      sourceTag: payload?.sourceTag,
      threadId: payload?.threadId || payload?.chatId || payload?.conversationId || '',
      sessionId: trimMemoryText(session?.id || '', 160),
      lastProcessedAt: num(session?.lastProcessedAt, 0),
      checkpointNote: 'failed: memory_turn_exception',
      trigger: { reason: trimMemoryText(payload?.triggerReason || 'chat_turn_complete', 80), highSignal: memoryProdHasHighSignalCue(getLastUserMessageText(payload?.messages || [])), manual: false, metrics: null },
      packetPreview: trimMemoryText(summarizeMessagesForMemory(payload?.messages || [], payload?.assistantText), MEMORY_EXTRACTION_PACKET_PREVIEW_CHARS),
      learned: { reinforce_labels: [], candidates: [], relation_hints: [], extractionError: String(err?.message || err || 'memory_turn_exception') },
      candidateCreated: [],
      candidatePromoted: [],
      reinforcedNodes: [],
      skippedItems: [{ label: trimMemoryText(getLastUserMessageText(payload?.messages || []), 80), reason: 'memory_turn_exception' }],
      eventDocs: [],
      placedNodes: [],
      connectionResults: [],
      extractionStatus: 'failed'
    }).catch(() => null);
    return { ok: false, failed: true, reason: 'memory_turn_exception', error: errText, sessionId: session?.id || '', debugStages };
  }
}

async function runMemoryMaintenance(accessToken, projectId, uid, cfg) {
  return memoryProdRunMemoryMaintenance(accessToken, projectId, uid, cfg);
}

// V3.1.5 â€” learning job split: /chat creates a cheap job, heavy extraction runs in a fresh invocation.
async function getMemoryLearningJob(accessToken, projectId, uid, jobId) {
  if (!jobId) return null;
  const doc = await fsGetDoc(accessToken, projectId, `users/${uid}/memoryLearningJobs/${jobId}`).catch(() => null);
  if (!doc || !doc.fields) return null;
  return { ...parseFirestoreFields(doc.fields || {}), id: docIdFromFsDoc(doc) || jobId };
}

async function patchMemoryLearningJob(accessToken, projectId, uid, jobId, patch = {}) {
  if (!jobId) return null;
  const nowMs = Date.now();
  const cleanPatch = { ...patch, updatedAt: patch.updatedAt || nowMs, schemaVersion: MEMORY_SCHEMA_VERSION };
  await fsUpsertDoc(accessToken, projectId, `users/${uid}/memoryLearningJobs/${jobId}`, cleanPatch);
  return cleanPatch;
}

async function createMemoryLearningJob(accessToken, projectId, uid, cfg, payload = {}) {
  const nowMs = num(payload?.nowMs, Date.now());
  const sourceTag = trimMemoryText(payload?.sourceTag || 'chat', 40).toLowerCase() || 'chat';
  const threadId = trimMemoryText(payload?.threadId || payload?.chatId || payload?.conversationId || '', 140);
  const threadKey = trimMemoryText(payload?.threadKey || buildMemoryThreadKey(threadId, sourceTag), 120);
  const userMsgId = trimMemoryText(payload?.userMsgId || payload?.linkedUserMsgId || '', 180);
  const assistantMsgId = trimMemoryText(payload?.assistantMsgId || '', 180);
  const jobId = buildMemoryLearningJobId(threadKey, userMsgId, nowMs);

  let session = null;
  try {
    session = await memoryProdCreateOrReuseMemorySession(accessToken, projectId, uid, cfg, {
      threadId: threadId || threadKey,
      sourceTag,
      messages: payload?.messages || [],
      nowMs
    });
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memorySessions/${session.id}`, {
      status: 'queued',
      lastExtractionReason: 'queued_learning_job',
      pendingTriggerReason: trimMemoryText(payload?.triggerReason || 'chat_turn_complete', 80),
      queuedLearningJobId: jobId,
      updatedAt: nowMs,
      schemaVersion: MEMORY_SCHEMA_VERSION
    }).catch(() => null);
  } catch (err) {
    await writeMemoryLearningTrace(accessToken, projectId, uid, {
      nowMs, stage: 'learning_job_session_create_failed', status: 'failed',
      sourceTag, threadId, threadKey, userMsgId, assistantMsgId,
      triggerReason: payload?.triggerReason || 'chat_turn_complete',
      failedStep: 'create_session_before_job', error: String(err?.message || err)
    }).catch(() => null);
  }

  const jobDoc = {
    id: jobId, uid, status: 'queued', kind: 'memory_learning_job',
    sourceTag, threadId, threadKey, sessionId: trimMemoryText(session?.id || '', 160),
    userMsgId, assistantMsgId, linkedUserMsgId: trimMemoryText(payload?.linkedUserMsgId || userMsgId, 180),
    triggerReason: trimMemoryText(payload?.triggerReason || 'chat_turn_complete', 100),
    mode: trimMemoryText(payload?.mode || MEMORY_SCOPE, 40),
    useBackendLog: payload?.useBackendLog !== false,
    forceExtract: !!payload?.forceExtract,
    bypassIdempotency: !!payload?.bypassIdempotency,
    debug: !!payload?.debug,
    dispatchMode: '', error: '', failedStep: '', resultOk: false,
    processedMessages: 0, candidateCount: 0, eventCount: 0, sliceCount: 0,
    createdAt: nowMs, updatedAt: nowMs, schemaVersion: MEMORY_SCHEMA_VERSION
  };
  try {
    await fsUpsertDoc(accessToken, projectId, `users/${uid}/memoryLearningJobs/${jobId}`, jobDoc);
  } catch (upsertErr) {
    // CRITICAL visibility: if the job upsert fails (subrequest budget, auth, network, etc.),
    // we MUST leave a deterministic record explaining why no memoryLearningJobs doc exists.
    // writeMemoryLearningTrace may itself fail for the same reason, but we try anyway.
    await writeMemoryLearningTrace(accessToken, projectId, uid, {
      nowMs: Date.now(), stage: 'learning_job_upsert_failed', status: 'failed',
      sourceTag, threadId, threadKey, sessionId: jobDoc.sessionId, userMsgId, assistantMsgId,
      triggerReason: jobDoc.triggerReason,
      failedStep: 'fsUpsertDoc_memoryLearningJobs',
      error: trimMemoryText(String(upsertErr?.message || upsertErr || 'upsert_failed'), 400),
      note: `jobId=${jobId}`
    }).catch(() => null);
    throw upsertErr; // let /chat's outer catch surface it into learningResult.error
  }
  await writeMemoryLearningTrace(accessToken, projectId, uid, {
    nowMs, stage: 'learning_job_queued', status: 'queued', sourceTag, threadId, threadKey,
    sessionId: jobDoc.sessionId, userMsgId, assistantMsgId, triggerReason: jobDoc.triggerReason, note: `jobId=${jobId}`
  }).catch(() => null);
  return jobDoc;
}

async function dispatchMemoryLearningJob(env, request, ctx, accessToken, projectId, uid, jobDoc, cfg) {
  if (!jobDoc?.id) return { ok: false, dispatched: false, dispatchMode: 'none', error: 'missing_job' };

  // ============================================================================
  // V3.1.8: QUEUE-ONLY AUTO LEARNING DISPATCH
  // ----------------------------------------------------------------------------
  // /chat may CREATE a memoryLearningJobs doc, but it MUST NOT run extraction.
  // /chat may enqueue the job to MEMORY_LEARNING_QUEUE if the binding exists.
  // If the queue binding is missing, the job stays visible as queued_waiting_for_queue.
  // No self-fetch fallback. No inline waitUntil fallback.
  // ============================================================================

  const queue = env?.MEMORY_LEARNING_QUEUE;
  if (queue && typeof queue.send === 'function') {
    try {
      // V3.1.12: write a 'learning_queue_dispatch_started' trace BEFORE the actual send,
      // so that even if queue.send throws synchronously we still see the attempt.
      await writeMemoryLearningTrace(accessToken, projectId, uid, {
        stage: 'learning_queue_dispatch_started',
        status: 'queued',
        sourceTag: jobDoc.sourceTag, threadId: jobDoc.threadId, threadKey: jobDoc.threadKey,
        sessionId: jobDoc.sessionId,
        userMsgId: jobDoc.userMsgId || jobDoc.linkedUserMsgId || '',
        assistantMsgId: jobDoc.assistantMsgId || '',
        triggerReason: jobDoc.triggerReason,
        note: `jobId=${jobDoc.id} queue=gpmai-memory-learning`,
        resultOk: true
      }).catch(() => null);
      await queue.send({ kind: 'memory_learning_job', uid, jobId: jobDoc.id });
      const queuedAt = Date.now();
      await patchMemoryLearningJob(accessToken, projectId, uid, jobDoc.id, {
        dispatchMode: 'cloudflare_queue',
        status: 'queued',
        queueName: 'gpmai-memory-learning',
        queuedAt,
        resultOk: false,
        failedStep: '',
        error: '',
        updatedAt: queuedAt
      }).catch(() => null);
      await writeMemoryLearningTrace(accessToken, projectId, uid, {
        stage: 'learning_queue_dispatch_succeeded',
        status: 'queued',
        sourceTag: jobDoc.sourceTag,
        threadId: jobDoc.threadId,
        threadKey: jobDoc.threadKey,
        sessionId: jobDoc.sessionId,
        userMsgId: jobDoc.userMsgId || jobDoc.linkedUserMsgId || '',
        assistantMsgId: jobDoc.assistantMsgId || '',
        triggerReason: jobDoc.triggerReason,
        note: `jobId=${jobDoc.id} dispatch=cloudflare_queue queue=gpmai-memory-learning`,
        resultOk: true
      }).catch(() => null);
      return { ok: true, dispatched: true, dispatchMode: 'cloudflare_queue', jobId: jobDoc.id, queueName: 'gpmai-memory-learning' };
    } catch (err) {
      const errText = String(err?.message || err || 'queue_send_failed');
      await patchMemoryLearningJob(accessToken, projectId, uid, jobDoc.id, {
        status: 'queue_dispatch_failed',
        dispatchMode: 'cloudflare_queue_send_failed',
        failedStep: 'queue_send',
        error: trimMemoryText(errText, 500),
        updatedAt: Date.now()
      }).catch(() => null);
      await writeMemoryLearningTrace(accessToken, projectId, uid, {
        stage: 'learning_queue_dispatch_failed',
        status: 'failed',
        sourceTag: jobDoc.sourceTag,
        threadId: jobDoc.threadId,
        threadKey: jobDoc.threadKey,
        sessionId: jobDoc.sessionId,
        userMsgId: jobDoc.userMsgId || jobDoc.linkedUserMsgId || '',
        assistantMsgId: jobDoc.assistantMsgId || '',
        triggerReason: jobDoc.triggerReason,
        failedStep: 'queue_send',
        error: errText,
        note: `jobId=${jobDoc.id}`,
        resultOk: false
      }).catch(() => null);
      return { ok: false, dispatched: false, dispatchMode: 'cloudflare_queue_send_failed', jobId: jobDoc.id, error: errText };
    }
  }

  const missingMsg = 'MEMORY_LEARNING_QUEUE binding missing; auto-learning job created but not dispatched. Add a Cloudflare Queue binding named MEMORY_LEARNING_QUEUE or run /memory/debug/process-thread manually.';
  await patchMemoryLearningJob(accessToken, projectId, uid, jobDoc.id, {
    status: 'queued_waiting_for_queue',
    dispatchMode: 'queue_missing',
    failedStep: '',
    error: missingMsg,
    updatedAt: Date.now()
  }).catch(() => null);
  await writeMemoryLearningTrace(accessToken, projectId, uid, {
    stage: 'learning_queue_missing',
    status: 'waiting_for_queue',
    sourceTag: jobDoc.sourceTag,
    threadId: jobDoc.threadId,
    threadKey: jobDoc.threadKey,
    sessionId: jobDoc.sessionId,
    userMsgId: jobDoc.userMsgId || jobDoc.linkedUserMsgId || '',
    assistantMsgId: jobDoc.assistantMsgId || '',
    triggerReason: jobDoc.triggerReason,
    failedStep: '',
    error: missingMsg,
    note: `jobId=${jobDoc.id}`,
    resultOk: false
  }).catch(() => null);
  return { ok: false, dispatched: false, dispatchMode: 'queue_missing', jobId: jobDoc.id, error: missingMsg };
}

async function runMemoryLearningJob(env, accessToken, projectId, uid, cfg, body = {}) {
  const nowMs = Date.now();
  const jobId = trimMemoryText(body?.jobId || body?.id || '', 180);
  let failedStep = 'load_job';
  if (!jobId) return { ok: false, error: 'jobId required', failedStep };
  const job = await getMemoryLearningJob(accessToken, projectId, uid, jobId);
  if (!job) return { ok: false, error: 'learning job not found', jobId, failedStep };
  const sourceTag = trimMemoryText(job.sourceTag || 'chat', 40).toLowerCase() || 'chat';
  const threadId = trimMemoryText(job.threadId || job.threadKey || '', 140);
  const threadKey = trimMemoryText(job.threadKey || buildMemoryThreadKey(threadId, sourceTag), 120);
  const traceBase = { sourceTag, threadId, threadKey, sessionId: job.sessionId || '', userMsgId: job.userMsgId || job.linkedUserMsgId || '', assistantMsgId: job.assistantMsgId || '', triggerReason: job.triggerReason || 'chat_turn_complete' };

  // V3.3.1 HOTFIX â€” Start a per-job subrequest budget. All trace/debug writes inside
  // this invocation will check the budget and buffer instead of writing individually.
  const _budget = _startLearningBudget();

  await patchMemoryLearningJob(accessToken, projectId, uid, jobId, { status: 'running', startedAt: nowMs, failedStep: '', error: '' }).catch(() => null);
  await writeMemoryLearningTrace(accessToken, projectId, uid, { ...traceBase, nowMs, stage: 'learning_job_running', status: 'running', note: `jobId=${jobId}` }).catch(() => null);

  let sessionId = trimMemoryText(job.sessionId || '', 160);
  let lockHeld = false;
  let lockReleaseDone = false;
  try {
    failedStep = 'ensure_session';
    let session = sessionId ? parseFirestoreFields((await fsGetDoc(accessToken, projectId, `users/${uid}/memorySessions/${sessionId}`).catch(() => null))?.fields || {}) : null;
    if (!session?.id) {
      session = await memoryProdCreateOrReuseMemorySession(accessToken, projectId, uid, cfg, { threadId: threadId || threadKey, sourceTag, messages: [], nowMs: Date.now() });
      sessionId = session.id;
      await patchMemoryLearningJob(accessToken, projectId, uid, jobId, { sessionId }).catch(() => null);
    }

    // ARCH Â§11 â€” Acquire the per-session learning lock BEFORE any extraction work.
    // If contended (another job already running and not expired), mark pendingLearning
    // and exit cleanly so the queue can ack and the holder dispatches follow-up work.
    failedStep = 'acquire_learning_lock';
    const lockResult = await memoryProdAcquireLearningLock(accessToken, projectId, uid, sessionId, jobId, Date.now());
    if (!lockResult.acquired) {
      if (lockResult.reason === 'busy' || lockResult.reason === 'precondition_lost') {
        const markRes = await memoryProdMarkPendingLearning(accessToken, projectId, uid, sessionId, jobId, Date.now());
        await writeMemoryLearningTrace(accessToken, projectId, uid, {
          ...traceBase, nowMs: Date.now(), stage: 'learning_lock_busy', status: 'pending',
          sessionId, decision: 'pending_set', reason: lockResult.reason,
          note: `jobId=${jobId} holder=${lockResult.holderJobId || ''} marked=${markRes.marked}`,
          resultOk: true
        }).catch(() => null);
        await patchMemoryLearningJob(accessToken, projectId, uid, jobId, {
          status: 'deferred_lock_busy', deferredAt: Date.now(),
          dispatchMode: 'lock_busy_pending_set',
          failedStep: '', error: '', updatedAt: Date.now()
        }).catch(() => null);
        _clearLearningBudget();
        return { ok: true, deferred: true, reason: 'lock_busy_pending_set', uid, jobId, sessionId, holderJobId: lockResult.holderJobId || '' };
      }
      // Other failure modes (session_missing / commit_error) â€” do not silently swallow.
      throw new Error(`acquire_learning_lock failed: ${lockResult.reason || 'unknown'} ${lockResult.error || ''}`.trim());
    }
    lockHeld = true;
    await writeMemoryLearningTrace(accessToken, projectId, uid, {
      ...traceBase, nowMs: Date.now(), stage: 'learning_lock_acquired', status: 'ok',
      sessionId, note: `jobId=${jobId} expiresAt=${lockResult.expiresAt}`, resultOk: true
    }).catch(() => null);

    await fsPatchDoc(accessToken, projectId, `users/${uid}/memorySessions/${sessionId}`, { status: 'running', lastExtractionReason: 'running_learning_job', runningLearningJobId: jobId, updatedAt: Date.now(), schemaVersion: MEMORY_SCHEMA_VERSION }).catch(() => null);
    await writeMemoryLearningTrace(accessToken, projectId, uid, { ...traceBase, nowMs: Date.now(), stage: 'learning_job_session_ready', status: 'ok', sessionId, note: `jobId=${jobId}` }).catch(() => null);

    failedStep = 'processConversationMemoryTurn';
    const result = await processConversationMemoryTurn(env, accessToken, projectId, uid, cfg, {
      mode: job.mode || MEMORY_SCOPE, sourceTag, threadId: threadId || threadKey, threadKey, messages: [], assistantText: '',
      triggerReason: job.triggerReason || 'chat_turn_complete', useBackendLog: true, userMsgId: job.userMsgId || job.linkedUserMsgId || '', assistantMsgId: job.assistantMsgId || '',
      linkedUserMsgId: job.linkedUserMsgId || job.userMsgId || '', forceExtract: !!job.forceExtract, bypassIdempotency: job.bypassIdempotency !== false, debug: !!job.debug, _debugStages: []
    });
    const ok = !!result?.ok && !result?.failed;
    const finishPatch = {
      status: ok ? 'completed' : 'failed', completedAt: ok ? Date.now() : 0, failedAt: ok ? 0 : Date.now(), resultOk: ok, reason: trimMemoryText(result?.reason || '', 100),
      sessionId: result?.sessionId || sessionId, processedMessages: num(result?.processedMessages, 0), candidateCount: num(result?.candidateCount, 0), eventCount: num(result?.eventCount, 0),
      sliceCount: num(result?.sliceCount, 0), failedStep: ok ? '' : 'processConversationMemoryTurn', error: ok ? '' : trimMemoryText(result?.error || result?.reason || 'learning_failed', 500)
    };
    await patchMemoryLearningJob(accessToken, projectId, uid, jobId, finishPatch).catch(() => null);

    // ARCH Â§11 â€” Release lock BEFORE the final session patch so the post-release session
    // patch (status='active') is observed in the unlocked state. Capture pendingLearning
    // so we can dispatch a follow-up job after the patch+trace below.
    failedStep = 'release_learning_lock';
    const releaseRes = await memoryProdReleaseLearningLock(accessToken, projectId, uid, sessionId, jobId, Date.now());
    lockReleaseDone = true;
    lockHeld = false;
    const followUpRequested = !!releaseRes.pendingLearning;
    await writeMemoryLearningTrace(accessToken, projectId, uid, {
      ...traceBase, nowMs: Date.now(), stage: 'learning_lock_released', status: releaseRes.released ? 'ok' : 'no_op',
      sessionId, decision: releaseRes.released ? 'released' : (releaseRes.reason || 'no_op'),
      note: `jobId=${jobId} pendingLearning=${followUpRequested}`, resultOk: releaseRes.released
    }).catch(() => null);

    await fsPatchDoc(accessToken, projectId, `users/${uid}/memorySessions/${finishPatch.sessionId || sessionId}`, {
      status: ok ? 'active' : 'learning_failed',
      lastExtractionReason: ok ? trimMemoryText(result?.reason || 'learning_job_completed', 120) : trimMemoryText(`failed: ${finishPatch.error || finishPatch.reason || 'learning_failed'}`, 120),
      lastLearningJobId: ok ? jobId : '', failedLearningJobId: ok ? '' : jobId, updatedAt: Date.now(), schemaVersion: MEMORY_SCHEMA_VERSION
    }).catch(() => null);
    await writeMemoryLearningTrace(accessToken, projectId, uid, {
      ...traceBase, nowMs: Date.now(), stage: 'learning_job_finished', status: ok ? 'completed' : 'failed', sessionId: finishPatch.sessionId || sessionId, rowsProcessed: finishPatch.processedMessages,
      sliceMessages: finishPatch.processedMessages, decision: finishPatch.reason, failedStep: finishPatch.failedStep, error: finishPatch.error, resultOk: ok, note: `jobId=${jobId}`
    }).catch(() => null);

    // ARCH Â§11 â€” If a contended job marked pendingLearning while we held the lock, dispatch
    // a fresh follow-up job through the same Cloudflare queue. We do not call extraction
    // inline; the queue consumer will pick it up under a fresh lock.
    if (followUpRequested && ok) {
      try {
        const followUpJob = await createMemoryLearningJob(accessToken, projectId, uid, cfg, {
          sourceTag, threadId: threadId || threadKey, threadKey,
          sessionId: finishPatch.sessionId || sessionId,
          triggerReason: 'pending_learning_followup',
          forceExtract: false,
          bypassIdempotency: false
        });
        if (followUpJob?.id && env?.MEMORY_LEARNING_QUEUE && typeof env.MEMORY_LEARNING_QUEUE.send === 'function') {
          await env.MEMORY_LEARNING_QUEUE.send({ kind: 'memory_learning_job', uid, jobId: followUpJob.id });
          await writeMemoryLearningTrace(accessToken, projectId, uid, {
            ...traceBase, nowMs: Date.now(), stage: 'learning_followup_dispatched', status: 'queued',
            sessionId: finishPatch.sessionId || sessionId,
            note: `parentJobId=${jobId} followUpJobId=${followUpJob.id}`, resultOk: true
          }).catch(() => null);
        }
      } catch (followErr) {
        console.log(`[learning_followup_dispatch_error] sid=${sessionId} parent=${jobId}: ${String(followErr?.message || followErr)}`);
      }
    }

    // V3.3.1 HOTFIX â€” Flush compact budget summary before returning.
    // This replaces the many per-stage Firestore trace docs with a single summary.
    if (_budget) { _budget.checkpointAdvanced = !!(result?.ok && !result?.failed && !result?.skipped && !result?.deferred); }
    await flushLearningBudgetSummary(accessToken, projectId, uid, _budget, {
      jobId, sessionId: finishPatch.sessionId || sessionId, threadId,
      resultOk: ok, reason: finishPatch.reason || '', error: finishPatch.error || '',
      processedMessages: finishPatch.processedMessages, candidateCount: finishPatch.candidateCount,
      sliceCount: finishPatch.sliceCount, eventCount: finishPatch.eventCount
    }).catch(() => null);
    _clearLearningBudget();

    return { ok, uid, jobId, sessionId: finishPatch.sessionId || sessionId, result, failedStep: ok ? null : finishPatch.failedStep, error: finishPatch.error || null, lockHeld: false, followUpRequested };
  } catch (err) {
    const errText = String(err?.message || err || 'learning_job_failed');
    // ARCH Â§11 â€” On any failure path, release the lock if we still hold it so a retry
    // does not deadlock on the expired-lock window. Read lock state freshly to avoid
    // releasing a lock another job has already stolen.
    if (lockHeld && !lockReleaseDone) {
      try {
        await memoryProdReleaseLearningLock(accessToken, projectId, uid, sessionId, jobId, Date.now());
      } catch (relErr) {
        console.log(`[learning_lock_release_in_catch_error] sid=${sessionId} job=${jobId}: ${String(relErr?.message || relErr)}`);
      }
    }
    await patchMemoryLearningJob(accessToken, projectId, uid, jobId, { status: 'failed', failedAt: Date.now(), failedStep, error: trimMemoryText(errText, 500), sessionId }).catch(() => null);
    if (sessionId) {
      await fsPatchDoc(accessToken, projectId, `users/${uid}/memorySessions/${sessionId}`, { status: 'learning_failed', lastExtractionReason: trimMemoryText(`failed: ${failedStep}: ${errText}`, 120), failedLearningJobId: jobId, updatedAt: Date.now(), schemaVersion: MEMORY_SCHEMA_VERSION }).catch(() => null);
    }
    await writeMemoryLearningTrace(accessToken, projectId, uid, { ...traceBase, nowMs: Date.now(), stage: 'learning_job_failed', status: 'failed', sessionId, failedStep, error: errText, note: `jobId=${jobId}` }).catch(() => null);
    // V3.3.1 HOTFIX â€” Flush compact summary even on failure path so job never stays running.
    const _budgetOnFail = _getActiveBudget();
    await flushLearningBudgetSummary(accessToken, projectId, uid, _budgetOnFail, {
      jobId, sessionId, threadId, resultOk: false, reason: failedStep, error: errText
    }).catch(() => null);
    _clearLearningBudget();
    return { ok: false, uid, jobId, sessionId, failedStep, error: errText };
  }
}

async function memoryLearningQueueConsumer(batch, env) {
  if (!batch || !Array.isArray(batch.messages)) return;
  const accessToken = await getGoogleAccessToken(parseFirebaseServiceAccountFromEnv(env));
  const projectId = env.FIREBASE_PROJECT_ID;
  const cfg = await loadPublicConfig(accessToken, projectId).catch(() => ({}));
  for (const msg of batch.messages) {
    const body = msg.body || {};
    if (body?.kind !== 'memory_learning_job') continue;
    try {
      if (!body?.uid || !body?.jobId) { msg.ack(); continue; }
      const result = await runMemoryLearningJob(env, accessToken, projectId, body.uid, cfg, { jobId: body.jobId, source: 'cloudflare_queue' });
      // V3.1.12 retry policy:
      // - ack on full success
      // - ack on "skipped" / "deferred_by_trigger" / non-extraction reasons (these are NOT failures, just gating)
      // - ack on bad-input failures that won't recover from retry
      // - retry only on processConversationMemoryTurn that *threw* (transient model/network issues)
      const reason = String(result?.reason || result?.result?.reason || '').toLowerCase();
      const isNonRecoverableBenign = !!result?.ok || /skipped|deferred|no_unprocessed|trigger_skip|idempotent_repeat/.test(reason);
      const isExtractionTurnFailure = !result?.ok && result?.failedStep === 'processConversationMemoryTurn' && !isNonRecoverableBenign;
      if (isExtractionTurnFailure) {
        try { msg.retry({ delaySeconds: 30 }); } catch (_) { try { msg.ack(); } catch (_) {} }
      } else {
        msg.ack();
      }
    } catch (err) {
      console.log(`[learning_queue_consumer_error] ${String(err?.message || err)}`);
      try { msg.retry({ delaySeconds: 30 }); } catch (_) { try { msg.ack(); } catch (_) {} }
    }
  }
}

function normalizeBootstrapEntry(entry) {
  return {
    title: trimMemoryText(entry?.title || entry?.chatTitle || '', 120),
    sourceTag: trimMemoryText(entry?.sourceTag || entry?.source || 'chat', 40).toLowerCase(),
    snippet: trimMemoryText(entry?.snippet || entry?.summary || '', 420),
    text: trimMemoryText(entry?.text || entry?.body || entry?.content || '', 2600)
  };
}

function buildBootstrapConversationText(entries) {
  return (Array.isArray(entries) ? entries : []).slice(0, MEMORY_BOOTSTRAP_MAX_ANALYZE_ENTRIES).map(normalizeBootstrapEntry).map((e) => {
    const combined = [e.title ? `TITLE: ${e.title}` : '', e.snippet ? `SNIPPET: ${e.snippet}` : '', e.text ?
      `TEXT: ${e.text}` : ''
    ].filter(Boolean).join('\n');
    return combined ? `ENTRY (${e.sourceTag || 'chat'})\n${combined}` : '';
  }).filter(Boolean).join('\n\n---\n\n').slice(0, MEMORY_BOOTSTRAP_MAX_IMPORT_TEXT_CHARS);
}

function buildMemoryBootstrapUserPrompt(_mode, existingSummary, historyText) {
  return [
    'Analyze these historical conversations for the GPMai Memory Brain.',
    'Return ONLY valid JSON with this exact shape:',
    '{"increment_nodes":["label"],"new_nodes":[{"label":"...","group":"project","parent":"...","suggestedLevel":2,"info":"...","strength":"strong","cluster":"work","importance":"important"}],"new_connections":[{"from":"...","to":"...","type":"part_of","reason":"..."}]}',
    'Rules:',
    '- group must be one of: identity, goal, project, skill, habit, interest, preference, reserve',
    '- type must be one of: part_of, uses, depends_on, drives, supports, improves, related_to',
    '- cluster should be a broad semantic world such as work, learning, health, sports, finance, relationships, personal, or general',
    '- focus on durable user context, recurring themes, stable preferences, active projects, goals, skills, habits, and important concerns',
    '- extract a rich but meaningful graph from the history; do not return filler noise',
    '- prefer meaningful parent containers over attaching everything directly to root',
    '- use increment_nodes when a concept is already present in existing memory',
    '- strength should be strong, normal, or weak',
    '- suggestedLevel should usually be 2, 3, or 4',
    '- importance should be ordinary, important, or life_significant when clearly warranted',
    '',
    '<existing_memory>',
    existingSummary || '',
    '</existing_memory>',
    '',
    '<history_batch>',
    historyText || '',
    '</history_batch>',
  ].join('\n');
}

async function analyzeHistoryBatchForMemory(env, cfg, mode, nodes, entries) {
  const historyText = buildBootstrapConversationText(entries);
  if (!historyText) return {
    increment_nodes: [],
    new_nodes: [],
    new_connections: []
  };
  const existingSummary = buildExistingMemorySummary(nodes, mode);
  const data = await callOpenRouterChat(env, {
    model: cfg.memoryLearnModel,
    messages: [{
      role: 'system',
      content: 'You are a memory bootstrap extraction model for GPMai. Return strict JSON only. Never add markdown. Never explain your answer.'
    }, {
      role: 'user',
      content: buildMemoryBootstrapUserPrompt(mode, existingSummary, historyText)
    }],
    temperature: 0.08,
    max_tokens: 2000
  });
  const parsed = safeParseJsonObject(stripMarkdownFences(String(data?.choices?.[0]?.message?.content || '')
  .trim())) || {};
  return {
    increment_nodes: Array.isArray(parsed.increment_nodes) ? parsed.increment_nodes : [],
    new_nodes: Array.isArray(parsed.new_nodes) ? parsed.new_nodes : [],
    new_connections: Array.isArray(parsed.new_connections) ? parsed.new_connections : []
  };
}

async function clearLearnedMemoryForMode(accessToken, projectId, uid, _mode, options = {}) {
  const keepProfile = options?.keepProfile !== false;
  const nowMs = Date.now();
  const [nodes, connections, candidates, events, sessions, threads, logs, queueDocs, auditDocs, nodeIndexes, eventIndexes] = await Promise.all([
    listMemoryNodes(accessToken, projectId, uid),
    listMemoryConnections(accessToken, projectId, uid),
    listMemoryCandidates(accessToken, projectId, uid),
    listMemoryEvents(accessToken, projectId, uid),
    listMemorySessions(accessToken, projectId, uid),
    listMemoryThreads(accessToken, projectId, uid),
    listMemoryDebugLogs(accessToken, projectId, uid),
    listConsolidationQueueDocs(accessToken, projectId, uid),
    listMergeAuditDocs(accessToken, projectId, uid),
    listNodeIndexDocs(accessToken, projectId, uid),
    listEventIndexDocs(accessToken, projectId, uid),
  ]);

  for (const node of nodes) {
    if (node.deleted || node.isRoot) continue;
    if (keepProfile && node.sourceType === 'profile') continue;
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryNodes/${node.id}`, {
      deleted: true,
      deletedAt: nowMs,
      linkedEventIds: [],
      eventCount: 0,
      lastEventAt: 0,
      lastMentioned: nowMs,
      schemaVersion: MEMORY_SCHEMA_VERSION,
    });
  }

  for (const conn of connections) {
    if (conn.deleted) continue;
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryConnections/${conn.id}`, {
      deleted: true,
      lastUpdated: nowMs
    });
  }

  for (const event of events) {
    if (event.deleted) continue;
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryEvents/${event.id}`, {
      deleted: true,
      deletedAt: nowMs,
      updatedAt: nowMs,
      status: 'cleared',
      schemaVersion: MEMORY_SCHEMA_VERSION,
    });
  }

  for (const session of sessions) {
    if (session.deleted) continue;
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memorySessions/${session.id}`, {
      deleted: true,
      deletedAt: nowMs,
      updatedAt: nowMs,
      linkedEventIds: [],
      countedTopicKeys: [],
      lastEventId: '',
      schemaVersion: MEMORY_SCHEMA_VERSION,
    });
  }

  for (const cand of candidates) {
    if (cand.deleted) continue;
    await fsPatchDoc(accessToken, projectId, `users/${uid}/memoryCandidates/${cand.id}`, {
      deleted: true,
      deletedAt: nowMs,
      status: 'cleared',
    });
  }

  for (const thread of threads) {
    await fsDeleteDoc(accessToken, projectId, `users/${uid}/memoryThreads/${thread.id}`).catch(() => null);
  }
  for (const log of logs) {
    await fsDeleteDoc(accessToken, projectId, `users/${uid}/memoryDebugLogs/${log.id}`).catch(() => null);
  }
  for (const q of queueDocs) {
    await fsDeleteDoc(accessToken, projectId, `users/${uid}/consolidationQueue/${q.id}`).catch(() => null);
  }
  for (const audit of auditDocs) {
    await fsDeleteDoc(accessToken, projectId, `users/${uid}/mergeAudit/${audit.id}`).catch(() => null);
  }
  for (const idx of nodeIndexes) {
    await fsDeleteDoc(accessToken, projectId, `users/${uid}/nodeIndex/${idx.id}`).catch(() => null);
  }
  for (const idx of eventIndexes) {
    await fsDeleteDoc(accessToken, projectId, `users/${uid}/eventIndex/${idx.id}`).catch(() => null);
  }

  await syncMemoryOperationalDocs(accessToken, projectId, uid).catch(() => null);

  await patchMemoryUserMeta(accessToken, projectId, uid, {
    memoryNodeCount: keepProfile ? nodes.filter((n) => !n.deleted && !n.isRoot && n.sourceType === 'profile').length + 1 : 1,
    memoryConnectionCount: 0,
    memoryEventCount: 0,
    memorySessionCount: 0,
    memoryAutoLearnedCount: 0,
    memoryLastProcessedAt: nowMs,
    memoryLastDecayAt: nowMs,
    memoryVersion: MEMORY_VERSION,
    memorySchemaVersion: MEMORY_SCHEMA_VERSION,
    activeMemoryMode: MEMORY_SCOPE,
  });

  const rootPath = `users/${uid}/memoryNodes/root`;
  const rootNode = parseFirestoreFields((await fsGetDoc(accessToken, projectId, rootPath))?.fields || {});
  if (rootNode && Object.keys(rootNode).length) {
    await fsPatchDoc(accessToken, projectId, rootPath, {
      deleted: false,
      linkedEventIds: [],
      eventCount: 0,
      lastEventAt: 0,
      lastMentioned: nowMs,
      updatedAt: nowMs,
      schemaVersion: MEMORY_SCHEMA_VERSION,
    });
    await syncNodeIndexDoc(accessToken, projectId, uid, { ...rootNode, deleted: false, linkedEventIds: [], eventCount: 0, lastEventAt: 0, lastMentioned: nowMs, updatedAt: nowMs }).catch(() => null);
  }

  return {
    ok: true,
    uid,
    cleared: true,
    keptProfile: keepProfile,
    resetMode: 'lite',
    counts: {
      nodes: keepProfile ? nodes.filter((n) => !n.deleted && !n.isRoot && n.sourceType === 'profile').length + 1 : 1,
      connections: 0,
      events: 0,
      sessions: 0,
      candidates: 0,
      clusters: keepProfile ? new Set(nodes.filter((n) => !n.deleted && !n.isRoot && n.sourceType === 'profile').map((n) => n.clusterId || inferClusterIdForNode(n.label, n.group, n.info) || 'general')).size : 0
    }
  };
}

async function resetLearnedMemoryState(accessToken, projectId, uid, cfg, body = {}) {
  const nowMs = Date.now();
  const user = parseFirestoreFields((await fsGetDoc(accessToken, projectId, `users/${uid}`))?.fields || {});
  return {
    ok: true,
    uid,
    activeMode: MEMORY_SCOPE,
    reset: {
      ok: true,
      skipped: true,
      resetMode: 'disabled_dev',
      reason: 'Heavy learned-memory reset is disabled in this build. Use synthetic history import as the main testing flow.'
    },
    profile: responseProfileForMode(await readUnifiedMemoryProfile(accessToken, projectId, uid, cfg), MEMORY_SCOPE),
    memoryMeta: {
      memoryEnabled: true,
      memoryNodeCount: num(user.memoryNodeCount, 0),
      memoryConnectionCount: num(user.memoryConnectionCount, 0),
      memoryEventCount: num(user.memoryEventCount, 0),
      memorySessionCount: num(user.memorySessionCount, 0),
      memoryAutoLearnedCount: num(user.memoryAutoLearnedCount, 0),
      memoryVersion: MEMORY_VERSION,
      memorySchemaVersion: MEMORY_SCHEMA_VERSION,
      memoryLastProcessedAt: num(user.memoryLastProcessedAt, nowMs),
      memoryLastDecayAt: num(user.memoryLastDecayAt, nowMs),
    }
  };
}

async function processMemoryBootstrapImport(env, accessToken, projectId, uid, cfg, payload) {
  const rawEntries = (Array.isArray(payload?.entries) ? payload.entries : [])
    .map(normalizeBootstrapEntry)
    .filter((e) => e.title || e.snippet || e.text);
  const entries = rawEntries.slice(0, MEMORY_BOOTSTRAP_MAX_ENTRIES_PER_RUN);

  if (!entries.length) {
    return { ok: false, error: 'entries required' };
  }

  if (payload?.resetLearned === true) {
    await clearLearnedMemoryForMode(accessToken, projectId, uid, MEMORY_SCOPE);
  }

  const [nodes, connections, suppressions] = await Promise.all([
    listMemoryNodes(accessToken, projectId, uid),
    listMemoryConnections(accessToken, projectId, uid),
    listMemorySuppressions(accessToken, projectId, uid),
  ]);

  const state = {
    nodes: nodes.slice(),
    connections: connections.slice(),
    suppressions: suppressions.slice(),
  };

  const now = Date.now();
  const maxIncrementWrites = MEMORY_BOOTSTRAP_MAX_INCREMENT_WRITES;
  const maxNodeCreates = MEMORY_BOOTSTRAP_MAX_NODE_CREATES;
  const maxConnectionCreates = MEMORY_BOOTSTRAP_MAX_CONNECTION_CREATES;
  const touchedNodeIds = new Set();
  const incrementedLabels = new Set();
  const pendingWrites = [];
  // ARCH Â§1, Â§8 â€” Bootstrap may not bypass the node gate. Rejected items are tracked
  // here and surfaced in the API response so admins can see why imports were skipped.
  const bootstrapRejected = [];
  // ARCH Â§3.1 â€” Phase B: items the gate routes to "candidate" are now actually written
  // through the candidate path with lifecycle evidence, instead of dropped.
  const bootstrapRoutedToCandidate = [];
  let created = 0;
  let promoted = 0;
  let linked = 0;

  const queueUpdate = (docPath, plainObj, mask = null) => {
    pendingWrites.push(makeFirestoreUpdateWrite(projectId, docPath, plainObj, mask));
  };

  const rootNode = () => state.nodes.find((n) => n.id === 'root' && !n.deleted) || {
    id: 'root',
    label: 'You',
    normalizedKey: '__root__',
    aliases: [],
    group: 'identity',
    level: 0,
    parentId: '',
    count: 100,
    heat: 100,
    info: 'Root identity node for the user.',
    learned: false,
    isRoot: true,
    identityDefining: true,
    modeScope: MEMORY_SCOPE,
    sourceType: 'system',
    deleted: false,
    dateAdded: now,
    lastMentioned: now,
    suppressedUntil: 0,
    clusterId: 'personal',
    importanceClass: 'important'
  };

  const findNode = (label) => {
    const key = normalizeMemoryKey(label);
    if (!key) return null;
    return state.nodes.find((node) => !node.deleted && (normalizeMemoryKey(node.normalizedKey || node.label) === key || (Array.isArray(node.aliases) && node.aliases.some((alias) => normalizeMemoryKey(alias) === key)))) || null;
  };

  const isSuppressed = (label) => {
    const key = normalizeMemoryKey(label);
    if (!key) return false;
    return state.suppressions.some((item) => !item.deleted && normalizeMemoryKey(item.normalizedKey || item.label) === key && num(item.suppressedUntil, 0) > Date.now());
  };

  const findConnection = (fromNodeId, toNodeId, type) => {
    const lookupKey = canonicalConnectionKey(fromNodeId, toNodeId, type);
    return state.connections.find((edge) => !edge.deleted && canonicalConnectionKey(edge.fromNodeId, edge.toNodeId, edge.type) === lookupKey) || null;
  };

  const patchNode = async (node, patch) => {
    queueUpdate(`users/${uid}/memoryNodes/${node.id}`, patch, Object.keys(patch || {}));
    Object.assign(node, patch);
  };

  const patchConnection = async (edge, patch) => {
    queueUpdate(`users/${uid}/memoryConnections/${edge.id}`, patch, Object.keys(patch || {}));
    Object.assign(edge, patch);
  };

  const createNode = async (item) => {
    const label = trimMemoryText(item?.label, 80);
    const key = normalizeMemoryKey(label);
    if (!label || !key || isSuppressed(label)) return null;

    const existing = findNode(label);
    if (existing) {
      if (!touchedNodeIds.has(existing.id)) {
        await patchNode(existing, {
          count: Math.max(1, num(existing.count, 0) + 1),
          heat: Math.min(100, num(existing.heat, 0) + 4),
          lastMentioned: now,
          modeScope: MEMORY_SCOPE,
          deleted: false,
        });
        touchedNodeIds.add(existing.id);
      }
      promoted += 1;
      incrementedLabels.add(label);
      return existing;
    }

    if (created >= maxNodeCreates) return null;

    // ARCH Â§1, Â§3.1, Â§8 â€” Bootstrap path respects the same node gate as live extraction.
    // Phase A blocked junk; Phase B routes "candidate" items through the candidate path
    // with proper lifecycle evidence, instead of dropping them.
    const group = normalizeMemoryGroup(item?.group);
    const gateInput = {
      label,
      strength: trimMemoryText(item?.strength || 'medium', 20).toLowerCase() || 'medium',
      importanceHint: trimMemoryText(item?.importance || '', 40),
      summaryHint: trimMemoryText(item?.info || '', 220),
      roleGuess: group,
      sourceType: 'bootstrap'
    };
    const bootstrapGate = memoryProdNodeGate(gateInput, trimMemoryText(item?.info || '', 220));
    if (!bootstrapGate.allow) {
      // Hard reject: blocked label / empty label â†’ drop with audit.
      if (bootstrapGate.suggestedDowngrade !== 'candidate') {
        bootstrapRejected.push({
          label,
          reason: bootstrapGate.reason || 'node_gate_rejected',
          suggestedDowngrade: bootstrapGate.suggestedDowngrade || 'reject'
        });
        return null;
      }
      // suggestedDowngrade === 'candidate' â†’ route through the candidate path with
      // a synthetic _clearButShallow flag so memoryProdCreateOrPromoteMemoryTopic
      // writes a candidate doc with evidence (PDF Â§3.1 lifecycle evidence rule).
      try {
        const _candItem = {
          label,
          strength: 'medium',
          roleGuess: group || 'interest',
          summaryHint: trimMemoryText(item?.info || '', 220),
          info: trimMemoryText(item?.info || '', 220),
          importanceHint: trimMemoryText(item?.importance || inferImportanceForLabel(label, group, item?.info), 40),
          parentHint: trimMemoryText(item?.parent || '', 80),
          stateHint: '',
          aliases: Array.isArray(item?.aliases) ? item.aliases : [],
          _clearButShallow: true,
          _arbiterDecision: 'candidate',
          _arbiterReason: bootstrapGate.reason || 'clear_but_shallow',
          _sourceUserText: trimMemoryText(item?.info || '', 600),
          _sourceMsgId: '',
          sourceType: 'bootstrap',
          existingNodes: state.nodes,
          existingCandidates: undefined,
          existingConnections: state.connections,
          suppressions: state.suppressions,
          mode: MEMORY_SCOPE,
          group: group || 'interest',
          nowMs: now
        };
        const _candOutcome = await memoryProdCreateOrPromoteMemoryTopic(accessToken, projectId, uid, cfg, _candItem);
        if (_candOutcome?.candidate || _candOutcome?.candidateId) {
          bootstrapRoutedToCandidate.push({
            label,
            candidateId: _candOutcome.candidateId || _candOutcome?.candidateDoc?.id || '',
            reason: bootstrapGate.reason || 'clear_but_shallow'
          });
        } else {
          bootstrapRejected.push({
            label,
            reason: trimMemoryText(_candOutcome?.reason || 'candidate_route_failed', 80),
            suggestedDowngrade: 'candidate'
          });
        }
      } catch (_candErr) {
        console.log(`[bootstrap_candidate_route_error] uid=${uid} label="${label}": ${String(_candErr?.message || _candErr)}`);
        bootstrapRejected.push({ label, reason: 'candidate_route_threw', suggestedDowngrade: 'candidate' });
      }
      return null;
    }

    const parent = findNode(item?.parent) || rootNode();
    const node = {
      id: buildMemoryNodeId(MEMORY_SCOPE, label),
      label,
      normalizedKey: key,
      aliases: boundedUniqueIds([label, ...(Array.isArray(item?.aliases) ? item.aliases : [])], 12),
      group,
      level: Math.max(1, Math.min(4, clampInt(item?.suggestedLevel, 3, 1, 4))),
      parentId: parent?.id || 'root',
      count: 1,
      heat: 46,
      info: trimMemoryText(item?.info || 'Learned from historical conversations.', 220),
      learned: true,
      isRoot: false,
      identityDefining: group === 'identity',
      modeScope: MEMORY_SCOPE,
      sourceType: 'synthetic_history_import',
      deleted: false,
      dateAdded: now,
      lastMentioned: now,
      suppressedUntil: 0,
      linkedEventIds: [],
      eventCount: 0,
      lastEventAt: 0,
      schemaVersion: MEMORY_SCHEMA_VERSION,
      clusterId: trimMemoryText(item?.cluster || inferClusterIdForNode(label, group, item?.info), 40),
      importanceClass: trimMemoryText(item?.importance || inferImportanceForLabel(label, group, item?.info), 40),
    };

    queueUpdate(`users/${uid}/memoryNodes/${node.id}`, node);
    state.nodes.push(node);
    created += 1;

    const relation = normalizeMemoryConnectionType(item?.type || inferConnectionTypeForGroup(group));
    const existingEdge = findConnection(parent?.id || 'root', node.id, relation);
    if (!existingEdge && linked < maxConnectionCreates) {
      const edge = {
        id: buildMemoryConnectionId(MEMORY_SCOPE, parent?.id || 'root', node.id, relation),
        fromNodeId: MEMORY_BIDIRECTIONAL_TYPES.has(relation) && (parent?.id || 'root') > node.id ? node.id : (parent?.id || 'root'),
        toNodeId: MEMORY_BIDIRECTIONAL_TYPES.has(relation) && (parent?.id || 'root') > node.id ? (parent?.id || 'root') : node.id,
        type: relation,
        coCount: 1,
        reason: trimMemoryText(item?.info || 'Derived from historical memory import.', 180),
        modeScope: MEMORY_SCOPE,
        deleted: false,
        createdAt: now,
        lastUpdated: now,
      };
      queueUpdate(`users/${uid}/memoryConnections/${edge.id}`, edge);
      state.connections.push(edge);
      linked += 1;
    }

    return node;
  };

  const learned = await analyzeHistoryBatchForMemory(env, cfg, MEMORY_SCOPE, buildUnifiedMemoryView(state.nodes, state.connections).nodes, entries.slice(0, MEMORY_BOOTSTRAP_MAX_ANALYZE_ENTRIES));

  for (const label of Array.from(new Set((learned.increment_nodes || []).map((x) => trimMemoryText(x, 80)).filter(Boolean))).slice(0, maxIncrementWrites)) {
    const node = findNode(label);
    if (!node || touchedNodeIds.has(node.id)) continue;
    await patchNode(node, {
      count: Math.max(1, num(node.count, 0) + 1),
      heat: Math.min(100, num(node.heat, 0) + 4),
      lastMentioned: now,
      modeScope: MEMORY_SCOPE,
      deleted: false,
    });
    touchedNodeIds.add(node.id);
    incrementedLabels.add(label);
  }

  const uniqueNewNodes = [];
  const seenNewNodeKeys = new Set();
  for (const item of learned.new_nodes || []) {
    const label = trimMemoryText(item?.label, 80);
    const key = normalizeMemoryKey(label);
    if (!label || !key || seenNewNodeKeys.has(key)) continue;
    seenNewNodeKeys.add(key);
    uniqueNewNodes.push(item);
  }

  uniqueNewNodes.sort((a, b) => {
    const score = (value) => String(value || '').toLowerCase() === 'strong' ? 2 : String(value || '').toLowerCase() === 'normal' ? 1 : 0;
    return score(b?.strength) - score(a?.strength);
  });

  for (const item of uniqueNewNodes) {
    await createNode(item);
  }

  const seenConnectionKeys = new Set();
  for (const item of learned.new_connections || []) {
    if (linked >= maxConnectionCreates) break;
    const fromNode = findNode(item?.from);
    const toNode = findNode(item?.to);
    if (!fromNode || !toNode || fromNode.id === toNode.id) continue;
    const type = normalizeMemoryConnectionType(item?.type || 'related_to');
    const key = canonicalConnectionKey(fromNode.id, toNode.id, type);
    if (seenConnectionKeys.has(key)) continue;
    seenConnectionKeys.add(key);

    const existing = findConnection(fromNode.id, toNode.id, type);
    if (existing) {
      await patchConnection(existing, {
        coCount: Math.max(1, num(existing.coCount, 0) + 1),
        reason: trimMemoryText(item?.reason || existing.reason || 'Topics appeared together in historical conversations.', 180),
        lastUpdated: now,
        deleted: false,
      });
      continue;
    }

    const edge = {
      id: buildMemoryConnectionId(MEMORY_SCOPE, fromNode.id, toNode.id, type),
      fromNodeId: MEMORY_BIDIRECTIONAL_TYPES.has(type) && fromNode.id > toNode.id ? toNode.id : fromNode.id,
      toNodeId: MEMORY_BIDIRECTIONAL_TYPES.has(type) && fromNode.id > toNode.id ? fromNode.id : toNode.id,
      type,
      coCount: 1,
      reason: trimMemoryText(item?.reason || 'Topics appeared together in historical conversations.', 180),
      modeScope: MEMORY_SCOPE,
      deleted: false,
      createdAt: now,
      lastUpdated: now,
    };
    queueUpdate(`users/${uid}/memoryConnections/${edge.id}`, edge);
    state.connections.push(edge);
    linked += 1;
  }

  if (pendingWrites.length) await fsCommitWritesInChunks(accessToken, projectId, pendingWrites, 250);

  const activeNodes = state.nodes.filter((n) => !n.deleted);
  const activeConnections = state.connections.filter((c) => !c.deleted);
  const counts = {
    nodeCount: activeNodes.length,
    connectionCount: activeConnections.length,
    eventCount: 0,
    sessionCount: 0,
    autoLearnedCount: activeNodes.filter((n) => n.learned).length,
  };

  await fsPatchDoc(accessToken, projectId, `users/${uid}`, {
    activeMemoryMode: MEMORY_SCOPE,
    memoryNodeCount: counts.nodeCount,
    memoryConnectionCount: counts.connectionCount,
    memoryAutoLearnedCount: counts.autoLearnedCount,
    memoryLastProcessedAt: now,
    lastRequestAt: now,
  });

  const unified = buildUnifiedMemoryView(state.nodes, state.connections);
  await syncMemoryNodeIndexes(accessToken, projectId, uid, state.nodes.filter((n) => !n.deleted));
  const profile = responseProfileForMode(await readUnifiedMemoryProfile(accessToken, projectId, uid, cfg), MEMORY_SCOPE);

  return {
    ok: true,
    uid,
    mode: MEMORY_SCOPE,
    importedEntries: entries.length,
    skippedEntries: Math.max(0, rawEntries.length - entries.length),
    hasMore: rawEntries.length > entries.length,
    limitReason: rawEntries.length > entries.length ? 'bootstrap_entry_cap' : '',
    createdNodesApprox: created,
    promotedNodesApprox: promoted,
    incrementedCount: incrementedLabels.size,
    newConnectionsApprox: linked,
    rejectedByGate: bootstrapRejected.length,
    rejectedByGateSamples: bootstrapRejected.slice(0, 12),
    routedToCandidate: bootstrapRoutedToCandidate.length,
    routedToCandidateSamples: bootstrapRoutedToCandidate.slice(0, 12),
    counts,
    graph: {
      ok: true,
      uid,
      mode: MEMORY_SCOPE,
      activeMode: MEMORY_SCOPE,
      profile,
      stats: {
        nodes: unified.nodes.length,
        connections: unified.connections.length,
        autoLearned: unified.nodes.filter((n) => n.learned).length,
      },
      nodes: unified.nodes.map((n) => ({
        ...n,
        visualSize: n.isRoot ? 48 : memoryNodeSizeForCount(n.count),
        modeScope: MEMORY_SCOPE,
      })),
      connections: unified.connections,
      memoryMeta: {
        activeMode: MEMORY_SCOPE,
        memoryEnabled: true,
        memoryNodeCount: counts.nodeCount,
        memoryConnectionCount: counts.connectionCount,
        memoryAutoLearnedCount: counts.autoLearnedCount,
        memoryVersion: MEMORY_VERSION,
      },
    },
  };
}


function normalizeSyntheticHistoryEntry(entry, fallbackIndex = 0) {
  const timestamp = num(entry?.timestamp ?? entry?.ts ?? entry?.nowMs, 0);
  const safeTs = timestamp > 0 ? timestamp : (Date.now() - ((fallbackIndex + 1) * 60 * 60 * 1000));
  const fallbackText = trimMemoryText(entry?.text || entry?.snippet || entry?.content || '', 4000);
  const messages = Array.isArray(entry?.messages) && entry.messages.length ? entry.messages : (fallbackText ? [{ role: 'user', content: fallbackText }] : []);
  const assistantText = trimMemoryText(entry?.assistantText || entry?.assistant || '', 1000);
  const sourceTag = trimMemoryText(entry?.sourceTag || entry?.source || 'synthetic_history', 40).toLowerCase() || 'synthetic_history';
  const threadId = trimMemoryText(entry?.threadId || entry?.chatId || entry?.conversationId || `synthetic_${safeTs}`, 120);
  return {
    timestamp: safeTs,
    messages,
    assistantText,
    sourceTag,
    threadId,
    chatId: threadId,
    conversationId: threadId,
    title: trimMemoryText(entry?.title || '', 120),
    snippet: trimMemoryText(entry?.snippet || fallbackText, 420),
    text: fallbackText
  };
}

async function importSyntheticDatedHistory(env, accessToken, projectId, uid, cfg, body = {}) {
  const rawEntries = Array.isArray(body?.entries) ? body.entries : [];
  const allEntries = rawEntries.map((entry, index) => normalizeSyntheticHistoryEntry(entry, index)).sort((a, b) => a.timestamp - b.timestamp);
  if (!allEntries.length) return { ok: false, error: 'entries required' };

  const batchInfo = body?.batch && typeof body.batch === 'object' ? body.batch : {};
  const requestedMax = Math.min(MEMORY_SYNTHETIC_IMPORT_MAX_ENTRIES_PER_RUN, clampInt(body?.maxEntriesPerRun || batchInfo?.maxEntriesPerRun, MEMORY_SYNTHETIC_IMPORT_MAX_ENTRIES_PER_RUN, 1, 48));
  const entries = allEntries.slice(0, requestedMax);
  const batchIndex = clampInt(body?.batchIndex ?? batchInfo?.batchIndex, 0, 0, 9999);
  const totalBatches = clampInt(body?.totalBatches ?? batchInfo?.totalBatches, 1, 1, 9999);
  const isFirstBatch = body?.isFirstBatch === true || batchInfo?.isFirstBatch === true || batchIndex === 0;
  const isLastBatch = body?.isLastBatch === true || batchInfo?.isLastBatch === true || batchIndex >= totalBatches - 1;
  const includeOverview = body?.includeOverview === true || isLastBatch;
  const chunkSize = clampInt(body?.chunkSize ?? batchInfo?.chunkSize, 8, 1, 12);

  const processed = [];
  let imported = 0;
  let createdNodesApprox = 0;
  let promotedNodesApprox = 0;
  let incrementedCount = 0;
  let newConnectionsApprox = 0;

  for (let i = 0; i < entries.length; i += chunkSize) {
    const chunk = entries.slice(i, i + chunkSize);
    const bootstrapEntries = chunk.map((entry) => ({
      title: entry.title || '',
      sourceTag: entry.sourceTag || 'synthetic_history',
      snippet: trimMemoryText(getLastUserMessageText(entry.messages || []) || entry.snippet || '', 420),
      text: trimMemoryText([
        entry.title ? `TITLE: ${entry.title}` : '',
        entry.messages && entry.messages.length ? entry.messages.map((m) => `${String(m?.role || 'user').toUpperCase()}: ${String(m?.content || '')}`).join('\n') : '',
        entry.assistantText ? `ASSISTANT: ${entry.assistantText}` : ''
      ].filter(Boolean).join('\n'), 3200)
    }));
    const result = await processMemoryBootstrapImport(env, accessToken, projectId, uid, cfg, {
      mode: MEMORY_SCOPE,
      entries: bootstrapEntries,
      resetLearned: false
    });
    if (!result?.ok) return result;
    imported += chunk.length;
    createdNodesApprox += num(result?.createdNodesApprox, 0);
    promotedNodesApprox += num(result?.promotedNodesApprox, 0);
    incrementedCount += num(result?.incrementedCount, 0);
    newConnectionsApprox += num(result?.newConnectionsApprox, 0);
    for (const entry of chunk) {
      processed.push({
        threadId: entry.threadId,
        sourceTag: entry.sourceTag,
        timestamp: entry.timestamp,
        dayKey: safeIsoDateFromMs(entry.timestamp),
        title: entry.title || null,
        messageCount: Array.isArray(entry.messages) ? entry.messages.length : 0
      });
    }
  }

  const remaining = Math.max(0, allEntries.length - entries.length);
  const overview = includeOverview ? await getMemoryFinalStatusPayload(accessToken, projectId, uid, cfg) : null;
  return {
    ok: true,
    uid,
    mode: MEMORY_SCOPE,
    imported,
    skippedBecauseOfLimit: remaining,
    hasMoreInPayload: remaining > 0,
    batch: {
      batchIndex,
      totalBatches,
      isFirstBatch,
      isLastBatch,
      requested: allEntries.length,
      processed: imported,
      remainingInPayload: remaining
    },
    createdNodesApprox,
    promotedNodesApprox,
    incrementedCount,
    newConnectionsApprox,
    counts: overview?.counts || null,
    processed,
    overview
  };
}

async function getModelsCatalogCached(env) {
  if (modelsCache && Date.now() - modelsCacheAt < MODELS_TTL_MS) return modelsCache;
  const res = await fetch('https://openrouter.ai/api/v1/models', {
    headers: {
      Authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
      'HTTP-Referer': 'https://gpmai.app',
      'X-Title': 'GPMai'
    }
  });
  if (!res.ok) throw new Error(`OpenRouter /models failed: ${res.status} ${await res.text()}`);
  const raw = await res.json(),
    list = Array.isArray(raw?.data) ? raw.data : [];
  const all = list.map(normalizeOpenRouterModel).filter(Boolean),
    providers = buildProvidersSummary(all);
  const categoriesCount = {
    all: all.length,
    chat: 0,
    image: 0,
    audio: 0,
    video: 0,
    tools: 0,
    other: 0
  };
  for (const m of all) categoriesCount[m.category] != null ? categoriesCount[m.category] += 1 : categoriesCount
    .other += 1;
  modelsCache = {
    all,
    providers,
    categoriesCount
  };
  modelsCacheAt = Date.now();
  return modelsCache;
}

function normalizeOpenRouterModel(m) {
  const id = m?.id ? String(m.id) : null;
  if (!id) return null;
  const provider = id.includes('/') ? id.split('/')[0].toLowerCase() : 'unknown';
  const providerLabel = providerLabelFor(provider);
  const name = m?.name ? String(m.name) : id,
    contextLength = num(m?.context_length, 0),
    pricing = (m?.pricing && typeof m.pricing === 'object') ? m.pricing : null;
  const arch = m?.architecture && typeof m.architecture === 'object' ? m.architecture : {};
  const inputMods = Array.isArray(arch?.input_modalities) ? arch.input_modalities : [],
    outputMods = Array.isArray(arch?.output_modalities) ? arch.output_modalities : [];
  const modalityStr = typeof arch?.modality === 'string' ? arch.modality : '';
  const arrowMods = modalityStr.includes('->') ? modalityStr.split('->').map((x) => x.trim()).filter(Boolean) : [];
  const supportedParams = Array.isArray(m?.supported_parameters) ? m.supported_parameters.map((x) => String(x)
    .toLowerCase()) : [];
  const modalities = [...inputMods.map((x) => String(x).toLowerCase()), ...outputMods.map((x) => String(x)
  .toLowerCase()), ...arrowMods.map((x) => String(x).toLowerCase())].filter(Boolean);
  const supportsTools = supportedParams.includes('tools') || supportedParams.includes('tool_choice');
  const category = inferCategory({
    id,
    outputModalities: outputMods,
    modalityStr,
    supportsTools,
    pricing
  });
  const capabilities = [];
  if (supportsTools) capabilities.push('tools');
  if (modalities.includes('image')) capabilities.push('image');
  if (modalities.includes('audio')) capabilities.push('audio');
  if (modalities.includes('video')) capabilities.push('video');
  if (inputMods.map((x) => String(x).toLowerCase()).includes('image') && outputMods.map((x) => String(x).toLowerCase())
    .includes('text')) capabilities.push('vision');
  return {
    id,
    name,
    provider,
    providerLabel,
    category,
    modalities,
    contextLength,
    pricing,
    priceTier: inferPriceTier(pricing),
    capabilities,
    _score: computeRecommendScore({
      provider,
      category,
      pricing,
      contextLength,
      id,
      name
    })
  };
}

function inferCategory({
  id,
  outputModalities,
  modalityStr,
  supportsTools,
  pricing
}) {
  const low = String(id || '').toLowerCase(),
    outMods = Array.isArray(outputModalities) ? outputModalities.map((x) => String(x).toLowerCase()) : [];
  if (outMods.includes('image')) return 'image';
  if (outMods.includes('video')) return 'video';
  if (outMods.includes('audio')) return 'audio';
  if (supportsTools) return 'tools';
  const mod = String(modalityStr || '').toLowerCase();
  if (mod.includes('->image')) return 'image';
  if (mod.includes('->video')) return 'video';
  if (mod.includes('->audio')) return 'audio';
  if (pricing && typeof pricing === 'object') {
    const keys = Object.keys(pricing).map((k) => k.toLowerCase());
    if (keys.includes('image')) return 'image';
    if (keys.includes('audio')) return 'audio';
    if (keys.includes('video')) return 'video';
  }
  if (/\b(dall-e|ideogram|flux|stable-diffusion|sdxl|sd)\b/i.test(low)) return 'image';
  if (/\b(runway|video)\b/i.test(low)) return 'video';
  if (/\b(whisper|tts|speech|audio)\b/i.test(low)) return 'audio';
  return 'chat';
}

function inferPriceTier(pricing) {
  if (!pricing || typeof pricing !== 'object') return 'unknown';
  const p = num(pricing.prompt, NaN),
    c = num(pricing.completion, NaN),
    any = Number.isFinite(p) ? p : (Number.isFinite(c) ? c : NaN);
  if (!Number.isFinite(any)) return 'unknown';
  if (any <= 0.0002) return 'budget';
  if (any <= 0.0015) return 'standard';
  return 'premium';
}

function computeRecommendScore({
  provider,
  category,
  pricing,
  contextLength,
  id,
  name
}) {
  let s = 0;
  const major = new Set(['openai', 'anthropic', 'google', 'meta', 'meta-llama', 'mistral', 'mistralai', 'deepseek']);
  if (major.has(provider)) s += 50;
  if (category === 'chat') s += 10;
  if (pricing) s += 8;
  if (contextLength > 0) s += 5;
  if (contextLength >= 128000) s += 4;
  else if (contextLength >= 32000) s += 2;
  if (name && name !== id) s += 1;
  return s;
}

function buildProvidersSummary(allModels) {
  const map = new Map();
  for (const m of allModels) {
    const slug = m.provider || 'unknown';
    if (!map.has(slug)) map.set(slug, {
      slug,
      label: m.providerLabel || slug,
      total: 0,
      categoriesCount: {
        chat: 0,
        image: 0,
        audio: 0,
        video: 0,
        tools: 0,
        other: 0
      }
    });
    const p = map.get(slug);
    p.total += 1;
    p.categoriesCount[m.category] != null ? p.categoriesCount[m.category] += 1 : p.categoriesCount.other += 1;
  }
  return Array.from(map.values()).sort((a, b) => (b.total - a.total) || String(a.label).localeCompare(String(b.label)));
}

function sortModels(list, sort) {
  const arr = Array.isArray(list) ? list.slice() : [];
  switch (sort) {
    case 'az':
      arr.sort((a, b) => String(a.name).localeCompare(String(b.name)));
      return arr;
    case 'provider':
      arr.sort((a, b) => {
        const c = String(a.providerLabel || a.provider).localeCompare(String(b.providerLabel || b.provider));
        return c || String(a.name).localeCompare(String(b.name));
      });
      return arr;
    case 'context_desc':
      arr.sort((a, b) => (num(b.contextLength, 0) - num(a.contextLength, 0)) || String(a.name).localeCompare(String(b
        .name)));
      return arr;
    case 'price_asc':
      arr.sort((a, b) => (tierRank(a.priceTier) - tierRank(b.priceTier)) || String(a.name).localeCompare(String(b
        .name)));
      return arr;
    case 'price_desc':
      arr.sort((a, b) => (tierRank(b.priceTier) - tierRank(a.priceTier)) || String(a.name).localeCompare(String(b
        .name)));
      return arr;
    default:
      arr.sort((a, b) => (num(b._score, 0) - num(a._score, 0)) || String(a.name).localeCompare(String(b.name)));
      return arr;
  }
}

function tierRank(tier) {
  if (tier === 'budget') return 0;
  if (tier === 'standard') return 1;
  if (tier === 'premium') return 2;
  return 9;
}

function providerLabelFor(slug) {
  const s = String(slug || '').toLowerCase();
  const map = {
    openai: 'OpenAI',
    anthropic: 'Anthropic',
    google: 'Google',
    meta: 'Meta',
    'meta-llama': 'Meta',
    mistral: 'Mistral',
    mistralai: 'Mistral',
    deepseek: 'DeepSeek',
    moonshot: 'Moonshot',
    kimi: 'Kimi',
    zhipu: 'Zhipu',
    glm: 'GLM',
    qwen: 'Qwen',
    alibaba: 'Alibaba',
    'black-forest-labs': 'Black Forest Labs',
    ideogram: 'Ideogram',
    runway: 'Runway',
    elevenlabs: 'ElevenLabs'
  };
  return map[s] || titleCaseProvider(s);
}

function titleCaseProvider(s) {
  return s ? s.split(/[-_]/g).filter(Boolean).map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ') : 'Unknown';
}

async function loadPublicConfig(accessToken, projectId) {
  const pub = await fsGetDoc(accessToken, projectId, 'config/public');
  const cfg = parseFirestoreFields(pub?.fields || {});
  return {
    bankCap: num(cfg.bankCap, 50000),
    dailyCreditAmount: num(cfg.dailyCreditAmount, 10000),
    defaultMonthlyCapPoints: num(cfg.defaultMonthlyCapPoints, 300000),
    minGatePoints: num(cfg.minGatePoints, 300),
    minImageGatePoints: num(cfg.minImageGatePoints, 500),
    minAudioGatePoints: num(cfg.minAudioGatePoints, 200),
    minVideoGatePoints: num(cfg.minVideoGatePoints, 1200),
    minPointsPerRequest: num(cfg.minPointsPerRequest, 20),
    defaultModel: String(cfg.defaultModel || 'openai/gpt-4o-mini'),
    promptChipModel: String(cfg.promptChipModel || 'google/gemini-2.5-flash-lite'),
    promptMediumMaxLines: num(cfg.promptMediumMaxLines, 80),
    promptMediumMaxChars: num(cfg.promptMediumMaxChars, 5000),
    promptHardMaxLines: num(cfg.promptHardMaxLines, 150),
    promptHardMaxChars: num(cfg.promptHardMaxChars, 10000),
    memoryEnabledDefault: cfg.memoryEnabledDefault !== false,
    memoryAutoLearnEnabled: cfg.memoryAutoLearnEnabled !== false,
    // --- Memory extraction model routing (two-pass + three-tier triage) ---
    // memoryLearnModel kept as backward-compat alias; the engine now routes via
    // memoryMediumModel / memoryStrongModel / memorySummaryModel / memoryEmbeddingModel.
    memoryLearnModel: String(cfg.memoryLearnModel || cfg.memoryMediumModel || 'google/gemini-2.5-flash'),
    memoryMediumModel: String(cfg.memoryMediumModel || cfg.memoryLearnModel || 'google/gemini-2.5-flash'),
    memoryStrongModel: String(cfg.memoryStrongModel || 'anthropic/claude-sonnet-4.6'),
    memorySummaryEnabled: cfg.memorySummaryEnabled !== false,
    memorySummaryModel: String(cfg.memorySummaryModel || 'google/gemini-2.5-flash-lite'),
    memoryEmbeddingModel: String(cfg.memoryEmbeddingModel || MEMORY_EMBEDDING_MODEL_DEFAULT),
    memorySummaryMaxPerTurn: num(cfg.memorySummaryMaxPerTurn, MEMORY_EXTRACTION_SUMMARY_MAX_PER_TURN),
    memoryPromptMaxChars: num(cfg.memoryPromptMaxChars, 1100),
    memorySuppressionDays: num(cfg.memorySuppressionDays, 45),
    memoryCandidatePromoteSessionsStrong: num(cfg.memoryCandidatePromoteSessionsStrong, 1),
    memoryCandidatePromoteSessionsWeak: num(cfg.memoryCandidatePromoteSessionsWeak, 2),
    memoryHeatDecayStep: num(cfg.memoryHeatDecayStep, 6),
    memoryHeatDecayFloor: num(cfg.memoryHeatDecayFloor, 12),
    memoryStaleCandidateDays: num(cfg.memoryStaleCandidateDays, 21),
    memorySessionGapHours: num(cfg.memorySessionGapHours, 12),
    memoryExtractIdleMs: num(cfg.memoryExtractIdleMs, MEMORY_EXTRACTION_IDLE_MS_DEFAULT),
    memoryExtractLongActiveMs: num(cfg.memoryExtractLongActiveMs, MEMORY_EXTRACTION_LONG_ACTIVE_MS_DEFAULT),
    memoryExtractOverflowMessages: num(cfg.memoryExtractOverflowMessages, MEMORY_EXTRACTION_OVERFLOW_MSGS_DEFAULT),
    memoryExtractOverflowChars: num(cfg.memoryExtractOverflowChars, MEMORY_EXTRACTION_OVERFLOW_CHARS_DEFAULT),
    memoryExtractCooldownMs: num(cfg.memoryExtractCooldownMs, MEMORY_EXTRACTION_COOLDOWN_MS_DEFAULT),
    memoryExtractMinMeaningfulChars: num(cfg.memoryExtractMinMeaningfulChars, MEMORY_EXTRACTION_MIN_MEANINGFUL_CHARS_DEFAULT),
    memoryExtractMinUserMessages: num(cfg.memoryExtractMinUserMessages, MEMORY_EXTRACTION_MIN_USER_MESSAGES_DEFAULT),
    memoryEventEvidenceCap: num(cfg.memoryEventEvidenceCap, MEMORY_EVENT_EVIDENCE_CAP),
    memoryNodeEventPreviewCap: num(cfg.memoryNodeEventPreviewCap, MEMORY_NODE_EVENT_PREVIEW_CAP),
    memoryReviewExpiryDays: num(cfg.memoryReviewExpiryDays, MEMORY_REVIEW_EXPIRY_DAYS),
    memoryConsolidationNodeAutoThreshold: num(cfg.memoryConsolidationNodeAutoThreshold, MEMORY_CONSOLIDATION_NODE_AUTO_THRESHOLD),
    memoryConsolidationNodePendingThreshold: num(cfg.memoryConsolidationNodePendingThreshold, MEMORY_CONSOLIDATION_NODE_PENDING_THRESHOLD),
    memoryConsolidationEventAutoThreshold: num(cfg.memoryConsolidationEventAutoThreshold, MEMORY_CONSOLIDATION_EVENT_AUTO_THRESHOLD),
    memoryConsolidationEventPendingThreshold: num(cfg.memoryConsolidationEventPendingThreshold, MEMORY_CONSOLIDATION_EVENT_PENDING_THRESHOLD),
    pointsPerInr: num(cfg.pointsPerInr, 100),
    usdToInrRate: num(cfg.usdToInrRate, 83),
    safetyMultiplier: num(cfg.safetyMultiplier, 2.3),
  };
}

function computePointsCost(usdCost, cfg) {
  const inr = usdCost * cfg.usdToInrRate;
  const calculated = Math.ceil(Math.max(0, inr * cfg.pointsPerInr * cfg.safetyMultiplier));
  return Math.max(Math.max(0, num(cfg.minPointsPerRequest, 20)), calculated);
}

function gatePointsForCategory(cfg, category) {
  if (category === 'image') return num(cfg.minImageGatePoints, 500);
  if (category === 'audio') return num(cfg.minAudioGatePoints, 200);
  if (category === 'video') return num(cfg.minVideoGatePoints, 1200);
  return num(cfg.minGatePoints, 300);
}
async function loadMediaPricingOverrides(accessToken, projectId) {
  if (mediaPricingOverridesCache && Date.now() - mediaPricingOverridesAt < MEDIA_PRICING_TTL_MS)
  return mediaPricingOverridesCache;
  const doc = await fsGetDoc(accessToken, projectId, 'config/mediaPricing');
  mediaPricingOverridesCache = parseFirestoreFields(doc?.fields || {}) || {};
  mediaPricingOverridesAt = Date.now();
  return mediaPricingOverridesCache;
}
async function resolveMediaPricing(accessToken, projectId, modelId) {
  const base = HARDCODED_MEDIA_MODELS[modelId],
    overrides = await loadMediaPricingOverrides(accessToken, projectId),
    override = overrides && overrides[modelId] && typeof overrides[modelId] === 'object' ? overrides[modelId] : null;
  if (!base && !override) return null;
  return {
    ...(base || {}),
    ...(override || {}),
    pricingSource: override ? 'firestore_override' : 'hardcoded',
    pricingVersion: override ? 'firestore-override' : PRICING_VERSION
  };
}

function computeReplicateUsdCost(pricing, prediction, prompt, input) {
  const billingType = String(pricing?.billingType || '').toLowerCase();
  if (billingType === 'per_run') return Math.max(0, num(pricing.usdPerRun, 0));
  if (billingType === 'per_second') return Math.max(0, num(prediction?.metrics?.predict_time, 0) * num(pricing
    .usdPerSecond, 0));
  if (billingType === 'per_1k_chars') {
    const text = String(input?.text || prompt || '');
    return Math.max(0, (text.length / 1000) * num(pricing.usdPer1kChars, 0));
  }
  throw new Error(`unsupported billingType for ${prediction?.id || 'prediction'}: ${billingType}`);
}

function normalizeSpeechVoiceHint(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (!raw) return '';
  for (const item of ['male', 'female', 'child', 'narrator', 'calm', 'energetic', 'soft', 'powerful', 'whisper', 'rap',
      'choir'
    ])
    if (raw.includes(item)) return item;
  return raw;
}

function buildReplicateInput(category, prompt, input, inputUrls, pricing, modelId = '') {
  const model = String(modelId || '').toLowerCase();
  const allowedKeys = ['aspect_ratio', 'size', 'width', 'height', 'quality', 'negative_prompt', 'seed', 'duration',
    'resolution', 'num_outputs', 'output_format', 'guidance_scale', 'steps', 'style', 'fps', 'motion_bucket_id',
    'camera_fixed', 'cfg', 'prompt_strength', 'lyrics', 'text', 'voice', 'voice_id', 'speaker', 'language', 'top_k',
    'top_p', 'temperature', 'image_prompt_strength', 'voice_style', 'vocal_style', 'reference_audio', 'audio_prompt',
    'mode'
  ];
  const out = {
    prompt: String(prompt || '').trim()
  };
  for (const k of allowedKeys)
    if (input[k] != null) out[k] = input[k];
  const firstUrl = Array.isArray(inputUrls) && inputUrls.length > 0 ? inputUrls[0] : '';
  const secondUrl = Array.isArray(inputUrls) && inputUrls.length > 1 ? inputUrls[1] : '';
  const isSpeechModel = /\b(speech|tts|qwen3-tts|elevenlabs|voice)\b/i.test(model);
  const isMusicModel = model === 'minimax/music-1.5' || model === 'stability-ai/stable-audio-2.5' ||
    /\b(stable-audio|stable audio|music|song)\b/i.test(model);
  if (category === 'image') {
    if (isStrongEditImageModel(model)) {
      const sourceImage = input.image || input.input_image || firstUrl || '';
      if (sourceImage) {
        out.image = sourceImage;
        out.input_image = sourceImage;
        out.image_prompt_strength = input.image_prompt_strength ?? 0.9;
        out.prompt_strength = input.prompt_strength ?? 0.35;
        if (pricing?.supportsReferenceImage) out.reference_image = sourceImage;
      }
    } else if (isReferenceImageModel(model)) {
      const ref = input.reference_image || input.image || firstUrl || '';
      if (ref) {
        out.reference_image = ref;
        out.image = ref;
        out.image_prompt_strength = input.image_prompt_strength ?? 0.8;
      }
    } else if (isControlImageModel(model)) {
      const control = input.image || input.input_image || firstUrl || '';
      if (control) {
        out.image = control;
        out.input_image = control;
      }
    } else {
      if (input.image) out.image = input.image;
      else if (input.input_image) out.input_image = input.input_image;
      else if (firstUrl && (pricing?.supportsImageInput || pricing?.supportsEdit || pricing?.supportsReferenceImage))
        out.image = firstUrl;
      if (input.reference_image) out.reference_image = input.reference_image;
      else if (firstUrl && pricing?.supportsReferenceImage && !out.reference_image) out.reference_image = firstUrl;
    }
  }
  if (category === 'video') {
    const imageUrl = input.image || input.start_image || firstUrl || '';
    const audioUrl = input.audio || input.audio_url || input.reference_audio || secondUrl || '';
    if (isImageAudioVideoModel(model)) {
      if (imageUrl) {
        out.image = imageUrl;
        out.start_image = imageUrl;
      }
      if (audioUrl) {
        out.audio = audioUrl;
        out.audio_prompt = String(prompt || '').trim();
      }
      out.prompt_strength = input.prompt_strength ?? 0.4;
    } else if (isImageToVideoModel(model)) {
      if (imageUrl) {
        out.image = imageUrl;
        out.start_image = imageUrl;
      }
    } else {
      if (input.image) out.image = input.image;
      else if (input.start_image) out.start_image = input.start_image;
      else if (imageUrl && pricing?.supportsImageInput) out.image = imageUrl;
      if (input.audio) out.audio = input.audio;
      else if (input.audio_url) out.audio = input.audio_url;
    }
  }
  if (category === 'audio') {
    if (input.reference_audio) out.reference_audio = input.reference_audio;
    else if (input.audio) out.reference_audio = input.audio;
    else if (input.audio_url) out.reference_audio = input.audio_url;
    else if (firstUrl && pricing?.supportsAudioInput) {
      out.reference_audio = firstUrl;
      out.audio = firstUrl;
    }
    const isQwenTts = model === 'qwen/qwen3-tts',
      isElevenLabsVoiceEnum = ['elevenlabs/turbo-v2.5', 'elevenlabs/flash-v2.5', 'elevenlabs/v2-multilingual',
        'elevenlabs/v3'
      ].includes(model),
      isMiniMaxSpeech = ['minimax/speech-2.8-turbo', 'minimax/speech-2.8-hd'].includes(model),
      isVoiceCloneModel = model === 'minimax/voice-cloning' || /voice-cloning/i.test(model);
    if (isSpeechModel) {
      const speechText = input.text ?? input.prompt_text ?? input.script ?? prompt;
      out.text = String(speechText || '');
      if (isQwenTts) {
        const exactSpeaker = String(input.speaker || '').trim();
        if (exactSpeaker) out.speaker = exactSpeaker;
      } else if (isElevenLabsVoiceEnum) {
        const exactVoice = String(input.voice || '').trim();
        if (exactVoice) out.voice = exactVoice;
      } else if (isVoiceCloneModel) {
        if (input.voice_id != null) out.voice_id = input.voice_id;
      } else if (isMiniMaxSpeech) {
        const speechVoice = normalizeSpeechVoiceHint(input.voice_style ?? input.voice ?? '');
        if (speechVoice) {
          out.voice = speechVoice;
          out.voice_style = speechVoice;
        }
      } else {
        if (input.voice != null) out.voice = String(input.voice);
        if (input.voice_style != null) out.voice_style = normalizeSpeechVoiceHint(input.voice_style);
        if (input.speaker != null) out.speaker = String(input.speaker);
      }
    }
    if (isMusicModel) {
      const musicText = input.lyrics ?? input.text ?? prompt;
      out.lyrics = String(musicText || '');
      out.prompt = String(prompt || musicText || '');
    }
    if (!out.text && input.text != null) out.text = String(input.text);
    if (!out.lyrics && input.lyrics != null) out.lyrics = String(input.lyrics);
  }
  return out;
}
async function ensureUserAndDailyCredit(accessToken, projectId, uid, cfg) {
  const userPath = `users/${uid}`;
  let userDoc = await fsGetDoc(accessToken, projectId, userPath);
  const today = todayKeyIST(),
    monthKey = monthKeyIST();
  if (!userDoc) {
    await fsCreateDoc(accessToken, projectId, userPath, {
      pointsBalance: cfg.dailyCreditAmount,
      bankCap: cfg.bankCap,
      dailyCreditAmount: cfg.dailyCreditAmount,
      lastDailyCreditDate: today,
      nextDailyCreditAt: nextDailyCreditAtISTTimestamp(),
      monthlyCapPoints: cfg.defaultMonthlyCapPoints,
      monthlyCapKey: monthKey,
      monthlyPointsSpent: 0,
      monthlyBlocked: false,
      plan: 'free',
      subscriptionStatus: 'inactive',
      isBanned: false,
      riskScore: 0,
      lastRequestAt: Date.now()
    });
    userDoc = await fsGetDoc(accessToken, projectId, userPath);
  }
  let user = parseFirestoreFields(userDoc.fields || {});
  if (user.isBanned) return {
    ok: false,
    uid,
    banned: true,
    wallet: null
  };
  if (user.monthlyCapKey !== monthKey) {
    await fsPatchDoc(accessToken, projectId, userPath, {
      monthlyCapKey: monthKey,
      monthlyPointsSpent: 0,
      monthlyBlocked: false,
      lastRequestAt: Date.now()
    });
    user = parseFirestoreFields((await fsGetDoc(accessToken, projectId, userPath)).fields || {});
  }
  let didDailyCredit = false;
  if (user.lastDailyCreditDate !== today) {
    const before = num(user.pointsBalance, 0),
      cap = num(user.bankCap, cfg.bankCap),
      credit = num(user.dailyCreditAmount, cfg.dailyCreditAmount),
      after = Math.min(before + credit, cap);
    await fsPatchDoc(accessToken, projectId, userPath, {
      pointsBalance: after,
      lastDailyCreditDate: today,
      nextDailyCreditAt: nextDailyCreditAtISTTimestamp(),
      lastRequestAt: Date.now(),
      monthlyCapKey: monthKey
    });
    didDailyCredit = true;
    user = parseFirestoreFields((await fsGetDoc(accessToken, projectId, userPath)).fields || {});
  } else {
    await fsPatchDoc(accessToken, projectId, userPath, {
      lastRequestAt: Date.now()
    });
  }
  return {
    ok: true,
    uid,
    didDailyCredit,
    wallet: {
      pointsBalance: num(user.pointsBalance, 0),
      bankCap: num(user.bankCap, cfg.bankCap),
      dailyCreditAmount: num(user.dailyCreditAmount, cfg.dailyCreditAmount),
      lastDailyCreditDate: user.lastDailyCreditDate || today,
      nextDailyCreditAt: user.nextDailyCreditAt || null,
      minGatePoints: cfg.minGatePoints,
      minImageGatePoints: cfg.minImageGatePoints,
      minAudioGatePoints: cfg.minAudioGatePoints,
      minVideoGatePoints: cfg.minVideoGatePoints,
      monthlyBlocked: !!user.monthlyBlocked,
      plan: user.plan || 'free',
      subscriptionStatus: user.subscriptionStatus || 'inactive'
    }
  };
}
async function deductPointsAndUpdateStats(accessToken, projectId, uid, cfg, info) {
  // V3.1.6: batched into a single Firestore commit to preserve subrequest budget.
  // Before: 2 reads + 7 sequential writes = 9 subrequests per /chat turn.
  // After:  2 reads + 1 commitWrites = 3 subrequests.
  const userPath = `users/${uid}`;
  const today = todayKeyIST(),
    monthKey = monthKeyIST();
  const nowMs = Date.now();
  // Two reads required (user + statsDaily) to compute the deltas. Run in parallel.
  const [userDoc, statsDoc] = await Promise.all([
    fsGetDoc(accessToken, projectId, userPath),
    fsGetDoc(accessToken, projectId, `statsDaily/${today}`)
  ]);
  const user = parseFirestoreFields(userDoc?.fields || {});
  const stats = parseFirestoreFields(statsDoc?.fields || {});
  const pointsBefore = num(user.pointsBalance, 0),
    spentBefore = num(user.monthlyPointsSpent, 0),
    cap = num(user.monthlyCapPoints, cfg.defaultMonthlyCapPoints),
    pointsCost = Math.max(0, num(info.pointsCost, 0)),
    usdCost = Math.max(0, num(info.usdCost, 0));
  const pointsAfter = Math.max(0, pointsBefore - pointsCost),
    spentAfter = spentBefore + pointsCost,
    monthlyBlocked = spentAfter >= cap;
  const txnId = `${uid}_${nowMs}`;
  const dailyKeyPath = `users/${uid}/usageDaily/${today}`;
  const monthlyKeyPath = `users/${uid}/usageMonthly/${monthKey}`;
  // Read current daily/monthly in parallel with the commit setup â€” cheap.
  const [dailyUsageDoc, monthlyUsageDoc] = await Promise.all([
    fsGetDoc(accessToken, projectId, dailyKeyPath),
    fsGetDoc(accessToken, projectId, monthlyKeyPath)
  ]);
  const daily = parseFirestoreFields(dailyUsageDoc?.fields || {});
  const monthly = parseFirestoreFields(monthlyUsageDoc?.fields || {});
  const writes = [
    makeFirestoreUpdateWrite(projectId, userPath, {
      pointsBalance: pointsAfter,
      monthlyPointsSpent: spentAfter,
      monthlyCapKey: monthKey,
      monthlyBlocked,
      lastRequestAt: nowMs
    }),
    makeFirestoreUpdateWrite(projectId, `statsDaily/${today}`, {
      date: today,
      totalRequests: num(stats.totalRequests, 0) + 1,
      totalUsdCost: num(stats.totalUsdCost, 0) + usdCost,
      totalPointsSpent: num(stats.totalPointsSpent, 0) + pointsCost,
      lastUpdatedAt: nowMs
    }),
    makeFirestoreUpdateWrite(projectId, `txns/${txnId}`, {
      uid,
      ts: nowMs,
      day: today,
      monthKey,
      provider: info.provider || 'unknown',
      category: info.category || 'other',
      model: info.model || 'unknown',
      predictionId: info.predictionId || '',
      pricingSource: info.pricingSource || '',
      pricingVersion: info.pricingVersion || '',
      predictTime: num(info.predictTime, 0),
      usdCost,
      pointsCost,
      pointsBefore,
      pointsAfter,
      monthlyPointsSpentAfter: spentAfter,
      monthlyCapPoints: cap,
      monthlyBlocked
    }),
    makeFirestoreUpdateWrite(projectId, dailyKeyPath, {
      dayKey: today,
      pointsSpent: num(daily.pointsSpent, 0) + pointsCost,
      requests: num(daily.requests, 0) + 1,
      lastUpdatedAt: nowMs
    }),
    makeFirestoreUpdateWrite(projectId, monthlyKeyPath, {
      monthKey,
      pointsSpent: num(monthly.pointsSpent, 0) + pointsCost,
      requests: num(monthly.requests, 0) + 1,
      lastUpdatedAt: nowMs
    })
  ];
  // Single commit â€” 5 writes in 1 subrequest.
  await fsCommitWritesInChunks(accessToken, projectId, writes, 250);
  return {
    pointsBalance: pointsAfter,
    monthlyPointsSpent: spentAfter,
    monthlyBlocked,
    monthlyCapPoints: cap,
    monthlyCapKey: monthKey
  };
}
async function deductPointsAndUpdateStats_legacy_unbatched(accessToken, projectId, uid, cfg, info) {
  const userPath = `users/${uid}`;
  const today = todayKeyIST(),
    monthKey = monthKeyIST();
  const user = parseFirestoreFields((await fsGetDoc(accessToken, projectId, userPath))?.fields || {});
  const pointsBefore = num(user.pointsBalance, 0),
    spentBefore = num(user.monthlyPointsSpent, 0),
    cap = num(user.monthlyCapPoints, cfg.defaultMonthlyCapPoints),
    pointsCost = Math.max(0, num(info.pointsCost, 0)),
    usdCost = Math.max(0, num(info.usdCost, 0));
  const pointsAfter = Math.max(0, pointsBefore - pointsCost),
    spentAfter = spentBefore + pointsCost,
    monthlyBlocked = spentAfter >= cap;
  await fsPatchDoc(accessToken, projectId, userPath, {
    pointsBalance: pointsAfter,
    monthlyPointsSpent: spentAfter,
    monthlyCapKey: monthKey,
    monthlyBlocked,
    lastRequestAt: Date.now()
  });
  const statsPath = `statsDaily/${today}`,
    stats = parseFirestoreFields((await fsGetDoc(accessToken, projectId, statsPath))?.fields || {});
  await fsCreateOrPatchDoc(accessToken, projectId, statsPath, {
    date: today,
    totalRequests: num(stats.totalRequests, 0) + 1,
    totalUsdCost: num(stats.totalUsdCost, 0) + usdCost,
    totalPointsSpent: num(stats.totalPointsSpent, 0) + pointsCost,
    lastUpdatedAt: Date.now()
  });
  const txnId = `${uid}_${Date.now()}`;
  await fsCreateDoc(accessToken, projectId, `txns/${txnId}`, {
    uid,
    ts: Date.now(),
    day: today,
    monthKey,
    provider: info.provider || 'unknown',
    category: info.category || 'other',
    model: info.model || 'unknown',
    predictionId: info.predictionId || '',
    pricingSource: info.pricingSource || '',
    pricingVersion: info.pricingVersion || '',
    predictTime: num(info.predictTime, 0),
    usdCost,
    pointsCost,
    pointsBefore,
    pointsAfter,
    monthlyPointsSpentAfter: spentAfter,
    monthlyCapPoints: cap,
    monthlyBlocked
  });
  await bumpUsageDaily(accessToken, projectId, uid, today, pointsCost);
  await bumpUsageMonthly(accessToken, projectId, uid, monthKey, pointsCost);
  return {
    pointsBalance: pointsAfter,
    monthlyPointsSpent: spentAfter,
    monthlyBlocked,
    monthlyCapPoints: cap,
    monthlyCapKey: monthKey
  };
}
async function getUsageDoc(accessToken, projectId, path) {
  const doc = await fsGetDoc(accessToken, projectId, path);
  return doc ? parseFirestoreFields(doc.fields || {}) : null;
}
async function bumpUsageDaily(accessToken, projectId, uid, dayKey, pointsCost) {
  const path = `users/${uid}/usageDaily/${dayKey}`,
    cur = (await getUsageDoc(accessToken, projectId, path)) || {
      dayKey,
      pointsSpent: 0,
      requests: 0
    };
  await fsCreateOrPatchDoc(accessToken, projectId, path, {
    dayKey,
    pointsSpent: num(cur.pointsSpent, 0) + pointsCost,
    requests: num(cur.requests, 0) + 1,
    lastUpdatedAt: Date.now()
  });
}
async function bumpUsageMonthly(accessToken, projectId, uid, monthKey, pointsCost) {
  const path = `users/${uid}/usageMonthly/${monthKey}`,
    cur = (await getUsageDoc(accessToken, projectId, path)) || {
      monthKey,
      pointsSpent: 0,
      requests: 0
    };
  await fsCreateOrPatchDoc(accessToken, projectId, path, {
    monthKey,
    pointsSpent: num(cur.pointsSpent, 0) + pointsCost,
    requests: num(cur.requests, 0) + 1,
    lastUpdatedAt: Date.now()
  });
}
async function getDailyUsageSeries(accessToken, projectId, uid, days) {
  const out = [];
  for (let i = days - 1; i >= 0; i--) {
    const key = dayKeyISTDaysAgo(i),
      doc = await getUsageDoc(accessToken, projectId, `users/${uid}/usageDaily/${key}`);
    out.push({
      dayKey: key,
      pointsSpent: num(doc?.pointsSpent, 0),
      requests: num(doc?.requests, 0)
    });
  }
  return out;
}
async function getMonthlyUsageSeries(accessToken, projectId, uid, months) {
  const out = [];
  for (let i = months - 1; i >= 0; i--) {
    const key = monthKeyISTMonthsAgo(i),
      doc = await getUsageDoc(accessToken, projectId, `users/${uid}/usageMonthly/${key}`);
    out.push({
      monthKey: key,
      pointsSpent: num(doc?.pointsSpent, 0),
      requests: num(doc?.requests, 0)
    });
  }
  return out;
}
async function requireFirebaseUid(request, projectId) {
  const authHeader = request.headers.get('Authorization') || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!token) throw new Response('Unauthorized (missing token)', {
    status: 401,
    headers: {
      'content-type': 'text/plain'
    }
  });
  let payload;
  try {
    payload = await verifyFirebaseIdToken(token, projectId);
  } catch {
    throw new Response('Unauthorized (bad token)', {
      status: 401,
      headers: {
        'content-type': 'text/plain'
      }
    });
  }
  const uid = payload.sub;
  if (!uid) throw new Response('Unauthorized (no uid)', {
    status: 401,
    headers: {
      'content-type': 'text/plain'
    }
  });
  return uid;
}
let jwksCache = null,
  jwksCacheAt = 0;
async function getSecureTokenJwks() {
  const ttlMs = 60 * 60 * 1000;
  if (jwksCache && Date.now() - jwksCacheAt < ttlMs) return jwksCache;
  const res = await fetch(
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com');
  if (!res.ok) throw new Error('JWKS fetch failed');
  jwksCache = await res.json();
  jwksCacheAt = Date.now();
  return jwksCache;
}
async function verifyFirebaseIdToken(idToken, projectId) {
  const parts = idToken.split('.');
  if (parts.length !== 3) throw new Error('Malformed JWT');
  const [headerB64, payloadB64, sigB64] = parts;
  const header = JSON.parse(b64urlToString(headerB64));
  const payload = JSON.parse(b64urlToString(payloadB64));
  if (header.alg !== 'RS256' || !header.kid) throw new Error('bad jwt header');
  const now = Math.floor(Date.now() / 1000),
    iss = `https://securetoken.google.com/${projectId}`;
  if (payload.aud !== projectId) throw new Error('aud mismatch');
  if (payload.iss !== iss) throw new Error('iss mismatch');
  if (!payload.sub || typeof payload.sub !== 'string') throw new Error('missing sub');
  if (payload.exp && payload.exp < now) throw new Error('token expired');
  if (payload.iat && payload.iat > now + 60) throw new Error('iat in future');
  const jwks = await getSecureTokenJwks();
  const jwk = (jwks.keys || []).find((k) => k.kid === header.kid);
  if (!jwk) throw new Error('kid not found');
  const key = await crypto.subtle.importKey('jwk', jwk, {
    name: 'RSASSA-PKCS1-v1_5',
    hash: 'SHA-256'
  }, false, ['verify']);
  const ok = await crypto.subtle.verify({
    name: 'RSASSA-PKCS1-v1_5'
  }, key, b64urlToBytes(sigB64), new TextEncoder().encode(`${headerB64}.${payloadB64}`));
  if (!ok) throw new Error('bad signature');
  return payload;
}

function b64urlToString(b64url) {
  const pad = '='.repeat((4 - (b64url.length % 4)) % 4);
  const b64 = (b64url + pad).replace(/-/g, '+').replace(/_/g, '/');
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

function b64urlToBytes(b64url) {
  const pad = '='.repeat((4 - (b64url.length % 4)) % 4);
  const b64 = (b64url + pad).replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

async function getGoogleAccessToken(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const header = {
    alg: 'RS256',
    typ: 'JWT'
  };
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600
  };
  const unsigned = `${toB64Url(JSON.stringify(header))}.${toB64Url(JSON.stringify(claimSet))}`;
  const key = await importPkcs8(serviceAccount.private_key);
  const sig = await crypto.subtle.sign({
    name: 'RSASSA-PKCS1-v1_5'
  }, key, new TextEncoder().encode(unsigned));
  const jwt = `${unsigned}.${bytesToB64Url(new Uint8Array(sig))}`;
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'content-type': 'application/x-www-form-urlencoded'
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt
    })
  });
  if (!res.ok) throw new Error(`oauth token failed: ${res.status} ${await res.text()}`);
  return (await res.json()).access_token;
}
async function fsGetDoc(accessToken, projectId, docPath) {
  const u = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${docPath}`;
  const res = await fetch(u, {
    headers: {
      Authorization: `Bearer ${accessToken}`
    }
  });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`fsGetDoc failed: ${res.status} ${await res.text()}`);
  return await res.json();
}
async function fsCreateDoc(accessToken, projectId, docPath, plainObj) {
  const [collectionPath, documentId] = splitDocPath(docPath);
  const u =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collectionPath}?documentId=${encodeURIComponent(documentId)}`;
  const res = await fetch(u, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json'
    },
    body: JSON.stringify({
      fields: toFirestoreFields(plainObj)
    })
  });
  if (res.status === 409) return fsGetDoc(accessToken, projectId, docPath);
  if (!res.ok) throw new Error(`fsCreateDoc failed: ${res.status} ${await res.text()}`);
  return await res.json();
}
async function fsPatchDoc(accessToken, projectId, docPath, plainObj) {
  const u = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${docPath}`;
  const qs = Object.keys(plainObj || {}).map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`).join('&');
  const res = await fetch(qs ? `${u}?${qs}` : u, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json'
    },
    body: JSON.stringify({
      fields: toFirestoreFields(plainObj)
    })
  });
  if (!res.ok) throw new Error(`fsPatchDoc failed: ${res.status} ${await res.text()}`);
  return await res.json();
}

function buildFirestoreDocName(projectId, docPath) {
  return `projects/${projectId}/databases/(default)/documents/${docPath}`;
}

function makeFirestoreUpdateWrite(projectId, docPath, plainObj, updateMask = null) {
  const write = {
    update: {
      name: buildFirestoreDocName(projectId, docPath),
      fields: toFirestoreFields(plainObj || {})
    }
  };
  const maskFields = Array.isArray(updateMask) ? updateMask.filter(Boolean) : Object.keys(plainObj || {});
  if (maskFields.length) write.updateMask = { fieldPaths: maskFields };
  return write;
}

function makeFirestoreDeleteWrite(projectId, docPath) {
  return { delete: buildFirestoreDocName(projectId, docPath) };
}

async function fsCommitWrites(accessToken, projectId, writes) {
  if (!Array.isArray(writes) || !writes.length) return { writeResults: [] };
  const u = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  const res = await fetch(u, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json'
    },
    body: JSON.stringify({ writes })
  });
  if (!res.ok) throw new Error(`fsCommitWrites failed: ${res.status} ${await res.text()}`);
  return await res.json();
}

async function fsCommitWritesInChunks(accessToken, projectId, writes, chunkSize = 250) {
  for (let i = 0; i < (writes || []).length; i += chunkSize) {
    await fsCommitWrites(accessToken, projectId, writes.slice(i, i + chunkSize));
  }
}
async function fsCreateOrPatchDoc(accessToken, projectId, docPath, plainObj) {
  return fsPatchDoc(accessToken, projectId, docPath, plainObj);
}

async function fsDeleteDoc(accessToken, projectId, docPath) {
  const u = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${docPath}`;
  const res = await fetch(u, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${accessToken}` }
  });
  if (res.status === 404) return true;
  if (!res.ok) throw new Error(`fsDeleteDoc failed: ${res.status} ${await res.text()}`);
  return true;
}

function splitDocPath(docPath) {
  const parts = docPath.split('/').filter(Boolean);
  if (parts.length < 2) throw new Error(`Invalid docPath: ${docPath}`);
  const documentId = parts.pop();
  return [parts.join('/'), documentId];
}

function toFirestoreFields(obj) {
  const out = {};
  for (const [k, v] of Object.entries(obj)) out[k] = toFsValue(v);
  return out;
}

function toFsValue(v) {
  if (v === null || v === undefined) return {
    nullValue: null
  };
  if (typeof v === 'string') return {
    stringValue: v
  };
  if (typeof v === 'number') return Number.isInteger(v) ? {
    integerValue: String(v)
  } : {
    doubleValue: v
  };
  if (typeof v === 'boolean') return {
    booleanValue: v
  };
  if (Array.isArray(v)) return {
    arrayValue: {
      values: v.map(toFsValue)
    }
  };
  if (typeof v === 'object') {
    const fields = {};
    for (const [k, val] of Object.entries(v)) fields[k] = toFsValue(val);
    return {
      mapValue: {
        fields
      }
    };
  }
  if (v instanceof Date) return {
    integerValue: String(v.getTime())
  };
  return {
    stringValue: String(v)
  };
}

function parseFirestoreFields(fields) {
  const out = {};
  for (const [k, val] of Object.entries(fields || {})) out[k] = fromFsValue(val);
  return out;
}

function fromFsValue(val) {
  if (val?.stringValue !== undefined) return val.stringValue;
  if (val?.integerValue !== undefined) return Number(val.integerValue);
  if (val?.doubleValue !== undefined) return Number(val.doubleValue);
  if (val?.booleanValue !== undefined) return !!val.booleanValue;
  if (val?.nullValue !== undefined) return null;
  if (val?.mapValue?.fields !== undefined) return parseFirestoreFields(val.mapValue.fields || {});
  if (val?.arrayValue?.values !== undefined) return (val.arrayValue.values || []).map(fromFsValue);
  return null;
}

function todayKeyIST() {
  const d = new Date(Date.now() + 330 * 60 * 1000);
  return d.toISOString().slice(0, 10);
}

function monthKeyIST() {
  const d = new Date(Date.now() + 330 * 60 * 1000);
  return d.toISOString().slice(0, 7);
}

function dayKeyISTDaysAgo(daysAgo) {
  const d = new Date(Date.now() + 330 * 60 * 1000);
  d.setUTCDate(d.getUTCDate() - daysAgo);
  return d.toISOString().slice(0, 10);
}

function monthKeyISTMonthsAgo(monthsAgo) {
  const d = new Date(Date.now() + 330 * 60 * 1000);
  d.setUTCDate(1);
  d.setUTCMonth(d.getUTCMonth() - monthsAgo);
  return d.toISOString().slice(0, 7);
}

function nextDailyCreditAtISTTimestamp() {
  const ist = new Date(Date.now() + 330 * 60 * 1000);
  ist.setUTCHours(0, 0, 0, 0);
  ist.setUTCDate(ist.getUTCDate() + 1);
  return ist.getTime() - 330 * 60 * 1000;
}

function toB64Url(s) {
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function bytesToB64Url(bytes) {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}
async function importPkcs8(pem) {
  const b64 = pem.replace('-----BEGIN PRIVATE KEY-----', '').replace('-----END PRIVATE KEY-----', '').replace(/\s+/g,
    '');
  const der = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey('pkcs8', der.buffer, {
    name: 'RSASSA-PKCS1-v1_5',
    hash: 'SHA-256'
  }, false, ['sign']);
}

