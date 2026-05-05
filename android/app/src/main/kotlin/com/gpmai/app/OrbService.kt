package com.gpmai.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service

import android.accessibilityservice.AccessibilityService

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.animation.ValueAnimator

import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import android.content.*
import android.content.pm.PackageManager
import android.content.res.Resources
import android.app.PendingIntent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import androidx.core.content.ContextCompat
import androidx.core.app.ActivityCompat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay

import android.media.AudioManager
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager

import android.net.Uri
import android.os.*
import android.provider.Settings

import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener

import android.text.InputType
import android.text.SpannableString
import android.text.method.ScrollingMovementMethod
import android.text.style.ForegroundColorSpan
import android.text.style.RelativeSizeSpan
import android.text.style.StyleSpan

import android.util.Base64
import android.util.Log

import android.view.GestureDetector
import android.view.MotionEvent
import android.view.*
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager

import android.widget.ScrollView
import android.widget.*

import com.airbnb.lottie.LottieAnimationView

import com.google.android.gms.tasks.OnSuccessListener
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

import java.io.ByteArrayOutputStream
import java.text.SimpleDateFormat
import java.util.*

import kotlin.random.Random


class OrbService : Service(), TextToSpeech.OnInitListener {

    /* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ companion constants (OK for const here) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
    companion object {
        private const val ACTION_STOP_ASK = "com.example.gpmai_clean.ACTION_STOP_ASK"
        private const val PREF_HIDE_EXPLAIN = "hide_sr_explain"
        private const val PREF_ACCEPT_SCREEN_READ = "accept_screen_read_terms"
        private const val NOTIF_ID = 1

        // inâ€‘memory screen log cap
        private const val SCREEN_LOG_CAP = 200

        // UI tunables
        private const val PEEK_ALPHA = 0.5f
        private const val ACTIVE_ALPHA = 1.0f
        private const val PEEK_RATIO = 0.5f
        private const val AUTO_DOCK_DELAY_MS = 3000L
        @JvmStatic @Volatile var isActive = false
    }

    /* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ TEMP log store (no persistence) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
   /* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ TEMP log store (no persistence) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
private object LogStore {
    fun nowTs(): Long = System.currentTimeMillis()

    fun saveVoiceSession(
        userId: String,
        text: String,
        reply: String?,
        mood: String?,
        extra: Map<String, Any?> = emptyMap()
    ) {
        Log.d("OrbLog", "voice_session {user=$userId, text=$text, reply=$reply, mood=$mood, extra=$extra}")
    }

    fun saveOrbChat(
        userId: String,
        chatId: String,
        role: String,               // "user" | "gpm"
        text: String,
        mood: String? = null,
        extra: Map<String, Any?> = emptyMap()
    ) {
        Log.d("OrbLog", "orb_session {user=$userId, chatId=$chatId, role=$role, text=$text, mood=$mood, extra=$extra}")
    }

    fun markChatTouched(userId: String, chatId: String) {
        Log.d("OrbLog", "chat_touched {user=$userId, chatId=$chatId, at=${nowTs()}}")
    }
}

/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ small data + in-memory buffer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
private data class ScreenLog(val ts: Long, val app: String, val content: String)
private val screenLogs = ArrayDeque<ScreenLog>()

/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ enums/data (SINGLE SOURCE) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
private enum class OrbUiState { DOCKED, ACTIVE, MENU, PILLS }

enum class IntentType {
    TAP, TYPE, SCROLL, FIND, OPEN_APP, NAV, READ_NOTIFICATIONS, SEND_MESSAGE,
    // System controls
    BRIGHTNESS, VOLUME, TOGGLE_SETTING,
    UNKNOWN
}

data class IntentData(
    val intent: IntentType,
    val slots: Map<String, String> = emptyMap()
)

/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ fields (regular vals/vars) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
private lateinit var windowManager: WindowManager
private lateinit var orbView: View
private lateinit var orbImage: ImageView
private lateinit var threadLine: View
private lateinit var loveAnim: LottieAnimationView
private lateinit var fireBurst: LottieAnimationView
private lateinit var fireSparks: LottieAnimationView
private lateinit var chatView: View
private lateinit var voiceMouthOverlay: View
private lateinit var closeVoiceBtn: ImageButton
private lateinit var flutterEngine: FlutterEngine
private lateinit var methodChannel: MethodChannel
private lateinit var speechRecognizer: SpeechRecognizer
private lateinit var tts: TextToSpeech
private lateinit var voiceMouth: LottieAnimationView
private lateinit var btnStopTts: ImageButton
private lateinit var btnRefresh: ImageButton
private lateinit var btnCloseVoice: ImageButton
private lateinit var controlOverlay: View

// optional overlay button refs
private var closeBtnOverlay: View? = null
private var refreshBtnOverlay: View? = null
private var stopBtnOverlay: View? = null
private lateinit var logContainer: LinearLayout
private lateinit var readButtonOverlay: View
private var floatingReadStopBtn: View? = null
private var greenReadBtn: View? = null
private var askMaskView: View? = null
private var explainView: View? = null // referenced later
// --- processing chip (secure, not included in screenshots) ---
private var processingChipView: View? = null
private var processingTextView: TextView? = null

private var allowTts = false
private var buttonsVisible = false
private var closeBtnAdded = false
private var refreshBtnAdded = false
private var stopBtnAdded = false
private var chatAnchoredToOrb = true

// ==== Processing (secure, masked) micro-widget ====
private var procView: View? = null
private var procParams = WindowManager.LayoutParams()
private var procStatus: TextView? = null

private var lastUiTap = 0L
private var sessionId = ""
private var isVoiceSessionActive = false
private var isTtsPaused = false

/* ==== Ask-progress (SINGLE SOURCE OF TRUTH) ==== */
private val askSteps = mutableListOf<String>()
private var stepsOverlay: View? = null
private var stepsOverlayList: LinearLayout? = null
private var lastAskStatus: String = ""
private var askStatusText: TextView? = null

// Foreground notification channel + id for Ask-progress
private val ASK_CHANNEL_ID = "gpmai_ask_progress"
private val ASK_CHANNEL_NAME = "GPMai Ask Progress"
private val NOTIF_ID_ASK = 2001

// Window params
private var orbParams = WindowManager.LayoutParams()
private var chatParams = WindowManager.LayoutParams()
private var controlParams = WindowManager.LayoutParams()

private val userId = "test_user_123"
private var analyzingDot: View? = null
private var lastTapTime = 0L
private var isDragging = false
private var defaultMoodRunnable: Runnable? = null
private var currentMood = "neutral"
private var screenReadingActive = false
private var screenContentLast = ""
private var watchHandler: Handler? = null
private var watchRunnable: Runnable? = null
private var lastSpokenText: String = ""
private var lastLogText: String = ""
private var lastTouchTime: Long = 0L

private val sessionMemory = mutableListOf<String>()
private val maxMemory = 50
private var isGroqRequestInProgress = false
private val seenScreenHashes = mutableSetOf<Int>()
private var lastGroqTime = 0L
private var screenContentLastSent = ""
private var lastAppSpoken = ""
private var lastUserVoiceTime = 0L
private var askVoiceView: View? = null
private var askVoiceParams = WindowManager.LayoutParams()

private var mediaProjection: MediaProjection? = null
private var virtualDisplay: VirtualDisplay? = null
private var imageReader: ImageReader? = null
private var projectionResultCode: Int = 0
private var projectionDataIntent: Intent? = null

private var lastMusicVolume: Int? = null

private var autoDockHandler: Handler? = null
private var autoDockRunnable: Runnable? = null
private var isOrbAdded = false

private var qaSuggestionBtn: View? = null
private var qaHomeBtn: View? = null
private var qaBackBtn: View? = null

private var pillAskBtn: View? = null
private var pillChatBtn: View? = null

private var askPanel: View? = null
private var lastAskBitmap: Bitmap? = null

private var uiState: OrbUiState = OrbUiState.DOCKED
private var quickActionsVisible = false

private var triPanel: ViewGroup? = null
private var triVisible = false
private var triCloseChip: View? = null

private var chatCloseChip: View? = null
private var askCloseChip: View? = null
private var askChatView: View? = null
private var askChatParams = WindowManager.LayoutParams()
private var askCompactView: View? = null
private var askCompactParams = WindowManager.LayoutParams()

private var preferLeftEdge = true
private var askMode = false
private var orbWatchdog: Handler? = null
private var projReceiver: BroadcastReceiver? = null
private var isProjectionSessionActive = false
private var onProjectionReady: (() -> Unit)? = null

private var hiddenOverlays: MutableList<View> = mutableListOf()
private val prefs by lazy { getSharedPreferences("gpmai_prefs", Context.MODE_PRIVATE) }

// dp â†’ px
private fun dp(v: Int): Int = (v * Resources.getSystem().displayMetrics.density).toInt()

// secure overlay flags combined at runtime
private val SECURE_FLAGS =
    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
    WindowManager.LayoutParams.FLAG_SECURE

private val SENSITIVE_APPS = setOf(
    "com.google.android.apps.nbu.paisa.user", // Google Pay
    "com.phonepe.app",
    "net.one97.paytm"
)

// ========= Fallback diagnostics =========
private enum class FallbackReason {
    NO_PROJECTION_CONSENT,
    CAPTURE_NULL,
    OCR_EMPTY,
    API_TIMEOUT,
    API_ERROR,
    CHANNEL_NOT_IMPLEMENTED,
    BUSY_LOCKED,
    TEXT_ONLY_PATH
}

private fun logFallback(reason: FallbackReason, detail: String = "") {
    val msg = "â†©ï¸ Fallback: ${reason.name}${if (detail.isNotBlank()) " â€” $detail" else ""}"
    // your onscreen transient log
    addLogLine(msg)
    // terminal / Logcat (filter by: GPMaiFallback)
    Log.w("GPMaiFallback", "${reason.name}|$detail")
}

    // ----- end of header/fields -----

    override fun onInit(status: Int) {
    if (status == TextToSpeech.SUCCESS) {
        tts.language = Locale.getDefault()
    }
}


override fun onCreate() {
    super.onCreate()
    isActive = true
    ensureAskChannel()

    // ---- Core inits ----
    windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

    flutterEngine = FlutterEngine(this).also {
        it.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
    }
    methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gpmai/brain")

    tts = TextToSpeech(this, this)

    // ---- UI setup ----
    setupOrbView()
    setupChatView()
    setupVoiceMouthOverlay()

    // ---- Notification channel for idle FGS ----
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val channel = NotificationChannel(
            "gpmai_channel",
            "GPMai Assistant",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "GPMai background assistant channel"
            setShowBadge(false)
        }
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(channel)
    }

    // Local helper functions (kept inside onCreate for clarity)
    fun hasRecordAudioPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun appTargetsSdkAtLeast(sdk: Int): Boolean {
        return applicationInfo?.targetSdkVersion ?: 0 >= sdk
    }

    // Build the default idle notification (non-intrusive)
    val idleNotif = Notification.Builder(this, "gpmai_channel")
        .setContentTitle("GPMai is running")
        .setContentText("Double-tap orb to chat • Long-press to Ask")
        .setSmallIcon(android.R.drawable.ic_menu_view)
        .setCategory(Notification.CATEGORY_SERVICE)
        .setOngoing(true)
        .build()

    // Try to start foreground safely.
    // Newer Android enforces that microphone-type foreground service can only start
    // if the app has RECORD_AUDIO (and appropriate foreground-only permission rules).
    try {
        // If app targets very modern SDKs (>=34) and we don't have RECORD_AUDIO,
        // prefer starting in "limited" mode to avoid SecurityException.
        val requiresStrictCheckSdk = 34 // (Android 14+ enforcement area)
        if (appTargetsSdkAtLeast(requiresStrictCheckSdk) && !hasRecordAudioPermission()) {
            // Start with a "limited" notification so system won't reject due to mic FGS rules.
            val limitedNotif = Notification.Builder(this, "gpmai_channel")
                .setContentTitle("GPMai (limited)")
                .setContentText("Voice features disabled — grant microphone permission to enable")
                .setSmallIcon(android.R.drawable.ic_menu_view)
                .setOngoing(true)
                .build()
            startForeground(1, limitedNotif)
            Log.w("OrbService", "Started foreground in LIMITED mode: missing RECORD_AUDIO")
        } else {
            // We either target older SDKs or have RECORD_AUDIO granted — try normal start.
            startForeground(1, idleNotif)
            Log.i("OrbService", "Started foreground normally")
        }
    } catch (se: SecurityException) {
        // Defensive fallback: system refused the requested FGS type (mic). Start safe fallback and continue.
        Log.w("OrbService", "SecurityException while starting foreground: ${se.message}")
        try {
            val fallback = Notification.Builder(this, "gpmai_channel")
                .setContentTitle("GPMai (limited)")
                .setContentText("Running without microphone privileges")
                .setSmallIcon(android.R.drawable.ic_menu_view)
                .setOngoing(true)
                .build()
            startForeground(1, fallback)
            Log.w("OrbService", "Started foreground with fallback notification after SecurityException")
        } catch (t: Throwable) {
            // If even fallback fails, log and continue without foreground (service may be killed on some OEMs).
            Log.e("OrbService", "Failed to start fallback foreground: ${t.message}")
        }
    } catch (t: Throwable) {
        // Catch-all: make sure service doesn't crash here.
        Log.e("OrbService", "Unexpected error when starting foreground: ${t.message}")
    }

    // ---- Projection consent receiver (fires after user taps "Start now") ----
    projReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, i: Intent?) {
            if (i?.action == "GPM_SCREEN_PROJECTION_RESULT") {
                projectionResultCode = i.getIntExtra("resultCode", 0)
                projectionDataIntent = i.getParcelableExtra("data")
                addLogLine("✓ Projection consent received")

                val ok = initMediaProjection()
                isProjectionSessionActive = ok
                if (!ok) {
                    addLogLine("✖ Failed to start projection from consent")
                    showIdleNotif()
                } else {
                    addLogLine("✅ Casting ON (status bar red icon)")
                    showCastingNotif()
                    onProjectionReady?.invoke()
                    onProjectionReady = null
                }
            }
        }
    }
    try {
        registerReceiver(projReceiver, IntentFilter("GPM_SCREEN_PROJECTION_RESULT"))
    } catch (_: Exception) {}

    // ---- App state ----
    logScreenContent("TestApp", "Testing drawer screen_session visibility")
    isGroqRequestInProgress = false
}


private fun isBlockingUiOpen(): Boolean {
    return triVisible || chatView.visibility == View.VISIBLE || askPanel != null || askChatView != null
}

// update any overlay's position safely
private fun repositionOverlay(v: View?, x: Int, y: Int) {
    if (v == null || v.parent == null) return
    val lp = v.layoutParams as WindowManager.LayoutParams
    lp.x = x; lp.y = y
    try { windowManager.updateViewLayout(v, lp) } catch (_: Exception) {}
}

private fun createSquareButton(
    label: String,
    x: Int,
    y: Int,
    onClick: () -> Unit
): View {
    val btn = Button(this).apply {
        text = label
        textSize = 14f
        setTextColor(0xFFFFFFFF.toInt())
        setPadding(12, 12, 12, 12)
        setBackgroundColor(0xCC222222.toInt()) // dark square
        layoutParams = ViewGroup.LayoutParams(170, 170)
        setOnClickListener { onClick() }
    }

    val lp = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        this.x = x
        this.y = y
    }

    windowManager.addView(btn, lp)
    return btn
}

private fun ensureA11yReady(): Boolean {
    addLogLine("â„¹ï¸ Accessibility features are disabled (OCR-only mode).")
    return true
}


// ==== 4-BUTTON PANEL (Back / Home / Recents / Close) ====
private fun showThreeSquareButtons() {
    if (!ensureA11yReady()) return

    cancelAutoDock()
    slideOutFromEdge()
    hideThreeSquareButtons()

    val panel = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        background = roundedDrawable(0xEE101010.toInt(), radius = 22f, strokePx = 4, strokeColor = 0xFF1F6FEB.toInt())
        setPadding(12, 12, 12, 12)
        isClickable = true
    }

    var lastClick = 0L
    fun safeClick(block: () -> Unit) {
        val now = System.currentTimeMillis()
        if (now - lastClick < 220) return
        lastClick = now
        block()
    }

    val backBtn = createSquareUiButton("Back") {
        safeClick {
            val ok = pressGlobal(AccessibilityService.GLOBAL_ACTION_BACK)
            addLogLine(if (ok) "âœ… Navigated back" else "âŒ Back failed â€” enable accessibility")
        }
    }

    val homeBtn = createSquareUiButton("Home") {
        safeClick {
            val ok = pressGlobal(AccessibilityService.GLOBAL_ACTION_HOME)
            addLogLine(if (ok) "âœ… Went home" else "âŒ Home failed")
        }
    }

    val recBtn = createSquareUiButton("Recents") {
        safeClick {
            val ok = pressGlobal(AccessibilityService.GLOBAL_ACTION_RECENTS)
            addLogLine(if (ok) "âœ… Opened Recents" else "âŒ Recents failed â€” enable accessibility")
        }
    }

    val closeBtn = createSquareUiButton("Close") {
        safeClick {
            hideThreeSquareButtons()
            dockToNearestEdge()
            addLogLine("ðŸ›‘ Panel closed")
        }
    }

    panel.addView(backBtn)
    panel.addView(homeBtn)
    panel.addView(recBtn)
    panel.addView(closeBtn)

    triPanel = panel
    triVisible = true

    val placeLeftOfOrb = !preferLeftEdge
    val py = orbParams.y
    val guessedWidth = 220

    val lp = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        // clickable but not stealing focus
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = if (placeLeftOfOrb) (orbParams.x - guessedWidth - 18) else (orbParams.x + orbView.width + 18)
        y = py
    }

    windowManager.addView(panel, lp)

    triCloseChip = createBlueCloseChip { hideThreeSquareButtons() }
    windowManager.addView(triCloseChip, WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = lp.x + 10
        y = lp.y - 24
    })

    panel.post {
        val exactX = if (placeLeftOfOrb) (orbParams.x - panel.width - 18) else (orbParams.x + orbView.width + 18)
        repositionOverlay(panel, exactX, py)
        repositionOverlay(triCloseChip, exactX + panel.width - 6, py - 24)
    }
}

private fun hideThreeSquareButtons() {
    triVisible = false
    removeOverlaySafe(triCloseChip); triCloseChip = null
    removeOverlaySafe(triPanel);     triPanel = null
    scheduleAutoDock(1200)
}

private fun ensureOrbVisible() {
    if (!isOrbAdded || orbView.parent == null) {
        try {
            windowManager.addView(orbView, orbParams)
            isOrbAdded = true
        } catch (_: Exception) { /* ignore if already added */ }
    }
}

