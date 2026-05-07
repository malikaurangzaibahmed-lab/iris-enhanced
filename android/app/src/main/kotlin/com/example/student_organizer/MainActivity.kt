package com.example.student_organizer

import android.media.AudioAttributes
import android.media.AudioManager
import android.content.res.AssetFileDescriptor
import android.media.MediaPlayer
import android.app.DownloadManager
import android.os.Environment
import android.webkit.MimeTypeMap
import android.webkit.URLUtil
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import kotlin.random.Random

import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec
import android.content.Context
import android.view.View
import com.qmdeve.liquidglass.widget.LiquidGlassView

class MainActivity : FlutterFragmentActivity() {
	private var uiMediaPlayer: MediaPlayer? = null
	private val uiAssetCache = mutableMapOf<String, String>()

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		flutterEngine.platformViewsController.registry.registerViewFactory(
			"android_liquid_glass",
			LiquidGlassViewFactory()
		)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "iris_notification")
			.setMethodCallHandler { call, result ->
				if (call.method == "updateNotification") {
					val title = call.argument<String>("title") ?: "IRIS Class Tracker"
					val line1 = call.argument<String>("line1") ?: ""
					val line2 = call.argument<String>("line2") ?: ""
					val progress = call.argument<Int>("progress") ?: 0
					val isLive = call.argument<Boolean>("isLive") ?: false

					NotificationHelper.showOrUpdate(
						context = this,
						title = title,
						line1 = line1,
						line2 = line2,
						progress = progress,
						isLive = isLive
					)
					result.success(null)
				} else {
					result.notImplemented()
				}
			}

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "iris/ui_sound_channel")
			.setMethodCallHandler { call, result ->
				if (call.method == "playTone") {
					val toneName = call.argument<String>("tone") ?: "click"
					playUiTone(toneName)
					result.success(null)
				} else {
					result.notImplemented()
				}
			}

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "iris/print")
			.setMethodCallHandler { call, result ->
				if (call.method == "printPdf") {
					val filePath = call.argument<String>("filePath") ?: return@setMethodCallHandler result.error("INVALID", "File path required", null)
					val jobName = call.argument<String>("jobName") ?: "IRIS Print Job"
					
					try {
						val file = File(filePath)
						if (!file.exists()) {
							return@setMethodCallHandler result.error("NOT_FOUND", "PDF file not found", null)
						}

						// Get file URI using FileProvider
						val uri = FileProvider.getUriForFile(
							this@MainActivity,
							"${packageName}.fileprovider",
							file
						)

						// Create print intent
						val printIntent = Intent()
						printIntent.action = "android.intent.action.PRINT"
						printIntent.setDataAndType(uri, "application/pdf")
						printIntent.flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
						printIntent.putExtra(Intent.EXTRA_TITLE, jobName)

						startActivity(printIntent)
						result.success(null)
					} catch (e: Exception) {
						result.error("PRINT_ERROR", e.message, null)
					}
				} else {
					result.notImplemented()
				}
			}

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "iris/download")
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"enqueueSystemDownload" -> {
						try {
							val url = call.argument<String>("url")
							if (url.isNullOrBlank()) {
								result.error("INVALID", "url is required", null)
								return@setMethodCallHandler
							}

							val userAgent = call.argument<String>("userAgent") ?: ""
							val referer = call.argument<String>("referer") ?: ""
							val cookie = call.argument<String>("cookie") ?: ""
							val requestedFileName = call.argument<String>("fileName") ?: ""

							val finalFileName = if (requestedFileName.isNotBlank()) {
								requestedFileName
							} else {
								URLUtil.guessFileName(url, null, null)
							}

							val request = DownloadManager.Request(Uri.parse(url)).apply {
								setTitle(finalFileName)
								setDescription("Downloading file")
								setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
								setAllowedOverMetered(true)
								setAllowedOverRoaming(true)
								setVisibleInDownloadsUi(true)
								allowScanningByMediaScanner()
								setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, finalFileName)

								if (userAgent.isNotBlank()) {
									addRequestHeader("User-Agent", userAgent)
								}
								if (referer.isNotBlank()) {
									addRequestHeader("Referer", referer)
								}
								if (cookie.isNotBlank()) {
									addRequestHeader("Cookie", cookie)
								}

								val extension = MimeTypeMap.getFileExtensionFromUrl(finalFileName)
								if (!extension.isNullOrBlank()) {
									val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.lowercase())
									if (!mime.isNullOrBlank()) {
										setMimeType(mime)
									}
								}
							}

							val manager = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
							val downloadId = manager.enqueue(request)
							val expectedPath = File(
								Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
								finalFileName
							).absolutePath

							result.success(
								mapOf(
									"downloadId" to downloadId,
									"fileName" to finalFileName,
									"filePath" to expectedPath,
								)
							)
						} catch (e: Exception) {
							result.error("ENQUEUE_FAILED", e.message, null)
						}
					}
					"openSystemDownloads" -> {
						try {
							val intent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS)
							intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
							startActivity(intent)
							result.success(true)
						} catch (e: Exception) {
							result.error("OPEN_FAILED", e.message, null)
						}
					}
					"querySystemDownload" -> {
						try {
							val rawId = call.argument<Number>("downloadId")
							val id = rawId?.toLong()
							if (id == null || id <= 0L) {
								result.error("INVALID", "downloadId is required", null)
								return@setMethodCallHandler
							}

							val manager = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
							val query = DownloadManager.Query().setFilterById(id)
							val cursor = manager.query(query)
							cursor.use { c ->
								if (c == null || !c.moveToFirst()) {
									result.success(
										mapOf(
											"exists" to false,
											"status" to "not_found",
										)
									)
									return@use
								}

								val statusInt = c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
								val reason = c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
								val title = c.getString(c.getColumnIndexOrThrow(DownloadManager.COLUMN_TITLE)) ?: ""
								val localUri = c.getString(c.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI)) ?: ""

								val mappedStatus = when (statusInt) {
									DownloadManager.STATUS_PENDING -> "queued"
									DownloadManager.STATUS_RUNNING -> "running"
									DownloadManager.STATUS_PAUSED -> "paused"
									DownloadManager.STATUS_SUCCESSFUL -> "completed"
									DownloadManager.STATUS_FAILED -> "failed"
									else -> "unknown"
								}

								result.success(
									mapOf(
										"exists" to true,
										"status" to mappedStatus,
										"reason" to reason,
										"title" to title,
										"localUri" to localUri,
									)
								)
							}
						} catch (e: Exception) {
							result.error("QUERY_FAILED", e.message, null)
						}
					}
					else -> result.notImplemented()
				}
			}
	}

	private fun playUiTone(toneName: String) {
		try {
			uiMediaPlayer?.release()
			uiMediaPlayer = null

			val assetPath = resolveToneAssetPath(toneName)
			if (assetPath == null) {
				// Fallback to system sound if tone file not found
				playSystemSound()
				return
			}

			val volume = when (toneName) {
				"sfx_nav_soft" -> 0.10f
				"sfx_nav_click" -> 0.12f
				"sfx_confirm" -> 0.10f
				"ui_toggle_soft" -> 0.06f
				"ui_toggle_click" -> 0.14f
				"ui_toggle_confirm" -> 0.13f
				"ui_sfx_laser" -> 0.07f
				"ui_sfx_coins" -> 0.10f
				"ui_sfx_nasa" -> 0.06f
				else -> 0.10f
			}

			try {
				val cachePath = uiAssetCache[assetPath] ?: copyAssetToCache(assetPath).also {
					uiAssetCache[assetPath] = it
				}

				val player = MediaPlayer().apply {
					setAudioAttributes(
						AudioAttributes.Builder()
							.setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
							.setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
							.build()
					)
					setDataSource(cachePath)
					setVolume(volume, volume)
					isLooping = false
					prepare()
					if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
						try {
							val drift = when (toneName) {
								"sfx_confirm", "ui_toggle_confirm" -> 0.01f
								else -> 0.02f
							}
							val rate = (1.0f + ((Random.nextFloat() * 2f) - 1f) * drift).coerceIn(0.97f, 1.03f)
							playbackParams = playbackParams.setSpeed(rate)
						} catch (_: Exception) {
							// Optional enhancement only.
						}
					}
				}

				uiMediaPlayer = player
				player.setOnCompletionListener {
					it.release()
					if (uiMediaPlayer === it) uiMediaPlayer = null
				}
				player.start()
			} catch (e: Exception) {
				// Asset playback failed, use system sound fallback
				playSystemSound()
			}
		} catch (e: Exception) {
			// Complete failure, try system sound
			try {
				playSystemSound()
			} catch (_: Exception) {
				// Silent final fallback
			}
		}
	}

	private fun playSystemSound() {
		try {
			val audioManager = getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager
			audioManager.playSoundEffect(android.media.AudioManager.FX_KEY_CLICK, 0.7f)
		} catch (_: Exception) {
			// Silent if system sound fails
		}
	}

	private fun resolveToneAssetPath(toneName: String): String? {
		// Try pro pack variants first
		resolveToneAssetFromPack(toneName)?.let { return it }

		val fallbackLegacy = when (toneName) {
			"sfx_nav_soft" -> listOf("flutter_assets/assets/sfx_nav_soft.ogg", "flutter_assets/assets/ui_toggle_soft.wav")
			"sfx_nav_click" -> listOf("flutter_assets/assets/sfx_nav_click.ogg", "flutter_assets/assets/ui_toggle_click.wav")
			"sfx_confirm" -> listOf("flutter_assets/assets/sfx_confirm.ogg")
			"ui_toggle_soft" -> listOf("flutter_assets/assets/ui_toggle_soft.wav", "flutter_assets/assets/ui_toggle_soft.mp3")
			"ui_toggle_click" -> listOf("flutter_assets/assets/ui_toggle_click.wav", "flutter_assets/assets/ui_toggle_click.mp3")
			"ui_toggle_confirm" -> listOf("flutter_assets/assets/sfx_confirm.ogg")
			"ui_sfx_laser" -> listOf("flutter_assets/assets/ui_sfx/laser.wav")
			"ui_sfx_coins" -> listOf("flutter_assets/assets/ui_sfx/coins.wav")
			"ui_sfx_nasa" -> listOf("flutter_assets/assets/ui_sfx/nasa_on_a_mission.mp3")
			else -> listOf("flutter_assets/assets/ui_toggle_click.wav")
		}

		// Try legacy fallback assets
		for (candidate in fallbackLegacy) {
			try {
				assets.open(candidate).close()
				return candidate
			} catch (_: Exception) {
				// Try next candidate path.
			}
		}

		return null
	}

	private fun resolveToneAssetFromPack(toneName: String): String? {
		val bases = when (toneName) {
			"sfx_nav_soft" -> listOf("nav_soft", "tap_soft")
			"sfx_nav_click", "ui_toggle_click" -> listOf("nav_click", "tap_click")
			"sfx_confirm", "ui_toggle_confirm" -> listOf("confirm", "success")
			"ui_toggle_soft" -> listOf("toggle_soft", "switch_soft")
			"ui_sfx_laser" -> listOf("laser", "digital_laser")
			"ui_sfx_coins" -> listOf("coins", "digital_coin")
			"ui_sfx_nasa" -> listOf("mission", "ambient_mission")
			else -> listOf("nav_click")
		}

		val extensions = listOf("ogg", "wav", "mp3", "m4a")
		val candidates = mutableListOf<String>()
		for (base in bases) {
			for (suffix in listOf("", "_1", "_2", "_3", "_4")) {
				for (ext in extensions) {
					candidates += "flutter_assets/assets/ui_sfx_pack/${base}${suffix}.${ext}"
				}
			}
		}

		val available = candidates.filter { assetExists(it) }
		if (available.isEmpty()) return null
		return available.random()
	}

	private fun assetExists(assetPath: String): Boolean {
		return try {
			assets.open(assetPath).close()
			true
		} catch (_: Exception) {
			false
		}
	}

	private fun copyAssetToCache(assetPath: String): String {
		val cacheFile = File(cacheDir, assetPath.substringAfterLast('/'))
		if (cacheFile.exists() && cacheFile.length() > 0) {
			return cacheFile.absolutePath
		}

		assets.open(assetPath).use { input ->
			FileOutputStream(cacheFile).use { output ->
				input.copyTo(output)
			}
		}

		return cacheFile.absolutePath
	}
}

