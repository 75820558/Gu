#!/bin/bash
# Запускати з ~/Gu
set -e

# ── build.gradle (root) ──────────────────────────────
cat > build.gradle << 'EOF'
buildscript {
    repositories { google(); mavenCentral() }
    dependencies { classpath 'com.android.tools.build:gradle:8.1.0' }
}
allprojects {
    repositories { google(); mavenCentral() }
}
EOF

# ── gradle wrapper properties ────────────────────────
mkdir -p gradle/wrapper
cat > gradle/wrapper/gradle-wrapper.properties << 'EOF'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.1-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF

# ── gradlew ──────────────────────────────────────────
cat > gradlew << 'GRADLEW'
#!/bin/sh
CLASSPATH=$APP_HOME/gradle/wrapper/gradle-wrapper.jar
exec java -classpath "$CLASSPATH" org.gradle.wrapper.GradleWrapperMain "$@"
GRADLEW
chmod +x gradlew

# Завантажуємо реальний gradle wrapper jar
mkdir -p gradle/wrapper
curl -sL "https://raw.githubusercontent.com/gradle/gradle/v8.1.0/gradle/wrapper/gradle-wrapper.jar" \
     -o gradle/wrapper/gradle-wrapper.jar 2>/dev/null || true

# ── app/build.gradle ────────────────────────────────
cat > app/build.gradle << 'EOF'
plugins {
    id 'com.android.application'
}
android {
    namespace 'com.gesture.overlay'
    compileSdk 34
    defaultConfig {
        applicationId "com.gesture.overlay"
        minSdk 26
        targetSdk 34
        versionCode 1
        versionName "1.0"
    }
    buildTypes {
        release { minifyEnabled false }
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}
dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.mediapipe:tasks-vision:0.10.9'
}
EOF

# ── AndroidManifest.xml ──────────────────────────────
cat > app/src/main/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.BIND_ACCESSIBILITY_SERVICE"/>
    <uses-feature android:name="android.hardware.camera" android:required="true"/>

    <application
        android:allowBackup="true"
        android:label="GestureAI"
        android:theme="@style/AppTheme">

        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <service
            android:name=".OverlayService"
            android:foregroundServiceType="camera"
            android:exported="false"/>

        <service
            android:name=".GestureAccessibilityService"
            android:exported="true"
            android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
            <intent-filter>
                <action android:name="android.accessibilityservice.AccessibilityService"/>
            </intent-filter>
            <meta-data
                android:name="android.accessibilityservice"
                android:resource="@xml/accessibility_service_config"/>
        </service>

    </application>
</manifest>
EOF

# ── accessibility config ─────────────────────────────
cat > app/src/main/res/xml/accessibility_service_config.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeAllMask"
    android:accessibilityFlags="flagDefault"
    android:canPerformGestures="true"
    android:description="@string/accessibility_description"/>
EOF

# ── strings.xml ──────────────────────────────────────
mkdir -p app/src/main/res/values
cat > app/src/main/res/values/strings.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">GestureAI</string>
    <string name="accessibility_description">Керування жестами руки</string>
</resources>
EOF

# ── styles.xml ───────────────────────────────────────
cat > app/src/main/res/values/styles.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="AppTheme" parent="Theme.AppCompat.Light.NoActionBar"/>
</resources>
EOF

# ── layout/activity_main.xml ─────────────────────────
cat > app/src/main/res/layout/activity_main.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:gravity="center"
    android:padding="24dp"
    android:background="#0a0e14">

    <TextView
        android:text="GESTURE AI"
        android:textColor="#00ffcc"
        android:textSize="26sp"
        android:letterSpacing="0.3"
        android:layout_marginBottom="8dp"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"/>

    <TextView
        android:id="@+id/tv_status"
        android:text="Вимкнено"
        android:textColor="#304050"
        android:textSize="13sp"
        android:layout_marginBottom="40dp"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"/>

    <Button
        android:id="@+id/btn_toggle"
        android:text="УВІМКНУТИ"
        android:textColor="#000000"
        android:backgroundTint="#00ffcc"
        android:layout_width="200dp"
        android:layout_height="52dp"
        android:layout_marginBottom="16dp"/>

    <Button
        android:id="@+id/btn_accessibility"
        android:text="ДОЗВОЛИ ДОСТУПНОСТІ"
        android:textColor="#ffaa00"
        android:backgroundTint="#1a2535"
        android:layout_width="200dp"
        android:layout_height="52dp"/>

    <TextView
        android:layout_marginTop="40dp"
        android:textColor="#304050"
        android:textSize="11sp"
        android:gravity="center"
        android:text="☝ вниз → наступне\n✌ вниз → назад\n☝ затримка → лайк"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"/>

