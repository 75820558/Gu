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
    public static final int SWIPE_DOWN = 1;
    public static final int SWIPE_UP   = 2;
    public static final int TAP_LIKE   = 3;

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

    private void performSwipeDown() {
        int w = getResources().getDisplayMetrics().widthPixels;
        int h = getResources().getDisplayMetrics().heightPixels;
        Path path = new Path();
        path.moveTo(w / 2f, h * 0.3f);
        path.lineTo(w / 2f, h * 0.7f);
        dispatch(path, 300);
    }

    private void performSwipeUp() {
        int w = getResources().getDisplayMetrics().widthPixels;
        int h = getResources().getDisplayMetrics().heightPixels;
        Path path = new Path();
        path.moveTo(w / 2f, h * 0.7f);
        path.lineTo(w / 2f, h * 0.3f);
        dispatch(path, 300);
    }

    private void performDoubleTap() {
        int w = getResources().getDisplayMetrics().widthPixels;
        int h = getResources().getDisplayMetrics().heightPixels;
        Path p1 = new Path(); p1.moveTo(w / 2f, h / 2f);
        Path p2 = new Path(); p2.moveTo(w / 2f, h / 2f);
        GestureDescription.Builder b = new GestureDescription.Builder();
        b.addStroke(new GestureDescription.StrokeDescription(p1,   0, 50));
        b.addStroke(new GestureDescription.StrokeDescription(p2, 150, 50));
        dispatchGesture(b.build(), null, null);
    }

    private void dispatch(Path path, long dur) {
        GestureDescription.Builder b = new GestureDescription.Builder();
        b.addStroke(new GestureDescription.StrokeDescription(path, 0, dur));
        dispatchGesture(b.build(), null, null);
    }

    @Override public void onAccessibilityEvent(AccessibilityEvent e) {}
    @Override public void onInterrupt() {}

    @Override
    public void onDestroy() {
        if (receiver != null) unregisterReceiver(receiver);
        super.onDestroy();
    }
}