private fun setupOrbView() {
    // inflate orb UI
    orbView = LayoutInflater.from(this).inflate(R.layout.orb_layout, null)
    orbImage = orbView.findViewById(R.id.orb_image)
    threadLine = orbView.findViewById(R.id.chat_thread_line)
    loveAnim = orbView.findViewById(R.id.love_animation)
    fireBurst = orbView.findViewById(R.id.fire_burst)
    fireSparks = orbView.findViewById(R.id.fire_sparks)
    startBreathingEffect()

    // base layout params
    orbParams = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = 300
        y = 400
    }

    // add if not already
    ensureOrbVisible()

    // -------- gestures --------
    val gestureDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
        override fun onDown(e: MotionEvent): Boolean = true

        // âœ… single tap â†’ 4-button panel (Back/Home/Recents/Kill)
    override fun onSingleTapUp(e: MotionEvent): Boolean {
    cancelAutoDock()
    slideOutFromEdge()
    // no more 4-button panel
    return true
}



        // âœ… double-tap â†’ chat box
        override fun onDoubleTap(e: MotionEvent): Boolean {
            cancelAutoDock()
            slideOutFromEdge()
            showChatBox()
            return true
        }

        // âœ… long-press â†’ ask-about-screen (policy-safe panel; capture only after Ask)
       // Long press â†’ compact Ask chat (text + Ask button)
override fun onLongPress(e: MotionEvent) {
    cancelAutoDock()
    slideOutFromEdge()
    showAskChatCompact()   // NEW
}
    })

    // -------- drag + edge-dock behavior --------
    orbView.setOnTouchListener { v, e ->
        gestureDetector.onTouchEvent(e)
        when (e.action) {
            MotionEvent.ACTION_DOWN -> {
                isDragging = false
                slideOutFromEdge()
                orbView.alpha = ACTIVE_ALPHA
                lastTouchTime = System.currentTimeMillis()
            }
            MotionEvent.ACTION_MOVE -> {
                isDragging = true
                hideThreeSquareButtons()

                val b = screenBounds()
                // choose side by finger position (switch when crossing center)
                preferLeftEdge = e.rawX < b.centerX()

                // lock X to chosen edge; Y free (clamped)
                val lockedX = if (preferLeftEdge) b.left + 24 else b.right - v.width - 24
                val lockedY = (e.rawY - v.height / 2).toInt()
                val (cx, cy) = clampXY(lockedX, lockedY, v.width, v.height)

                orbParams.x = cx
                orbParams.y = cy

                ensureOrbVisible()
                try { windowManager.updateViewLayout(orbView, orbParams) } catch (_: Exception) {}

                // keep related overlays near orb
                updateChatPosition()
                updateControlPosition()
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                isDragging = false
                scheduleAutoDock(1200L) // reâ€‘arm peek after a short delay
            }
        }
        true
    }

    // start docked (peek)
    orbView.alpha = PEEK_ALPHA
    orbView.post { dockToNearestEdge() }

    // watchdog (prevents offâ€‘screen vanish on rotation/launcher quirks)
    startOrbWatchdog()
}

private fun showAskPanelTextOnly() {
    if (askPanel != null) removeViewSafe(askPanel)

    val container = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(24, 24, 24, 24)
        setBackgroundColor(0xDD000000.toInt())
    }

    val tip = TextView(this).apply {
        text = "Ask about the current screen"
        setTextColor(0xFFFFFFFF.toInt())
        textSize = 16f
        setPadding(0,0,0,12)
    }
    container.addView(tip)

    val input = EditText(this).apply {
        hint = "Type your question..."
        setTextColor(0xFFFFFFFF.toInt())
        setHintTextColor(0x99FFFFFF.toInt())
        setBackgroundColor(0x22000000)
        setPadding(20, 20, 20, 20)
    }
    container.addView(input)

    val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
    val sendBtn = Button(this).apply { text = "Ask" }
    val cancelBtn = Button(this).apply { text = "Cancel" }
    row.addView(sendBtn)
    row.addView(cancelBtn)
    container.addView(row)

    val params = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL, // let keyboard focus
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = (orbParams.x + orbView.width + 20)
            .coerceAtMost(Resources.getSystem().displayMetrics.widthPixels - 420)
        y = (orbParams.y).coerceAtLeast(40)
    }

    askPanel = container
    windowManager.addView(askPanel, params)

    // Focus & show keyboard (Gboard)
    input.requestFocus()
    val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
    imm.showSoftInput(input, InputMethodManager.SHOW_IMPLICIT)

    sendBtn.setOnClickListener {
        val q = input.text?.toString()?.trim().orEmpty()
        if (q.isEmpty()) {
            Toast.makeText(this, "Type your question", Toast.LENGTH_SHORT).show()
            return@setOnClickListener
        }
        askAboutCurrentScreen(q)
        removeViewSafe(askPanel); askPanel = null
    }
    cancelBtn.setOnClickListener {
        removeViewSafe(askPanel); askPanel = null
    }
}

private fun askAboutCurrentScreen(question: String) {
    // Accessibility text
    val access = GPMaiAccessibilityService.readVisibleScreenText()

    // OCR text (silent screenshot capture)
    val bmp = captureScreenBitmap() // returns null if MediaProjection not ready
    if (bmp == null) {
        val prompt = """
            USER QUESTION:
            $question

            SCREEN CONTENT (Accessibility only):
            $access
        """.trimIndent()
        sendToBrain(prompt, false, null, null)
        return
    }

    getOCRTextFromBitmap(bmp) { ocr ->
        val prompt = """
            USER QUESTION:
            $question

            SCREEN CONTENT (Accessibility):
            $access

            SCREEN CONTENT (OCR):
            $ocr
        """.trimIndent()
        sendToBrain(prompt, false, null, null)
    }
}



private fun setupChatView() {
    // inflate chat bubble; keep hidden initially
    chatView = LayoutInflater.from(this).inflate(R.layout.chat_bubble_layout, null).apply {
        visibility = View.GONE
        minimumWidth = (resources.displayMetrics.widthPixels * 0.55f).toInt()
        isFocusable = true
        isFocusableInTouchMode = true
    }

    // window params for chat bubble near orb
    chatParams = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL, // allow IME focus
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = orbParams.x + 240
        y = orbParams.y
        softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
    }

    // add once; we toggle visibility later
    windowManager.addView(chatView, chatParams)

    // ----- inner views -----
    val input    = chatView.findViewById<EditText>(R.id.message_input)
    val send     = chatView.findViewById<Button>(R.id.send_button)
    val userText = chatView.findViewById<TextView>(R.id.user_text)
    val aiReply  = chatView.findViewById<TextView>(R.id.gpmai_response)
    val ttsBtn   = chatView.findViewById<ImageButton>(R.id.tts_toggle)
    val closeBtn = chatView.findViewById<ImageButton>(R.id.close_chat)
    val dragHandle = chatView.findViewById<View?>(R.id.chat_header) ?: chatView

    // âœ… input grows up to 3 lines, then scrolls (no clipping)
    input.apply {
        isSingleLine = false
        setHorizontallyScrolling(false)
        inputType = InputType.TYPE_CLASS_TEXT or
            InputType.TYPE_TEXT_FLAG_MULTI_LINE or
            InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
        imeOptions = EditorInfo.IME_ACTION_SEND
        minLines = 1
        maxLines = 3
        overScrollMode = View.OVER_SCROLL_IF_CONTENT_SCROLLS
        gravity = Gravity.TOP or Gravity.START
    }

    // Allow scrolling long AI text but keep box compact
    aiReply.movementMethod = ScrollingMovementMethod.getInstance()

    // Reposition only when anchored (prevents â€œsnap-backâ€ after drag; see updateChatPosition())
    chatView.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
        updateChatPosition()
    }
    input.addTextChangedListener(object : android.text.TextWatcher {
        override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
        override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
            input.post { updateChatPosition() }
        }
        override fun afterTextChanged(s: android.text.Editable?) {}
    })

    // ----- drag to reposition (via header handle only) -----
    var dragStartRawX = 0f
    var dragStartRawY = 0f
    var originX = 0
    var originY = 0
    var dragging = false
    val touchSlop = (8 * resources.displayMetrics.density).toInt()

    dragHandle.setOnTouchListener { _, e ->
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                dragStartRawX = e.rawX
                dragStartRawY = e.rawY
                originX = chatParams.x
                originY = chatParams.y
                dragging = false
                true
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = (e.rawX - dragStartRawX).toInt()
                val dy = (e.rawY - dragStartRawY).toInt()
                if (!dragging &&
                    (kotlin.math.abs(dx) > touchSlop || kotlin.math.abs(dy) > touchSlop)) {
                    dragging = true
                    chatAnchoredToOrb = false // â† free-float after first drag
                }
                if (dragging) {
                    val (cx, cy) = clampXY(originX + dx, originY + dy, chatView.width, chatView.height)
                    chatParams.x = cx
                    chatParams.y = cy
                    windowManager.updateViewLayout(chatView, chatParams)
                    true
                } else false
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                dragging = false
                true
            }
            else -> false
        }
    }

    // âœ• close â€” hard-reset; next open will anchor near orb again (see showChatBox)
    closeBtn.setOnClickListener {
        try { if (tts.isSpeaking) tts.stop() } catch (_: Exception) {}
        ttsBtn.setImageResource(android.R.drawable.ic_lock_silent_mode_off)

        try {
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.hideSoftInputFromWindow(input.windowToken, 0)
            input.clearFocus()
        } catch (_: Exception) {}

        resetChatUi()
        chatView.visibility = View.GONE
        threadLine.visibility = View.GONE
        scheduleAutoDock()
    }

    // ðŸ”Š TTS toggle
    ttsBtn.setOnClickListener {
        try {
            if (tts.isSpeaking) {
                tts.stop()
                ttsBtn.setImageResource(android.R.drawable.ic_lock_silent_mode_off)
                return@setOnClickListener
            }
            val text = aiReply.text?.toString()?.removePrefix("GPMai:")?.trim().orEmpty()
            if (text.isNotBlank()) {
                ttsBtn.setImageResource(android.R.drawable.ic_lock_silent_mode)
                speakOut(text) {
                    try { ttsBtn.setImageResource(android.R.drawable.ic_lock_silent_mode_off) } catch (_: Exception) {}
                }
            }
        } catch (_: Exception) { /* ignore */ }
    }

    fun doSend(msg: String) {
        userText.visibility = View.VISIBLE
        aiReply.visibility  = View.VISIBLE

        userText.text = "You: $msg"
        aiReply.text  = "Thinking..."
        try { if (tts.isSpeaking) tts.stop() } catch (_: Exception) {}
        ttsBtn.setImageResource(android.R.drawable.ic_lock_silent_mode_off)

        sendToBrain(msg, true, userText, aiReply)

        // reset input for next message
        input.setText("")
        input.minLines = 1
        input.maxLines = 3
        input.scrollTo(0, 0)
        input.requestFocus()
    }

    send.setOnClickListener {
        val msg = input.text.toString().trim()
        if (msg.isNotEmpty()) doSend(msg)
    }

    // Enter/Done to send
    input.setOnEditorActionListener { _, actionId, _ ->
        if (actionId == EditorInfo.IME_ACTION_SEND || actionId == EditorInfo.IME_ACTION_DONE) {
            val msg = input.text.toString().trim()
            if (msg.isNotEmpty()) doSend(msg)
            true
        } else false
    }
}

// quick helper so long-press opens chat and focuses keyboard
private fun showChatBox() {
    cancelAutoDock()
    chatAnchoredToOrb = true           // â† anchor only at open
    resetChatUi()
    chatView.visibility = View.VISIBLE
    threadLine.visibility = View.VISIBLE
    updateChatPosition()
    val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
    val input = chatView.findViewById<EditText>(R.id.message_input)
    input.requestFocus()
    imm.showSoftInput(input, InputMethodManager.SHOW_IMPLICIT)
}

private fun setupVoiceMouthOverlay() {
    voiceMouthOverlay = LayoutInflater.from(this).inflate(R.layout.voice_mouth_overlay, null)
    voiceMouth = voiceMouthOverlay.findViewById(R.id.voice_mouth)
    val statusLabel = voiceMouthOverlay.findViewById<TextView>(R.id.status_label)
    logContainer = voiceMouthOverlay.findViewById(R.id.voice_log_container)

    val overlayParams = WindowManager.LayoutParams(
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.MATCH_PARENT,
        getLayoutType(),
        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
        WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
        PixelFormat.TRANSLUCENT
    )
    overlayParams.gravity = Gravity.TOP or Gravity.START
    windowManager.addView(voiceMouthOverlay, overlayParams)

    voiceMouthOverlay.visibility = View.GONE

    // âŒ NO green button here â€” handled only during showVoiceMouthOverlay()
}

private fun showFloatingReadStopBtn() {
    if (floatingReadStopBtn == null) {
        floatingReadStopBtn = createStyledButton(
            R.drawable.bg_red_glow_x,
            R.drawable.ic_close_white,
            40,
            60
        ) {
            screenReadingActive = false
            stopWatchingForScreenChange()
            try { voiceMouthOverlay.setBackgroundColor(0x00000000) } catch (_: Exception) {}
            try { voiceMouthOverlay.findViewById<TextView>(R.id.status_label).text = "ðŸ›‘ Not Reading" } catch (_: Exception) {}
            hideFloatingReadStopBtn()
        }
    }

    floatingReadStopBtn?.let { v ->
        if (v.parent == null) {
            windowManager.addView(v, v.layoutParams)
        } else {
            v.visibility = View.VISIBLE
        }
    }
}

private fun hideFloatingReadStopBtn() {
    floatingReadStopBtn?.let { v ->
        try {
            if (v.parent != null) windowManager.removeView(v)
        } catch (_: Exception) {}
    }
    floatingReadStopBtn = null
}


private fun startWatchingForScreenChange() {
    watchHandler = Handler(Looper.getMainLooper())
    watchRunnable = object : Runnable {
        override fun run() {
            try {
                val now = System.currentTimeMillis()

                if (isGroqRequestInProgress) {
                    addLogLine("â³ Skipped: GPMai is still replying")
                } else if ((now - lastUserVoiceTime) < 5000) { // â± Only if asked within last 5s
                    val current = GPMaiAccessibilityService.readVisibleScreenText()
                    val appName = GPMaiAccessibilityService.getTopAppName(this@OrbService)

                    if (
                        current.isNotBlank() &&
                        current.length > 10 &&
                        current != screenContentLast &&
                        current != screenContentLastSent
                    ) {
                        screenContentLast = current
                        screenContentLastSent = current
                        logScreenContent(appName, current)

                        val cleaned = cleanScreenContent(current)
                        sendToBrain(cleaned, false, null, null)
                    } else {
                        addLogLine("â³ Skipped: No new screen content")
                    }
                } else {
                    addLogLine("ðŸ›‘ Skipped: No recent screen request")
                }
            } catch (_: Exception) {}

            if (screenReadingActive) {
                watchHandler?.postDelayed(this, 2000)  // âœ… Delay only if active
            }
        }
    }

    watchHandler?.post(watchRunnable!!)
}

private fun stopWatchingForScreenChange() {
    screenReadingActive = false
    isGroqRequestInProgress = false  // âœ… Ensure unlocked after stopping
    lastUserVoiceTime = 0L           // âœ… Reset trigger timer

    // ðŸ›‘ Stop the loop cleanly
    try {
        watchHandler?.removeCallbacks(watchRunnable!!)
        watchHandler = null
        watchRunnable = null
    } catch (_: Exception) {}

    // â™»ï¸ Reset last screen so it can trigger again later
    screenContentLast = ""

    // ðŸ”™ Optional: Dim overlay background
    voiceMouthOverlay.setBackgroundColor(0x66000000)

    // ðŸ§  Update status text
    try {
        val statusLabel = voiceMouthOverlay.findViewById<TextView>(R.id.status_label)
        statusLabel.text = "ðŸ›‘ Not Reading"
    } catch (_: Exception) {}
}
  private fun toggleChatBox() {
    val visible = chatView.visibility == View.VISIBLE
    if (visible) {
        chatView.visibility = View.GONE
        threadLine.visibility = View.GONE
        scheduleAutoDock() // allow reâ€‘peek after close
    } else {
        cancelAutoDock()
        chatView.visibility = View.VISIBLE
        threadLine.visibility = View.VISIBLE
        updateChatPosition()
        // focus IME
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        chatView.findViewById<EditText>(R.id.message_input)?.let {
            it.requestFocus()
            imm.showSoftInput(it, InputMethodManager.SHOW_IMPLICIT)
        }
    }
}


private fun updateChatPosition() {
    if (!::chatView.isInitialized) return

    // If user has dragged it, don't anchor to orb anymore.
    if (!chatAnchoredToOrb) {
        // Just keep it on-screen if the size changed.
        val (cx, cy) = clampXY(chatParams.x, chatParams.y, chatView.width, chatView.height)
        if (cx != chatParams.x || cy != chatParams.y) {
            chatParams.x = cx; chatParams.y = cy
            try { windowManager.updateViewLayout(chatView, chatParams) } catch (_: Exception) {}
        }
        return
    }

    // --- anchored mode (first open) ---
    val screenWidth = Resources.getSystem().displayMetrics.widthPixels
    val leftSide = orbParams.x < screenWidth / 2
    val bubbleW = when {
        chatView.width > 0 -> chatView.width
        chatView.measuredWidth > 0 -> chatView.measuredWidth
        else -> chatView.minimumWidth
    }

    chatParams.x = if (leftSide) orbParams.x + orbView.width + 40 else orbParams.x - bubbleW - 40
    chatParams.y = orbParams.y
    try { windowManager.updateViewLayout(chatView, chatParams) } catch (_: Exception) {}
}

    private fun updateControlPosition() {
        controlParams.x = orbParams.x + 40
        controlParams.y = orbParams.y - 60
    }

private fun showVoiceButtonsOverlay() {
    val screenWidth = Resources.getSystem().displayMetrics.widthPixels
    val screenHeight = Resources.getSystem().displayMetrics.heightPixels

    if (closeBtnOverlay == null) {
        closeBtnOverlay = createStyledButton(
            R.drawable.bg_red_glow_x,
            R.drawable.ic_close_white,
            screenWidth - 180,
            80
        ) { stopVoiceSession() }
    }

    closeBtnOverlay?.let { v ->
        if (v.parent == null) {
            windowManager.addView(v, v.layoutParams)
        } else {
            v.visibility = View.VISIBLE
        }
    }

    if (refreshBtnOverlay == null) {
        refreshBtnOverlay = createStyledButton(
            R.drawable.bg_blue_glow_refresh,
            android.R.drawable.ic_popup_sync,
            60,
            screenHeight - 380
        ) { startVoiceInput() }
    }

    refreshBtnOverlay?.let { v ->
        if (v.parent == null) {
            windowManager.addView(v, v.layoutParams)
        } else {
            v.visibility = View.VISIBLE
        }
    }
}

private fun addLogLine(message: String) {
    if (!::logContainer.isInitialized) return
    if (message == lastLogText) return
    lastLogText = message

    val context = this
    val logView = TextView(context).apply {
        text = formatLogMessage(message)
        setTextColor(0xFFFFFFFF.toInt()) // white fallback
        textSize = 14f
        setPadding(28, 20, 28, 20)
        setBackgroundColor(0xCC000000.toInt()) // semi-transparent black
        setLineSpacing(6f, 1f)
        alpha = 0f
    }

    logContainer.removeAllViews()
    logContainer.addView(logView)

    logView.animate()
        .alpha(1f)
        .setDuration(500)
        .withEndAction {
            Handler(Looper.getMainLooper()).postDelayed({
                logView.animate()
                    .alpha(0f)
                    .setDuration(2500)
                    .withEndAction {
                        logContainer.removeView(logView)
                    }.start()
            }, 4000)
        }
        .start()
}

