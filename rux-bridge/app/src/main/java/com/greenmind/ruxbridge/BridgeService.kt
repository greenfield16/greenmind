package com.greenmind.ruxbridge

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import com.leitianpai.robotsdk.RobotService
import com.leitianpai.robotsdk.message.ActionMessage
import com.leitianpai.robotsdk.message.AntennaLightMessage
import com.leitianpai.robotsdk.commandlib.Light
import fi.iki.elonen.NanoHTTPD
import org.json.JSONObject

class BridgeService : Service() {

    private var httpServer: RuxHttpServer? = null
    private var robotService: RobotService? = null

    override fun onCreate() {
        super.onCreate()
        robotService = RobotService.getInstance(this)
        httpServer = RuxHttpServer(8080, robotService!!)
        httpServer?.start()
        Log.d(TAG, "RUX Bridge started on port 8080")
    }

    override fun onDestroy() {
        httpServer?.stop()
        RobotService.getInstance(applicationContext).unbindService()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val TAG = "RuxBridge"
    }
}

class RuxHttpServer(port: Int, private val robot: RobotService) : NanoHTTPD(port) {

    override fun serve(session: IHTTPSession): Response {
        val uri = session.uri
        val method = session.method

        // Parse body JSON
        val body = try {
            val map = mutableMapOf<String, String>()
            session.parseBody(map)
            JSONObject(map["postData"] ?: "{}")
        } catch (e: Exception) {
            JSONObject()
        }

        Log.d("RuxBridge", "→ $method $uri | body=$body")

        return try {
            when {
                // ── Nói ─────────────────────────────────────────────
                uri == "/speak" && method == Method.POST -> {
                    val text = body.optString("text", "xin chào")
                    robot.robotPlayTTs(text)
                    ok("Speaking: $text")
                }

                // ── Di chuyển ────────────────────────────────────────
                uri == "/move" && method == Method.POST -> {
                    val dir = body.optString("dir", "stop")
                    val steps = body.optInt("steps", 3)
                    val msg = ActionMessage()
                    when (dir) {
                        "forward"  -> msg[63, 2] = steps
                        "backward" -> msg[63, 3] = steps
                        "left"     -> msg[63, 4] = steps
                        "right"    -> msg[63, 5] = steps
                        else       -> return ok("Unknown direction: $dir")
                    }
                    robot.robotActionCommand(msg)
                    ok("Moving: $dir x$steps")
                }

                // ── Đèn anten ────────────────────────────────────────
                uri == "/light" && method == Method.POST -> {
                    val color = body.optString("color", "off")
                    val msg = AntennaLightMessage()
                    when (color) {
                        "red"    -> { msg.set(Light.RED);   robot.robotAntennaLight(msg) }
                        "green"  -> { msg.set(Light.GREEN); robot.robotAntennaLight(msg) }
                        "blue"   -> { msg.set(Light.BLUE);  robot.robotAntennaLight(msg) }
                        "white"  -> { msg.set(Light.WHITE); robot.robotAntennaLight(msg) }
                        "off"    -> robot.robotCloseAntennaLight()
                        else     -> return ok("Unknown color: $color")
                    }
                    ok("Light: $color")
                }

                // ── Bật/tắt motor ────────────────────────────────────
                uri == "/motor/on"  && method == Method.POST -> {
                    robot.robotOpenMotor()
                    ok("Motor ON")
                }
                uri == "/motor/off" && method == Method.POST -> {
                    robot.robotCloseMotor()
                    ok("Motor OFF")
                }

                // ── Animation ────────────────────────────────────────
                uri == "/dance" && method == Method.POST -> {
                    robot.sendLongCommand("speechDance", "from_third")
                    ok("Dancing!")
                }

                // ── Status ───────────────────────────────────────────
                uri == "/status" && method == Method.GET -> {
                    newFixedLengthResponse("""{"status":"ok","robot":"rux","version":"1.0"}""")
                }

                else -> newFixedLengthResponse(
                    Response.Status.NOT_FOUND, MIME_PLAINTEXT, "Unknown endpoint: $uri"
                )
            }
        } catch (e: Exception) {
            Log.e("RuxBridge", "Error: ${e.message}")
            newFixedLengthResponse(
                Response.Status.INTERNAL_ERROR, MIME_PLAINTEXT, "Error: ${e.message}"
            )
        }
    }

    private fun ok(msg: String): Response =
        newFixedLengthResponse("""{"ok":true,"msg":"$msg"}""")
}
