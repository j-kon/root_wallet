plugins {
    `kotlin-dsl`
}

repositories {
    google()
    mavenCentral()
    gradlePluginPortal()
}

gradlePlugin {
    plugins {
        create("flutterPluginCompat") {
            id = "rootwallet.flutter-plugin-compat"
            implementationClass = "FlutterPlugin"
        }
    }
}