private fun formatLogMessage(raw: String): String {
    val topicColor = "ðŸ”´"
    val sourceColor = "ðŸ”µ"
    val contentColor = "ðŸŸ¡"

    return when {
        raw.startsWith("Screen:") -> {
            val content = raw.removePrefix("Screen:").trim()
            "$topicColor Topic: Screen Reading\n$sourceColor Source: Visible Screen\n$contentColor Content: ${content.take(80)}"
        }
        raw.contains("Tapped", true) -> {
            "$topicColor Topic: Button Tap\n$sourceColor Source: GPMai Autopilot\n$contentColor Content: ${raw.replace("Tapped", "").trim()}"
        }
        raw.contains("Typed", true) -> {
            "$topicColor Topic: Text Input\n$sourceColor Source: GPMai Autopilot\n$contentColor Content: ${raw.replace("Typed", "").trim()}"
        }
        raw.contains("Opened", true) -> {
            "$topicColor Topic: App Launch\n$sourceColor Source: GPMai\n$contentColor Content: ${raw.replace("Opened", "").trim()}"
        }
        raw.contains("Failed", true) || raw.contains("Couldn't", true) -> {
            "$topicColor Topic: Action Failed\n$sourceColor Source: System\n$contentColor Content: $raw"
        }
        raw.contains("Mic reactivated", true) -> {
            "$topicColor Topic: Voice Listening\n$sourceColor Source: TTS Engine\n$contentColor Content: Mic is ready again."
        }
        else -> {
            "$topicColor Topic: Message\n$sourceColor Source: GPMai Log\n$contentColor Content: $raw"
        }
    }
}

private fun showVoiceMouthOverlay() {
    try {
        if (!::voiceMouthOverlay.isInitialized) return

        if (voiceMouthOverlay.parent == null) {
            val overlayParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                getLayoutType(),
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT
            )
            overlayParams.gravity = Gravity.TOP or Gravity.START
            windowManager.addView(voiceMouthOverlay, overlayParams)
        }

        voiceMouthOverlay.setBackgroundColor(0x66000000)
        voiceMouthOverlay.visibility = View.VISIBLE
        voiceMouth.playAnimation()

        showVoiceButtonsOverlay()
        // showGreenReadButton()  // âŒ removed
   } catch (e: Exception) {
        e.printStackTrace()
   }
}
// Temporary stub so build doesn't fail if a call remains
private fun showGreenReadButton() { /* removed feature â€“ no-op */ }

private fun stopVoiceSession() {
    isVoiceSessionActive = false

    try { tts.stop() } catch (_: Exception) {}
    try { voiceMouth.cancelAnimation() } catch (_: Exception) {}

    fun rm(v: View?) {
        try { if (v != null && v.parent != null) windowManager.removeView(v) } catch (_: Exception) {}
    }

    rm(voiceMouthOverlay)    // itâ€™s added in setup; safe to remove if present
    rm(stopBtnOverlay);       stopBtnOverlay = null
    rm(refreshBtnOverlay);    refreshBtnOverlay = null
    rm(greenReadBtn);         greenReadBtn = null
    rm(closeBtnOverlay);      closeBtnOverlay = null
    rm(floatingReadStopBtn);  floatingReadStopBtn = null

    screenReadingActive = false
    isTtsPaused = false
    isGroqRequestInProgress = false
}

    private fun startBreathingEffect() {
        val scaleX = ObjectAnimator.ofFloat(orbView, "scaleX", 1.0f, 0.9f, 1.0f)
        val scaleY = ObjectAnimator.ofFloat(orbView, "scaleY", 1.0f, 0.9f, 1.0f)
        scaleX.repeatCount = ValueAnimator.INFINITE
        scaleY.repeatCount = ValueAnimator.INFINITE
        scaleX.duration = 3200
        scaleY.duration = 3200
        val animatorSet = AnimatorSet()
        animatorSet.playTogether(scaleX, scaleY)
        animatorSet.start()
    }

    private fun pauseTTS() {
        if (!isTtsPaused) {
            tts.stop()
            isTtsPaused = true
        }
    }

    private fun resumeTTS() {
        if (isTtsPaused) {
            isTtsPaused = false
            tts.speak("Resuming.", TextToSpeech.QUEUE_FLUSH, null, "TTS")
        }
    }
// ---- Plain TTS: no overlays, no dimming, no extra buttons ----
// ---- Plain TTS: no overlays, no dimming, no extra buttons ----
private fun speakOut(text: String, onDone: (() -> Unit)? = null) {
    val now = System.currentTimeMillis()
    if (now - lastTouchTime < 400) {  // tiny guard
        onDone?.invoke()
        return
    }
    if (text.isBlank()) { onDone?.invoke(); return }

    lastSpokenText = text
    isTtsPaused = false

    val utteranceId = UUID.randomUUID().toString()
    tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
        override fun onStart(utteranceId: String?) {}
        override fun onDone(utteranceId: String?) { Handler(Looper.getMainLooper()).post { onDone?.invoke() } }
        override fun onError(utteranceId: String?) { Handler(Looper.getMainLooper()).post { onDone?.invoke() } }
    })

    val params = Bundle()
    params.putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, utteranceId)
    tts.speak(text, TextToSpeech.QUEUE_FLUSH, params, utteranceId)
}

// ==== INLINE TTS (no overlay, no dim, no extra buttons) ====
private fun speakOutInline(text: String, onDone: (() -> Unit)? = null) {
    if (text.isBlank()) { onDone?.invoke(); return }

    // if already speaking, replace with new utterance
    if (tts.isSpeaking) {
        try { tts.stop() } catch (_: Exception) {}
    }

    // make sure the user can hear (unmute + ~50% if volume is 0)
    try {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val vol = am.getStreamVolume(AudioManager.STREAM_MUSIC)
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (vol == 0) {
            am.setStreamVolume(
                AudioManager.STREAM_MUSIC,
                (max * 0.5f).toInt().coerceAtLeast(1),
                0
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_UNMUTE, 0)
        }
    } catch (_: Exception) {}

    isTtsPaused = false
    lastSpokenText = text

    // ðŸ”Ž TEMP LOG ONLY (no persistence)
    // 'lastLogText' -> whatever you captured from user/screen last
    // 'currentMood' -> your current orb mood string
    try {
        LogStore.saveVoiceSession(
            userId = userId,
            text   = lastLogText,   // user/screen input that triggered this reply
            reply  = text,          // what we're speaking now
            mood   = currentMood,
            extra  = mapOf("source" to "speakOutInline")
        )
    } catch (_: Exception) {}

    val utteranceId = UUID.randomUUID().toString()
    tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
        override fun onStart(id: String?) { /* no-op */ }
        override fun onDone(id: String?) {
            Handler(Looper.getMainLooper()).post { onDone?.invoke() }
        }
        override fun onError(id: String?) {
            Handler(Looper.getMainLooper()).post { onDone?.invoke() }
        }
    })

    val params = Bundle().apply {
        putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, utteranceId)
    }
    tts.speak(text, TextToSpeech.QUEUE_FLUSH, params, utteranceId)
}


private fun showErrorLog(topic: String, source: String, content: String) {
    val errorLog = """
        ðŸ”´ Topic: $topic
        ðŸ”µ Source: $source
        ðŸŸ¡ Content: $content
    """.trimIndent()
    addLogLine(errorLog)
}

private fun createStyledButton(
    bgDrawable: Int,
    iconDrawable: Int,
    x: Int,
    y: Int,
    onClick: () -> Unit
): View {
    val button = ImageButton(this).apply {
        setImageResource(iconDrawable)
        setBackgroundResource(bgDrawable)
        setPadding(20, 20, 20, 20)
        scaleType = ImageView.ScaleType.CENTER_INSIDE
        alpha = 0f // ðŸ‘ˆ start transparent for fade-in

        // Shrink âŒ if oversized
        layoutParams = ViewGroup.LayoutParams(180, 180)
        if (bgDrawable == R.drawable.bg_red_glow_x) {
            layoutParams = ViewGroup.LayoutParams(160, 160)
        }

        setOnClickListener { onClick() }
    }

    val params = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT
    )

    params.gravity = Gravity.TOP or Gravity.START
    params.x = x.coerceIn(30, Resources.getSystem().displayMetrics.widthPixels - 200)
    params.y = y.coerceIn(30, Resources.getSystem().displayMetrics.heightPixels - 300)

    // Drag listener (optional)
    button.setOnTouchListener(object : View.OnTouchListener {
        var lastX = 0
        var lastY = 0
        override fun onTouch(v: View, event: MotionEvent): Boolean {
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    lastX = event.rawX.toInt()
                    lastY = event.rawY.toInt()
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX.toInt() - lastX
                    val dy = event.rawY.toInt() - lastY
                    params.x += dx
                    params.y += dy
                    windowManager.updateViewLayout(button, params)
                    lastX = event.rawX.toInt()
                    lastY = event.rawY.toInt()
                }
            }
            return false
        }
    })

    windowManager.addView(button, params)

    // Smooth fade-in animation
    button.animate().alpha(1f).setDuration(350).start()

    return button
}

    private fun stopTTS() {
        tts.stop()
        isTtsPaused = false
    }

    private fun updateOrbMood(mood: String) {
        currentMood = mood.lowercase()
        loveAnim.visibility = View.GONE
        fireBurst.visibility = View.GONE
        fireSparks.visibility = View.GONE

        orbImage.setImageResource(
            when (mood.lowercase()) {
                "love" -> R.drawable.orb_love.also {
                    loveAnim.visibility = View.VISIBLE
                    loveAnim.playAnimation()
                }
                "fire" -> R.drawable.orb_fire.also {
                    fireBurst.visibility = View.VISIBLE
                    fireBurst.playAnimation()
                    Handler(Looper.getMainLooper()).postDelayed({
                        fireBurst.visibility = View.GONE
                        fireSparks.visibility = View.VISIBLE
                        fireSparks.playAnimation()
                    }, 1000)
                }
                "sad" -> R.drawable.orb_sad
                "cold" -> R.drawable.orb_cold
                "dead" -> R.drawable.orb_dead
                "happy" -> R.drawable.orb_gold
                else -> R.drawable.ai_orb
            }
        )

        defaultMoodRunnable?.let { Handler(Looper.getMainLooper()).removeCallbacks(it) }
        defaultMoodRunnable = Runnable {
            loveAnim.visibility = View.GONE
            fireBurst.visibility = View.GONE
            fireSparks.visibility = View.GONE
            orbImage.setImageResource(R.drawable.ai_orb)
        }
        Handler(Looper.getMainLooper()).postDelayed(defaultMoodRunnable!!, 8000)
    }

private fun saveToFirestore(
    user: String,
    reply: String,
    mood: String,
    sessionType: String // "orb_session", "voice_session", or "screen_session"
) {
    // ensure a non-empty session id for grouping logs in Logcat
    if (sessionId.isBlank()) {
        sessionId = java.text.SimpleDateFormat("yyyyMMdd-HHmmss", java.util.Locale.getDefault())
            .format(java.util.Date())
    }

    // temp: log both user + gpm messages (no persistence)
    try {
        LogStore.saveOrbChat(
            userId = userId,
            chatId = sessionId,
            role   = "user",
            text   = user,
            mood   = mood,
            extra  = mapOf("session" to sessionType)
        )
        LogStore.saveOrbChat(
            userId = userId,
            chatId = sessionId,
            role   = "gpm",
            text   = reply,
            mood   = mood,
            extra  = mapOf("session" to sessionType)
        )
        LogStore.markChatTouched(userId, sessionId)
    } catch (_: Exception) { /* no-op */ }

    addLogLine("ðŸ’¾(temp) $sessionType saved (no Firebase)")
}

private fun sendToBrain(msg: String, isChat: Boolean, userView: TextView?, replyView: TextView?) {
    if (isGroqRequestInProgress || tts.isSpeaking) {
        addLogLine("ðŸ›‘ Skipped: GPMai is busy")
        return
    }

    if (!::methodChannel.isInitialized || !::flutterEngine.isInitialized) {
        if (!isChat) speakOut("Oops, brain is not ready.")
        replyView?.text = "GPMai: [brain not ready]"
        return
    }

    isGroqRequestInProgress = true

    // ---- PURE CHAT PATH (no screenshot dependency; NO AUTO-TTS) ----
    if (isChat) {
        val prompt = sessionMemory.run {
            add("You: $msg")
            if (size > maxMemory) removeFirst()
            joinToString("\n")
        }

        methodChannel.invokeMethod("handleUserMessage", prompt, object : MethodChannel.Result {
            override fun success(result: Any?) {
                val raw = result?.toString()?.trim().orEmpty()
                val reply = if (raw.isBlank()) "[No response]" else raw
                val mood = Regex("\\[mood:(.*?)\\]").find(reply)?.groupValues?.get(1) ?: "neutral"
                val clean = reply.replace(Regex("\\[mood:.*?\\]"), "").trim()

                replyView?.text = "GPMai: $clean"
                updateOrbMood(mood)
                saveToFirestore(msg, clean, mood, "orb_session")

                // âŒ no speakOut here (user taps the speaker button if they want)
                isGroqRequestInProgress = false
                addLogLine("ðŸ‘¤ $msg")
                addLogLine("ðŸ¤– $clean")
            }

            override fun error(code: String, msg2: String?, details: Any?) {
                replyView?.text = "GPMai: Error â€” ${msg2 ?: "unknown"}"
                isGroqRequestInProgress = false
            }

            override fun notImplemented() {
                replyView?.text = "GPMai: Brain not available"
                isGroqRequestInProgress = false
            }
        })
        return
    }

    // ---- SCREENâ€‘AWARE ANSWERS (Accessibility + OCR) â†’ keep TTS ----
    val accessText = GPMaiAccessibilityService.readVisibleScreenText()
    val bitmap = captureScreenBitmap()
    if (bitmap == null) {
        addLogLine("âŒ Failed to capture screen image for OCR")
        replyView?.text = "GPMai: I couldn't capture the screen."
        speakOut("I can't read your screen right now.") { isGroqRequestInProgress = false }
        return
    }

    getOCRTextFromBitmap(bitmap) { ocrResult ->
        val formattedPrompt = """
            You are GPMai, a smart assistant helping the user understand their screen.

            ðŸ§  USER QUESTION:
            $msg

            ðŸ“‹ ACCESSIBILITY TEXT:
            - ${accessText.trim().lines().joinToString("\n- ")}

            ðŸ–¼ï¸ OCR TEXT:
            ${ocrResult.trim().replace("\n", "\nâ€¢ ")}

            ðŸ“Œ TASK:
            Based on both accessibility and OCR content, answer the user's question clearly.
            Be brief (1â€“2 lines max). Avoid repeating app name unless asked.
        """.trimIndent()

        try {
            methodChannel.invokeMethod("handleUserMessage", formattedPrompt, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    val reply = result?.toString()?.trim() ?: "[No response]"
                    val mood = Regex("\\[mood:(.*?)\\]").find(reply)?.groupValues?.get(1) ?: "neutral"
                    val clean = reply.replace(Regex("\\[mood:.*?\\]"), "").trim()

                    replyView?.text = "GPMai: $clean"
                    updateOrbMood(mood)
                    saveToFirestore(msg, clean, mood, "screen_session")

                    // âœ… keep TTS for screen answers
                    speakOut(clean) { isGroqRequestInProgress = false }
                    addLogLine(msg)
                    addLogLine(clean)
                }

                override fun error(code: String, msg2: String?, details: Any?) {
                    replyView?.text = "GPMai: Error â€” ${msg2 ?: "unknown"}"
                    speakOut("Error from brain: ${msg2 ?: "unknown"}") {
                        isGroqRequestInProgress = false
                    }
                    addLogLine("âŒ Groq error: $msg2")
                }

                override fun notImplemented() {
                    replyView?.text = "GPMai: Brain not available"
                    speakOut("Brain not available") {
                        isGroqRequestInProgress = false
                    }
                }
            })
        } catch (e: Exception) {
            e.printStackTrace()
            addLogLine("âŒ Brain crashed: ${e.message}")
            replyView?.text = "GPMai: Brain crashed"
            speakOut("Brain crashed") { isGroqRequestInProgress = false }
        }
    }
}

private fun startVoiceInput() {
    try {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) return
        if (!::methodChannel.isInitialized || !::flutterEngine.isInitialized) return

        isVoiceSessionActive = true
        sessionId = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        }

        speechRecognizer.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                voiceMouthOverlay.setBackgroundColor(0x66000000)
                showVoiceMouthOverlay()
            }

            override fun onRmsChanged(rmsdB: Float) {
                val mouth = voiceMouthOverlay.findViewById<LottieAnimationView>(R.id.voice_mouth)
                mouth.scaleX = 1f + (rmsdB / 10f).coerceIn(0f, 1.2f)
                mouth.scaleY = 1f + (rmsdB / 10f).coerceIn(0f, 1.2f)
            }

            override fun onBeginningOfSpeech() {}
            override fun onEndOfSpeech() {}
            override fun onError(error: Int) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
            override fun onPartialResults(partialResults: Bundle?) {}

            override fun onResults(results: Bundle?) {
               val spoken = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
if (spoken.isNullOrBlank()) return

// ðŸ†• Try to parse as an intent first
val intentData = parseIntent(spoken)
if (intentData.intent != IntentType.UNKNOWN) {
    executeIntent(intentData)
    return // âœ… Skip Groq if itâ€™s a direct command
}

                if (isGroqRequestInProgress || tts.isSpeaking) {
                    addLogLine("ðŸ›‘ Skipped: Groq or TTS busy")
                    return
                }

                val accessText = GPMaiAccessibilityService.readVisibleScreenText()
                val bitmap = captureScreenBitmap()

                if (bitmap != null) {
                    getOCRTextFromBitmap(bitmap) { ocrText ->
                        val screenText = mergeScreenText(accessText, ocrText)

                        val prompt = """
                        ðŸ§  USER REQUEST:
                        $spoken

                        ðŸ“± SCREEN CONTENT:
                        $screenText

                        Respond briefly. Only answer what the user asked. Max 2 lines. Avoid filler.
                        """.trimIndent()

                        sendToBrain(prompt, false, null, null)
                    }
                } else {
                    speakOut("I couldnâ€™t capture your screen.")
                }
            }
        })

        speechRecognizer.startListening(intent)

    } catch (e: Exception) {
        e.printStackTrace()
    }
}

    private fun getLayoutType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            WindowManager.LayoutParams.TYPE_PHONE
    }
private fun logScreenContent(appName: String, content: String) {
    val now = System.currentTimeMillis()
    val time = java.text.SimpleDateFormat("hh:mm a", java.util.Locale.getDefault()).format(java.util.Date(now))

    // keep last captured content for other parts of the service
    screenContentLast = content

    // add to in-memory ring buffer
    try {
        screenLogs.addLast(ScreenLog(now, appName, content))
        while (screenLogs.size > SCREEN_LOG_CAP) screenLogs.removeFirst()
    } catch (_: Exception) {}

    // temp log (instead of Firestore)
    try {
        LogStore.saveVoiceSession(
            userId = userId,
            text   = "[$appName] $content",
            reply  = null,
            mood   = currentMood,
            extra  = mapOf("kind" to "screen_log", "at" to now)
        )
    } catch (_: Exception) {}

    addLogLine("ðŸ“ Logged screen content: $appName at $time (temp)")
}

