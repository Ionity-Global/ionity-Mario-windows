package today.ionity.mariosounds

/*
 * Ionity Mario Sounds — Android applier
 * (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd · ionity.today
 * Sounds (c) Nintendo — non-commercial fan project, personal use.
 *
 *  · Soundboard (tap = play, long-press = set as ringtone/notification/alarm)
 *  · One-tap "Apply Mario preset" (ringtone/notification/alarm)
 *  · Ionity watermark overlay (bottom-right, toggleable) — WatermarkService
 */

import android.app.AlertDialog
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Bundle
import android.provider.MediaStore
import android.provider.Settings
import android.view.Gravity
import android.widget.*
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    private var player: MediaPlayer? = null
    private val prefs by lazy { getSharedPreferences("ionity", Context.MODE_PRIVATE) }

    private val sounds = listOf(
        "smb_1_up", "smb_bowserfalls", "smb_bowserfire", "smb_breakblock", "smb_bump",
        "smb_coin", "smb_fireball", "smb_fireworks", "smb_flagpole", "smb_gameover",
        "smb_jump_small", "smb_jump_super", "smb_kick", "smb_mariodie", "smb_pause",
        "smb_pipe", "smb_powerup", "smb_powerup_appears", "smb_stage_clear", "smb_stomp",
        "smb_vine", "smb_warning", "smb_world_clear"
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#0d1b2a"))
            setPadding(40, 60, 40, 40)
        }

        root.addView(TextView(this).apply {
            text = "IONITY × MARIO SOUNDS"
            textSize = 22f; setTextColor(Color.parseColor("#00c6ff"))
            gravity = Gravity.CENTER
        })
        root.addView(TextView(this).apply {
            text = "Building Tomorrow, Today · ionity.today"
            textSize = 12f; setTextColor(Color.parseColor("#8fb8d8"))
            gravity = Gravity.CENTER; setPadding(0, 4, 0, 24)
        })

        // watermark toggle
        root.addView(Switch(this).apply {
            text = "Ionity watermark overlay"
            setTextColor(Color.WHITE)
            isChecked = prefs.getBoolean("watermark", false)
            setOnCheckedChangeListener { _, on ->
                prefs.edit().putBoolean("watermark", on).apply()
                if (on) startWatermark() else stopService(Intent(this@MainActivity, WatermarkService::class.java))
            }
        })

        // preset button
        root.addView(Button(this).apply {
            text = "★ Apply Mario preset (ringtone · notification · alarm)"
            setBackgroundColor(Color.parseColor("#00c6ff")); setTextColor(Color.parseColor("#0d1b2a"))
            setOnClickListener { applyPreset() }
        })

        root.addView(TextView(this).apply {
            text = "Tap = play · Long-press = set as ringtone / notification / alarm"
            textSize = 12f; setTextColor(Color.parseColor("#8fb8d8")); setPadding(0, 20, 0, 8)
        })

        val list = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        sounds.forEach { res ->
            list.addView(Button(this).apply {
                text = res.removePrefix("smb_").replace('_', ' ').uppercase()
                setBackgroundColor(Color.parseColor("#16213e")); setTextColor(Color.WHITE)
                setOnClickListener { play(res) }
                setOnLongClickListener { askSetAs(res); true }
                layoutParams = LinearLayout.LayoutParams(-1, -2).apply { setMargins(0, 6, 0, 6) }
            })
        }
        root.addView(ScrollView(this).apply { addView(list) })

        setContentView(ScrollView(this).apply { addView(root) })

        if (prefs.getBoolean("watermark", false)) startWatermark()
    }

    private fun play(res: String) {
        player?.release()
        player = MediaPlayer.create(this, resources.getIdentifier(res, "raw", packageName))
        player?.start()
    }

    private fun startWatermark() {
        if (!Settings.canDrawOverlays(this)) {
            startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
            Toast.makeText(this, "Allow overlay for Ionity, then toggle again", Toast.LENGTH_LONG).show()
            return
        }
        startService(Intent(this, WatermarkService::class.java))
    }

    private fun ensureWriteSettings(): Boolean {
        if (Settings.System.canWrite(this)) return true
        startActivity(Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS, Uri.parse("package:$packageName")))
        Toast.makeText(this, "Allow 'Modify system settings' for Ionity, then retry", Toast.LENGTH_LONG).show()
        return false
    }

    private fun askSetAs(res: String) {
        val types = arrayOf("Ringtone", "Notification", "Alarm")
        AlertDialog.Builder(this)
            .setTitle("Set '${res.removePrefix("smb_").replace('_', ' ')}' as…")
            .setItems(types) { _, i ->
                val t = when (i) {
                    0 -> RingtoneManager.TYPE_RINGTONE
                    1 -> RingtoneManager.TYPE_NOTIFICATION
                    else -> RingtoneManager.TYPE_ALARM
                }
                setAs(res, t)
            }.show()
    }

    private fun applyPreset() {
        if (!ensureWriteSettings()) return
        setAs("smb_world_clear", RingtoneManager.TYPE_RINGTONE)
        setAs("smb_coin", RingtoneManager.TYPE_NOTIFICATION)
        setAs("smb_warning", RingtoneManager.TYPE_ALARM)
        play("smb_powerup")
        Toast.makeText(this, "Preset applied — it's-a your phone now!", Toast.LENGTH_LONG).show()
    }

    private fun setAs(res: String, type: Int) {
        if (!ensureWriteSettings()) return
        try {
            val name = "Mario " + res.removePrefix("smb_").replace('_', ' ')
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, "$name.wav")
                put(MediaStore.MediaColumns.MIME_TYPE, "audio/wav")
                put(MediaStore.MediaColumns.RELATIVE_PATH, "Ringtones/IonityMario")
                put(MediaStore.Audio.Media.IS_RINGTONE, type == RingtoneManager.TYPE_RINGTONE)
                put(MediaStore.Audio.Media.IS_NOTIFICATION, type == RingtoneManager.TYPE_NOTIFICATION)
                put(MediaStore.Audio.Media.IS_ALARM, type == RingtoneManager.TYPE_ALARM)
            }
            // reuse if already inserted
            val resolver = contentResolver
            var uri: Uri? = null
            resolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.MediaColumns._ID),
                "${MediaStore.MediaColumns.DISPLAY_NAME}=? AND ${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?",
                arrayOf("$name.wav", "%IonityMario%"), null
            )?.use { c ->
                if (c.moveToFirst())
                    uri = Uri.withAppendedPath(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, c.getLong(0).toString())
            }
            if (uri == null) {
                uri = resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
                resolver.openOutputStream(uri!!)?.use { out ->
                    resources.openRawResource(resources.getIdentifier(res, "raw", packageName))
                        .use { it.copyTo(out) }
                }
            }
            RingtoneManager.setActualDefaultRingtoneUri(this, type, uri)
            Toast.makeText(this, "$name set ✓", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Toast.makeText(this, "Failed: ${e.message}", Toast.LENGTH_LONG).show()
        }
    }

    override fun onDestroy() { player?.release(); super.onDestroy() }
}
