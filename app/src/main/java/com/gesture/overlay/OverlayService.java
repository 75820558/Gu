package com.gesture.overlay;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.ImageFormat;
import android.graphics.Rect;
import android.graphics.YuvImage;
import android.hardware.camera2.*;
import android.media.Image;
import android.media.ImageReader;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;
import com.google.mediapipe.framework.image.BitmapImageBuilder;
import com.google.mediapipe.framework.image.MPImage;
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark;
import com.google.mediapipe.tasks.core.BaseOptions;
import com.google.mediapipe.tasks.vision.core.RunningMode;
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker;
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult;
import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.util.List;

public class OverlayService extends Service {

    private HandLandmarker handLandmarker;
    private HandlerThread cameraThread;
    private Handler cameraHandler;
    private CameraDevice cameraDevice;
    private ImageReader imageReader;
    private long indexDownTime = 0;
    private boolean likeArmed  = false;
    private static final long HOLD_MS   = 800;
    private static final String CH_ID   = "gesture_ch";

    @Override
    public void onCreate() {
        super.onCreate();
        startForeground();
        initMediaPipe();
        startCamera();
    }

    private void startForeground() {
        NotificationChannel ch = new NotificationChannel(
            CH_ID, "Gesture", NotificationManager.IMPORTANCE_LOW);
        getSystemService(NotificationManager.class).createNotificationChannel(ch);
        Notification n = new NotificationCompat.Builder(this, CH_ID)
            .setContentTitle("GestureAI активний")
            .setContentText("Розпізнавання жестів")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .build();
        startForeground(1, n);
    }

    private void initMediaPipe() {
        try {
            HandLandmarker.HandLandmarkerOptions opts =
                HandLandmarker.HandLandmarkerOptions.builder()
                    .setBaseOptions(BaseOptions.builder()
                        .setModelAssetPath("hand_landmarker.task").build())
                    .setNumHands(1)
                    .setMinHandDetectionConfidence(0.6f)
                    .setMinHandPresenceConfidence(0.6f)
                    .setMinTrackingConfidence(0.6f)
                    .setRunningMode(RunningMode.IMAGE)
                    .build();
            handLandmarker = HandLandmarker.createFromOptions(this, opts);
        } catch (Exception e) { stopSelf(); }
    }

    private void startCamera() {
        cameraThread = new HandlerThread("CamThread");
        cameraThread.start();
        cameraHandler = new Handler(cameraThread.getLooper());
        imageReader = ImageReader.newInstance(320, 240, ImageFormat.YUV_420_888, 2);
        imageReader.setOnImageAvailableListener(reader -> {
            Image img = reader.acquireLatestImage();
            if (img == null) return;
            processFrame(img);
            img.close();
        }, cameraHandler);

        CameraManager mgr = (CameraManager) getSystemService(CAMERA_SERVICE);
        try {
            String camId = mgr.getCameraIdList()[0];
            for (String id : mgr.getCameraIdList()) {
                CameraCharacteristics c = mgr.getCameraCharacteristics(id);
                Integer f = c.get(CameraCharacteristics.LENS_FACING);
                if (f != null && f == CameraCharacteristics.LENS_FACING_FRONT) {
                    camId = id; break;
                }
            }
            mgr.openCamera(camId, new CameraDevice.StateCallback() {
                @Override public void onOpened(CameraDevice cam) {
                    cameraDevice = cam;
                    try {
                        CaptureRequest.Builder req = cam.createCaptureRequest(
                            CameraDevice.TEMPLATE_PREVIEW);
                        req.addTarget(imageReader.getSurface());
                        cam.createCaptureSession(List.of(imageReader.getSurface()),
                            new CameraCaptureSession.StateCallback() {
                                @Override public void onConfigured(CameraCaptureSession s) {
                                    try { s.setRepeatingRequest(req.build(),null,cameraHandler); }
                                    catch (Exception e) { stopSelf(); }
                                }
                                @Override public void onConfigureFailed(CameraCaptureSession s) { stopSelf(); }
                            }, cameraHandler);
                    } catch (Exception e) { stopSelf(); }
                }
                @Override public void onDisconnected(CameraDevice cam) { cam.close(); }
                @Override public void onError(CameraDevice cam, int e) { cam.close(); }
            }, cameraHandler);
        } catch (Exception e) { stopSelf(); }
    }

