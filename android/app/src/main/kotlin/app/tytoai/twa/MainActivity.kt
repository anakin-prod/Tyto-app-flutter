package app.tytoai.twa

import android.media.AudioAttributes
import android.media.SoundPool
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Collections

/**
 * L'activité principale. Elle ajoute un seul petit canal, « app.tytoai/son » :
 * jouer un court son de l'appli (le « hou » de la chouette à l'envoi d'un
 * message). Le son vient des ressources res/raw. Il est joué comme un son
 * d'interface : il ne coupe pas la musique en cours, suit le volume des
 * notifications et se tait en mode silencieux.
 */
class MainActivity : FlutterActivity() {
    private var pool: SoundPool? = null
    private val sons = HashMap<String, Int>()
    private val prets: MutableSet<Int> = Collections.synchronizedSet(HashSet<Int>())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        preparerSons()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.tytoai/son")
            .setMethodCallHandler { call, result ->
                if (call.method == "jouer") {
                    val nom = call.argument<String>("nom")
                    val volume = (call.argument<Double>("volume") ?: 0.7).toFloat()
                    jouer(nom, volume)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    /** Charge les sons une fois, pour qu'ils partent sans délai. */
    private fun preparerSons() {
        if (pool != null) return
        val attributs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val nouveau = SoundPool.Builder()
            .setMaxStreams(2)
            .setAudioAttributes(attributs)
            .build()
        nouveau.setOnLoadCompleteListener { _, identifiant, statut ->
            if (statut == 0) prets.add(identifiant)
        }
        for (nom in listOf("tyto_hou_chouette", "tyto_hou_hibou")) {
            val ressource = resources.getIdentifier(nom, "raw", packageName)
            if (ressource != 0) sons[nom] = nouveau.load(this, ressource, 1)
        }
        pool = nouveau
    }

    private fun jouer(nom: String?, volume: Float) {
        if (nom == null) return
        val identifiant = sons[nom] ?: return
        if (!prets.contains(identifiant)) return
        pool?.play(identifiant, volume, volume, 1, 0, 1.0f)
    }

    override fun onDestroy() {
        pool?.release()
        pool = null
        sons.clear()
        prets.clear()
        super.onDestroy()
    }
}