</LinearLayout>
EOF

echo "✅ Layouts і configs створено"

# ── MainActivity.java ────────────────────────────────
cat > app/src/main/java/com/gesture/overlay/MainActivity.java << 'EOF'
package com.gesture.overlay;

import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.widget.Button;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;

public class MainActivity extends AppCompatActivity {

    Button btnToggle, btnAccessibility;
    TextView tvStatus;
    boolean running = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        btnToggle       = findViewById(R.id.btn_toggle);
        btnAccessibility= findViewById(R.id.btn_accessibility);
        tvStatus        = findViewById(R.id.tv_status);

        btnToggle.setOnClickListener(v -> {
            if (!running) {
                // перевіряємо overlay дозвіл
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                        && !Settings.canDrawOverlays(this)) {
                    Intent i = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:" + getPackageName()));
                    startActivity(i);
                    return;
                }
                startService(new Intent(this, OverlayService.class));
                running = true;
                btnToggle.setText("ВИМКНУТИ");
                tvStatus.setText("Працює — камера активна");
                tvStatus.setTextColor(0xFF00FFCC);
            } else {
                stopService(new Intent(this, OverlayService.class));
                running = false;
                btnToggle.setText("УВІМКНУТИ");
                tvStatus.setText("Вимкнено");
                tvStatus.setTextColor(0xFF304050);
            }
        });

        btnAccessibility.setOnClickListener(v -> {
            startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS));
        });
    }
}
EOF

echo "✅ MainActivity.java створено"

# ── GestureAccessibilityService.java ────────────────
cat > app/src/main/java/com/gesture/overlay/GestureAccessibilityService.java << 'EOF'
package com.gesture.overlay;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.Path;
import android.view.accessibility.AccessibilityEvent;

public class GestureAccessibilityService extends AccessibilityService {

    public static final String ACTION_GESTURE = "com.gesture.overlay.GESTURE";
    public static final String EXTRA_TYPE     = "gesture_type";

    // Типи жестів
    public static final int SWIPE_DOWN  = 1;  // ☝ вниз → наступне
    public static final int SWIPE_UP    = 2;  // ✌ вниз → назад (свайп вгору)
    public static final int TAP_LIKE    = 3;  // ☝ затримка → лайк (подвійний тап)

    private BroadcastReceiver receiver;