private fun getScreenAt(minutesAgo: Int, onResult: (String) -> Unit) {
    val target = System.currentTimeMillis() - (minutesAgo * 60_000L)

    // find closest entry in our in-memory buffer
    var best: ScreenLog? = null
    var bestDiff = Long.MAX_VALUE

    for (e in screenLogs) {
        val diff = kotlin.math.abs(e.ts - target)
        if (diff < bestDiff) {
            bestDiff = diff
            best = e
        }
    }

    if (best != null) {
        val msg = "ðŸ•’ $minutesAgo min ago you were using ${best.app}. Summary: ${best.content}"
        onResult(msg)
    } else {
        onResult("Sorry, I couldn't find any screen record from $minutesAgo minutes ago.")
    }
}

private fun detectAndTranslate(text: String, onResult: (String) -> Unit) {
    try {
        val isLikelyNonEnglish = !text.matches(Regex("^[\\p{ASCII}\\s\\p{Punct}]*$"))
        if (!isLikelyNonEnglish) {
            onResult("") // ignore English
            return
        }

        // ðŸ” Very basic built-in mapping (replace this with real API later)
        val fakeTranslated = when {
            text.contains("Ù…Ø±Ø­Ø¨Ø§") -> "Hello"
            text.contains("Ø´ÙƒØ±Ø§") -> "Thank you"
            else -> "Translated: $text"
        }

        onResult(fakeTranslated)

    } catch (e: Exception) {
        onResult("âŒ Translation failed")
    }
}
private fun startTranslationWatcher() {
    screenReadingActive = true
    watchHandler = Handler(Looper.getMainLooper())

    watchRunnable = object : Runnable {
        override fun run() {
            try {
                val currentText = GPMaiAccessibilityService.readVisibleScreenText()
                if (currentText != screenContentLast && currentText.isNotBlank()) {
                    screenContentLast = currentText
                    detectAndTranslate(currentText) { translated ->
                        if (translated.isNotBlank()) {
                            speakOut("ðŸˆ¯ $translated")
                            addLogLine("ðŸŒ Translated: $translated")
                        }
                    }
                }
            } catch (_: Exception) {}

            if (screenReadingActive) watchHandler?.postDelayed(this, 5000)
        }
    }

    watchHandler?.post(watchRunnable!!)
    addLogLine("ðŸŸ¢ Translation watcher started")
}
private fun cleanScreenContent(raw: String): String {
    val lines = raw.split("\n")
        .map { it.trim() }
        .filter { it.isNotEmpty() }

    val grouped = mutableMapOf<String, Int>()
    for (line in lines) {
        val normalized = line.lowercase()
        grouped[normalized] = grouped.getOrDefault(normalized, 0) + 1
    }

    return grouped.entries.joinToString("\n") { (text, count) ->
        val tag = when {
            text.contains("pm") || text.contains("am") || text.matches(Regex("\\d{1,2}:\\d{2} ?(am|pm)?")) -> "[Time]"
            text.contains("+91") || text.matches(Regex(".*\\d{10}.*")) -> "[Phone]"
            text.contains("chat") || text.contains("match") || text.contains("reply") -> "[Chat]"
            text.contains("whatsapp") || text.contains("settings") || text.contains("youtube") -> "[App]"
            else -> "[Line]"
        }
        val countTag = if (count > 1) " (x$count)" else ""
        "$tag ${text.replaceFirstChar { it.uppercaseChar() }}$countTag"
    }
}

fun mergeScreenText(accessibilityText: String, ocrText: String): String {
    return """
        ðŸ‘ï¸ ACCESSIBILITY TEXT:
        $accessibilityText

        ðŸ–¼ï¸ OCR TEXT:
        $ocrText
    """.trimIndent().take(3000)
}
fun getOCRTextFromBitmap(bitmap: Bitmap, onResult: (String) -> Unit) {
    Log.d("GPMai", "ðŸ” Running OCR on bitmap (${bitmap.width}x${bitmap.height})...")

    try {
        val image = InputImage.fromBitmap(bitmap, 0)
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.Builder().build())

        recognizer.process(image)
            .addOnSuccessListener { visionText ->
                Log.d("GPMai", "âœ… OCR success â€” detected text: ${visionText.text.take(200)}")
                onResult(visionText.text)
            }
            .addOnFailureListener { e ->
                Log.e("GPMai", "âŒ OCR failed", e)
                onResult("")
            }

    } catch (e: Exception) {
        Log.e("GPMai", "âŒ Exception during OCR", e)
        onResult("")
    }
}

fun initScreenshotComponents(width: Int, height: Int, density: Int) {
    imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
    virtualDisplay = mediaProjection?.createVirtualDisplay(
        "GPMaiScreenCapture",
        width, height, density,
        DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
        imageReader?.surface, null, null
    )
}

fun captureScreenBitmap(): Bitmap? {
    Log.d("GPMai", "ðŸŸ¢ Attempting to capture screen...")

    // If session is active we must already have an initialized mediaProjection
    val haveProjection = (isProjectionSessionActive && mediaProjection != null)
    if (!haveProjection) {
        // No session â†’ we shouldnâ€™t capture silently
        Log.e("GPMai", "âŒ No active projection session")
        return null
    }

    val metrics = Resources.getSystem().displayMetrics
    initScreenshotComponents(metrics.widthPixels, metrics.heightPixels, metrics.densityDpi)

    try {
        Thread.sleep(250) // Let image load

        val image = imageReader?.acquireLatestImage()
        if (image == null) {
            Log.e("GPMai", "âŒ No image from imageReader")
            return null
        }

        val planes = image.planes
        val buffer = planes[0].buffer
        val pixelStride = planes[0].pixelStride
        val rowStride = planes[0].rowStride
        val rowPadding = rowStride - pixelStride * image.width

        val bmp = Bitmap.createBitmap(
            image.width + rowPadding / pixelStride,
            image.height,
            Bitmap.Config.ARGB_8888
        )
        bmp.copyPixelsFromBuffer(buffer)
        image.close()

        Log.d("GPMai", "âœ… Screen captured (${bmp.width}x${bmp.height})")
        return bmp

    } catch (e: Exception) {
        Log.e("GPMai", "âŒ Error capturing screen: ${e.message}")
        return null
    } finally {
        // IMPORTANT: Do NOT stop projection if the session is active.
        // We only release surfaces between frames; keep MediaProjection alive.
        try {
            virtualDisplay?.release()
            virtualDisplay = null
            imageReader?.close()
            imageReader = null
        } catch (_: Exception) {}
        // DO NOT call releaseMediaProjection() here
    }
}


private fun initMediaProjection(): Boolean {
    return try {
        if (projectionResultCode == 0 || projectionDataIntent == null) return false
        val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = manager.getMediaProjection(projectionResultCode, projectionDataIntent!!)
        true
    } catch (e: Exception) {
        Log.e("GPMai", "âŒ initMediaProjection failed: ${e.message}")
        false
    }
}


private fun releaseMediaProjection() {
    try {
        virtualDisplay?.release()
        virtualDisplay = null

        imageReader?.close()
        imageReader = null

        mediaProjection?.stop()
        mediaProjection = null

        Log.d("GPMai", "ðŸŸ¢ Released mediaProjection")
    } catch (e: Exception) {
        Log.e("GPMai", "âŒ Failed to release mediaProjection: ${e.message}")
    }
}

override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    Log.d("GPMai", "ðŸŸ¡ onStartCommand called")

    // NEW: Handle STOP button from the notification
   if (intent?.action == ACTION_STOP_ASK) {
    handleAskStopFromNotif()
    return START_NOT_STICKY
}

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val channel = NotificationChannel(
            "gpmai_channel",
            "GPMai Assistant",
            NotificationManager.IMPORTANCE_LOW
        )
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    // âœ… Idle state: background service with a dismissible notification
    showIdleNotif()  // swipe-away

    // Save projection extras if the Activity passed them later (optional)
    projectionResultCode = intent?.getIntExtra("resultCode", 0) ?: 0
    projectionDataIntent = intent?.getParcelableExtra("data")

    return START_STICKY
}


// ==== PARSE INTENT (OrbService.kt) ====
// ==== PARSE INTENT ====
// ==== PARSE INTENT (OCR-only; no Accessibility ops) ====
private fun parseIntent(userCommand: String): IntentData {
    val cmd = userCommand.trim().lowercase()

    // --- brightness ---
    Regex("^(brightness)\\s+(up|down)$").find(cmd)?.let {
        return IntentData(IntentType.BRIGHTNESS, mapOf("mode" to it.groupValues[2]))
    }
    Regex("^(set\\s+)?brightness\\s+(to\\s+)?(\\d{1,3})%?$").find(cmd)?.let {
        return IntentData(IntentType.BRIGHTNESS, mapOf("mode" to "percent", "value" to it.groupValues[3]))
    }
    if (cmd.contains("brighter")) return IntentData(IntentType.BRIGHTNESS, mapOf("mode" to "up"))
    if (cmd.contains("dimmer"))   return IntentData(IntentType.BRIGHTNESS, mapOf("mode" to "down"))

    // --- volume ---
    Regex("^(volume)\\s+(up|down)$").find(cmd)?.let {
        return IntentData(IntentType.VOLUME, mapOf("op" to it.groupValues[2]))
    }
    if (cmd == "mute" || cmd.contains("volume mute"))      return IntentData(IntentType.VOLUME, mapOf("op" to "mute"))
    if (cmd == "unmute" || cmd.contains("volume unmute"))  return IntentData(IntentType.VOLUME, mapOf("op" to "unmute"))
    Regex("^(set\\s+)?volume\\s+(to\\s+)?(\\d{1,3})%?$").find(cmd)?.let {
        return IntentData(IntentType.VOLUME, mapOf("op" to "percent", "value" to it.groupValues[3]))
    }

    // --- open app ---
    Regex("^(open|launch)\\s+(.+)").find(cmd)?.let {
        return IntentData(IntentType.OPEN_APP, mapOf("appName" to cmd.replace(Regex("^(open|launch)\\s+"), "")))
    }

    // --- optional stubs you already show in UI ---
    if (Regex("^read notifications?").containsMatchIn(cmd)) return IntentData(IntentType.READ_NOTIFICATIONS)
    Regex("^send message\\s+(.+)").find(cmd)?.let {
        return IntentData(IntentType.SEND_MESSAGE, mapOf("fullText" to cmd.removePrefix("send message").trim()))
    }

    // Everything else is unknown (no a11y)
    return IntentData(IntentType.UNKNOWN)
}

// ==== EXECUTE INTENT (OCR-only; no Accessibility) ====
private fun executeIntent(intentData: IntentData) {
    try {
        when (intentData.intent) {

            // ---- Open app ----
            IntentType.OPEN_APP -> {
                val appName = intentData.slots["appName"] ?: return
                val ok = openAppByName(appName)
                addLogLine(if (ok) "âœ… Opened app: $appName" else "âŒ App not found or couldnâ€™t open: $appName")
            }

            // ---- Brightness ----
            IntentType.BRIGHTNESS -> {
                val mode = intentData.slots["mode"] ?: return
                val ok = when (mode) {
                    "up" -> { ensureManualBrightness(); changeBrightnessBy(+28) }
                    "down" -> { ensureManualBrightness(); changeBrightnessBy(-28) }
                    "percent" -> {
                        ensureManualBrightness()
                        val pct = (intentData.slots["value"] ?: "50").toInt().coerceIn(1, 100)
                        setBrightnessPercent(pct)
                    }
                    else -> false
                }
                addLogLine(if (ok) "ðŸ”† Brightness $mode" else "âŒ Brightness $mode failed (grant WRITE_SETTINGS?)")
            }

            // ---- Volume ----
            IntentType.VOLUME -> {
                val op = intentData.slots["op"] ?: return
                val ok = when (op) {
                    "up"      -> adjustVolumeStep(AudioManager.ADJUST_RAISE)
                    "down"    -> adjustVolumeStep(AudioManager.ADJUST_LOWER)
                    "mute"    -> setMute(true)
                    "unmute"  -> setMute(false)
                    "percent" -> {
                        val pct = (intentData.slots["value"] ?: "50").toInt().coerceIn(0, 100)
                        setVolumePercent(pct)
                    }
                    else -> false
                }
                addLogLine(if (ok) "ðŸ”Š Volume $op" else "âŒ Volume $op failed")
            }

            // ---- Optional stubs you already surface in UI ----
            IntentType.READ_NOTIFICATIONS -> {
                addLogLine("ðŸ“¢ Reading notificationsâ€¦ (Not implemented in OCR-only mode)")
            }
            IntentType.SEND_MESSAGE -> {
                val full = intentData.slots["fullText"].orEmpty()
                addLogLine("âœ‰ï¸ Sending messageâ€¦ (Not implemented) | $full")
            }

            // ---- Everything else (TAP/TYPE/SCROLL/FIND/NAV/QS) not supported now ----
            else -> addLogLine("â„¹ï¸ Command not available in OCR-only mode.")
        }
    } catch (e: Exception) {
        addLogLine("ðŸ’¥ executeIntent error: ${e.message ?: "unknown"}")
    }
}

private fun ensureManualBrightness(): Boolean {
    return try {
        if (!Settings.System.canWrite(this)) return false
        Settings.System.putInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS_MODE,
            Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL)
        true
    } catch (_: Exception) { false }
}

// ==== HELPERS (OrbService.kt) ====
private fun changeBrightnessBy(delta: Int): Boolean {
    return try {
        if (!Settings.System.canWrite(this)) return false
        val cr = contentResolver
        val cur = Settings.System.getInt(cr, Settings.System.SCREEN_BRIGHTNESS, 128)
        val nxt = (cur + delta).coerceIn(10, 255)
        Settings.System.putInt(cr, Settings.System.SCREEN_BRIGHTNESS, nxt)
        true
    } catch (_: Exception) {
        false
    }
}

private fun setBrightnessPercent(pct: Int): Boolean {
    return try {
        if (!Settings.System.canWrite(this)) return false
        val value = (pct / 100f * 255).toInt().coerceIn(10, 255)
        Settings.System.putInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS, value)
        true
    } catch (_: Exception) {
        false
    }
}

// --- Volume helpers (robust) ---
private fun ensureDndAccess(): Boolean {
    return try {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !nm.isNotificationPolicyAccessGranted) {
            val i = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(i)
            addLogLine("âš ï¸ Grant 'Do Not Disturb' access so mute/unmute works.")
            return false
        }
        true
    } catch (_: Exception) { true }
}

private fun adjustVolumeStep(direction: Int): Boolean {
    return try {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val flags = AudioManager.FLAG_SHOW_UI or AudioManager.FLAG_PLAY_SOUND
        // Touch multiple streams so the change is obvious to the user
        am.adjustStreamVolume(AudioManager.STREAM_MUSIC, direction, flags)
        am.adjustStreamVolume(AudioManager.STREAM_RING,  direction, flags)
        am.adjustStreamVolume(AudioManager.STREAM_ALARM, direction, flags)
        true
    } catch (_: Exception) { false }
}

private fun setMute(mute: Boolean): Boolean {
    return try {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val flags = AudioManager.FLAG_SHOW_UI

        if (mute) {
            // 1) Try a true mute on MUSIC (doesn't need DND)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_MUTE, flags)
            }

            // 2) Remember current music level once (for restore)
            val cur = am.getStreamVolume(AudioManager.STREAM_MUSIC)
            if (cur > 0) lastMusicVolume = cur

            // 3) Force-set a few streams to 0 to make it obvious
            am.setStreamVolume(AudioManager.STREAM_MUSIC, 0, flags)
            am.setStreamVolume(AudioManager.STREAM_ALARM, 0, flags)   // harmless; no DND needed
            // Avoid RING here to not hit DND policy and avoid any settings pages
        } else {
            // Unmute MUSIC (no DND needed)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_UNMUTE, flags)
            }

            // Restore previous level or a safe mid value
            val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val restore = (lastMusicVolume ?: (max * 0.5f).toInt()).coerceIn(1, max)
            am.setStreamVolume(AudioManager.STREAM_MUSIC, restore, flags)

            // Optional: give alarm a sensible level again (skip if you donâ€™t want this)
            val alarmMax = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            am.setStreamVolume(AudioManager.STREAM_ALARM, (alarmMax * 0.5f).toInt().coerceAtLeast(1), 0)
        }
        true
    } catch (_: Exception) { false }
}

private fun setVolumePercent(pct: Int): Boolean {
    return try {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val streams = intArrayOf(AudioManager.STREAM_MUSIC, AudioManager.STREAM_RING, AudioManager.STREAM_ALARM)
        streams.forEach { s ->
            val max = am.getStreamMaxVolume(s)
            val target = ((pct / 100f) * max).toInt().coerceIn(0, max)
            am.setStreamVolume(s, target, AudioManager.FLAG_SHOW_UI)
        }
        true
    } catch (_: Exception) { false }
}


private fun openQuickSettingsViaA11y(): Boolean {
    addLogLine("â„¹ï¸ Quick Settings via accessibility is disabled.")
    return false
}


// --- OPEN_APP helper (robust across launchers) ---
private fun openAppByName(appQuery: String): Boolean {
    val pm = packageManager
    val raw = appQuery.trim()
    val q = raw.lowercase()
        .replace("[^a-z0-9\\s]".toRegex(), "")   // strip punctuation
        .replace("\\s+".toRegex(), " ")          // collapse spaces

    // Quick alias/typo map
    val alias = mapOf(
        "insta" to "com.instagram.android",
        "instagram" to "com.instagram.android",
        "ig" to "com.instagram.android",
        "whatsapp" to "com.whatsapp",
        "whats app" to "com.whatsapp",
        "wa" to "com.whatsapp",
        "playstore" to "com.android.vending",
        "play store" to "com.android.vending",
        "youtube" to "com.google.android.youtube",
        "yt" to "com.google.android.youtube",
        "chrome" to "com.android.chrome",
        "settings" to "com.android.settings"
    )

    // If user spoke a full package name
    if (q.contains(".")) {
        pm.getLaunchIntentForPackage(q)?.let {
            it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(it)
            return true
        }
    }

    // Alias hit?
    alias[q]?.let { pkg ->
        pm.getLaunchIntentForPackage(pkg)?.let {
            it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(it)
            return true
        }
    }

    // Search launcher activities by label (case/space insensitive)
    val main = Intent(Intent.ACTION_MAIN, null).apply { addCategory(Intent.CATEGORY_LAUNCHER) }
    val launchables = pm.queryIntentActivities(main, 0)

    fun norm(s: String) = s.lowercase()
        .replace("[^a-z0-9\\s]".toRegex(), "")
        .replace("\\s+".toRegex(), " ")

    val best = launchables.firstOrNull {
        val label = norm(pm.getApplicationLabel(it.activityInfo.applicationInfo).toString())
        label == q || label.startsWith(q)
    } ?: launchables.firstOrNull {
        val label = norm(pm.getApplicationLabel(it.activityInfo.applicationInfo).toString())
        label.contains(q)
    }

    best?.let { ri ->
        pm.getLaunchIntentForPackage(ri.activityInfo.packageName)?.let { launch ->
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(launch)
            return true
        }
    }

    addLogLine("âŒ No launcher match for '$raw' (q='$q')")
    return false
}
private fun addOrbIfNeeded() {
    if (!isOrbAdded) {
        try {
            windowManager.addView(orbView, orbParams)
            isOrbAdded = true
        } catch (_: Exception) { /* already added? ignore */ }
    }
}

private fun updateOrbLayoutSafe() {
    if (isOrbAdded && orbView.parent != null) {
        try { windowManager.updateViewLayout(orbView, orbParams) } catch (_: Exception) {}
    }
}

