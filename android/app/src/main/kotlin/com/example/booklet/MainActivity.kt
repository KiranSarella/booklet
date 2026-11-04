package com.example.booklet

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors
import java.util.zip.ZipInputStream

/** SAF imports are private copies: no write permission to the source is requested. */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pickerResult: MethodChannel.Result? = null
    private var initialPath: String? = null
    private var initialError: String? = null
    private var listening = false
    private val worker = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Old sessions are no longer referenced after a process restart.
        File(cacheDir, "reader").deleteRecursively()
        receiveIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "booklet/open_file")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeInitialFile" -> {
                    listening = true
                    val error = initialError
                    initialError = null
                    if (error != null) {
                        result.error("OPEN_FAILED", error, null)
                    } else {
                        result.success(initialPath)
                        initialPath = null
                    }
                }
                "pickBooklet" -> {
                    if (pickerResult != null) {
                        result.error("BUSY", "A picker is already open", null)
                    } else {
                        pickerResult = result
                        val picker = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            // Providers do not consistently recognise custom extensions.
                            type = "*/*"
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            putExtra(Intent.EXTRA_TITLE, "Open .booklet document")
                        }
                        try { startActivityForResult(picker, 302) }
                        catch (error: Exception) { finishPicker(null, error) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiveIntent(intent)
    }

    private fun receiveIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        worker.execute {
            try {
                val path = importBooklet(uri, DocumentsContract.isTreeUri(uri))
                runOnUiThread {
                    if (listening) channel?.invokeMethod("openFile", path) else initialPath = path
                }
            } catch (error: Exception) {
                runOnUiThread {
                    if (listening) channel?.invokeMethod("openError", error.message)
                    else initialError = error.message ?: "Could not open booklet"
                }
            }
        }
    }

    @Deprecated("Used for FlutterActivity's activity result forwarding")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 301 && requestCode != 302) return
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) { finishPicker(null, null); return }
        worker.execute {
            try {
                val path = importBooklet(uri, requestCode == 301)
                runOnUiThread { finishPicker(path, null) }
            } catch (error: Exception) {
                runOnUiThread { finishPicker(null, error) }
            }
        }
    }

    private fun finishPicker(path: String?, error: Exception?) {
        val result = pickerResult
        pickerResult = null
        if (error == null) result?.success(path)
        else result?.error("OPEN_FAILED", error.message, null)
    }

    private fun importBooklet(uri: Uri, tree: Boolean): String {
        val root = File(cacheDir, "reader/${UUID.randomUUID()}").apply { mkdirs() }
        try {
            if (tree) copyTree(uri, DocumentsContract.getTreeDocumentId(uri), root, 0)
            else if (uri.scheme == "file" && File(uri.path!!).isDirectory) {
                File(uri.path!!).copyRecursively(root, overwrite = true)
            } else {
                val stream = contentResolver.openInputStream(uri) ?: error("Cannot read booklet")
                var total = 0L
                var entries = 0
                ZipInputStream(stream.buffered()).use { zip ->
                    while (true) {
                        val entry = zip.nextEntry ?: break
                        require(++entries <= 50000) { "Too many files in booklet" }
                        val target = safeChild(root, entry.name)
                        if (entry.isDirectory) target.mkdirs() else {
                            target.parentFile!!.mkdirs()
                            target.outputStream().use { output ->
                                val buffer = ByteArray(65536)
                                while (true) {
                                    val count = zip.read(buffer)
                                    if (count < 0) break
                                    total += count
                                    require(total <= 2L * 1024 * 1024 * 1024) { "Booklet is too large" }
                                    output.write(buffer, 0, count)
                                }
                            }
                        }
                        zip.closeEntry()
                    }
                }
            }
            // Accept either the package contents or one enclosing .booklet folder.
            val packageRoot = if (File(root, "content.json").isFile) root else {
                root.listFiles()?.filter { it.isDirectory && File(it, "content.json").isFile }
                    ?.singleOrNull() ?: error("Choose a valid .booklet document")
            }
            require(File(packageRoot, "content.json").isFile) { "Missing content.json" }
            return packageRoot.absolutePath
        } catch (error: Exception) {
            root.deleteRecursively()
            throw error
        }
    }

    private fun safeChild(root: File, name: String): File {
        val target = File(root, name).canonicalFile
        require(target.path.startsWith(root.canonicalPath + File.separator)) { "Invalid booklet path" }
        return target
    }

    private fun copyTree(tree: Uri, documentId: String, destination: File, depth: Int) {
        require(depth <= 64) { "Booklet folders are nested too deeply" }
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, documentId)
        val projection = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE)
        val cursor = contentResolver.query(children, projection, null, null, null)
            ?: error("Cannot read booklet folder")
        cursor.use {
            while (it.moveToNext()) {
                val id = it.getString(0)
                val name = it.getString(1)
                require(name != "." && name != ".." && !name.contains('/')) { "Invalid file name" }
                val target = safeChild(destination, name)
                if (it.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                    target.mkdirs()
                    copyTree(tree, id, target, depth + 1)
                } else {
                    val document = DocumentsContract.buildDocumentUriUsingTree(tree, id)
                    val input = contentResolver.openInputStream(document) ?: error("Cannot read $name")
                    input.use { source -> target.outputStream().use { output -> source.copyTo(output) } }
                }
            }
        }
    }
}
