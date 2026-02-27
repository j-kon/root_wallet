import org.gradle.api.Plugin
import org.gradle.api.Project

/**
 * Compatibility shim for plugins that look up a Flutter Gradle plugin by class name only.
 *
 * bdk_flutter's CargoKit script searches for `plugin.class.name == "FlutterPlugin"`.
 * The modern Flutter plugin class is `com.flutter.gradle.FlutterPlugin`, so discovery fails and
 * Rust native libraries are not built. This shim provides the expected class name and the minimal
 * API CargoKit uses (`project` + `getTargetPlatforms()`).
 */
class FlutterPlugin : Plugin<Project> {
    lateinit var project: Project
        private set

    override fun apply(target: Project) {
        project = target
    }

    @Suppress("unused")
    fun getTargetPlatforms(): List<String> {
        val fromAbiFilters =
            resolveAbiFilters().mapNotNull(::toCargoTarget).distinct()

        // Mirrors Flutter defaults when ABI filters are not explicitly set.
        if (fromAbiFilters.isEmpty()) {
            return listOf("android-arm", "android-arm64")
        }

        return fromAbiFilters
    }

    private fun resolveAbiFilters(): Set<String> {
        return runCatching {
            val androidExt = project.extensions.findByName("android") ?: return emptySet()
            val defaultConfig = invokeZeroArg(androidExt, "getDefaultConfig") ?: return emptySet()
            val ndk = invokeZeroArg(defaultConfig, "getNdk") ?: return emptySet()
            val abiFilters = invokeZeroArg(ndk, "getAbiFilters")

            when (abiFilters) {
                is Set<*> -> abiFilters.filterIsInstance<String>().toSet()
                is Collection<*> -> abiFilters.filterIsInstance<String>().toSet()
                else -> emptySet()
            }
        }.getOrElse { emptySet() }
    }

    private fun invokeZeroArg(target: Any, methodName: String): Any? {
        val method =
            target.javaClass.methods.firstOrNull {
                it.name == methodName && it.parameterCount == 0
            } ?: return null
        return method.invoke(target)
    }

    private fun toCargoTarget(abi: String): String? {
        return when (abi) {
            "armeabi-v7a" -> "android-arm"
            "arm64-v8a" -> "android-arm64"
            "x86" -> "android-x86"
            "x86_64" -> "android-x64"
            else -> null
        }
    }
}