private fun removeViewSafe(v: View?) {
    if (v == null) return
    try { if (v.parent != null) windowManager.removeView(v) } catch (_: Exception) {}
}

private fun showQuickActions() {
    if (uiState == OrbUiState.MENU) return
    uiState = OrbUiState.MENU

    val bx = orbParams.x + orbView.width + 12
    val by = orbParams.y + 12

    if (qaSuggestionBtn == null) {
        qaSuggestionBtn = createStyledButton(
            R.drawable.bg_blue_glow_refresh, // reuse your blue
            android.R.drawable.ic_menu_help, // suggestion icon
            bx, by
        ) {
            // simple â€œsuggestionâ€: summarize current screen
            val text = GPMaiAccessibilityService.readVisibleScreenText()
            val cleaned = cleanScreenContent(text)
            sendToBrain("Give me a short tip for what I can do here:\n$cleaned", false, null, null)
            hideQuickActions(); scheduleAutoDock()
        }
    }

    if (qaHomeBtn == null) {
        qaHomeBtn = createStyledButton(
            R.drawable.bg_green_button,
            android.R.drawable.ic_menu_compass,
            bx, by + 170
        ) {
            GPMaiAccessibilityService.goHome()
            hideQuickActions(); scheduleAutoDock()
        }
    }

    if (qaBackBtn == null) {
        qaBackBtn = createStyledButton(
            R.drawable.bg_red_glow_x,
            android.R.drawable.ic_media_previous,
            bx, by + 340
        ) {
            GPMaiAccessibilityService.goBack()
            hideQuickActions(); scheduleAutoDock()
        }
    }
}

private fun hideQuickActions() {
    removeViewSafe(qaSuggestionBtn); qaSuggestionBtn = null
    removeViewSafe(qaHomeBtn);       qaHomeBtn = null
    removeViewSafe(qaBackBtn);       qaBackBtn = null
    if (uiState == OrbUiState.MENU) uiState = OrbUiState.ACTIVE
}
private fun showPills() {
    val bx = orbParams.x - 24
    val by = orbParams.y - 24

    if (pillAskBtn == null) {
        pillAskBtn = createStyledButton(
            R.drawable.bg_green_button,
            android.R.drawable.ic_menu_camera,   // snapshot icon
            bx, by - 160
        ) {
            captureScreenBitmap()?.let { bmp ->
                lastAskBitmap = bmp
                showAskAboutScreenPanel(bmp)  // opens thumbnail + input box
            } ?: addLogLine("âŒ Couldnâ€™t capture screen")
        }
    }
    if (pillChatBtn == null) {
        pillChatBtn = createStyledButton(
            R.drawable.bg_blue_glow_refresh,
            android.R.drawable.ic_menu_edit,
            bx, by + 160
        ) {
            hidePills()
            toggleChatBox()       // reuse your chat
            ensureOrbVisible()
        }
    }
}

private fun hidePills() {
    removeViewSafe(pillAskBtn); pillAskBtn = null
    removeViewSafe(pillChatBtn); pillChatBtn = null
    if (uiState == OrbUiState.PILLS) uiState = OrbUiState.ACTIVE
}
private fun showAskAboutScreenPanel(bitmap: Bitmap) {
    if (askPanel != null) removeViewSafe(askPanel)

    val container = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(24, 24, 24, 24)
        setBackgroundColor(0xDD000000.toInt())
    }

    val thumb = ImageView(this).apply {
        val w = (Resources.getSystem().displayMetrics.widthPixels * 0.45f).toInt()
        val h = (w * (bitmap.height.toFloat() / bitmap.width)).toInt().coerceAtLeast(200)
        layoutParams = LinearLayout.LayoutParams(w, h)
        setImageBitmap(bitmap)
        adjustViewBounds = true
        scaleType = ImageView.ScaleType.CENTER_CROP
    }

    val input = EditText(this).apply {
        hint = "Ask about this screen..."
        setTextColor(0xFFFFFFFF.toInt())
        setHintTextColor(0x99FFFFFF.toInt())
        setBackgroundColor(0x22000000)
        setPadding(20, 20, 20, 20)
    }

    val row = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
    }

    val sendBtn = Button(this).apply {
        text = "Ask"
        setOnClickListener {
            val q = input.text?.toString()?.trim().orEmpty()
            if (q.isNotEmpty()) {
                sendQuestionAboutBitmap(bitmap, q)
                removeViewSafe(askPanel); askPanel = null
                hidePills()
                scheduleAutoDock()
            } else {
                Toast.makeText(this@OrbService, "Type your question", Toast.LENGTH_SHORT).show()
            }
        }
    }

    val cancelBtn = Button(this).apply {
        text = "Cancel"
        setOnClickListener {
            removeViewSafe(askPanel); askPanel = null
            hidePills()
            scheduleAutoDock()
        }
    }

    row.addView(sendBtn)
    row.addView(cancelBtn)

    container.addView(thumb)
    container.addView(input)
    container.addView(row)

    val params = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = (orbParams.x + orbView.width + 20).coerceAtMost(Resources.getSystem().displayMetrics.widthPixels - 400)
        y = (orbParams.y).coerceAtLeast(40)
    }

    askPanel = container
    windowManager.addView(askPanel, params)
}

private fun sendQuestionAboutBitmap(bitmap: Bitmap, question: String) {
    getOCRTextFromBitmap(bitmap) { ocr ->
        val access = GPMaiAccessibilityService.readVisibleScreenText()
        val prompt = """
            The user is asking about the current screen (screenshot captured now).

            QUESTION:
            $question

            ACCESSIBILITY TEXT:
            $access

            OCR TEXT:
            $ocr

            Answer clearly in 1â€“2 lines.
        """.trimIndent()

        // send as a one-off "screen_session" answer
        sendToBrain(prompt, false, null, null)
    }
}
private fun setUiState(next: OrbUiState) {
    // You can add transitions/analytics here later if you want
    uiState = next
    addLogLine("ðŸŽ›ï¸ UI â†’ $uiState")
}
private fun roundedDrawable(
    fill: Int,
    radius: Float = 24f,
    strokePx: Int = 4,
    strokeColor: Int = 0xFF1976D2.toInt() // blue
): GradientDrawable {
    return GradientDrawable().apply {
        setColor(fill)
        cornerRadius = radius
        setStroke(strokePx, strokeColor)
    }
}

// Add an overlay view with safe LayoutParams at x,y
private fun addOverlay(v: View, x: Int, y: Int) {
    val lp = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        this.x = x
        this.y = y
    }
    try { windowManager.addView(v, lp) } catch (_: Exception) {}
}

// Remove overlay if added
private fun removeOverlaySafe(v: View?) {
    if (v == null) return
    try { if (v.parent != null) windowManager.removeView(v) } catch (_: Exception) {}
}

// smaller black box with white text + blue outline
private fun createSquareUiButton(label: String, onClick: () -> Unit): View {
    return TextView(this).apply {
        text = label
        setTextColor(0xFFFFFFFF.toInt()) // white text
        textSize = 14f
        setPadding(22, 18, 22, 18)
        background = roundedDrawable(
            fill = 0xFF000000.toInt(),   // black inside
            radius = 22f,
            strokePx = 3,
            strokeColor = 0xFF1F6FEB.toInt() // blue stroke
        )
        val p = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        p.setMargins(0, 10, 0, 10) // vertical spacing
        layoutParams = p
        setOnClickListener { onClick() }
    }
}

private fun createBlueCloseChip(onClick: () -> Unit): View {
    return TextView(this).apply {
        text = "âœ•"
        setTextColor(0xFFFFFFFF.toInt())
        textSize = 14f
        setPadding(18, 10, 18, 10)
        background = roundedDrawable(
            fill = 0xFF1F6FEB.toInt(), // blue fill
            radius = 20f,
            strokePx = 0,
            strokeColor = 0xFF1F6FEB.toInt()
        )
        setOnClickListener { onClick() }
    }
}
private fun startMicIntoEdit(field: EditText) {
    try {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) return
        val sr = SpeechRecognizer.createSpeechRecognizer(this)
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
        }
        sr.setRecognitionListener(object : RecognitionListener {
            override fun onResults(results: Bundle?) {
                val spoken = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                if (!spoken.isNullOrBlank()) field.setText(spoken)
                sr.destroy()
            }
            override fun onReadyForSpeech(p0: Bundle?) {}
            override fun onError(p0: Int) { sr.destroy() }
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(p0: Float) {}
            override fun onBufferReceived(p0: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(p0: Bundle?) {}
            override fun onEvent(p0: Int, p1: Bundle?) {}
        })
        sr.startListening(intent)
    } catch (_: Exception) {}
}

private fun showAskGreenChat() {
    // remove prior
    removeOverlaySafe(askChatView); askChatView = null
    removeOverlaySafe(askCloseChip); askCloseChip = null

    // container
    val box = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        background = roundedDrawable(0xFF2E7D32.toInt(), radius = 24f, strokePx = 6, strokeColor = 0xFF1B5E20.toInt()) // green
        setPadding(24, 24, 24, 24)
    }

    val title = TextView(this).apply {
        text = "Ask about this screen"
        setTextColor(0xFFFFFFFF.toInt())
        textSize = 16f
    }
    val user = TextView(this).apply {
        setTextColor(0xFFFFFFFF.toInt())
        textSize = 14f
    }
    val ai = TextView(this).apply {
        setTextColor(0xFFFFFFFF.toInt())
        textSize = 14f
    }

    val input = EditText(this).apply {
        hint = "Type or use Mic button..."
        setTextColor(0xFFFFFFFF.toInt())
        setHintTextColor(0xAAFFFFFF.toInt())
        setBackgroundColor(0x22000000)
        setPadding(20, 20, 20, 20)
    }

    val row = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
    }
    val micBtn = Button(this).apply {
        text = "ðŸŽ¤"
        textSize = 18f
        setTextColor(0xFFFFFFFF.toInt())
        background = roundedDrawable(0xFF1B5E20.toInt(), radius = 18f, strokePx = 0) // dark green
        setPadding(22, 10, 22, 10)
        setOnClickListener { startMicIntoEdit(input) }
    }
    val sendBtn = Button(this).apply {
        text = "Ask"
        textSize = 14f
        background = roundedDrawable(0xFF1B5E20.toInt(), radius = 18f, strokePx = 0)
        setTextColor(0xFFFFFFFF.toInt())
        setPadding(22, 10, 22, 10)
        setOnClickListener {
            val q = input.text?.toString()?.trim().orEmpty()
            if (q.isBlank()) { Toast.makeText(this@OrbService, "Type something", Toast.LENGTH_SHORT).show(); return@setOnClickListener }
            user.text = "You: $q"
            askSendMergedScreenQuestion(q) { answer ->
                ai.text = "GPMai: $answer"
            }
        }
    }
    row.addView(micBtn)
    row.addView(sendBtn)

    box.addView(title)
    box.addView(user)
    box.addView(ai)
    box.addView(input)
    box.addView(row)

    askChatView = box
    askChatParams = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = (orbParams.x + orbView.width + 24).coerceAtMost(Resources.getSystem().displayMetrics.widthPixels - 480)
        y = (orbParams.y).coerceAtLeast(40)
    }
    windowManager.addView(askChatView, askChatParams)

    // Focus keyboard
    input.requestFocus()
    (getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager).showSoftInput(input, InputMethodManager.SHOW_IMPLICIT)

    // Blue close for ask chat
    askCloseChip = createBlueCloseChip {
        removeOverlaySafe(askChatView); askChatView = null
        removeOverlaySafe(askCloseChip); askCloseChip = null
    }
    askChatView!!.post {
        val cx = askChatParams.x + askChatView!!.width - 10
        val cy = askChatParams.y - 28
        addOverlay(askCloseChip!!, cx, cy)
    }
}

private fun askSendMergedScreenQuestion(q: String, onAnswer: (String) -> Unit) {
    val access = GPMaiAccessibilityService.readVisibleScreenText()
    val bmp = captureScreenBitmap()
    if (bmp == null) {
        val prompt = "USER QUESTION:\n$q\n\nSCREEN CONTENT (Accessibility only):\n$access"
        methodChannel.invokeMethod("handleUserMessage", prompt, object : MethodChannel.Result {
            override fun success(result: Any?) { onAnswer(result?.toString()?.trim().orEmpty()) }
            override fun error(code: String, msg: String?, details: Any?) { val m = msg ?: "unknown"; onAnswer(if (m.contains("401") || m.contains("Unauthorized")) "Sign in required to use screen-aware answers." else "Could not answer. Check login/server.") }
            override fun notImplemented() { onAnswer("Brain not available") }
        })
        return
    }
    getOCRTextFromBitmap(bmp) { ocr ->
        val prompt = """
            USER QUESTION:
            $q

            SCREEN CONTENT (Accessibility):
            $access

            SCREEN CONTENT (OCR):
            $ocr
        """.trimIndent()
        methodChannel.invokeMethod("handleUserMessage", prompt, object : MethodChannel.Result {
            override fun success(result: Any?) { onAnswer(result?.toString()?.trim().orEmpty()) }
            override fun error(code: String, msg: String?, details: Any?) { val m = msg ?: "unknown"; onAnswer(if (m.contains("401") || m.contains("Unauthorized")) "Sign in required to use screen-aware answers." else "Could not answer. Check login/server.") }
            override fun notImplemented() { onAnswer("Brain not available") }
        })
    }
}

// ---- Edge & state helpers ----
private fun screenBounds(): Rect {
    val wm = getSystemService(WINDOW_SERVICE) as WindowManager
    return if (Build.VERSION.SDK_INT >= 30) wm.currentWindowMetrics.bounds
    else Rect(0, 0,
        Resources.getSystem().displayMetrics.widthPixels,
        Resources.getSystem().displayMetrics.heightPixels)
}

// Safe clamp: handles 0/oversized views without crashing
private fun clampXY(x: Int, y: Int, w: Int, h: Int): Pair<Int, Int> {
    val b = screenBounds()

    // Ensure nonzero dims
    val vw = w.coerceAtLeast(1)
    val vh = h.coerceAtLeast(1)

    val minX = b.left + 8
    val maxX = b.right - vw - 8
    val minY = b.top + 8
    val maxY = b.bottom - vh - 8

    // If the view is bigger than the screen in that axis, center it safely
    val safeX = if (maxX < minX) {
        b.left + ((b.width() - vw).coerceAtLeast(0) / 2)
    } else {
        x.coerceIn(minX, maxX)
    }

    val safeY = if (maxY < minY) {
        b.top + ((b.height() - vh).coerceAtLeast(0) / 2)
    } else {
        y.coerceIn(minY, maxY)
    }

    return safeX to safeY
}


private fun dockToNearestEdge() {
    val b = screenBounds()

    // choose side by current center
    val centerX = orbParams.x + (orbView.width / 2)
    preferLeftEdge = centerX < b.centerX()

    val peekPx = (orbView.width * PEEK_RATIO).toInt().coerceAtLeast(24)

    // keep only peekPx visible; allow X to overflow intentionally
    val targetX = if (preferLeftEdge) {
        b.left - (orbView.width - peekPx)
    } else {
        b.right - peekPx
    }
    val targetY = orbParams.y.coerceIn(b.top + 40, b.bottom - orbView.height - 40)

    orbParams.x = targetX
    orbParams.y = targetY

    ensureOrbVisible()
    try { windowManager.updateViewLayout(orbView, orbParams) } catch (_: Exception) {}

    orbView.alpha = PEEK_ALPHA
    uiState = OrbUiState.DOCKED
}


private fun slideOutFromEdge() {
    val b = screenBounds()
    val targetX = if (preferLeftEdge) b.left + 24 else b.right - orbView.width - 24
    val targetY = orbParams.y.coerceIn(b.top + 40, b.bottom - orbView.height - 40)

    // update LayoutParams directly (no .x/.y animation â†’ no â€œvanishâ€ race)
    orbParams.x = targetX
    orbParams.y = targetY
    ensureOrbVisible()
    try { windowManager.updateViewLayout(orbView, orbParams) } catch (_: Exception) {}

    // just fade alpha for feedback
    orbView.animate().alpha(ACTIVE_ALPHA).setDuration(120).withEndAction {
        uiState = OrbUiState.ACTIVE
    }.start()
}

private fun scheduleAutoDock(delayMs: Long = AUTO_DOCK_DELAY_MS) {
    if (autoDockHandler == null) autoDockHandler = Handler(Looper.getMainLooper())
    autoDockRunnable?.let { autoDockHandler?.removeCallbacks(it) }
    autoDockRunnable = Runnable {
        // donâ€™t peek while any UI is open
        if (!isBlockingUiOpen()) dockToNearestEdge()
        else scheduleAutoDock(1200L) // check again a bit later
    }
    autoDockHandler?.postDelayed(autoDockRunnable!!, delayMs)
}


private fun cancelAutoDock() { 
    autoDockRunnable?.let { autoDockHandler?.removeCallbacks(it) }
    autoDockRunnable = null
}

private fun setTextColors(root: View, color: Int) {
    if (root is TextView) root.setTextColor(color)
    if (root is ViewGroup) for (i in 0 until root.childCount) setTextColors(root.getChildAt(i), color)
}

private fun startOrbWatchdog() {
    if (orbWatchdog != null) return
    orbWatchdog = Handler(Looper.getMainLooper())
    orbWatchdog?.post(object : Runnable {
        override fun run() {
            try {
                if (orbView.parent == null) {
                    ensureOrbVisible()
                    dockToNearestEdge()
                }
            } catch (_: Exception) {}
            orbWatchdog?.postDelayed(this, 2000)
        }
    })
}


override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
    super.onConfigurationChanged(newConfig)
    // keep within new screen bounds and reâ€‘dock to edge
    val (cx, cy) = clampXY(orbParams.x, orbParams.y, orbView.width, orbView.height)
    orbParams.x = cx
    orbParams.y = cy
    try { windowManager.updateViewLayout(orbView, orbParams) } catch (_: Exception) {}
    dockToNearestEdge()
}
private fun summonOrb() {
    ensureOrbVisible()
    orbView.alpha = ACTIVE_ALPHA
    slideOutFromEdge()
}
private fun positionChatCloseChip() {
    chatCloseChip?.let { chip ->
        // default size guess before measure
        val chipW = if (chip.width > 0) chip.width else 36
        val chipH = if (chip.height > 0) chip.height else 36
        val gap = 10

        val x = chatParams.x + (chatView.width - chipW) / 2
        val y = chatParams.y - chipH - gap

        val (cx, cy) = clampXY(x, y, chipW, chipH)
        repositionOverlay(chip, cx, cy)
    }
}

private fun isSensitiveApp(): Boolean {
    val pkg = GPMaiAccessibilityService.getTopAppPackage(this) ?: return false
    return SENSITIVE_APPS.contains(pkg)
}