    @Override
    public void onServiceConnected() {
        receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context ctx, Intent intent) {
                int type = intent.getIntExtra(EXTRA_TYPE, 0);
                switch (type) {
                    case SWIPE_DOWN: performSwipeDown(); break;
                    case SWIPE_UP:   performSwipeUp();   break;
                    case TAP_LIKE:   performDoubleTap(); break;
                }
            }
        };
        IntentFilter f = new IntentFilter(ACTION_GESTURE);
        registerReceiver(receiver, f, Context.RECEIVER_NOT_EXPORTED);
    }

    // ── Свайп вниз (TikTok наступне відео) ──────────
    private void performSwipeDown() {
        int w = getResources().getDisplayMetrics().widthPixels;
        int h = getResources().getDisplayMetrics().heightPixels;
        Path path = new Path();
        path.moveTo(w / 2f, h * 0.3f);
        path.lineTo(w / 2f, h * 0.7f);
        dispatch(path, 300);
    }

    // ── Свайп вгору (TikTok попереднє відео) ────────
    private void performSwipeUp() {
        int w = getResources().getDisplayMetrics().widthPixels;
        int h = getResources().getDisplayMetrics().heightPixels;
        Path path = new Path();
        path.moveTo(w / 2f, h * 0.7f);
        path.lineTo(w / 2f, h * 0.3f);
        dispatch(path, 300);
    }

    // ── Подвійний тап (лайк у TikTok) ───────────────
    private void performDoubleTap() {
        int w = getResources().getDisplayMetrics().widthPixels;
        int h = getResources().getDisplayMetrics().heightPixels;
        Path p1 = new Path(); p1.moveTo(w / 2f, h / 2f);
        Path p2 = new Path(); p2.moveTo(w / 2f, h / 2f);

        GestureDescription.Builder builder = new GestureDescription.Builder();
        builder.addStroke(new GestureDescription.StrokeDescription(p1, 0,   50));
        builder.addStroke(new GestureDescription.StrokeDescription(p2, 150, 50));
        dispatchGesture(builder.build(), null, null);
    }

    private void dispatch(Path path, long dur) {
        GestureDescription.Builder b = new GestureDescription.Builder();
        b.addStroke(new GestureDescription.StrokeDescription(path, 0, dur));
        dispatchGesture(b.build(), null, null);
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent e) {}
    @Override
    public void onInterrupt() {}

    @Override
    public void onDestroy() {
        if (receiver != null) unregisterReceiver(receiver);
        super.onDestroy();
    }
}
EOF

echo "✅ GestureAccessibilityService.java створено"

# ── OverlayService.java ──────────────────────────────
cat > app/src/main/java/com/gesture/overlay/OverlayService.java << 'EOF'
package com.gesture.overlay;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.PixelFormat;
import android.hardware.camera2.*;
import android.media.ImageReader;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import android.util.Size;
import android.view.Gravity;
import android.view.WindowManager;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;

import com.google.mediapipe.tasks.core.BaseOptions;
import com.google.mediapipe.tasks.vision.core.RunningMode;
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker;
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult;
import com.google.mediapipe.framework.image.BitmapImageBuilder;
import com.google.mediapipe.framework.image.MPImage;
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark;

import java.util.List;

public class OverlayService extends Service {

    // ── Жест-детектор ────────────────────────────────
    // Індекси пальців MediaPipe:
    // 8=вказівний TIP, 12=середній TIP, 6=вказівний PIP, 10=середній PIP
    // 4=великий TIP, 0=зап'ястя

    private HandLandmarker handLandmarker;
    private HandlerThread cameraThread;
    private Handler cameraHandler;
    private CameraDevice cameraDevice;
    private ImageReader imageReader;

    // Стан жестів
    private long indexDownTime  = 0;   // коли вказівний опустився
    private boolean likeArmed   = false;
    private static final long HOLD_MS = 800; // час утримання для лайку

    private static final String CHANNEL_ID = "gesture_channel";

    @Override
    public void onCreate() {
        super.onCreate();
        startForegroundNotification();
        initMediaPipe();
        startCamera();
    }

    // ── Foreground notification ──────────────────────
    private void startForegroundNotification() {
        NotificationChannel ch = new NotificationChannel(
                CHANNEL_ID, "Gesture Service", NotificationManager.IMPORTANCE_LOW);
        getSystemService(NotificationManager.class).createNotificationChannel(ch);
        Notification n = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("GestureAI активний")
                .setContentText("Розпізнавання жестів працює")
                .setSmallIcon(android.R.drawable.ic_menu_camera)
                .build();
        startForeground(1, n);
    }

    // ── MediaPipe HandLandmarker ─────────────────────
    private void initMediaPipe() {
        try {
            BaseOptions baseOptions = BaseOptions.builder()
                    .setModelAssetPath("hand_landmarker.task")
                    .build();
            HandLandmarker.HandLandmarkerOptions options =
                    HandLandmarker.HandLandmarkerOptions.builder()
                            .setBaseOptions(baseOptions)
                            .setNumHands(1)
                            .setMinHandDetectionConfidence(0.6f)
                            .setMinHandPresenceConfidence(0.6f)
                            .setMinTrackingConfidence(0.6f)
                            .setRunningMode(RunningMode.IMAGE)
                            .build();
            handLandmarker = HandLandmarker.createFromOptions(this, options);
        } catch (Exception e) {
            stopSelf();
        }
    }

