allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// android.builtInKotlin=false (gradle.properties) is needed by plugins that
// apply KGP themselves, but file_picker assumes AGP 9's built-in Kotlin and
// applies nothing, so its Kotlin sources (FilePickerPlugin) were never
// compiled. Apply KGP to it here, as soon as AGP is applied.
subprojects {
    if (project.name == "file_picker") {
        pluginManager.withPlugin("com.android.library") {
            pluginManager.apply("org.jetbrains.kotlin.android")
        }
    }
}
// desktop_drop 0.4.4 pins compileSdk 33, but it depends on AndroidX artifacts
// that require 34+. Override to the app's compileSdk to satisfy AAR metadata checks.
subprojects {
    if (project.name == "desktop_drop") {
        pluginManager.withPlugin("com.android.library") {
            extensions.findByName("android")?.let { androidExtension ->
                androidExtension.javaClass.methods
                    .firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
                    ?.invoke(androidExtension, 37)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