class LiquidGlassPlatformView(val context: Context, id: Int, creationParams: Map<String?, Any?>?) : PlatformView {
    private var liquidGlassView: LiquidGlassView? = null

    init {
        try {
            // Android 13+ (Tiramisu) is required for AGSL RenderEffect support
            if (android.os.Build.VERSION.SDK_INT >= 33) {
                liquidGlassView = LiquidGlassView(context).apply {
                    val radius = (creationParams?.get("radius") as? Number)?.toFloat() ?: 30f
                    val blur = (creationParams?.get("blurRadius") as? Number)?.toFloat() ?: 4.0f
                    val rHeight = (creationParams?.get("refractionHeight") as? Number)?.toFloat() ?: 45f
                    val rAmount = (creationParams?.get("refractionAmount") as? Number)?.toFloat() ?: 35f
                    val tAlpha = (creationParams?.get("tintAlpha") as? Number)?.toFloat() ?: 0.08f
                    
                    setCornerRadius(radius)
                    setBlurRadius(blur)
                    setRefractionHeight(rHeight)
                    // setRefractionAmount(rAmount) // commented out: method missing
                    setTintAlpha(tAlpha)
                    // setTintColor(android.graphics.Color.argb(255, 255, 255, 255)) // commented out: method missing
                    setDispersion(0.65f)
                    // setChromaMultiplier(1.12f) // commented out: method missing
                    // setContrast(0.06f) // commented out: method missing
                    // setChromaticAberration(0.45f) // commented out: method missing
                    
                    // REVOLUTIONARY FIX: Find the actual FlutterView surface
                    (context as? android.app.Activity)?.let { activity ->
                        val flutterView = findFlutterView(activity.findViewById(android.R.id.content))
                        flutterView?.let { 
                            bind(it as android.view.ViewGroup) 
                            android.util.Log.d("IRIS_NATIVE", "Successfully bound LiquidGlass to Flutter Surface")
                        } ?: run {
                            // Fallback to root content if FlutterView detection fails
                            val root = activity.findViewById<android.view.ViewGroup>(android.R.id.content)
                            bind(root)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("IRIS_NATIVE", "Native LiquidGlass Critical Failure: ${e.message}")
        }
    }
    
    private fun findFlutterView(view: View?): View? {
        if (view == null) return null
        if (view.javaClass.name.contains("FlutterView")) return view
        if (view is android.view.ViewGroup) {
            for (i in 0 until view.childCount) {
                val found = findFlutterView(view.getChildAt(i))
                if (found != null) return found
            }
        }
        return null
    }
    
    override fun getView(): View = liquidGlassView ?: View(context)
    override fun dispose() {}
}

class LiquidGlassViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<String?, Any?>
        return LiquidGlassPlatformView(context, viewId, creationParams)
    }
}