    // ── Camera2 ──────────────────────────────────────
    private void startCamera() {
        cameraThread = new HandlerThread("CameraThread");
        cameraThread.start();
        cameraHandler = new Handler(cameraThread.getLooper());

        imageReader = ImageReader.newInstance(320, 240, android.graphics.ImageFormat.YUV_420_888, 2);
        imageReader.setOnImageAvailableListener(reader -> {
            android.media.Image image = reader.acquireLatestImage();
            if (image == null) return;
            processFrame(image);
            image.close();
        }, cameraHandler);

        CameraManager manager = (CameraManager) getSystemService(CAMERA_SERVICE);
        try {
            String camId = manager.getCameraIdList()[0]; // фронтальна зазвичай 1, задня 0
            // шукаємо фронтальну
            for (String id : manager.getCameraIdList()) {
                CameraCharacteristics ch = manager.getCameraCharacteristics(id);
                Integer facing = ch.get(CameraCharacteristics.LENS_FACING);
                if (facing != null && facing == CameraCharacteristics.LENS_FACING_FRONT) {
                    camId = id; break;
                }
            }
            manager.openCamera(camId, new CameraDevice.StateCallback() {
                @Override
                public void onOpened(CameraDevice cam) {
                    cameraDevice = cam;
                    startCaptureSession();
                }
                @Override public void onDisconnected(CameraDevice cam) { cam.close(); }
                @Override public void onError(CameraDevice cam, int e) { cam.close(); }
            }, cameraHandler);
        } catch (Exception e) { stopSelf(); }
    }

    private void startCaptureSession() {
        try {
            CaptureRequest.Builder req = cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
            req.addTarget(imageReader.getSurface());
            cameraDevice.createCaptureSession(
                    List.of(imageReader.getSurface()),
                    new CameraCaptureSession.StateCallback() {
                        @Override
                        public void onConfigured(CameraCaptureSession session) {
                            try {
                                session.setRepeatingRequest(req.build(), null, cameraHandler);
                            } catch (Exception e) { stopSelf(); }
                        }
                        @Override public void onConfigureFailed(CameraCaptureSession s) { stopSelf(); }
                    }, cameraHandler);
        } catch (Exception e) { stopSelf(); }
    }

    // ── Обробка кадру ────────────────────────────────
    private void processFrame(android.media.Image image) {
        if (handLandmarker == null) return;
        Bitmap bmp = yuvToBitmap(image);
        if (bmp == null) return;

        MPImage mpImage = new BitmapImageBuilder(bmp).build();
        HandLandmarkerResult result = handLandmarker.detect(mpImage);

        if (result.landmarks().isEmpty()) {
            indexDownTime = 0;
            likeArmed = false;
            return;
        }

        List<NormalizedLandmark> lm = result.landmarks().get(0);
        detectGesture(lm);
    }