// Ensure we have MediaProjection consent; otherwise open your permission flow
private fun ensureScreenReadConsentThen(onReady: () -> Unit) {
    if (isSensitiveApp()) {
        speakOut("Screen reading is disabled in this app.")
        addLogLine("ðŸš« Blocked capture in sensitive app")
        return
    }
    if (projectionResultCode == 0 || projectionDataIntent == null) {
        addLogLine("âš ï¸ Need screen-capture consent â€” opening wizard")
        try {
            val i = Intent(this, PermissionActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(i)
        } catch (_: Exception) {}
        return
    }
    onReady()
}

// Panel that tells the user we only capture AFTER they press Ask
private fun showAskPanelPolicySafe() {
    removeViewSafe(askPanel); askPanel = null

    val container = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(24, 24, 24, 24)
        setBackgroundColor(0xEE000000.toInt())
    }

    val title = TextView(this).apply {
        text = "Ask about the current screen"
        setTextColor(0xFFFFFFFF.toInt()); textSize = 16f
        setPadding(0,0,0,12)
    }
    val note = TextView(this).apply {
        text = "A oneâ€‘time snapshot is taken ONLY after you press Ask."
        setTextColor(0xAAFFFFFF.toInt()); textSize = 12f
        setPadding(0,0,0,10)
    }
    val input = EditText(this).apply {
        hint = "e.g., Summarize this screen"
        setTextColor(0xFFFFFFFF.toInt()); setHintTextColor(0x99FFFFFF.toInt())
        setBackgroundColor(0x22000000); setPadding(20, 20, 20, 20)
    }

    val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }

    val micBtn = Button(this).apply {
        text = "ðŸŽ¤"; textSize = 18f
        background = roundedDrawable(0xFF1B5E20.toInt(), radius = 18f, strokePx = 0)
        setTextColor(0xFFFFFFFF.toInt()); setPadding(22, 10, 22, 10)
        setOnClickListener { startMicIntoEdit(input) }
    }
    val askBtn = Button(this).apply {
        text = "Ask"; textSize = 14f
        background = roundedDrawable(0xFF1976D2.toInt(), radius = 18f, strokePx = 0)
        setTextColor(0xFFFFFFFF.toInt()); setPadding(22, 10, 22, 10)
        setOnClickListener {
            val q = input.text?.toString()?.trim().orEmpty()
            if (q.isBlank()) {
                Toast.makeText(this@OrbService, "Type your question", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            askAboutScreenPolicySafe(q)    // â¬…ï¸ does the capture (user-initiated)
            removeViewSafe(askPanel); askPanel = null
            scheduleAutoDock()
        }
    }
    val cancelBtn = Button(this).apply {
        text = "Cancel"; textSize = 14f
        background = roundedDrawable(0xFF444444.toInt(), radius = 18f, strokePx = 0)
        setTextColor(0xFFFFFFFF.toInt()); setPadding(22, 10, 22, 10)
        setOnClickListener {
            removeViewSafe(askPanel); askPanel = null
            scheduleAutoDock()
        }
    }

    row.addView(micBtn); row.addView(askBtn); row.addView(cancelBtn)
    container.addView(title); container.addView(note); container.addView(input); container.addView(row)

    val params = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = (orbParams.x + orbView.width + 20)
            .coerceAtMost(Resources.getSystem().displayMetrics.widthPixels - 480)
        y = (orbParams.y).coerceAtLeast(40)
    }

    askPanel = container
    windowManager.addView(askPanel, params)

    input.requestFocus()
    (getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager)
        .showSoftInput(input, InputMethodManager.SHOW_IMPLICIT)
}

// Actually perform the capture only after user taps Ask
private fun askAboutScreenPolicySafe(question: String) {
    ensureScreenReadConsentThen {
        // visible indicator
        showVoiceMouthOverlay()
        voiceMouthOverlay.findViewById<TextView>(R.id.status_label).text = "Analyzing this screen..."

        val bmp = captureScreenBitmap()
        if (bmp == null) {
            addLogLine("âŒ Couldnâ€™t capture screen")
            speakOut("I couldnâ€™t capture the screen.")
            voiceMouthOverlay.setBackgroundColor(0x00000000)
            return@ensureScreenReadConsentThen
        }

        getOCRTextFromBitmap(bmp) { ocr ->
            val access = GPMaiAccessibilityService.readVisibleScreenText()

            val prompt = """
                USER ASKED ABOUT CURRENT SCREEN:
                $question

                ACCESSIBILITY:
                $access

                OCR:
                $ocr

                Respond briefly (max 2 lines). If asked to summarize, be concise.
            """.trimIndent()

            sendToBrain(prompt, false, null, null)
            Handler(Looper.getMainLooper()).postDelayed({
                voiceMouthOverlay.setBackgroundColor(0x00000000)
            }, 500)
        }
    }
}

// ==== COMPACT ASK â€” SMALL, NO-BLINK, DRAGGABLE, CLEAR INPUT, SHOW Q ABOVE A ====
// ==== COMPACT ASK â€” ORIGINAL SIZE, NO SECURE FLAG, NO-BLINK, DRAGGABLE ====
// - Size/padding back to the older larger look
// - NO FLAG_SECURE so the compact box appears in screenshots
// - Input clears after send
// - Shows "You: ..." above "GPMai: ..." every time
// compact panel with tight gap + live status + auto expand (no FLAG_SECURE)
// ==== COMPACT ASK â€” with Bulb Help + Agreement Gate (no FLAG_SECURE) ====
// ==== COMPACT ASK â€” tight width + info bulb + agreement gate ====
// ==== COMPACT ASK â€” with Speaker toggle beside AI answer (play/stop TTS) ====
// ==== COMPACT ASK â€” with Speaker toggle beside AI answer (play/stop TTS) ====
// ==== COMPACT ASK â€” Speaker toggle (no overlay TTS) ====
// ==== COMPACT ASK â€” super compact, single Q/A, speaker w/ inline TTS ====
// ==== COMPACT ASK â€” single Q/A, tiny & draggable, with speaker toggle ====
// ==== COMPACT ASK â€” single Q/A, tiny & draggable, with speaker toggle ====
private fun showAskChatCompact() {
    removeOverlaySafe(askCompactView); askCompactView = null

    val overlayFlags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS

    val box = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        background = roundedDrawable(0xEE111111.toInt(), radius = 18f, strokePx = 3, strokeColor = 0xFF1F6FEB.toInt())
        setPadding(dp(14), dp(6), dp(14), dp(8))
        layoutParams = LinearLayout.LayoutParams(dp(280), LinearLayout.LayoutParams.WRAP_CONTENT)
    }

    // header
    val header = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
    val title = TextView(this).apply {
        text = "Ask about this screen"
        setTextColor(0xFFFFFFFF.toInt()); textSize = 14f
    }
    val spacer = View(this).apply { layoutParams = LinearLayout.LayoutParams(0, 1, 1f) }
    val infoBtn = ImageButton(this).apply {
        setImageResource(android.R.drawable.ic_dialog_info)
        setBackgroundColor(0x00000000)
        setPadding(dp(4), dp(2), dp(4), dp(2))
        // Always show the long sheet WITH the checkbox; user can tick/untick, then CLOSE.
        setOnClickListener { showInfoPopover(requireAgree = false) { /* no-op */ } }
    }
    header.addView(title); header.addView(spacer); header.addView(infoBtn)

    // status (tap to expand/collapse the steps panel)
    val status = TextView(this).apply {
        visibility = View.GONE
        setTextColor(0xFFB0BEC5.toInt()); textSize = 11f
        setPadding(dp(6), dp(4), dp(6), dp(4))
        isClickable = true
        setOnClickListener { toggleStepsOverlay() }
    }
    status.text = "Waitingâ€¦ â–¾"
    askStatusText = status

    // one pair of lines keeps widget small
    val userLine = TextView(this).apply {
        visibility = View.GONE; textSize = 13f
        setTextColor(0xFFFFFFFF.toInt()); setPadding(0, dp(2), 0, 0)
    }

    val aiRow = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        visibility = View.GONE
    }
    val aiLine = TextView(this).apply {
        textSize = 13f
        setTextColor(0xFFE0E0E0.toInt())
        setPadding(0, 0, dp(6), dp(4))
        layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
    }
    val speakerBtn = ImageButton(this).apply {
        setImageResource(android.R.drawable.ic_lock_silent_mode_off)
        setBackgroundColor(0x00000000)
        setPadding(dp(6), dp(2), dp(6), dp(2))
        visibility = View.GONE
    }
    var isSpeaking = false
    speakerBtn.setOnClickListener {
        val text = aiLine.text?.toString()?.removePrefix("GPMai:")?.trim().orEmpty()
        if (text.isBlank()) return@setOnClickListener
        if (isSpeaking) { stopTTS(); isSpeaking = false } else { speakOut(text) { isSpeaking = false }; isSpeaking = true }
    }
    aiRow.addView(aiLine); aiRow.addView(speakerBtn)

    val input = EditText(this).apply {
        hint = "Type your question..."
        setTextColor(0xFFFFFFFF.toInt()); setHintTextColor(0x88FFFFFF.toInt())
        setBackgroundColor(0x22000000)
        setPadding(dp(8), dp(6), dp(8), dp(6))
        maxLines = 1
    }

    fun pill(bg: Int, label: String, onTap: () -> Unit) = Button(this).apply {
        text = label; textSize = 13f
        background = roundedDrawable(bg, radius = 14f, strokePx = 0)
        setTextColor(0xFFFFFFFF.toInt()); setPadding(dp(16), dp(6), dp(16), dp(6))
        setOnClickListener { onTap() }
        layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
    }

    val askBtn = pill(0xFF1976D2.toInt(), "ASK") {
        val q = input.text?.toString()?.trim().orEmpty()
        if (q.isBlank()) {
            Toast.makeText(this, "Type something or use the mic â†’", Toast.LENGTH_SHORT).show()
            return@pill
        }

        // ASK is always tappable â€” we gate here if consent not yet granted.
        ensureScreenReadAgreementThen {
            // clear previous so the box stays small
            userLine.text = ""; userLine.visibility = View.GONE
            aiLine.text = ""; aiRow.visibility = View.GONE
            speakerBtn.visibility = View.GONE
            isSpeaking = false

            userLine.visibility = View.VISIBLE; userLine.text = "You: $q"
            aiRow.visibility = View.VISIBLE;    aiLine.text = "GPMai: Thinking..."

            input.setText(""); askCompactView?.requestLayout()
            status.visibility = View.VISIBLE
            setAskStatus("Preparing...")

            // 25-second hard timeout
            val timeoutHandler = android.os.Handler(android.os.Looper.getMainLooper())
            var answered = false
            val timeoutRunnable = Runnable {
                if (!answered) {
                    answered = true
                    aiLine.text = "GPMai: Could not get response. Check login/server connection."
                    setAskStatus("Timeout")
                    speakerBtn.visibility = View.GONE
                    askCompactView?.requestLayout()
                }
            }
            timeoutHandler.postDelayed(timeoutRunnable, 25000L)

            // start capture & pipeline
            startProjectionSession {
                hideImeNow()
                setAskStatus("Capturing screen...")

                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    setAskStatus("Securing...")

                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        setAskStatus("Sending...")
                        setAskStatus("Waiting for reply...")
                        askOncePolicySafe(q) { ans ->
                            if (!answered) {
                                answered = true
                                timeoutHandler.removeCallbacks(timeoutRunnable)
                            }
                            val display = when {
                                ans.contains("401") || ans.contains("Unauthorized") ->
                                    "Sign in required to use screen-aware answers."
                                ans.contains("Error:") && ans.length < 80 ->
                                    "Could not answer. Check login/server."
                                ans.isBlank() -> "[No response]"
                                else -> ans
                            }
                            setAskStatus("Reply received")
                            aiLine.text = "GPMai: $display"
                            speakerBtn.visibility = if (ans.isBlank() || display.startsWith("Sign in") || display.startsWith("Could not")) View.GONE else View.VISIBLE
                            isSpeaking = false
                            askCompactView?.requestLayout()
                            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                                setAskStatus("Done")
                            }, 120)
                        }
                    }, 100)
                }, 100)
            }
        }
    }

    val micPill = pill(0xFFFFFFFF.toInt(), "ðŸŽ¤") { startMicIntoEdit(input) }.apply {
        setTextColor(0xFF000000.toInt())
    }

    val closePill = pill(0xFFB00020.toInt(), "âœ•") {
        stopProjectionSession()
        endAskProgressNotif()                           // remove non-dismissible notif
        removeOverlaySafe(stepsOverlay); stepsOverlay = null; stepsOverlayList = null
        removeOverlaySafe(askCompactView); askCompactView = null
        scheduleAutoDock()
    }

    val row = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        setPadding(0, dp(4), 0, 0)
        addView(askBtn)
        addView(View(this@OrbService).apply { layoutParams = LinearLayout.LayoutParams(dp(6), 1) })
        addView(micPill)
        addView(View(this@OrbService).apply { layoutParams = LinearLayout.LayoutParams(dp(6), 1) })
        addView(closePill)
    }

    box.addView(header)
    box.addView(status)
    box.addView(userLine)
    box.addView(aiRow)
    box.addView(input)
    box.addView(row)

    askCompactView = box
    askCompactParams = WindowManager.LayoutParams(
        dp(280),
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        overlayFlags,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = (orbParams.x + orbView.width + 20).coerceAtMost(Resources.getSystem().displayMetrics.widthPixels - dp(300))
        y = (orbParams.y).coerceAtLeast(40)
    }
    windowManager.addView(askCompactView, askCompactParams)

    // Start the non-dismissible progress notification tied to this compact session
    startAskProgressNotif("Panel opened")

    makeOverlayDraggable(askCompactView!!, askCompactParams)
    askCompactView?.post { nudgeInsideScreen(askCompactView!!, askCompactParams) }

    // focus input
    (getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager).apply {
        input.requestFocus(); showSoftInput(input, InputMethodManager.SHOW_IMPLICIT)
    }
}

// ==== ONE-SHOT CAPTURE (TEXT â†’ TEXT) â€” CLEAN ====
private fun askOncePolicySafe(question: String, onAnswer: (String) -> Unit) {
    askScreenWithImageFirst(question, onAnswer, alsoSpeak = false)
}


// ==== ONE-SHOT CAPTURE (VOICE â†’ TTS) â€” CLEAN ====
private fun askOncePolicySafeTts(question: String) {
    askScreenWithImageFirst(question, onAnswer = {}, alsoSpeak = true)
}

private fun removeBusyUi() {
    try { voiceMouthOverlay.setBackgroundColor(0x00000000) } catch (_: Exception) {}
}

// --- tiny helpers ---
private fun hasRecordAudioPermission(): Boolean {
    return try {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) true
        checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) == android.content.pm.PackageManager.PERMISSION_GRANTED
    } catch (_: Exception) { true }
}

private fun openMicPermissionDialog() {
    try {
        val i = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = android.net.Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(i)
    } catch (_: Exception) {}
}

private fun hasMediaProjectionConsent(): Boolean {
    return !(projectionResultCode == 0 || projectionDataIntent == null)
}

// ==== ANALYZING DOT â€” fully removed (safe stubs) ====
private fun showAnalyzingDot(x: Int, y: Int) { /* removed */ }
private fun hideAnalyzingDot() { /* removed */ }
private fun moveAnalyzingDot(x: Int, y: Int) { /* removed */ }

private fun showAskVoiceMode() {
    removeOverlaySafe(askVoiceView); askVoiceView = null
    hideAnalyzingDot()

    val root = FrameLayout(this).apply {
        background = roundedDrawable(0xEE111111.toInt(), radius = 22f, strokePx = 4, strokeColor = 0xFF1F6FEB.toInt())
        setPadding(20, 20, 20, 20)
    }

    // top-right X
    val close = Button(this).apply {
        text = "âœ•"
        textSize = 14f
        background = roundedDrawable(0xFFB00020.toInt(), radius = 18f, strokePx = 0)
        setTextColor(0xFFFFFFFF.toInt())
        setPadding(20, 12, 20, 12)
        setOnClickListener {
            removeOverlaySafe(askVoiceView); askVoiceView = null
            scheduleAutoDock()
        }
    }
    val closeLp = FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT).apply {
        gravity = Gravity.TOP or Gravity.END
    }
    root.addView(close, closeLp)

    // centered hint
    val hint = TextView(this).apply {
        text = "Tap ASK to speak. Iâ€™ll capture once and answer with voice."
        setTextColor(0xFFFFFFFF.toInt()); textSize = 14f
    }
    val hintLp = FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT).apply {
        gravity = Gravity.CENTER
    }
    root.addView(hint, hintLp)

    // bottom fixed ASK (starts mic)
    val ask = Button(this).apply {
        text = "Ask (Voice)"
        textSize = 16f
        background = roundedDrawable(0xFF1976D2.toInt(), radius = 22f, strokePx = 0)
        setTextColor(0xFFFFFFFF.toInt())
        setPadding(30, 18, 30, 18)
        setOnClickListener {
            // start mic; after speech result, do one-time capture + TTS
            startVoiceAskOnce()
        }
    }
    val askLp = FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT).apply {
        gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
        bottomMargin = 10
    }
    root.addView(ask, askLp)

    askVoiceView = root
    askVoiceParams = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = (orbParams.x + orbView.width + 20)
            .coerceAtMost(Resources.getSystem().displayMetrics.widthPixels - 540)
        y = (orbParams.y).coerceAtLeast(40)
    }
    windowManager.addView(askVoiceView, askVoiceParams)
}

// ==== START MIC â†’ ON RESULT, CAPTURE ONCE, TTS REPLY (no dots/overlays) ====
private fun startVoiceAskOnce() {
    if (!hasRecordAudioPermission()) { openMicPermissionDialog(); speakOut("Please grant microphone permission, then try again."); return }
    if (!hasMediaProjectionConsent()) {
        try {
            val i = Intent(this, PermissionActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(i)
        } catch (_: Exception) {}
        speakOut("Allow 'Start now' to capture the screen once, then tap Ask again.")
        return
    }

    try {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) return
        val sr = SpeechRecognizer.createSpeechRecognizer(this)
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
        }
        sr.setRecognitionListener(object : RecognitionListener {
            override fun onResults(results: Bundle?) {
                val q = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
                sr.destroy()
                if (q.isBlank()) { speakOut("I didnâ€™t hear anything."); return }
                askOncePolicySafeTts(q)
            }
            override fun onReadyForSpeech(p0: Bundle?) {}
            override fun onError(p0: Int) { sr.destroy() }
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(p0: Float) {}
            override fun onBufferReceived(p0: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(p0: Bundle?) {}
            override fun onEvent(p0: Int, p1: Bundle?) {}
        })
        sr.startListening(intent)
    } catch (_: Exception) {}
}

// ==== MAKE ANY OVERLAY DRAGGABLE ====
private fun makeOverlayDraggable(view: View, lp: WindowManager.LayoutParams) {
    var downX = 0
    var downY = 0
    var startX = 0
    var startY = 0

    view.setOnTouchListener { _, e ->
        when (e.action) {
            MotionEvent.ACTION_DOWN -> {
                downX = e.rawX.toInt()
                downY = e.rawY.toInt()
                startX = lp.x
                startY = lp.y
                true
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = e.rawX.toInt() - downX
                val dy = e.rawY.toInt() - downY
                val nx = startX + dx
                val ny = startY + dy
                // clamp to screen
                val (cx, cy) = clampXY(nx, ny, view.width.coerceAtLeast(1), view.height.coerceAtLeast(1))
                lp.x = cx; lp.y = cy
                try { windowManager.updateViewLayout(view, lp) } catch (_: Exception) {}
                true
            }
            else -> false
        }
    }
}
// ==== GLOBAL KEY PRESS (with HOME fallback) ====
private fun pressGlobal(action: Int): Boolean {
    val ok = GPMaiAccessibilityService.instance()
        ?.performGlobalAction(action) ?: false

    // Fallback only for HOME (lets you go home even if service didn't fire)
    if (!ok && action == AccessibilityService.GLOBAL_ACTION_HOME) {
        return try {
            val i = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(i)
            true
        } catch (_: Exception) { false }
    }
    return ok
}

