package com.chairup.android.integration.wear

import android.content.Context
import com.chairup.android.BuildConfig
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Wear Engine P2P — reflection API для совместимости версий HMS.
 */
@Singleton
class WearEngineBridge @Inject constructor(
    @ApplicationContext private val context: Context,
) : WearBridge {

    private var listener: ((WearMicroDone) -> Unit)? = null
    private var p2pClient: Any? = null

    init {
        if (BuildConfig.HMS_ENABLED) initWearEngine()
    }

    override fun setMessageListener(listener: (WearMicroDone) -> Unit) {
        this.listener = listener
    }

    override suspend fun sendState(state: WearStatePush): Result<Unit> =
        sendPayload(WearMessageCodec.encodeState(state))

    override suspend fun sendStartMicro(slotIndex: Int, targetSec: Int): Result<Unit> {
        val json = org.json.JSONObject()
            .put("v", 1)
            .put("type", "START_MICRO")
            .put("ts", System.currentTimeMillis())
            .put("slotIndex", slotIndex)
            .put("targetSec", targetSec)
            .toString()
        return sendPayload(json)
    }

    private suspend fun sendPayload(payload: String): Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            if (!BuildConfig.HMS_ENABLED) {
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .putString("last_payload", payload)
                    .apply()
                return@runCatching
            }
            val client = p2pClient ?: error("Wear Engine недоступен")
            val callback = java.lang.reflect.Proxy.newProxyInstance(
                client.javaClass.classLoader,
                arrayOf(Class.forName("com.huawei.wearengine.p2p.SendCallback")),
            ) { _, method, _ ->
                if (method.name == "onSendResult") Unit else null
            }
            client.javaClass.getMethod(
                "send",
                String::class.java,
                ByteArray::class.java,
                Class.forName("com.huawei.wearengine.p2p.SendCallback"),
            ).invoke(client, WATCH_PKG, payload.toByteArray(Charsets.UTF_8), callback)
        }
    }

    private fun initWearEngine() {
        runCatching {
            val hiWear = Class.forName("com.huawei.wearengine.HiWear")
            p2pClient = hiWear.getMethod("getP2pClient", Context::class.java).invoke(null, context)
            val receiver = java.lang.reflect.Proxy.newProxyInstance(
                p2pClient!!.javaClass.classLoader,
                arrayOf(Class.forName("com.huawei.wearengine.p2p.Receiver")),
            ) { _, method, args ->
                if (method.name == "onReceiveMessage" && args != null && args.size >= 2) {
                    val bytes = args[1] as? ByteArray ?: return@newProxyInstance null
                    WearMessageCodec.decode(String(bytes, Charsets.UTF_8))?.let { listener?.invoke(it) }
                }
                null
            }
            p2pClient!!.javaClass.getMethod(
                "registerReceiver",
                Class.forName("com.huawei.wearengine.p2p.Receiver"),
            ).invoke(p2pClient, receiver)
        }
    }

    companion object {
        private const val PREFS = "wear_bridge"
        private const val WATCH_PKG = "com.chairup.watch"
    }
}