    // ── Розпізнавання жестів ─────────────────────────
    /*
     * Landmark індекси MediaPipe:
     * 0=WRIST, 4=THUMB_TIP
     * 5=INDEX_MCP, 6=INDEX_PIP, 7=INDEX_DIP, 8=INDEX_TIP
     * 9=MIDDLE_MCP,10=MIDDLE_PIP,11=MIDDLE_DIP,12=MIDDLE_TIP
     * 13=RING_MCP, 14=RING_PIP, ...  16=RING_TIP
     * 17=PINKY_MCP,...               20=PINKY_TIP
     */
    private void detectGesture(List<NormalizedLandmark> lm) {
        float ix_tip = lm.get(8).y();   // вказівний TIP  (y↓ = нижче)
        float ix_pip = lm.get(6).y();   // вказівний PIP
        float mx_tip = lm.get(12).y();  // середній TIP
        float mx_pip = lm.get(10).y();  // середній PIP
        float rx_tip = lm.get(16).y();  // безіменний TIP
        float rx_pip = lm.get(14).y();  // безіменний PIP
        float px_tip = lm.get(20).y();  // мізинець TIP
        float px_pip = lm.get(18).y();  // мізинець PIP
        float wrist  = lm.get(0).y();   // зап'ястя

        // Чи палець ПІДНЯТИЙ: TIP вище (менше y) ніж PIP
        boolean indexUp  = ix_tip < ix_pip - 0.04f;
        boolean middleUp = mx_tip < mx_pip - 0.04f;
        boolean ringDown = rx_tip > rx_pip;
        boolean pinkyDown= px_tip > px_pip;

        // ── ☝ один палець вгору ──────────────────────
        boolean oneFingerUp = indexUp && !middleUp && ringDown && pinkyDown;

        // ── ✌ два пальці вгору ───────────────────────
        boolean twoFingersUp = indexUp && middleUp && ringDown && pinkyDown;

        // Напрямок руху вказівного (порівнюємо TIP з MCP по Y)
        float ix_mcp = lm.get(5).y();
        boolean indexPointingDown = ix_tip > ix_mcp + 0.05f; // вказує вниз

        long now = System.currentTimeMillis();

        if (oneFingerUp && indexPointingDown) {
            // ── ☝ вниз → свайп вниз (TikTok наступне) ──
            sendGesture(GestureAccessibilityService.SWIPE_DOWN);
            try { Thread.sleep(600); } catch(Exception e) {}

        } else if (twoFingersUp && indexPointingDown) {
            // ── ✌ вниз → свайп вгору (назад) ──────────
            sendGesture(GestureAccessibilityService.SWIPE_UP);
            try { Thread.sleep(600); } catch(Exception e) {}

        } else if (oneFingerUp && !indexPointingDown) {
            // ── ☝ вгору — відраховуємо час утримання ──
            if (indexDownTime == 0) indexDownTime = now;
            if (!likeArmed && (now - indexDownTime) >= HOLD_MS) {
                likeArmed = true;
                sendGesture(GestureAccessibilityService.TAP_LIKE);
            }
        } else {
            indexDownTime = 0;
            likeArmed = false;
        }
    }

    private void sendGesture(int type) {
        Intent i = new Intent(GestureAccessibilityService.ACTION_GESTURE);
        i.putExtra(GestureAccessibilityService.EXTRA_TYPE, type);
        i.setPackage(getPackageName());
        sendBroadcast(i);
    }

    // ── YUV → Bitmap ────────────────────────────────
    private Bitmap yuvToBitmap(android.media.Image image) {
        try {
            android.media.Image.Plane[] planes = image.getPlanes();
            java.nio.ByteBuffer yBuf  = planes[0].getBuffer();
            java.nio.ByteBuffer uBuf  = planes[1].getBuffer();
            java.nio.ByteBuffer vBuf  = planes[2].getBuffer();
            int ySize = yBuf.remaining();
            int uSize = uBuf.remaining();
            int vSize = vBuf.remaining();
            byte[] nv21 = new byte[ySize + uSize + vSize];
            yBuf.get(nv21, 0, ySize);
            vBuf.get(nv21, ySize, vSize);
            uBuf.get(nv21, ySize + vSize, uSize);
            android.graphics.YuvImage yuvImage = new android.graphics.YuvImage(
                    nv21, android.graphics.ImageFormat.NV21,
                    image.getWidth(), image.getHeight(), null);
            java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
            yuvImage.compressToJpeg(
                    new android.graphics.Rect(0,0,image.getWidth(),image.getHeight()), 80, out);
            byte[] bytes = out.toByteArray();
            return android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
        } catch (Exception e) { return null; }
    }

    @Nullable @Override public IBinder onBind(Intent i) { return null; }

    @Override
    public void onDestroy() {
        if (cameraDevice != null) cameraDevice.close();
        if (imageReader  != null) imageReader.close();
        if (cameraThread != null) cameraThread.quitSafely();
        if (handLandmarker != null) handLandmarker.close();
        super.onDestroy();
    }
}
EOF

echo "✅ OverlayService.java створено"
echo ""
echo "✅ ВСІ ФАЙЛИ ГОТОВІ"
echo "Тепер:"
echo "  1. bash download_model.sh"
echo "  2. git add . && git commit -m 'init' && git push"