private fun toJpegBase64(src: Bitmap, maxW: Int = 1280, quality: Int = 80): String {
    val (w, h) = src.width to src.height
    val scaled = if (w > maxW) {
        val nh = (h * (maxW.toFloat() / w)).toInt().coerceAtLeast(1)
        Bitmap.createScaledBitmap(src, maxW, nh, true)
    } else src

    val out = ByteArrayOutputStream()
    scaled.compress(Bitmap.CompressFormat.JPEG, quality, out)
    if (scaled !== src) scaled.recycle()
    return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
}
// Map any internal step text to a coarse, privacy-safe phase
private fun mapToPublicStep(s: String): String {
    val t = s.lowercase(Locale.US)
    return when {
        // PREPARING
        listOf("prepare", "boot", "init", "load").any { it in t } -> "Preparing..."

        // CAPTURING
        listOf("capture", "screenshot", "grab frame", "snapshot").any { it in t } -> "Capturing screen..."

        // SECURING (encryption / masking / redaction hints)
        listOf("secure", "encrypt", "mask", "redact", "sanitize").any { it in t } -> "Securing..."

        // ANALYZING (ocr / vision / nlp bundled)
        listOf("ocr", "read", "analyz", "parse", "understand", "inspect").any { it in t } -> "Analyzing..."

        // SUMMARIZING
        listOf("summary", "summariz", "distill", "condense").any { it in t } -> "Summarizing..."

        // ANSWERING
        listOf("compose", "draft", "answer", "reply", "generate").any { it in t } -> "Answering..."

        // FINALIZING
        listOf("format", "finaliz", "polish", "wrap", "render").any { it in t } -> "Finalizing..."

        // NETWORK / RETRY / STATES
        listOf("connect", "network").any { it in t } -> "Connecting..."
        listOf("retry", "backoff").any { it in t } -> "Retrying..."
        listOf("pause", "paused").any { it in t } -> "Paused"
        listOf("cancel", "cancelled", "canceled").any { it in t } -> "Cancelled"
        listOf("error", "fail", "timeout").any { it in t } -> "Error"

        // DONE
        listOf("done", "complete", "finished", "success").any { it in t } -> "Done âœ…"

        else -> "Working..."
    }
}

private fun setAskStatus(s: String) {
    val public = mapToPublicStep(s)
    val expanded = stepsOverlay != null
    val caret = if (expanded) "â–´" else "â–¾"
    val full = if (public.isBlank()) "" else "$public  $caret"

    val green = 0xFF00E676.toInt()
    val ss = if (full.isNotEmpty()) {
        val sp = android.text.SpannableString(full)
        val caretStart = full.length - 1
        sp.setSpan(android.text.style.ForegroundColorSpan(green), 0, full.length, 0)
        sp.setSpan(android.text.style.StyleSpan(android.graphics.Typeface.BOLD), 0, caretStart - 1, 0)
        sp.setSpan(android.text.style.RelativeSizeSpan(1.35f), caretStart, full.length, 0)
        sp
    } else null

    android.os.Handler(android.os.Looper.getMainLooper()).post {
        askStatusText?.let { v ->
            if (public.isBlank()) { v.visibility = View.GONE; v.text = "" }
            else {
                v.visibility = View.VISIBLE
                v.text = ss
                v.setTextIsSelectable(false); v.setOnLongClickListener { true } // no copy
            }
        }
        askCompactView?.requestLayout()
    }

    if (s.isNotBlank() && s != lastAskStatus) {
        lastAskStatus = s
        pushAskStep(s)   // updates steps list + notification
    }
}

private fun askScreenWithImageFirst(
    question: String,
    onAnswer: (String) -> Unit,
    alsoSpeak: Boolean = false
) {
    if (isSensitiveApp()) {
        val msg = "Screen reading is disabled in this app."
        if (alsoSpeak) speakOut(msg) else onAnswer(msg)
        return
    }

    setAskStatus("Preparing...")

    maybeShowExplainThen {
        startProjectionSession {
            hideImeNow()
            temporarilyHideOurOverlays()

            Handler(Looper.getMainLooper()).postDelayed({
                setAskStatus("Capturing screen...")

                fun captureWithRetry(onGot: (Bitmap?) -> Unit) {
                    val first = captureScreenBitmap()
                    if (first != null) { onGot(first); return }
                    // â¬‡ï¸ If projection isnâ€™t active, log a clear reason
                    if (!isProjectionSessionActive || mediaProjection == null) {
                        logFallback(FallbackReason.NO_PROJECTION_CONSENT, "projection inactive")
                    }
                    Handler(Looper.getMainLooper()).postDelayed({ onGot(captureScreenBitmap()) }, 180)
                }

                captureWithRetry { bmp ->
                    try {
                        val a11y = GPMaiAccessibilityService.readVisibleScreenText()

                        if (bmp == null) {
                            // â¬‡ï¸ Capture failed â†’ we are going to text fallback
                            logFallback(FallbackReason.CAPTURE_NULL, "captureScreenBitmap() returned null")
                            setAskStatus("Analyzing text...")
                            logFallback(FallbackReason.TEXT_ONLY_PATH, "fallback to askSendMergedScreenQuestion")
                            askSendMergedScreenQuestion(question) { ans ->
                                setAskStatus("Done")
                                if (alsoSpeak) speakOut(ans) else onAnswer(ans)
                            }
                            return@captureWithRetry
                        }

                        setAskStatus("Reading text (OCR)...")
                        val scaled = Bitmap.createScaledBitmap(
                            bmp,
                            512, (bmp.height * 512f / bmp.width).toInt().coerceAtLeast(1), true
                        )

                        getOCRTextFromBitmap(scaled) { ocr ->
                            if (ocr.isNullOrBlank()) {
                                // â¬‡ï¸ OCR empty (not fatal â€” we still try Vision, but log)
                                logFallback(FallbackReason.OCR_EMPTY, "MLKit returned empty text")
                            }

                            setAskStatus("Sending...")
                            val b64 = toJpegBase64(scaled)
                            val payload = mapOf(
                                "question" to question,
                                "image_base64_jpeg" to b64,
                                "a11y_text" to a11y,
                                "ocr_text" to (ocr ?: "")
                            )

                            setAskStatus("Waiting for reply...")

                            methodChannel.invokeMethod("handleVisionMessage", payload,
                                object : MethodChannel.Result {
                                    override fun success(result: Any?) {
                                        val ans = result?.toString()?.trim().orEmpty().ifBlank { "[No response]" }
                                        if (alsoSpeak) speakOut(ans) else onAnswer(ans)
                                        setAskStatus("Done")
                                    }
                                    override fun error(code: String, msg: String?, details: Any?) {
                                        // â¬‡ï¸ Vision API path errored â†’ text fallback
                                        logFallback(FallbackReason.API_ERROR, "code=$code msg=${msg ?: "?"}")
                                        setAskStatus("Fallback (text only)...")
                                        logFallback(FallbackReason.TEXT_ONLY_PATH, "fallback to askSendMergedScreenQuestion")
                                        askSendMergedScreenQuestion(question) { ans ->
                                            if (alsoSpeak) speakOut(ans) else onAnswer(ans)
                                            setAskStatus("Done")
                                        }
                                    }
                                    override fun notImplemented() {
                                        // â¬‡ï¸ Dart channel not wired
                                        logFallback(FallbackReason.CHANNEL_NOT_IMPLEMENTED, "handleVisionMessage not implemented")
                                        setAskStatus("Fallback (text only)...")
                                        logFallback(FallbackReason.TEXT_ONLY_PATH, "fallback to askSendMergedScreenQuestion")
                                        askSendMergedScreenQuestion(question) { ans ->
                                            if (alsoSpeak) speakOut(ans) else onAnswer(ans)
                                            setAskStatus("Done")
                                        }
                                    }
                                })
                        }
                    } finally {
                        restoreHiddenOverlays()
                    }
                }
            }, 140)
        }
    }
}


private fun startProjectionSession(then: () -> Unit) {
    if (isSensitiveApp()) {
        speakOut("Screen reading is disabled in this app.")
        addLogLine("ðŸš« Blocked capture in sensitive app")
        return
    }
    if (isProjectionSessionActive && mediaProjection != null) {
        // Already capturing â†’ ensure/refresh foreground
        try { startForeground(NOTIF_ID, buildCastingNotification()) } catch (_: Exception) {}
        showCastingNotif()
        then()
        return
    }

    // fresh consent
    projectionResultCode = 0
    projectionDataIntent = null
    onProjectionReady = {
        // user tapped â€œStart nowâ€ â†’ receiver will startForeground + showCastingNotif
        then()
    }

    addLogLine("ðŸŸ  Requesting screen-capture consent")
    try {
        val i = Intent(this, PermissionActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(i)
    } catch (_: Exception) {
        addLogLine("âŒ Could not open consent activity")
        onProjectionReady = null
    }
}

private fun stopProjectionSession() {
    addLogLine("ðŸ›‘ Stopping screen-cast session")
    try { releaseMediaProjection() } catch (_: Exception) {}
    isProjectionSessionActive = false
    projectionResultCode = 0
    projectionDataIntent = null
    onProjectionReady = null

    try { stopForeground(true) } catch (_: Exception) {}
    showIdleNotif() // back to swipeâ€‘away idle notice
}


private fun hideImeNow(anchor: View? = askCompactView) {
    try {
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        val token = (anchor ?: orbView).windowToken
        imm.hideSoftInputFromWindow(token, 0)
    } catch (_: Exception) {}
}

// ==== OVERLAY HIDE (no-blink: don't hide askCompactView) ====
// ==== OVERLAY HIDE (include compact Ask now) ====

// ==== OVERLAY HIDE (include compact Ask now) ====
private fun temporarilyHideOurOverlays() {
    hiddenOverlays.clear()
    listOf(askChatView, chatView, triPanel, triCloseChip, askCompactView).forEach { v ->
        if (v != null && v.visibility == View.VISIBLE) {
            hiddenOverlays.add(v)
            v.alpha = 0f   // invisible but not removed (avoids layout jump)
        }
    }
}

private fun restoreHiddenOverlays() {
    hiddenOverlays.forEach { v -> v.alpha = 1f }
    hiddenOverlays.clear()
}


private fun maybeShowExplainThen(next: () -> Unit) {
    if (prefs.getBoolean(PREF_HIDE_EXPLAIN, false)) { next(); return }
    showExplainOverlay(next)
}

private fun showExplainOverlay(onAccept: () -> Unit) {
    removeOverlaySafe(explainView); explainView = null

    val box = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(28, 28, 28, 28)
        background = roundedDrawable(0xEE000000.toInt(), radius = 24f, strokePx = 4, strokeColor = 0xFF1F6FEB.toInt())
    }

    val title = TextView(this).apply {
        text = "Permission Needed"
        setTextColor(0xFFFFFFFF.toInt()); textSize = 18f
    }
    val msg = TextView(this).apply {
        text = "GPMai needs screen capture *once* to understand this screen. " +
               "We do not monitor, collect, or share your private data."
        setTextColor(0xDDFFFFFF.toInt()); textSize = 14f
        setPadding(0, 10, 0, 14)
    }
    val dont = CheckBox(this).apply {
        text = "Do not show again"
        setTextColor(0xFFFFFFFF.toInt())
    }
    val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
    val cancel = Button(this).apply {
        text = "Cancel"
        background = roundedDrawable(0xFF444444.toInt(), 18f, 0)
        setTextColor(0xFFFFFFFF.toInt())
        setOnClickListener { removeOverlaySafe(explainView); explainView = null }
    }
    val accept = Button(this).apply {
        text = "Accept"
        background = roundedDrawable(0xFF1976D2.toInt(), 18f, 0)
        setTextColor(0xFFFFFFFF.toInt())
        setOnClickListener {
            if (dont.isChecked) prefs.edit().putBoolean(PREF_HIDE_EXPLAIN, true).apply()
            removeOverlaySafe(explainView); explainView = null
            onAccept()
        }
    }
    row.addView(cancel); row.addView(View(this).apply { layoutParams = LinearLayout.LayoutParams(16,1) }); row.addView(accept)

    box.addView(title); box.addView(msg); box.addView(dont); box.addView(row)

    explainView = box
    val lp = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        SECURE_FLAGS,                                     // secure as well
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.CENTER
    }
    windowManager.addView(explainView, lp)
}

private fun updateNotif(title: String, text: String, color: Int? = null, ongoing: Boolean = true) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val ch = NotificationChannel("gpmai_channel", "GPMai Assistant", NotificationManager.IMPORTANCE_LOW)
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(ch)
    }
    val n = Notification.Builder(this, "gpmai_channel")
        .setSmallIcon(android.R.drawable.ic_menu_view)
        .setContentTitle(title)
        .setContentText(text)
        .setOngoing(ongoing)
        .apply { if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && color != null) setColor(color) }
        .build()
    (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).notify(NOTIF_ID, n)
}

private fun showIdleNotif() {
    updateNotif(
        title = "GPMai is running",
        text  = "Doubleâ€‘tap the orb to chat â€¢ Longâ€‘press to Ask",
        ongoing = false   // âœ… user can swipe it away
    )
}


private fun showCastingNotif() {
    // red-ish like your screenshot
    updateNotif("Sharing your screen with GPMai", "One-time capture for this Ask", 0xFFE53935.toInt())
}
private fun hideNotif() {
    (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIF_ID)
}

// Gate: ensure the user read & accepted the short terms once before screen capture
// Gate: ensure the user read & accepted the short terms once before screen capture

// Long, scrollable consent + guide sheet (half-screen tall, footer pinned).
// - requireAgree = true  â†’ gate: shows checkbox, no toggle
// - requireAgree = false â†’ info: shows a consent toggle (user can revoke/enable anytime)
// Always-on checkbox consent sheet (half-screen, scrollable, footer pinned)
// - requireAgree = true  â†’ ASK gate: checkbox must be ticked; "GOT IT" enables and proceeds
// - requireAgree = false â†’ Info: checkbox remains visible; ticking/unticking updates consent immediately
private fun showInfoPopover(requireAgree: Boolean = true, onAgreed: () -> Unit = {}) {
    val halfH = (resources.displayMetrics.heightPixels * 0.5f).toInt()

    val card = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        background = roundedDrawable(0xF0101010.toInt(), radius = 18f, strokePx = dp(2), strokeColor = 0xFF1F6FEB.toInt())
        setPadding(dp(14), dp(12), dp(14), dp(12))
        layoutParams = LinearLayout.LayoutParams(dp(320), halfH)
    }

    fun h(text: String) = TextView(this).apply {
        this.text = text
        setTextColor(0xFFFFFFFF.toInt()); textSize = 16f
        setTypeface(null, android.graphics.Typeface.BOLD)
        setPadding(0, dp(8), 0, dp(4))
        setTextIsSelectable(false)
    }
    fun p(text: String) = TextView(this).apply {
        this.text = text
        setTextColor(0xFFE0E0E0.toInt()); textSize = 13f
        setLineSpacing(0f, 1.15f)
        setPadding(0, dp(2), 0, dp(2))
        setTextIsSelectable(false)
    }
    fun bullet(text: String) = TextView(this).apply {
        this.text = "â€¢ $text"
        setTextColor(0xFFE0E0E0.toInt()); textSize = 13f
        setLineSpacing(0f, 1.15f)
        setPadding(0, dp(2), 0, dp(2))
        setTextIsSelectable(false)
    }

    val content = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }

    // Body (same in both modes)
    listOf(
        h("How to use"),
        bullet("Long-press the orb â†’ the small box opens."),
        bullet("Type your question about THIS screen, then tap ASK."),
        bullet("A ONE-TIME snapshot happens only after you tap ASK (no continuous monitoring)."),

        h("What we capture"),
        bullet("A one-time snapshot of the current screen plus detected on-screen text, only when you tap ASK."),
        bullet("Used solely to answer your question; not used for advertising or profiling."),

        h("What we do NOT capture"),
        bullet("No continuous screen recording or background monitoring."),
        bullet("No microphone audio (unless you intentionally use voice-to-text)."),
        bullet("No files outside the screen, and no background apps."),
        bullet("No clipboard access (unless you explicitly paste)."),

        h("Processing & security"),
        bullet("Data is encrypted in transit. Sensitive fields may be masked or ignored."),
        bullet("The snapshot is not stored by the app; it is discarded after answering."),
        bullet("If analysis fails, we may fall back to text-only analysis of readable on-screen text."),

        h("When to avoid"),
        bullet("Banking, OTP, passwords, or other highly sensitive pages."),
        bullet("Content you do not have permission to capture or share."),

        h("Your controls"),
        bullet("Stop any time via the âœ• in the compact box."),
        bullet("A persistent notification shows when processing is active."),
        bullet("Open app notification settings to allow/disable notifications."),
        bullet("Revisit this page via the (i) button to review or change capture permission."),

        h("Tips for best results"),
        bullet("Be specific: e.g., â€œWhatâ€™s the due date on this page?â€"),
        bullet("Ensure the content you care about is visible before tapping ASK."),
        bullet("Use short, clear questions; you can ask follow-ups."),

        h("Your responsibility"),
        p("By continuing, you confirm you understand how capture works and accept responsibility for what you choose to show and ask. Results may be imperfect; verify important information.")
    ).forEach { content.addView(it) }

    val scroll = ScrollView(this).apply {
        isFillViewport = true
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            0,
            1f
        )
        addView(content)
    }
    card.addView(scroll)

    // Footer (checkbox + buttons). Checkbox ALWAYS visible.
    val footer = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        setPadding(0, dp(10), 0, 0)
        gravity = Gravity.END or Gravity.CENTER_VERTICAL
    }

    val agreeBox = CheckBox(this).apply {
        text = "I understand and agree."
        setTextColor(0xFFE0E0E0.toInt()); textSize = 13f
        isChecked = hasScreenReadConsent()
        // In info mode: update consent immediately when user ticks/unticks.
        // In gate mode: still update immediately, and GOT IT will proceed only if checked.
        setOnCheckedChangeListener { _, checked ->
            setScreenReadConsent(checked)
            if (!requireAgree) {
                Toast.makeText(this@OrbService, if (checked) "Consent granted" else "Consent revoked", Toast.LENGTH_SHORT).show()
            }
        }
    }
 val sheet = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(dp(10), dp(10), dp(10), dp(10))
        addView(card)
    }
    val confirmBtn = Button(this).apply {
        text = if (requireAgree) "GOT IT" else "CLOSE"
        background = roundedDrawable(0xFF1976D2.toInt(), radius = 14f)
        setTextColor(0xFFFFFFFF.toInt())
        isEnabled = if (requireAgree) agreeBox.isChecked else true
        setOnClickListener {
            removeOverlaySafe(sheet)
            if (requireAgree && agreeBox.isChecked) {
                // proceed only when agreed during gate
                onAgreed()
            }
        }
    }

    val cancelBtn = Button(this).apply {
        text = "CANCEL"
        background = roundedDrawable(0xFF424242.toInt(), radius = 14f)
        setTextColor(0xFFFFFFFF.toInt())
        setOnClickListener { removeOverlaySafe(sheet) }
        visibility = if (requireAgree) View.VISIBLE else View.GONE // keep simple; info mode just has CLOSE
    }

    // Keep confirm enabled state synced with checkbox in gate mode
    if (requireAgree) {
        agreeBox.setOnCheckedChangeListener { _, checked ->
            setScreenReadConsent(checked)
            confirmBtn.isEnabled = checked
        }
    }

    val leftWrap = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        addView(agreeBox)
        layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
    }
    footer.addView(leftWrap)
    footer.addView(confirmBtn)
    footer.addView(View(this).apply { layoutParams = LinearLayout.LayoutParams(dp(8), 1) })
    footer.addView(cancelBtn)
    card.addView(footer)


    val lp = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT
    ).apply { gravity = Gravity.CENTER }

    try { windowManager.addView(sheet, lp) } catch (_: Exception) {}
}



