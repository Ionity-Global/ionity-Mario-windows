package today.ionity.mariosounds

/*
 * Ionity watermark overlay — bottom-right, touch-through.
 * (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd · ionity.today
 */

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import android.widget.ImageView

class WatermarkService : Service() {

    private var wm: WindowManager? = null
    private var view: ImageView? = null

    override fun onCreate() {
        super.onCreate()
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        view = ImageView(this).apply {
            setImageResource(R.drawable.ic_ionity)
            alpha = 0.55f
        }
        val d = resources.displayMetrics.density
        val params = WindowManager.LayoutParams(
            (110 * d).toInt(), (110 * d).toInt(),
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.END
            x = (12 * d).toInt(); y = (24 * d).toInt()
        }
        try { wm?.addView(view, params) } catch (_: Exception) { stopSelf() }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int) = START_STICKY

    override fun onDestroy() {
        try { view?.let { wm?.removeView(it) } } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