    private void processFrame(Image image) {
        if (handLandmarker == null) return;
        Bitmap bmp = yuvToBitmap(image);
        if (bmp == null) return;
        HandLandmarkerResult result = handLandmarker.detect(
            new BitmapImageBuilder(bmp).build());
        if (result.landmarks().isEmpty()) {
            indexDownTime = 0; likeArmed = false; return;
        }
        detectGesture(result.landmarks().get(0));
    }

    private void detectGesture(List<NormalizedLandmark> lm) {
        float ix_tip = lm.get(8).y();
        float ix_pip = lm.get(6).y();
        float ix_mcp = lm.get(5).y();
        float mx_tip = lm.get(12).y();
        float mx_pip = lm.get(10).y();
        float rx_tip = lm.get(16).y();
        float rx_pip = lm.get(14).y();
        float px_tip = lm.get(20).y();
        float px_pip = lm.get(18).y();

        boolean indexUp  = ix_tip < ix_pip - 0.04f;
        boolean middleUp = mx_tip < mx_pip - 0.04f;
        boolean ringDown = rx_tip > rx_pip;
        boolean pinkyDown= px_tip > px_pip;
        boolean oneUp    = indexUp && !middleUp && ringDown && pinkyDown;
        boolean twoUp    = indexUp &&  middleUp && ringDown && pinkyDown;
        boolean pointDown= ix_tip > ix_mcp + 0.05f;

        long now = System.currentTimeMillis();

        if (oneUp && pointDown) {
            send(GestureAccessibilityService.SWIPE_DOWN);
            sleep(600);
        } else if (twoUp && pointDown) {
            send(GestureAccessibilityService.SWIPE_UP);
            sleep(600);
        } else if (oneUp && !pointDown) {
            if (indexDownTime == 0) indexDownTime = now;
            if (!likeArmed && (now - indexDownTime) >= HOLD_MS) {
                likeArmed = true;
                send(GestureAccessibilityService.TAP_LIKE);
            }
        } else {
            indexDownTime = 0; likeArmed = false;
        }
    }

    private void send(int type) {
        Intent i = new Intent(GestureAccessibilityService.ACTION_GESTURE);
        i.putExtra(GestureAccessibilityService.EXTRA_TYPE, type);
        i.setPackage(getPackageName());
        sendBroadcast(i);
    }

    private void sleep(long ms) {
        try { Thread.sleep(ms); } catch (Exception ignored) {}
    }

    private Bitmap yuvToBitmap(Image image) {
        try {
            Image.Plane[] p = image.getPlanes();
            ByteBuffer yB = p[0].getBuffer();
            ByteBuffer uB = p[1].getBuffer();
            ByteBuffer vB = p[2].getBuffer();
            byte[] nv21 = new byte[yB.remaining()+uB.remaining()+vB.remaining()];
            yB.get(nv21, 0, yB.remaining());
            vB.get(nv21, yB.capacity(), vB.remaining());
            uB.get(nv21, yB.capacity()+vB.capacity(), uB.remaining());
            YuvImage yuv = new YuvImage(nv21, ImageFormat.NV21,
                image.getWidth(), image.getHeight(), null);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            yuv.compressToJpeg(new Rect(0,0,image.getWidth(),image.getHeight()), 80, out);
            byte[] b = out.toByteArray();
            return BitmapFactory.decodeByteArray(b, 0, b.length);
        } catch (Exception e) { return null; }
    }

    @Nullable @Override public IBinder onBind(Intent i) { return null; }

    @Override
    public void onDestroy() {
        if (cameraDevice   != null) cameraDevice.close();
        if (imageReader    != null) imageReader.close();
        if (cameraThread   != null) cameraThread.quitSafely();
        if (handLandmarker != null) handLandmarker.close();
        super.onDestroy();
    }
}