// Keep any overlay fully on-screen after it's added or moved (safe on all devices)
private fun nudgeInsideScreen(view: View, lp: WindowManager.LayoutParams) {
    val b = screenBounds()                 // actual screen rect
    val vw = (if (view.width  > 0) view.width  else 1)
    val vh = (if (view.height > 0) view.height else 1)

    val minX = b.left + 8
    val minY = b.top  + 8
    var maxX = b.right  - vw - 8
    var maxY = b.bottom - vh - 8

    // If the view is larger than the screen (minus margins), clamp size first
    val usableW = (b.width()  - 16).coerceAtLeast(64)
    val usableH = (b.height() - 16).coerceAtLeast(48)

    if (vw > usableW) {
        lp.width = usableW
        maxX = b.right - lp.width - 8
    }
    if (vh > usableH) {
        lp.height = usableH
        maxY = b.bottom - lp.height - 8
    }

    val nx = if (maxX >= minX) lp.x.coerceIn(minX, maxX) else minX
    val ny = if (maxY >= minY) lp.y.coerceIn(minY, maxY) else minY

    if (nx != lp.x || ny != lp.y) {
        lp.x = nx
        lp.y = ny
    }
    try { windowManager.updateViewLayout(view, lp) } catch (_: Exception) {}
}

// ========= helpers (class-scope) =========
private fun <T> tryGet(getter: () -> T): T? =
    try { getter() } catch (_: UninitializedPropertyAccessException) { null } catch (_: Exception) { null }

private fun removeViewIfPresent(view: View?) {
    try { if (view != null && view.parent != null) windowManager.removeView(view) } catch (_: Exception) {}
}


private fun maskCompactBox() {
    if (askCompactView == null || askMaskView != null) return

    val mask = View(this).apply {
        setBackgroundColor(Color.BLACK)   // solid mask
        alpha = 0.85f                      // slightly see-through so user still sees box shape
    }

    val lp = WindowManager.LayoutParams(
        askCompactView!!.width.coerceAtLeast(220),
        askCompactView!!.height.coerceAtLeast(120),
        getLayoutType(),
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = askCompactParams.x
        y = askCompactParams.y
    }

    try {
        windowManager.addView(mask, lp)
        askMaskView = mask
    } catch (_: Exception) {}
}

private fun unmaskCompactBox() {
    askMaskView?.let {
        try { if (it.parent != null) windowManager.removeView(it) } catch (_: Exception) {}
    }
    askMaskView = null
}

private fun buildProcessingChip(): View {
    // Small rounded chip, spinner + status label
    val root = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        setPadding(dp(10), dp(8), dp(12), dp(8))
        background = roundedDrawable(0xEE101010.toInt(), radius = 16f, strokePx = 3, strokeColor = 0xFF1F6FEB.toInt())
        elevation = 12f
    }

    val spinner = ProgressBar(this).apply {
        isIndeterminate = true
        layoutParams = LinearLayout.LayoutParams(dp(18), dp(18)).apply { rightMargin = dp(10) }
    }
    val label = TextView(this).apply {
        text = "Preparing..."
        setTextColor(0xFFEFEFEF.toInt())
        textSize = 12f
    }

    root.addView(spinner)
    root.addView(label)
    procStatus = label

    // SECURE overlay so MediaProjection will mask it in screenshots
    procParams = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
        WindowManager.LayoutParams.FLAG_SECURE, // ðŸ‘ˆ the mask magic
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        // Place near the orb; weâ€™ll fine-tune after add
        x = (orbParams.x + orbView.width + dp(8))
            .coerceAtMost(Resources.getSystem().displayMetrics.widthPixels - dp(160))
        y = (orbParams.y - dp(8)).coerceAtLeast(dp(40))
    }

    return root
}
private fun showProcessing(status: String) {
    try {
        if (procView == null) procView = buildProcessingChip()
        if (procView?.parent == null) windowManager.addView(procView, procParams)
        updateProcessing(status)

        // keep it snug with the orb even if user dragged it
        val b = screenBounds()
        val nx = if (preferLeftEdge) (orbParams.x + orbView.width + dp(8))
                 else                 (orbParams.x - dp(150))
        val ny = (orbParams.y - dp(8)).coerceIn(b.top + dp(40), b.bottom - dp(40))
        repositionOverlay(procView, nx, ny)

        addLogLine("ðŸ”’ Processing chip (SECURE) shown: $status")
    } catch (e: Exception) {
        addLogLine("âŒ showProcessing error: ${e.message}")
    }
}

private fun updateProcessing(status: String) {
    try {
        procStatus?.text = status
    } catch (_: Exception) {}
}

private fun hideProcessing() {
    try {
        if (procView?.parent != null) windowManager.removeView(procView)
    } catch (_: Exception) {}
    procView = null
    procStatus = null
    addLogLine("ðŸ”“ Processing chip hidden")
}

private fun fadeOutKeepMounted(v: View?, onDone: (() -> Unit)? = null) {
    if (v == null) { onDone?.invoke(); return }
    try {
        if (v.alpha <= 0.05f) { onDone?.invoke(); return }
        v.animate().alpha(0f).setDuration(120).withEndAction { onDone?.invoke() }.start()
    } catch (_: Exception) { onDone?.invoke() }
}

private fun fadeIn(v: View?, onDone: (() -> Unit)? = null) {
    if (v == null) { onDone?.invoke(); return }
    try {
        v.animate().alpha(1f).setDuration(120).withEndAction { onDone?.invoke() }.start()
    } catch (_: Exception) { onDone?.invoke() }
}
// quick fades (safe on nulls)
private fun fadeOut(v: View?, dur: Long = 120L) {
    if (v == null) return
    try { v.animate().alpha(0f).setDuration(dur).start() } catch (_: Exception) {}
}
private fun fadeIn(v: View?, dur: Long = 120L) {
    if (v == null) return
    try { v.animate().alpha(1f).setDuration(dur).start() } catch (_: Exception) {}
}

// small rounded bg
private fun pillBg(fill: Int = 0xEE111111.toInt(), stroke: Int = 0xFF1F6FEB.toInt()): GradientDrawable {
    return GradientDrawable().apply {
        cornerRadius = dp(16).toFloat()
        setColor(fill)
        setStroke(dp(2), stroke)
    }
}

// show a tiny secure processing chip near the compact box
private fun showProcessingChip(initial: String) {
    hideProcessingChip() // ensure single instance

    val wrap = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        background = pillBg()
        setPadding(dp(12), dp(10), dp(12), dp(10))
    }

    val spinner = ProgressBar(this).apply {
        isIndeterminate = true
        layoutParams = LinearLayout.LayoutParams(dp(18), dp(18)).apply { rightMargin = dp(10) }
    }

    val txt = TextView(this).apply {
        text = initial
        setTextColor(0xFFFFFFFF.toInt())
        textSize = 13f
    }

    wrap.addView(spinner)
    wrap.addView(txt)

    val lp = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        // SECURE â†’ this overlay will NOT appear in screenshots
        SECURE_FLAGS or
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        // place near the compact box if present, else near orb
        x = try { askCompactParams.x + dp(8) } catch (_: Exception) { orbParams.x + dp(8) }
        y = try { askCompactParams.y - dp(8) } catch (_: Exception) { (orbParams.y - dp(8)).coerceAtLeast(dp(40)) }
    }

    processingChipView = wrap
    processingTextView = txt
    try { windowManager.addView(wrap, lp) } catch (_: Exception) {}
}

private fun updateProcessingChip(s: String) {
    try { processingTextView?.text = s } catch (_: Exception) {}
}

private fun hideProcessingChip() {
    val v = processingChipView
    processingChipView = null
    processingTextView = null
    try { if (v != null && v.parent != null) windowManager.removeView(v) } catch (_: Exception) {}
}

private fun buildCastingNotification(): Notification {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val ch = NotificationChannel(
            "gpmai_channel",
            "GPMai Assistant",
            NotificationManager.IMPORTANCE_LOW
        )
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(ch)
    }
    return Notification.Builder(this, "gpmai_channel")
        .setSmallIcon(android.R.drawable.ic_menu_view)
        .setContentTitle("Sharing your screen with GPMai")
        .setContentText("Oneâ€‘time capture for this Ask")
        .setOngoing(true) // nonâ€‘dismissible while capturing
        .build()
}
private fun speakOutGuarded(text: String, onDone: (() -> Unit)? = null) {
    if (!allowTts) { onDone?.invoke(); return }
    speakOut(text, onDone)
}

private fun tappedRecently(ms: Long = 250) =
    (System.currentTimeMillis() - lastUiTap).also { lastUiTap = System.currentTimeMillis() } < ms
private fun resetChatUi() {
    if (!::chatView.isInitialized) return

    val input    = chatView.findViewById<EditText>(R.id.message_input)
    val userText = chatView.findViewById<TextView>(R.id.user_text)
    val aiReply  = chatView.findViewById<TextView>(R.id.gpmai_response)
    val ttsBtn   = chatView.findViewById<ImageButton>(R.id.tts_toggle)

    // clear fields + return to compact defaults
    input.apply {
        setText("")
        isSingleLine = false
        setHorizontallyScrolling(false)
        inputType = InputType.TYPE_CLASS_TEXT or
                    InputType.TYPE_TEXT_FLAG_MULTI_LINE or
                    InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
        minLines = 1
        maxLines = 4
        scrollTo(0, 0)
    }

    userText.text = ""
    aiReply.text  = ""

    userText.visibility = View.GONE
    aiReply.visibility  = View.GONE

    ttsBtn?.setImageResource(android.R.drawable.ic_lock_silent_mode_off)

    // make sure the bubble remeasures and stays on-screen
    chatView.requestLayout()
    chatView.post { updateChatPosition() }
}
// Start a non-dismissible foreground notification for compact Ask
// Foreground notification for compact Ask
private fun startAskProgressNotif(initial: String = "Panel opened") {
    askSteps.clear()
    lastAskStatus = ""
    ensureAskChannel()

    // Android 13+ runtime notification permission â†’ deep-link if missing
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        val granted = checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        if (!granted) {
            try {
                val i = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(i)
            } catch (_: Exception) {
                try {
                    val i = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.fromParts("package", packageName, null)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(i)
                } catch (_: Exception) { /* ignore */ }
            }
        }
    }

    // First step also posts/updates the non-dismissible notification
    pushAskStep(initial)
}


// Append a step and update the notification (big text style)
private fun pushAskStep(step: String) {
    val public = "â€¢ " + mapToPublicStep(step)
    if (askSteps.lastOrNull() == public) return
    askSteps.add(public)
    updateStepsOverlayContent()

    val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
    val big = askSteps.joinToString("\n")
    val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        Notification.Builder(this, ASK_CHANNEL_ID)
    } else Notification.Builder(this)

    val notif = builder
        .setSmallIcon(android.R.drawable.ic_menu_view)
        .setContentTitle("GPMai: Ask in progress")
        .setContentText(mapToPublicStep(step))
        .setStyle(Notification.BigTextStyle().bigText(big))
        .setOngoing(true)                // non-dismissible
        .setOnlyAlertOnce(true)
        .addAction(                       // ðŸ”´ STOP action
            android.R.drawable.ic_delete,
            "STOP",
            stopAskPendingIntent()
        )
        .build()

    try { startForeground(NOTIF_ID_ASK, notif) } catch (_: Exception) {}
    try { nm.notify(NOTIF_ID_ASK, notif) } catch (_: Exception) {}
}

// Stop the progress notification cleanly
private fun endAskProgressNotif() {
    askSteps.clear()
    lastAskStatus = ""
    try { stopForeground(true) } catch (_: Exception) {}
    try { (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIF_ID_ASK) } catch (_: Exception) {}
}

private fun toggleStepsOverlay() {
    if (stepsOverlay != null) {
        removeOverlaySafe(stepsOverlay); stepsOverlay = null
        stepsOverlayList = null
        // rebuild status to flip caret
        val label = askStatusText?.text?.toString()
            ?.replace(" â–¾","")?.replace(" â–´","")?.trim().orEmpty()
        // label already contains public text; reapply caret via setAskStatus
        if (lastAskStatus.isNotBlank()) setAskStatus(lastAskStatus)
        return
    }

    val maxW = dp(280)
    val card = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        background = roundedDrawable(0xF0101010.toInt(), radius = 18f, strokePx = dp(2), strokeColor = 0xFF1F6FEB.toInt())
        setPadding(dp(12), dp(10), dp(12), dp(10))
        layoutParams = LinearLayout.LayoutParams(maxW, LinearLayout.LayoutParams.WRAP_CONTENT)
    }

    val title = TextView(this).apply {
        text = "Process"
        setTextColor(0xFFFFFFFF.toInt()); textSize = 14f
        setPadding(0, 0, 0, dp(6))
        setTextIsSelectable(false)
    }
    card.addView(title)

    val list = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
    }
    val scroll = ScrollView(this).apply {
        isFillViewport = false
        addView(list)
    }
    card.addView(scroll)

    val lp = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        getLayoutType(),
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = (askCompactParams.x + dp(6))
        y = (askCompactParams.y + (askCompactView?.height ?: dp(120)) + dp(6))
    }

    stepsOverlay = card
    stepsOverlayList = list
    try { windowManager.addView(card, lp) } catch (_: Exception) {}

    updateStepsOverlayContent()

    // flip caret by re-setting current status
    if (lastAskStatus.isNotBlank()) setAskStatus(lastAskStatus)
}


private fun updateStepsOverlayContent() {
    val container = stepsOverlayList ?: return
    container.removeAllViews()
    val green = 0xFF00E676.toInt()
    askSteps.forEach { s: String ->
        val tv = TextView(this).apply {
            text = s
            setTextColor(green)
            textSize = 13f
            setPadding(0, dp(3), 0, dp(2))
            setTypeface(null, android.graphics.Typeface.BOLD)
            setTextIsSelectable(false); setOnLongClickListener { true }
        }
        container.addView(tv)
    }
}

private fun ensureAskChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val ch = NotificationChannel(
            ASK_CHANNEL_ID,
            ASK_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            enableVibration(false)
            setShowBadge(false)
        }
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(ch)
    }
}
// Consent state helpers
// Consent helpers (single source of truth â€” keep only these once)
private fun hasScreenReadConsent(): Boolean =
    prefs.getBoolean("screen_read_agreed", false)

private fun ensureScreenReadAgreementThen(onGranted: () -> Unit) {
    if (hasScreenReadConsent()) {
        onGranted()
    } else {
        showInfoPopover(requireAgree = true) { onGranted() }
    }
}

private fun buildAskProgressNotification(status: String): Notification {
    ensureAskChannel()
    return Notification.Builder(this, ASK_CHANNEL_ID)
        .setSmallIcon(android.R.drawable.ic_menu_info_details)
        .setContentTitle("GPMai is analyzing this screen")
        .setContentText(status.ifBlank { "Working..." })
        .setOnlyAlertOnce(true)
        .setOngoing(true)                       // non-dismissible
        .setColor(0xFFE53935.toInt())           // ðŸ”´ red accent
        // ðŸ”´ STOP action (tinted by the red color above)
        .addAction(android.R.drawable.ic_delete, "STOP", stopAskPendingIntent())
        .build()
}

private fun resetScreenReadConsent() {
    prefs.edit().putBoolean("screen_read_agreed", false).apply()
}

private fun setScreenReadConsent(value: Boolean) {
    prefs.edit().putBoolean("screen_read_agreed", value).apply()
}

// ðŸ”´ Single source of truth â€” keep only this one
private fun stopAskPendingIntent(): PendingIntent {
    val i = Intent(this, OrbService::class.java).setAction(ACTION_STOP_ASK)
    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    else
        PendingIntent.FLAG_UPDATE_CURRENT
    return PendingIntent.getService(this, 1001, i, flags)
}



private fun handleAskStopFromNotif() {
    try { tts.stop() } catch (_: Exception) {}
    try { voiceMouthOverlay.visibility = View.GONE } catch (_: Exception) {}

    removeOverlaySafe(stepsOverlay); stepsOverlay = null; stepsOverlayList = null
    removeOverlaySafe(askCompactView); askCompactView = null
    removeOverlaySafe(askChatView);    askChatView = null
    removeOverlaySafe(askPanel);       askPanel = null

    stopProjectionSession()
    endAskProgressNotif()
    showIdleNotif()

    try { dockToNearestEdge() } catch (_: Exception) {}
    scheduleAutoDock()
    addLogLine("ðŸ›‘ Ask stopped from notification")
}

override fun onDestroy() {
    super.onDestroy()
    isActive = false

    // helpers
    fun getOrNull(block: () -> Any?): Any? = try { block() } catch (_: Exception) { null }
    fun removeViewIfPresent(view: View?) {
        try { if (view != null && view.parent != null) windowManager.removeView(view) } catch (_: Exception) {}
    }

    // Stop projection session & timers
    try { stopProjectionSession() } catch (_: Exception) {}
    try { autoDockRunnable?.let { autoDockHandler?.removeCallbacks(it) } } catch (_: Exception) {}
    autoDockHandler = null
    autoDockRunnable = null

    try { stopWatchingForScreenChange() } catch (_: Exception) {}
    try { orbWatchdog?.removeCallbacksAndMessages(null) } catch (_: Exception) {}
    orbWatchdog = null

    // Receiver
    try { projReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
    projReceiver = null

    // Speech recognizer
    (getOrNull { speechRecognizer } as? SpeechRecognizer)?.let {
        try { it.destroy() } catch (_: Exception) {}
    }

    // Remove overlays/panels
    listOf(
        getOrNull { voiceMouthOverlay } as? View,
        getOrNull { chatView } as? View,
        triPanel as? View, triCloseChip,
        qaSuggestionBtn, qaHomeBtn, qaBackBtn,
        pillAskBtn, pillChatBtn,
        askPanel, askChatView, askCompactView, askVoiceView,
        closeBtnOverlay, refreshBtnOverlay, stopBtnOverlay,
        floatingReadStopBtn, greenReadBtn
    ).forEach { v -> removeViewIfPresent(v) }

    closeBtnOverlay = null
    refreshBtnOverlay = null
    stopBtnOverlay = null
    floatingReadStopBtn = null
    greenReadBtn = null

    // Orb
    removeViewIfPresent(getOrNull { orbView } as? View)

    // TTS
    (getOrNull { tts } as? TextToSpeech)?.let {
        try { it.stop() } catch (_: Exception) {}
        try { it.shutdown() } catch (_: Exception) {}
    }

    // Flutter
    (getOrNull { flutterEngine } as? FlutterEngine)?.let {
        try { it.destroy() } catch (_: Exception) {}
    }
}
override fun onBind(intent: Intent?): IBinder? = null
}
